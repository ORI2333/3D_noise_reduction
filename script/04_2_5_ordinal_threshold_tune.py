
#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Stage4-2.5: Ordinal tau tuning + monotonic constraint + export."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import matplotlib.pyplot as plt
import numpy as np
from lightgbm import Booster
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_recall_fscore_support
from sklearn.model_selection import train_test_split


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Ordinal tau tuning and export")
    p.add_argument("--run_dir", type=str, default=None)
    p.add_argument("--shard_dir", type=str, default=None)
    p.add_argument("--model_dir", type=str, default=None)
    p.add_argument("--out_dir", type=str, required=True)
    p.add_argument("--split_mode", type=str, choices=["random", "by_shard"], default="by_shard")
    p.add_argument("--val_shards", type=int, default=2)
    p.add_argument("--val_ratio", type=float, default=0.1)
    p.add_argument("--max_rows_per_shard", type=int, default=200000)
    p.add_argument("--seed", type=int, default=123)
    p.add_argument("--log1p_features", type=str, default="true")
    p.add_argument("--log1p_keys", type=str, default="sad1,sad2,margin,grad_energy,sum")
    p.add_argument("--drop_constant_features", type=str, default="true")
    p.add_argument("--constant_eps", type=float, default=1e-6)
    p.add_argument("--tau_min", type=float, default=0.20)
    p.add_argument("--tau_max", type=float, default=0.80)
    p.add_argument("--tau_step", type=float, default=0.02)
    p.add_argument("--search_method", type=str, choices=["per_threshold_greedy", "global_shared_tau", "coordinate_descent"], default="per_threshold_greedy")
    p.add_argument("--num_passes", type=int, default=2)
    p.add_argument("--enforce_tau_monotonic", type=str, choices=["none", "project", "constrained_search"], default="project")
    p.add_argument("--monotonic_direction", type=str, choices=["nondecreasing"], default="nondecreasing")
    p.add_argument("--objective", type=str, choices=["macro_f1", "mean_abs_class_error", "hybrid", "hybrid_tail24"], default="hybrid")
    p.add_argument("--hybrid_alpha", type=float, default=0.5)
    p.add_argument("--tail24_beta", type=float, default=0.03)
    p.add_argument("--tail24_floor", type=float, default=0.04)
    p.add_argument("--late_threshold_joint_search", type=str, default="false")
    p.add_argument("--joint_tau20_grid", type=str, default="0.56:0.72:0.02")
    p.add_argument("--joint_tau24_grid", type=str, default="0.46:0.66:0.02")
    p.add_argument("--joint_tau28_grid", type=str, default="0.40:0.60:0.02")
    p.add_argument("--save_wmap", type=str, default="true")
    p.add_argument("--viz_samples", type=int, default=10)
    p.add_argument("--mb_h", type=int, default=80)
    p.add_argument("--mb_w", type=int, default=120)
    p.add_argument("--mb_up", type=int, default=4)
    return p.parse_args()


def parse_bool(text: str) -> bool:
    return text.strip().lower() in {"1", "true", "yes", "y", "on"}


def parse_csv_keys(text: str) -> List[str]:
    return [x.strip() for x in text.split(",") if x.strip()]


def parse_range_grid(text: str) -> np.ndarray:
    parts = [p.strip() for p in text.split(":")]
    if len(parts) != 3:
        raise ValueError(f"invalid range grid: {text}")
    lo, hi, step = float(parts[0]), float(parts[1]), float(parts[2])
    if step <= 0:
        raise ValueError(f"grid step must > 0: {text}")
    return np.arange(lo, hi + 1e-8, step, dtype=np.float32)


def ensure_dirs(out_dir: Path) -> Dict[str, Path]:
    d = {"root": out_dir, "report": out_dir / "report", "figures": out_dir / "figures", "export": out_dir / "export"}
    for p in d.values():
        p.mkdir(parents=True, exist_ok=True)
    return d


def resolve_inputs(args: argparse.Namespace) -> Tuple[Path, Path]:
    run_dir = Path(args.run_dir) if args.run_dir else None
    cfg: Dict[str, Any] = {}
    if run_dir is not None:
        cfg_path = run_dir / "models" / "train_config.json"
        if cfg_path.is_file():
            with open(cfg_path, "r", encoding="utf-8") as f:
                cfg = json.load(f)
    if args.shard_dir is not None:
        shard_dir = Path(args.shard_dir)
    elif "shard_dir" in cfg:
        shard_dir = Path(cfg["shard_dir"])
    else:
        raise ValueError("missing shard_dir")
    if args.model_dir is not None:
        model_dir = Path(args.model_dir)
    elif run_dir is not None:
        model_dir = run_dir / "models"
    else:
        model_dir = Path("out_train_ord") / "models"
    if not shard_dir.is_dir():
        raise FileNotFoundError(f"shard_dir not found: {shard_dir}")
    if not model_dir.is_dir():
        raise FileNotFoundError(f"model_dir not found: {model_dir}")
    return shard_dir, model_dir


def load_shards(shard_dir: Path, max_rows_per_shard: Optional[int], seed: int) -> Dict[str, Any]:
    rng = np.random.default_rng(seed)
    files = sorted(shard_dir.glob("*.npz"))
    if not files:
        raise RuntimeError(f"no shards in {shard_dir}")
    xs: List[np.ndarray] = []
    ys: List[np.ndarray] = []
    shard_ids: List[np.ndarray] = []
    infos: List[np.ndarray] = []
    has_any_info = False
    ref_feature_names = None
    ref_w_set = None
    for sid, fp in enumerate(files):
        with np.load(fp, allow_pickle=False) as d:
            for key in ("X", "y", "feature_names", "w_set"):
                if key not in d.files:
                    raise RuntimeError(f"{fp.name} missing key: {key}")
            x_full, y_full = d["X"], d["y"]
            fn, ws = d["feature_names"], d["w_set"]
            info = d["info"] if "info" in d.files else None
            if ref_feature_names is None:
                ref_feature_names = fn
            elif not np.array_equal(ref_feature_names, fn):
                raise RuntimeError(f"{fp.name}: feature_names mismatch")
            if ref_w_set is None:
                ref_w_set = ws
            elif not np.array_equal(ref_w_set, ws):
                raise RuntimeError(f"{fp.name}: w_set mismatch")
            n = x_full.shape[0]
            if max_rows_per_shard is None or max_rows_per_shard >= n:
                idx = np.arange(n, dtype=np.int64)
            else:
                idx = rng.choice(n, size=max_rows_per_shard, replace=False)
                idx.sort()
            xs.append(x_full[idx].astype(np.float32, copy=False))
            ys.append(y_full[idx].astype(np.uint8, copy=False))
            shard_ids.append(np.full(idx.shape[0], sid, dtype=np.int32))
            if info is not None:
                has_any_info = True
                infos.append(info[idx].astype(np.int32, copy=False))
            else:
                infos.append(np.empty((idx.shape[0], 4), dtype=np.int32))
    return {
        "X": np.concatenate(xs, axis=0),
        "y": np.concatenate(ys, axis=0),
        "shard_ids": np.concatenate(shard_ids, axis=0),
        "info": np.concatenate(infos, axis=0) if has_any_info else None,
        "feature_names": ref_feature_names.astype("U"),
        "w_set": ref_w_set.astype(np.uint8),
    }

def split_data(x: np.ndarray, y: np.ndarray, shard_ids: np.ndarray, split_mode: str, val_ratio: float, val_shards: int, seed: int) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    idx_all = np.arange(x.shape[0], dtype=np.int64)
    if split_mode == "random":
        try:
            _, val_idx = train_test_split(idx_all, test_size=val_ratio, random_state=seed, stratify=y)
        except ValueError:
            _, val_idx = train_test_split(idx_all, test_size=val_ratio, random_state=seed, stratify=None)
    else:
        uniq = np.unique(shard_ids)
        if val_shards <= 0 or val_shards >= uniq.size:
            raise ValueError("val_shards must be in (0, num_shards)")
        val_sid = np.sort(uniq)[-val_shards:]
        val_idx = idx_all[np.isin(shard_ids, val_sid)]
    return x[val_idx], y[val_idx], val_idx


def apply_log1p_features(x: np.ndarray, feature_names: np.ndarray, keys: List[str]) -> np.ndarray:
    name_to_idx = {str(n): i for i, n in enumerate(feature_names.tolist())}
    out = x.copy()
    for k in keys:
        if k in name_to_idx:
            ci = name_to_idx[k]
            out[:, ci] = np.log1p(np.maximum(out[:, ci], 0.0))
    return out


def drop_constant_columns(x_train_like: np.ndarray, x_val: np.ndarray, feature_names: np.ndarray, eps: float) -> Tuple[np.ndarray, np.ndarray]:
    std = x_train_like.astype(np.float64).std(axis=0)
    keep = std >= eps
    if np.count_nonzero(keep) == 0:
        raise RuntimeError("all features are constant after filtering")
    return x_val[:, keep], feature_names[keep].astype("U")


def load_ordinal_models(model_dir: Path) -> Tuple[List[Booster], np.ndarray]:
    pats = sorted(model_dir.glob("lgbm_model_ordinal_t*_*.txt"))
    if len(pats) == 0:
        raise RuntimeError(f"no ordinal model files in {model_dir}")
    reg = re.compile(r"lgbm_model_ordinal_t\d+_(\d+)\.txt$")
    items: List[Tuple[int, Path]] = []
    for p in pats:
        m = reg.search(p.name)
        if m:
            items.append((int(m.group(1)), p))
    items.sort(key=lambda v: v[0])
    if len(items) == 0:
        raise RuntimeError(f"cannot parse threshold ids from {model_dir}")
    models = [Booster(model_file=str(p)) for _, p in items]
    thresholds = np.array([t for t, _ in items], dtype=np.uint8)
    return models, thresholds


def predict_p_gt(models: List[Booster], x: np.ndarray) -> np.ndarray:
    ps: List[np.ndarray] = []
    for model in models:
        ps.append(np.asarray(model.predict(x), dtype=np.float32))
    return np.stack(ps, axis=1)


def predict_with_tau(p_gt: np.ndarray, tau: np.ndarray, w_set: np.ndarray) -> np.ndarray:
    rank = (p_gt >= tau[None, :]).sum(axis=1)
    rank = np.clip(rank, 0, len(w_set) - 1)
    return w_set[rank].astype(np.uint8)


def build_metrics(y_true: np.ndarray, y_pred: np.ndarray, w_set: np.ndarray) -> Dict[str, Any]:
    labels = [int(w) for w in w_set.tolist()]
    acc = float(accuracy_score(y_true, y_pred))
    macro = float(f1_score(y_true, y_pred, labels=labels, average="macro", zero_division=0))
    p, r, f, s = precision_recall_fscore_support(y_true, y_pred, labels=labels, zero_division=0)
    per_class = {
        str(lbl): {"precision": float(p[i]), "recall": float(r[i]), "f1": float(f[i]), "support": int(s[i])}
        for i, lbl in enumerate(labels)
    }
    mae_class = float(np.mean(np.abs(y_pred.astype(np.int16) - y_true.astype(np.int16))))
    return {
        "accuracy": acc,
        "macro_f1": macro,
        "mean_abs_class_error": mae_class,
        "per_class": per_class,
        "tail_recall": {str(k): per_class[str(k)]["recall"] for k in (24, 28, 31) if str(k) in per_class},
    }


def objective_score(metrics: Dict[str, Any], objective: str, alpha: float, tail24_beta: float, tail24_floor: float) -> float:
    macro = float(metrics["macro_f1"])
    mae_norm = float(metrics["mean_abs_class_error"]) / 31.0
    recall_24 = float(metrics.get("per_class", {}).get("24", {}).get("recall", 0.0))
    if objective == "macro_f1":
        return macro
    if objective == "mean_abs_class_error":
        return -float(metrics["mean_abs_class_error"])
    if objective == "hybrid":
        return alpha * macro - (1.0 - alpha) * mae_norm
    # hybrid_tail24
    score = alpha * macro - (1.0 - alpha) * mae_norm + tail24_beta * recall_24
    if recall_24 < tail24_floor:
        score -= 0.02
    return score


def project_non_decreasing_pav(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    v = np.clip(x.astype(np.float64), lo, hi)
    blocks: List[List[float]] = []
    for i, val in enumerate(v.tolist()):
        blocks.append([float(i), float(i), float(val), 1.0])
        while len(blocks) >= 2 and blocks[-2][2] > blocks[-1][2]:
            b2 = blocks.pop()
            b1 = blocks.pop()
            w = b1[3] + b2[3]
            m = (b1[2] * b1[3] + b2[2] * b2[3]) / w
            blocks.append([b1[0], b2[1], m, w])
    y = np.empty_like(v)
    for b in blocks:
        y[int(b[0]): int(b[1]) + 1] = float(b[2])
    return np.clip(y, lo, hi).astype(np.float32)


def enforce_tau_monotonic(tau_unconstrained: np.ndarray, mode: str, direction: str, lo: float, hi: float) -> np.ndarray:
    if mode == "none":
        return np.clip(tau_unconstrained.astype(np.float32), lo, hi)
    if direction != "nondecreasing":
        raise ValueError(f"unsupported monotonic_direction={direction}")
    return project_non_decreasing_pav(tau_unconstrained, lo=lo, hi=hi)


def check_non_decreasing(x: np.ndarray, atol: float = 1e-8) -> bool:
    return bool(np.all(x[1:] + atol >= x[:-1]))

def save_confusion_fig(path: Path, cm: np.ndarray, labels: List[int], title: str, fmt: str) -> None:
    fig, ax = plt.subplots(figsize=(8, 6))
    im = ax.imshow(cm, interpolation="nearest", cmap="Blues")
    ax.figure.colorbar(im, ax=ax)
    ax.set(xticks=np.arange(len(labels)), yticks=np.arange(len(labels)), xticklabels=[str(x) for x in labels], yticklabels=[str(x) for x in labels], ylabel="True", xlabel="Pred", title=title)
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")
    th = cm.max() / 2.0 if cm.size > 0 else 0.0
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            ax.text(j, i, format(cm[i, j], fmt), ha="center", va="center", color="white" if cm[i, j] > th else "black", fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=160)
    plt.close(fig)


def wmap_to_img(wmap: np.ndarray, mb_up: int) -> np.ndarray:
    w_u8 = np.clip(np.rint(wmap.astype(np.float32) * (255.0 / 31.0)), 0, 255).astype(np.uint8)
    return np.kron(w_u8, np.ones((mb_up, mb_up), dtype=np.uint8))


def diff_to_img(w_pred: np.ndarray, w_true: np.ndarray, mb_up: int) -> np.ndarray:
    d = np.abs(w_pred.astype(np.int16) - w_true.astype(np.int16)).astype(np.float32)
    d_u8 = np.clip(np.rint(d * (255.0 / 31.0)), 0, 255).astype(np.uint8)
    return np.kron(d_u8, np.ones((mb_up, mb_up), dtype=np.uint8))


def save_wmap_triplet(fig_dir: Path, stem: str, w_true: np.ndarray, w_pred: np.ndarray, mb_up: int) -> None:
    img_true = wmap_to_img(w_true, mb_up)
    img_pred = wmap_to_img(w_pred, mb_up)
    img_diff = diff_to_img(w_pred, w_true, mb_up)
    plt.imsave(fig_dir / f"wmap_{stem}_oracle.png", img_true, cmap="gray", vmin=0, vmax=255)
    plt.imsave(fig_dir / f"wmap_{stem}_student.png", img_pred, cmap="gray", vmin=0, vmax=255)
    plt.imsave(fig_dir / f"wmap_{stem}_diff.png", img_diff, cmap="gray", vmin=0, vmax=255)
    fig, axs = plt.subplots(1, 3, figsize=(12, 4))
    axs[0].imshow(img_true, cmap="gray", vmin=0, vmax=255)
    axs[0].set_title("Oracle")
    axs[1].imshow(img_pred, cmap="gray", vmin=0, vmax=255)
    axs[1].set_title("Student")
    axs[2].imshow(img_diff, cmap="gray", vmin=0, vmax=255)
    axs[2].set_title("|Diff|")
    for a in axs:
        a.axis("off")
    fig.tight_layout()
    fig.savefig(fig_dir / f"wmap_{stem}_triple.png", dpi=160)
    plt.close(fig)


def save_wmaps(fig_dir: Path, y_true: np.ndarray, y_pred: np.ndarray, info: np.ndarray, shard_ids: np.ndarray, mb_h: int, mb_w: int, mb_up: int, max_samples: int, tag: str) -> int:
    groups: Dict[Tuple[int, int, int], List[int]] = {}
    for i in range(info.shape[0]):
        clip_id, _, _, frame_idx = info[i]
        key = (int(shard_ids[i]), int(clip_id), int(frame_idx))
        groups.setdefault(key, []).append(i)
    scored = []
    for key, idxs in groups.items():
        g = np.zeros((mb_h, mb_w), dtype=np.uint8)
        for ii in idxs:
            br, bc = int(info[ii, 1]), int(info[ii, 2])
            if 0 <= br < mb_h and 0 <= bc < mb_w:
                g[br, bc] = 1
        scored.append((int(g.sum()), key, idxs))
    scored.sort(key=lambda x: x[0], reverse=True)
    made = 0
    for cov, key, idxs in scored:
        if made >= max_samples:
            break
        wt = np.zeros((mb_h, mb_w), dtype=np.uint8)
        wp = np.zeros((mb_h, mb_w), dtype=np.uint8)
        for ii in idxs:
            br, bc = int(info[ii, 1]), int(info[ii, 2])
            if 0 <= br < mb_h and 0 <= bc < mb_w:
                wt[br, bc] = y_true[ii]
                wp[br, bc] = y_pred[ii]
        save_wmap_triplet(fig_dir, f"sid{key[0]}_cid{key[1]}_f{key[2]}_cov{cov}_{tag}", wt, wp, mb_up)
        made += 1
    return made


def save_tau_curve(path: Path, tau_grid: np.ndarray, score_grid: np.ndarray, k: int, t_val: int) -> None:
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.plot(tau_grid, score_grid, marker="o", linewidth=1.5)
    ax.set_title(f"Threshold k={k} (T={t_val})")
    ax.set_xlabel("tau")
    ax.set_ylabel("objective")
    fig.tight_layout()
    fig.savefig(path, dpi=160)
    plt.close(fig)


def save_tau_compare(path: Path, t_list: np.ndarray, tau_unconstrained: np.ndarray, tau_monotone: np.ndarray) -> None:
    fig, ax = plt.subplots(figsize=(7, 4))
    x = np.arange(len(t_list))
    ax.plot(x, tau_unconstrained, marker="o", label="unconstrained")
    ax.plot(x, tau_monotone, marker="s", label="monotone")
    ax.set_xticks(x)
    ax.set_xticklabels([str(int(t)) for t in t_list.tolist()])
    ax.set_xlabel("T[k]")
    ax.set_ylabel("tau")
    ax.set_title("Tau Compare")
    ax.grid(alpha=0.25)
    ax.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=160)
    plt.close(fig)


def save_tail_recall_compare(path: Path, before: Dict[str, Any], after: Dict[str, Any]) -> None:
    keys = ["24", "28", "31"]
    b = [float(before.get("tail_recall", {}).get(k, 0.0)) for k in keys]
    a = [float(after.get("tail_recall", {}).get(k, 0.0)) for k in keys]
    x = np.arange(len(keys))
    w = 0.36
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar(x - w / 2, b, width=w, label="before")
    ax.bar(x + w / 2, a, width=w, label="after")
    ax.set_xticks(x)
    ax.set_xticklabels(keys)
    ax.set_ylabel("recall")
    ax.set_title("Tail Recall Compare")
    ax.set_ylim(0.0, 1.0)
    ax.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=160)
    plt.close(fig)


def search_taus(
    p_val: np.ndarray,
    y_val: np.ndarray,
    w_set: np.ndarray,
    tau_grid: np.ndarray,
    search_method: str,
    objective: str,
    alpha: float,
    num_passes: int,
    tail24_beta: float,
    tail24_floor: float,
) -> Tuple[np.ndarray, Dict[int, Dict[str, List[float]]], Dict[str, float]]:
    k_num = p_val.shape[1]
    tau = np.full(k_num, 0.5, dtype=np.float32)
    curves: Dict[int, Dict[str, List[float]]] = {}

    def eval_score(tau_now: np.ndarray) -> Tuple[float, Dict[str, Any]]:
        yp = predict_with_tau(p_val, tau_now, w_set)
        m = build_metrics(y_val, yp, w_set)
        return objective_score(m, objective, alpha, tail24_beta, tail24_floor), m

    best_score, _ = eval_score(tau)
    if search_method == "global_shared_tau":
        best_tau, curve_scores = 0.5, []
        for t in tau_grid:
            tau_try = np.full(k_num, t, dtype=np.float32)
            sc, _ = eval_score(tau_try)
            curve_scores.append(float(sc))
            if sc > best_score:
                best_score, best_tau = sc, float(t)
        tau[:] = best_tau
        for k in range(k_num):
            curves[k] = {"tau": tau_grid.tolist(), "score": curve_scores}
    else:
        passes = num_passes if search_method == "coordinate_descent" else max(1, num_passes)
        for _ in range(passes):
            for k in range(k_num):
                best_local_tau, best_local_score, local_scores = float(tau[k]), -1e18, []
                for t in tau_grid:
                    tau_try = tau.copy()
                    tau_try[k] = t
                    sc, _ = eval_score(tau_try)
                    local_scores.append(float(sc))
                    if sc > best_local_score:
                        best_local_score, best_local_tau = float(sc), float(t)
                tau[k] = np.float32(best_local_tau)
                curves[k] = {"tau": tau_grid.tolist(), "score": local_scores}
            best_score, _ = eval_score(tau)
    y_before = predict_with_tau(p_val, np.full(k_num, 0.5, dtype=np.float32), w_set)
    y_after = predict_with_tau(p_val, tau, w_set)
    m_before = build_metrics(y_val, y_before, w_set)
    m_after = build_metrics(y_val, y_after, w_set)
    summary = {
        "objective_before": float(objective_score(m_before, objective, alpha, tail24_beta, tail24_floor)),
        "objective_after": float(objective_score(m_after, objective, alpha, tail24_beta, tail24_floor)),
    }
    return tau.astype(np.float32), curves, summary


def late_joint_search_tail(
    p_val: np.ndarray,
    y_val: np.ndarray,
    w_set: np.ndarray,
    tau_base: np.ndarray,
    objective: str,
    alpha: float,
    tail24_beta: float,
    tail24_floor: float,
    g20: np.ndarray,
    g24: np.ndarray,
    g28: np.ndarray,
) -> Tuple[np.ndarray, Dict[str, Any]]:
    tau_best = tau_base.copy().astype(np.float32)
    best_score = -1e18
    eval_count = 0
    k20, k24, k28 = 5, 6, 7
    for t20 in g20.tolist():
        for t24 in g24.tolist():
            for t28 in g28.tolist():
                tau_try = tau_base.copy().astype(np.float32)
                if k20 < tau_try.shape[0]:
                    tau_try[k20] = np.float32(t20)
                if k24 < tau_try.shape[0]:
                    tau_try[k24] = np.float32(t24)
                if k28 < tau_try.shape[0]:
                    tau_try[k28] = np.float32(t28)
                y_try = predict_with_tau(p_val, tau_try, w_set)
                m = build_metrics(y_val, y_try, w_set)
                sc = objective_score(m, objective, alpha, tail24_beta, tail24_floor)
                eval_count += 1
                if sc > best_score:
                    best_score = float(sc)
                    tau_best = tau_try
    return tau_best, {"eval_count": eval_count, "best_score": float(best_score)}

def main() -> None:
    args = parse_args()
    out = ensure_dirs(Path(args.out_dir))
    save_wmap = parse_bool(args.save_wmap)
    use_log1p = parse_bool(args.log1p_features)
    drop_const = parse_bool(args.drop_constant_features)
    do_late_joint = parse_bool(args.late_threshold_joint_search)

    shard_dir, model_dir = resolve_inputs(args)
    print(f"[INFO] shard_dir={shard_dir}")
    print(f"[INFO] model_dir={model_dir}")

    ds = load_shards(shard_dir, args.max_rows_per_shard, args.seed)
    x, y = ds["X"], ds["y"]
    shard_ids, info = ds["shard_ids"], ds["info"]
    feature_names, w_set = ds["feature_names"], ds["w_set"]

    if use_log1p:
        x = apply_log1p_features(x, feature_names, parse_csv_keys(args.log1p_keys))

    x_val, y_val, val_idx = split_data(x, y, shard_ids, args.split_mode, args.val_ratio, args.val_shards, args.seed)
    shard_ids_val = shard_ids[val_idx]
    info_val = info[val_idx] if info is not None else None

    if drop_const:
        x_val, feature_names = drop_constant_columns(x, x_val, feature_names, args.constant_eps)

    models, t_list = load_ordinal_models(model_dir)
    print(f"[INFO] ordinal models={len(models)}, thresholds={t_list.tolist()}")
    if len(models) != len(w_set) - 1:
        print(f"[WARNING] model count={len(models)} vs expected={len(w_set)-1}")

    feat_dim = x_val.shape[1]
    for i, model in enumerate(models):
        if model.num_feature() != feat_dim:
            raise RuntimeError(f"model[{i}] feature dim={model.num_feature()} mismatch data={feat_dim}")

    p_val = predict_p_gt(models, x_val)
    tau_grid = np.arange(args.tau_min, args.tau_max + 1e-8, args.tau_step, dtype=np.float32)
    tau_opt, curves, objective_summary = search_taus(
        p_val=p_val,
        y_val=y_val,
        w_set=w_set,
        tau_grid=tau_grid,
        search_method=args.search_method,
        objective=args.objective,
        alpha=args.hybrid_alpha,
        num_passes=args.num_passes,
        tail24_beta=args.tail24_beta,
        tail24_floor=args.tail24_floor,
    )

    tau_before = np.full(len(models), 0.5, dtype=np.float32)
    tau_unconstrained = np.clip(tau_opt.astype(np.float32), args.tau_min, args.tau_max)
    joint_summary: Dict[str, Any] = {"enabled": False}
    if do_late_joint and len(models) >= 8:
        g20 = parse_range_grid(args.joint_tau20_grid)
        g24 = parse_range_grid(args.joint_tau24_grid)
        g28 = parse_range_grid(args.joint_tau28_grid)
        tau_joint, joint_info = late_joint_search_tail(
            p_val=p_val,
            y_val=y_val,
            w_set=w_set,
            tau_base=tau_unconstrained,
            objective=args.objective,
            alpha=args.hybrid_alpha,
            tail24_beta=args.tail24_beta,
            tail24_floor=args.tail24_floor,
            g20=g20,
            g24=g24,
            g28=g28,
        )
        tau_unconstrained = np.clip(tau_joint.astype(np.float32), args.tau_min, args.tau_max)
        joint_summary = {
            "enabled": True,
            "tau20_grid": args.joint_tau20_grid,
            "tau24_grid": args.joint_tau24_grid,
            "tau28_grid": args.joint_tau28_grid,
            **joint_info,
        }
    tau_monotone = enforce_tau_monotonic(tau_unconstrained, args.enforce_tau_monotonic, args.monotonic_direction, args.tau_min, args.tau_max)

    y_before = predict_with_tau(p_val, tau_before, w_set)
    y_unconstrained = predict_with_tau(p_val, tau_unconstrained, w_set)
    y_monotone = predict_with_tau(p_val, tau_monotone, w_set)

    metrics_before = build_metrics(y_val, y_before, w_set)
    metrics_unconstrained = build_metrics(y_val, y_unconstrained, w_set)
    metrics_monotone = build_metrics(y_val, y_monotone, w_set)
    metrics_before["objective_score"] = float(objective_score(metrics_before, args.objective, args.hybrid_alpha, args.tail24_beta, args.tail24_floor))
    metrics_unconstrained["objective_score"] = float(objective_score(metrics_unconstrained, args.objective, args.hybrid_alpha, args.tail24_beta, args.tail24_floor))
    metrics_monotone["objective_score"] = float(objective_score(metrics_monotone, args.objective, args.hybrid_alpha, args.tail24_beta, args.tail24_floor))
    for m in (metrics_before, metrics_unconstrained, metrics_monotone):
        m["objective"] = args.objective
        m["hybrid_alpha"] = float(args.hybrid_alpha)
        m["tail24_beta"] = float(args.tail24_beta)
        m["tail24_floor"] = float(args.tail24_floor)
        m["w24_recall"] = float(m.get("per_class", {}).get("24", {}).get("recall", 0.0))

    labels = [int(w) for w in w_set.tolist()]
    cm_before = confusion_matrix(y_val, y_before, labels=labels)
    cm_unconstrained = confusion_matrix(y_val, y_unconstrained, labels=labels)
    cm_monotone = confusion_matrix(y_val, y_monotone, labels=labels)
    cm_before_norm = cm_before.astype(np.float64) / np.maximum(cm_before.sum(axis=1, keepdims=True), 1.0)
    cm_unconstrained_norm = cm_unconstrained.astype(np.float64) / np.maximum(cm_unconstrained.sum(axis=1, keepdims=True), 1.0)
    cm_monotone_norm = cm_monotone.astype(np.float64) / np.maximum(cm_monotone.sum(axis=1, keepdims=True), 1.0)
    tau_export = tau_monotone if args.enforce_tau_monotonic != "none" else tau_unconstrained
    metrics_export = metrics_monotone if args.enforce_tau_monotonic != "none" else metrics_unconstrained

    with open(out["report"] / "metrics_before.json", "w", encoding="utf-8") as f:
        json.dump(metrics_before, f, ensure_ascii=False, indent=2)
    with open(out["report"] / "metrics_after.json", "w", encoding="utf-8") as f:
        json.dump(metrics_monotone, f, ensure_ascii=False, indent=2)
    with open(out["report"] / "metrics_unconstrained.json", "w", encoding="utf-8") as f:
        json.dump(metrics_unconstrained, f, ensure_ascii=False, indent=2)
    with open(out["report"] / "metrics_monotone.json", "w", encoding="utf-8") as f:
        json.dump(metrics_monotone, f, ensure_ascii=False, indent=2)

    with open(out["report"] / "taus.json", "w", encoding="utf-8") as f:
        json.dump({
            "thresholds_T": [int(v) for v in t_list.tolist()],
            "tau_before": [float(v) for v in tau_before.tolist()],
            "tau_after": [float(v) for v in tau_monotone.tolist()],
            "tau_min": float(args.tau_min), "tau_max": float(args.tau_max), "tau_step": float(args.tau_step),
            "search_method": args.search_method, "objective": args.objective, "hybrid_alpha": float(args.hybrid_alpha),
            "tail24_beta": float(args.tail24_beta), "tail24_floor": float(args.tail24_floor),
            "enforce_tau_monotonic": args.enforce_tau_monotonic, "monotonic_direction": args.monotonic_direction,
            "objective_summary": {
                "before": float(metrics_before["objective_score"]),
                "unconstrained": float(metrics_unconstrained["objective_score"]),
                "monotone": float(metrics_monotone["objective_score"]),
            },
            "is_monotone": bool(check_non_decreasing(tau_monotone)),
            "objective_summary_from_search": objective_summary,
            "late_threshold_joint_search": joint_summary,
        }, f, ensure_ascii=False, indent=2)

    with open(out["report"] / "taus_unconstrained.json", "w", encoding="utf-8") as f:
        json.dump({"thresholds_T": [int(v) for v in t_list.tolist()], "tau": [float(v) for v in tau_unconstrained.tolist()], "objective_score": float(metrics_unconstrained["objective_score"])}, f, ensure_ascii=False, indent=2)
    with open(out["report"] / "taus_monotone.json", "w", encoding="utf-8") as f:
        json.dump({"thresholds_T": [int(v) for v in t_list.tolist()], "tau": [float(v) for v in tau_monotone.tolist()], "objective_score": float(metrics_monotone["objective_score"]), "is_non_decreasing": bool(check_non_decreasing(tau_monotone))}, f, ensure_ascii=False, indent=2)

    np.save(out["report"] / "confusion_before.npy", cm_before)
    np.save(out["report"] / "confusion_after.npy", cm_monotone)
    np.save(out["report"] / "confusion_before_norm.npy", cm_before_norm)
    np.save(out["report"] / "confusion_after_norm.npy", cm_monotone_norm)
    np.save(out["report"] / "confusion_unconstrained.npy", cm_unconstrained)
    np.save(out["report"] / "confusion_monotone.npy", cm_monotone)
    np.save(out["report"] / "confusion_unconstrained_norm.npy", cm_unconstrained_norm)
    np.save(out["report"] / "confusion_monotone_norm.npy", cm_monotone_norm)

    save_confusion_fig(out["figures"] / "confusion_before_norm.png", cm_before_norm, labels, "Confusion Before (norm)", ".2f")
    save_confusion_fig(out["figures"] / "confusion_after_norm.png", cm_monotone_norm, labels, "Confusion After (norm)", ".2f")
    save_confusion_fig(out["report"] / "confusion_unconstrained_norm.png", cm_unconstrained_norm, labels, "Confusion Unconstrained (norm)", ".2f")
    save_confusion_fig(out["report"] / "confusion_monotone_norm.png", cm_monotone_norm, labels, "Confusion Monotone (norm)", ".2f")
    save_tau_compare(out["figures"] / "tau_compare.png", t_list, tau_unconstrained, tau_monotone)
    save_tail_recall_compare(out["figures"] / "tail_recall_compare.png", metrics_before, metrics_export)

    for k, t_val in enumerate(t_list.tolist()):
        if k in curves:
            c = curves[k]
            save_tau_curve(out["figures"] / f"tau_curve_k{k:02d}.png", np.array(c["tau"], dtype=np.float32), np.array(c["score"], dtype=np.float32), k, int(t_val))

    if save_wmap:
        if info_val is None:
            print("[WARNING] val has no info; skip w_map")
        else:
            n1 = save_wmaps(out["figures"], y_val, y_before, info_val, shard_ids_val, args.mb_h, args.mb_w, args.mb_up, args.viz_samples, "before")
            n2 = save_wmaps(out["figures"], y_val, y_unconstrained, info_val, shard_ids_val, args.mb_h, args.mb_w, args.mb_up, args.viz_samples, "unconstrained")
            n3 = save_wmaps(out["figures"], y_val, y_monotone, info_val, shard_ids_val, args.mb_h, args.mb_w, args.mb_up, args.viz_samples, "after")
            print(f"[INFO] w_map generated: before={n1}, unconstrained={n2}, after(monotone)={n3}")

    with open(out["export"] / "ordinal_thresholds.json", "w", encoding="utf-8") as f:
        json.dump({
            "w_set": [int(v) for v in w_set.tolist()],
            "thresholds_T": [int(v) for v in t_list.tolist()],
            "tau": [float(v) for v in tau_export.tolist()],
            "decision_rule": "rank=sum(p_k>=tau_k); w=w_set[rank]",
            "tau_search": {
                "tau_min": float(args.tau_min), "tau_max": float(args.tau_max), "tau_step": float(args.tau_step),
                "search_method": args.search_method, "objective": args.objective, "hybrid_alpha": float(args.hybrid_alpha),
                "tail24_beta": float(args.tail24_beta), "tail24_floor": float(args.tail24_floor),
                "enforce_tau_monotonic": args.enforce_tau_monotonic, "monotonic_direction": args.monotonic_direction,
                "late_threshold_joint_search": joint_summary,
            },
            "metrics_before": metrics_before,
            "metrics_after": metrics_export,
        }, f, ensure_ascii=False, indent=2)

    with open(out["export"] / "ordinal_thresholds.csv", "w", encoding="utf-8") as f:
        f.write("T,tau\n")
        for t, tau in zip(t_list.tolist(), tau_export.tolist()):
            f.write(f"{int(t)},{float(tau):.6f}\n")

    with open(out["export"] / "rtl_snippet.sv", "w", encoding="utf-8") as f:
        f.write("// Auto-generated ordinal threshold rule\n")
        f.write("// rank = sum_k( p_k >= tau_k ) ; w = w_set[rank]\n")
        b_w = max(len(tau_export) - 1, 0)
        f.write(f"logic [{b_w}:0] b;\n")
        f.write("int rank;\n")
        for i, tau in enumerate(tau_export.tolist()):
            f.write(f"assign b[{i}] = (p_{i} >= {tau:.6f});\n")
        rank_expr = "+".join([f"b[{i}]" for i in range(len(tau_export))]) if len(tau_export) > 0 else "0"
        f.write(f"assign rank = {rank_expr};\n")
        f.write("always_comb begin\n  case(rank)\n")
        for i, w in enumerate(w_set.tolist()):
            f.write(f"    {i}: w_out = 6'd{int(w)};\n")
        f.write("    default: w_out = 6'd0;\n  endcase\nend\n")

    with open(out["export"] / "ordinal_rules.md", "w", encoding="utf-8") as f:
        f.write("# Ordinal Rules\n\n")
        f.write("- Rule: `rank = sum_k (p_k >= tau_k)`, `w = w_set[rank]`\n")
        f.write("- Each threshold model decides whether `y > T[k]` is true.\n")
        f.write("- Higher confidence crosses more thresholds and leads to larger `w`.\n\n")
        f.write("## Threshold Table\n")
        for t, tau in zip(t_list.tolist(), tau_export.tolist()):
            f.write(f"- T={int(t)} -> tau={float(tau):.6f}\n")

    obj_before = float(metrics_before["objective_score"])
    obj_un = float(metrics_unconstrained["objective_score"])
    obj_mono = float(metrics_monotone["objective_score"])
    drop_ratio = (obj_un - obj_mono) / max(abs(obj_un), 1e-12)
    macro_drop = float(metrics_before["macro_f1"]) - float(metrics_export["macro_f1"])
    mae_rise = float(metrics_export["mean_abs_class_error"]) - float(metrics_before["mean_abs_class_error"])

    print("[DONE] Ordinal tau tuning completed")
    print(f"[OBJECTIVE] before={obj_before:.6f}, unconstrained={obj_un:.6f}, monotone={obj_mono:.6f}")
    print(f"[CHECK] tau_monotone_non_decreasing={check_non_decreasing(tau_monotone)}")
    print(f"[CHECK] monotone objective drop ratio={drop_ratio:.6%}")
    print(f"[CHECK] w24_recall before={metrics_before['w24_recall']:.6f}, after={metrics_export['w24_recall']:.6f}")
    if macro_drop > 0.01:
        print(f"[WARNING] macro_f1 dropped by {macro_drop:.6f} (>0.01)")
    if mae_rise > 0.05:
        print(f"[WARNING] mean_abs_class_error increased by {mae_rise:.6f} (>0.05)")
    print(f"[OUT] report={out['report']}")
    print(f"[OUT] figures={out['figures']}")
    print(f"[OUT] export={out['export']}")


if __name__ == "__main__":
    main()
