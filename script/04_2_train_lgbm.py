
#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script04-2: LightGBM 训练 + 混淆矩阵 + w_map 可视化

支持三种任务：
- multiclass: 直接多分类
- reg: 回归预测连续 w，再量化到最近 w_set
- ordinal: 8 个阈值二分类重构有序档位
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple

import matplotlib.pyplot as plt
import numpy as np
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    mean_absolute_error,
    precision_recall_fscore_support,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split

try:
    from lightgbm import LGBMClassifier, LGBMRegressor, early_stopping, log_evaluation
except ImportError as exc:  # pragma: no cover
    raise SystemExit("未安装 lightgbm，请先执行: pip install lightgbm") from exc


def parse_args() -> argparse.Namespace:
    """解析命令行参数。"""
    p = argparse.ArgumentParser(description="从 Script03 shard 数据训练 LightGBM 并输出评估/可视化。")
    p.add_argument("--shard_dir", type=str, required=True)
    p.add_argument("--out_dir", type=str, required=True)
    p.add_argument("--max_shards", type=int, default=None)
    p.add_argument("--max_rows_per_shard", type=int, default=None)
    p.add_argument("--seed", type=int, default=123)

    p.add_argument("--task", type=str, choices=["multiclass", "reg", "ordinal"], default="ordinal")
    p.add_argument("--ordinal_strategy", type=str, choices=["independent"], default="independent")
    p.add_argument("--quantize_method", type=str, choices=["nearest", "floor", "ceil"], default="nearest")

    p.add_argument("--split_mode", type=str, choices=["random", "by_shard"], default="random")
    p.add_argument("--val_ratio", type=float, default=0.1)
    p.add_argument("--val_shards", type=int, default=2)

    p.add_argument("--class_weight", type=str, choices=["none", "inv", "inv_sqrt"], default="inv_sqrt")
    p.add_argument("--min_class_weight", type=float, default=0.2)
    p.add_argument("--max_class_weight", type=float, default=10.0)

    p.add_argument("--num_leaves", type=int, default=127)
    p.add_argument("--max_depth", type=int, default=10)
    p.add_argument("--learning_rate", type=float, default=0.05)
    p.add_argument("--n_estimators", type=int, default=800)
    p.add_argument("--subsample", type=float, default=0.8)
    p.add_argument("--colsample_bytree", type=float, default=0.8)
    p.add_argument("--min_child_samples", type=int, default=20)
    p.add_argument("--reg_lambda", type=float, default=1.0)
    p.add_argument("--early_stopping_rounds", type=int, default=50)

    p.add_argument("--log1p_features", type=str, default="true")
    p.add_argument("--log1p_keys", type=str, default="sad1,sad2,margin,grad_energy,sum")
    p.add_argument("--drop_constant_features", type=str, default="true")
    p.add_argument("--constant_eps", type=float, default=1e-6)

    p.add_argument("--use_expected_w", type=str, default="true")
    p.add_argument("--expected_only_for_viz", type=str, default="false")

    p.add_argument("--viz_mode", type=str, choices=["auto", "from_info", "from_oracle_clip"], default="auto")
    p.add_argument("--viz_samples", type=int, default=3)
    p.add_argument("--oracle_clip_dir", type=str, default=None)
    p.add_argument("--mb_h", type=int, default=80)
    p.add_argument("--mb_w", type=int, default=120)
    p.add_argument("--mb_up", type=int, default=4)

    p.add_argument("--support_warn_threshold", type=int, default=200)
    return p.parse_args()


def parse_bool(text: str) -> bool:
    return text.strip().lower() in {"1", "true", "yes", "y", "on"}


def parse_csv_keys(text: str) -> List[str]:
    return [x.strip() for x in text.split(",") if x.strip()]


def ensure_dirs(out_dir: Path) -> Dict[str, Path]:
    d = {"root": out_dir, "models": out_dir / "models", "report": out_dir / "report", "figures": out_dir / "figures"}
    for p in d.values():
        p.mkdir(parents=True, exist_ok=True)
    return d


def load_shards(shard_dir: Path, max_shards: Optional[int], max_rows_per_shard: Optional[int], seed: int) -> Dict[str, Any]:
    rng = np.random.default_rng(seed)
    shard_files = sorted(shard_dir.glob("*.npz"))
    if max_shards is not None:
        shard_files = shard_files[: max(0, max_shards)]
    if not shard_files:
        raise RuntimeError("未找到可用 shard 文件")

    X_list: List[np.ndarray] = []
    y_list: List[np.ndarray] = []
    shard_id_list: List[np.ndarray] = []
    info_list: List[np.ndarray] = []
    has_any_info = False
    ref_feature_names = None
    ref_w_set = None

    for sid, sp in enumerate(shard_files):
        with np.load(sp, allow_pickle=False) as d:
            for k in ("X", "y", "feature_names", "w_set", "files"):
                if k not in d.files:
                    raise RuntimeError(f"{sp.name} 缺少字段 `{k}`")
            X_full = d["X"]
            y_full = d["y"]
            feature_names = d["feature_names"]
            w_set = d["w_set"]
            info = d["info"] if "info" in d.files else None

            if X_full.dtype != np.float32 or X_full.ndim != 2:
                raise RuntimeError(f"{sp.name} X 契约错误")
            if y_full.dtype != np.uint8 or y_full.ndim != 1:
                raise RuntimeError(f"{sp.name} y 契约错误")
            if X_full.shape[0] != y_full.shape[0]:
                raise RuntimeError(f"{sp.name} X/y 行数不一致")
            if ref_feature_names is None:
                ref_feature_names = feature_names
            elif not np.array_equal(ref_feature_names, feature_names):
                raise RuntimeError(f"{sp.name} feature_names 与其他 shard 不一致")
            if ref_w_set is None:
                ref_w_set = w_set
            elif not np.array_equal(ref_w_set, w_set):
                raise RuntimeError(f"{sp.name} w_set 与其他 shard 不一致")

            n = X_full.shape[0]
            if max_rows_per_shard is None or max_rows_per_shard >= n:
                idx = np.arange(n, dtype=np.int64)
            else:
                idx = rng.choice(n, size=max_rows_per_shard, replace=False)
                idx.sort()

            X_list.append(X_full[idx].astype(np.float32, copy=False))
            y_list.append(y_full[idx].astype(np.uint8, copy=False))
            shard_id_list.append(np.full(idx.shape[0], sid, dtype=np.int32))
            if info is not None:
                has_any_info = True
                info_list.append(info[idx].astype(np.int32, copy=False))
            else:
                info_list.append(np.empty((idx.shape[0], 4), dtype=np.int32))

    return {
        "X": np.concatenate(X_list, axis=0),
        "y": np.concatenate(y_list, axis=0),
        "shard_ids": np.concatenate(shard_id_list, axis=0),
        "info": np.concatenate(info_list, axis=0) if has_any_info else None,
        "feature_names": ref_feature_names.astype("U"),
        "w_set": ref_w_set.astype(np.uint8),
    }

def apply_log1p_features(X: np.ndarray, feature_names: np.ndarray, keys: List[str]) -> Tuple[np.ndarray, List[str]]:
    name_to_idx = {str(n): i for i, n in enumerate(feature_names.tolist())}
    used: List[str] = []
    if not keys:
        return X, used
    X_out = X.copy()
    for k in keys:
        if k in name_to_idx:
            ci = name_to_idx[k]
            X_out[:, ci] = np.log1p(np.maximum(X_out[:, ci], 0.0))
            used.append(k)
    return X_out, used


def split_data(
    X: np.ndarray,
    y: np.ndarray,
    shard_ids: np.ndarray,
    split_mode: str,
    val_ratio: float,
    val_shards: int,
    seed: int,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    idx_all = np.arange(X.shape[0], dtype=np.int64)
    if split_mode == "random":
        try:
            train_idx, val_idx = train_test_split(
                idx_all,
                test_size=val_ratio,
                random_state=seed,
                stratify=y,
            )
        except ValueError as exc:
            print(f"[WARNING] random+stratify 失败，回退为非分层切分: {exc}")
            train_idx, val_idx = train_test_split(
                idx_all,
                test_size=val_ratio,
                random_state=seed,
                stratify=None,
            )
    else:
        uniq = np.unique(shard_ids)
        if val_shards <= 0 or val_shards >= uniq.size:
            raise ValueError("by_shard 模式下 val_shards 必须在 (0, num_shards) 范围内")
        val_sid = np.sort(uniq)[-val_shards:]
        m = np.isin(shard_ids, val_sid)
        val_idx = idx_all[m]
        train_idx = idx_all[~m]
        if val_idx.size == 0 or train_idx.size == 0:
            raise RuntimeError("by_shard 切分后 train/val 为空")
    return X[train_idx], y[train_idx], X[val_idx], y[val_idx], train_idx, val_idx


def drop_constant_columns(X_train: np.ndarray, X_val: np.ndarray, feature_names: np.ndarray, eps: float) -> Tuple[np.ndarray, np.ndarray, np.ndarray, List[str]]:
    std = X_train.astype(np.float64).std(axis=0)
    keep = std >= eps
    if np.count_nonzero(keep) == 0:
        raise RuntimeError("常数列过滤后无可用特征，请放宽 constant_eps")
    dropped = [str(feature_names[i]) for i in np.where(~keep)[0].tolist()]
    return X_train[:, keep], X_val[:, keep], feature_names[keep].astype("U"), dropped


def quantize_to_wset(vals: np.ndarray, w_set: np.ndarray, method: str) -> np.ndarray:
    ws = np.sort(w_set.astype(np.float32))
    v = vals.astype(np.float32)
    if method == "nearest":
        idx = np.argmin(np.abs(v[:, None] - ws[None, :]), axis=1)
    elif method == "floor":
        idx = np.searchsorted(ws, v, side="right") - 1
        idx = np.clip(idx, 0, len(ws) - 1)
    elif method == "ceil":
        idx = np.searchsorted(ws, v, side="left")
        idx = np.clip(idx, 0, len(ws) - 1)
    else:
        raise ValueError(f"未知 quantize_method: {method}")
    return ws[idx].astype(np.uint8)


def compute_class_weights(y_train: np.ndarray, labels: np.ndarray, mode: str, min_w: float, max_w: float) -> Dict[int, float]:
    labels_i = labels.astype(np.int64)
    if mode == "none":
        return {int(w): 1.0 for w in labels_i.tolist()}
    total = float(y_train.size)
    out: Dict[int, float] = {}
    for w in labels_i.tolist():
        c = int((y_train == w).sum())
        if c <= 0:
            raw = max_w
        else:
            f = c / total
            raw = 1.0 / f if mode == "inv" else 1.0 / np.sqrt(f)
        out[int(w)] = float(np.clip(raw, min_w, max_w))
    return out


def make_sample_weights(y: np.ndarray, class_weights: Dict[int, float]) -> np.ndarray:
    out = np.ones_like(y, dtype=np.float32)
    for w, cw in class_weights.items():
        out[y == w] = np.float32(cw)
    return out


def postprocess_expected_w(proba: np.ndarray, w_set: np.ndarray, class_values: Optional[np.ndarray], method: str) -> np.ndarray:
    ws = w_set.astype(np.float32)
    cls = ws if class_values is None else class_values.astype(np.float32)
    w_exp = (proba.astype(np.float32) * cls[None, :]).sum(axis=1)
    return quantize_to_wset(w_exp, w_set, method)


def cumulative_probs_to_class_probs(p_gt: np.ndarray) -> np.ndarray:
    n, m = p_gt.shape
    out = np.zeros((n, m + 1), dtype=np.float32)
    out[:, 0] = 1.0 - p_gt[:, 0]
    for i in range(1, m):
        out[:, i] = p_gt[:, i - 1] - p_gt[:, i]
    out[:, -1] = p_gt[:, -1]
    out = np.clip(out, 0.0, 1.0)
    s = np.maximum(out.sum(axis=1, keepdims=True), 1e-6)
    return out / s


def save_confusion_fig(path: Path, cm: np.ndarray, labels: List[int], title: str, fmt: str) -> None:
    fig, ax = plt.subplots(figsize=(8, 6))
    im = ax.imshow(cm, interpolation="nearest", cmap="Blues")
    ax.figure.colorbar(im, ax=ax)
    ax.set(xticks=np.arange(len(labels)), yticks=np.arange(len(labels)), xticklabels=[str(x) for x in labels], yticklabels=[str(x) for x in labels], ylabel="True label", xlabel="Predicted label", title=title)
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")
    th = cm.max() / 2.0 if cm.size > 0 else 0.0
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            ax.text(j, i, format(cm[i, j], fmt), ha="center", va="center", color="white" if cm[i, j] > th else "black", fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=160)
    plt.close(fig)


def save_feature_importance(path: Path, feature_names: np.ndarray, gains: np.ndarray) -> None:
    order = np.argsort(gains)[::-1]
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.bar(np.arange(len(gains)), gains[order], color="#4C78A8")
    ax.set_xticks(np.arange(len(gains)))
    ax.set_xticklabels(feature_names[order], rotation=45, ha="right")
    ax.set_ylabel("gain")
    ax.set_title("Feature Importance (gain)")
    fig.tight_layout()
    fig.savefig(path, dpi=160)
    plt.close(fig)


def save_error_distance_hist(path: Path, y_true: np.ndarray, y_pred: np.ndarray) -> None:
    d = np.abs(y_pred.astype(np.int16) - y_true.astype(np.int16)).astype(np.int16)
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.hist(d, bins=np.arange(0, 34, 2), color="#F58518", edgecolor="black", alpha=0.85)
    ax.set_title("Absolute Error Distance |w_pred - w_true|")
    ax.set_xlabel("distance")
    ax.set_ylabel("count")
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
    axs[0].imshow(img_true, cmap="gray", vmin=0, vmax=255); axs[0].set_title("Oracle")
    axs[1].imshow(img_pred, cmap="gray", vmin=0, vmax=255); axs[1].set_title("Student")
    axs[2].imshow(img_diff, cmap="gray", vmin=0, vmax=255); axs[2].set_title("|Diff|")
    for a in axs:
        a.axis("off")
    fig.tight_layout()
    fig.savefig(fig_dir / f"wmap_{stem}_triple.png", dpi=160)
    plt.close(fig)


def align_features_by_name(feat: np.ndarray, feat_names: np.ndarray, model_feat_names: np.ndarray) -> np.ndarray:
    src = {str(n): i for i, n in enumerate(feat_names.tolist())}
    idx = []
    for n in model_feat_names.tolist():
        if str(n) not in src:
            raise RuntimeError(f"oracle clip 缺少特征 `{n}`，无法对齐")
        idx.append(src[str(n)])
    return feat[..., idx]


def viz_from_info(fig_dir: Path, y_true_val: np.ndarray, y_pred_val: np.ndarray, info_val: np.ndarray, shard_ids_val: np.ndarray, mb_h: int, mb_w: int, mb_up: int, viz_samples: int, stem_suffix: str) -> int:
    groups: Dict[Tuple[int, int, int], List[int]] = {}
    for i in range(info_val.shape[0]):
        clip_id, _, _, frame_idx = info_val[i]
        key = (int(shard_ids_val[i]), int(clip_id), int(frame_idx))
        groups.setdefault(key, []).append(i)
    scored = []
    for key, idxs in groups.items():
        grid = np.zeros((mb_h, mb_w), dtype=np.uint8)
        for ii in idxs:
            br = int(info_val[ii, 1]); bc = int(info_val[ii, 2])
            if 0 <= br < mb_h and 0 <= bc < mb_w:
                grid[br, bc] = 1
        scored.append((int(grid.sum()), key, idxs))
    scored.sort(key=lambda x: x[0], reverse=True)
    made = 0
    for cov, key, idxs in scored:
        if made >= viz_samples:
            break
        wt = np.zeros((mb_h, mb_w), dtype=np.uint8)
        wp = np.zeros((mb_h, mb_w), dtype=np.uint8)
        for ii in idxs:
            br = int(info_val[ii, 1]); bc = int(info_val[ii, 2])
            if 0 <= br < mb_h and 0 <= bc < mb_w:
                wt[br, bc] = y_true_val[ii]
                wp[br, bc] = y_pred_val[ii]
        stem = f"sid{key[0]}_cid{key[1]}_f{key[2]}_cov{cov}_{stem_suffix}" if stem_suffix else f"sid{key[0]}_cid{key[1]}_f{key[2]}_cov{cov}"
        save_wmap_triplet(fig_dir, stem, wt, wp, mb_up)
        made += 1
    return made


def viz_from_oracle_clip(fig_dir: Path, predict_fn: Callable[[np.ndarray], np.ndarray], model_feature_names: np.ndarray, oracle_clip_dir: Path, mb_h: int, mb_w: int, mb_up: int, viz_samples: int, stem_suffix: str) -> int:
    files = sorted(oracle_clip_dir.glob("*_oracle.npz"))
    if not files:
        raise RuntimeError(f"oracle_clip_dir 下无 *_oracle.npz: {oracle_clip_dir}")
    made = 0
    skipped = 0
    for fp in files:
        if made >= viz_samples:
            break
        with np.load(fp, allow_pickle=False) as d:
            if "features" not in d.files or "w_label" not in d.files or "feature_names" not in d.files:
                continue
            feat = d["features"]; feat_names = d["feature_names"]; wt = d["w_label"]
            if feat.ndim != 3 or wt.ndim != 2 or feat.shape[0] != mb_h or feat.shape[1] != mb_w:
                continue
            try:
                fa = align_features_by_name(feat, feat_names, model_feature_names)
            except RuntimeError as exc:
                skipped += 1
                print(f"[WARNING] 跳过不兼容 oracle 文件 {fp.name}: {exc}")
                continue
            x = fa.reshape(-1, fa.shape[-1]).astype(np.float32)
            yp = predict_fn(x).astype(np.uint8).reshape(mb_h, mb_w)
            stem = f"{fp.stem}_{stem_suffix}" if stem_suffix else fp.stem
            save_wmap_triplet(fig_dir, stem, wt.astype(np.uint8), yp, mb_up)
            made += 1
    if skipped > 0:
        print(f"[WARNING] oracle_clip 可视化跳过不兼容文件数量: {skipped}")
    return made


def bucketize_mv_mag(x: np.ndarray) -> np.ndarray:
    return np.clip(x.astype(np.int64), 0, 5)


def bucketize_edges(x: np.ndarray, edges: np.ndarray) -> np.ndarray:
    idx = np.searchsorted(edges, x, side="right") - 1
    return np.clip(idx, 0, len(edges) - 2)


def build_bucket_mean_map(mv_vals: np.ndarray, margin_vals: np.ndarray, w_vals: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    mv_bin = bucketize_mv_mag(mv_vals)
    edges = np.percentile(margin_vals, [0, 20, 40, 60, 80, 100])
    margin_bin = bucketize_edges(margin_vals, edges)
    heat = np.full((6, 5), np.nan, dtype=np.float64)
    cnt = np.zeros((6, 5), dtype=np.int64)
    for i in range(6):
        for j in range(5):
            m = (mv_bin == i) & (margin_bin == j)
            if np.any(m):
                cnt[i, j] = int(np.sum(m))
                heat[i, j] = float(np.mean(w_vals[m].astype(np.float64)))
    return heat, cnt


def save_heatmap(path: Path, heat: np.ndarray, cnt: np.ndarray, title: str) -> None:
    fig, ax = plt.subplots(figsize=(8, 5))
    im = ax.imshow(heat, cmap="viridis", aspect="auto")
    cbar = fig.colorbar(im, ax=ax); cbar.set_label("E[w]")
    ax.set_title(title)
    ax.set_xlabel("margin bucket (quantile B0..B4)")
    ax.set_ylabel("mv_mag bucket (0,1,2,3,4,>=5)")
    ax.set_xticks(np.arange(5)); ax.set_yticks(np.arange(6))
    ax.set_xticklabels([f"B{i}" for i in range(5)])
    ax.set_yticklabels(["0", "1", "2", "3", "4", ">=5"])
    for i in range(6):
        for j in range(5):
            txt = "-" if np.isnan(heat[i, j]) else f"{heat[i, j]:.2f}\n({cnt[i, j]})"
            ax.text(j, i, txt, ha="center", va="center", fontsize=8, color="white")
    fig.tight_layout()
    fig.savefig(path, dpi=160)
    plt.close(fig)


def build_metrics(y_true: np.ndarray, y_pred: np.ndarray, w_set: np.ndarray, support_warn_threshold: int) -> Dict[str, Any]:
    labels = [int(w) for w in w_set.tolist()]
    acc = float(accuracy_score(y_true, y_pred))
    macro_f1 = float(f1_score(y_true, y_pred, labels=labels, average="macro", zero_division=0))
    p, r, f, s = precision_recall_fscore_support(y_true, y_pred, labels=labels, zero_division=0)
    per_class = {
        str(lbl): {"precision": float(p[i]), "recall": float(r[i]), "f1": float(f[i]), "support": int(s[i])}
        for i, lbl in enumerate(labels)
    }
    low = []
    for i, lbl in enumerate(labels):
        if int(s[i]) < int(support_warn_threshold):
            low.append({"class": int(lbl), "support": int(s[i]), "note": "metric may be unstable due to low support"})
    return {
        "accuracy": acc,
        "macro_f1": macro_f1,
        "mean_abs_class_error": float(np.mean(np.abs(y_pred.astype(np.int16) - y_true.astype(np.int16)))),
        "per_class": per_class,
        "tail_recall": {str(k): per_class[str(k)]["recall"] for k in (24, 28, 31) if str(k) in per_class},
        "low_support_classes": low,
        "support_warn_threshold": int(support_warn_threshold),
    }

def fit_lgbm_classifier(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_val: np.ndarray,
    y_val: np.ndarray,
    sw_train: np.ndarray,
    sw_val: np.ndarray,
    args: argparse.Namespace,
    objective: str,
    num_class: Optional[int],
    eval_metric: str,
) -> LGBMClassifier:
    kw: Dict[str, Any] = {
        "objective": objective,
        "num_leaves": args.num_leaves,
        "max_depth": args.max_depth,
        "learning_rate": args.learning_rate,
        "n_estimators": args.n_estimators,
        "subsample": args.subsample,
        "colsample_bytree": args.colsample_bytree,
        "min_child_samples": args.min_child_samples,
        "reg_lambda": args.reg_lambda,
        "random_state": args.seed,
        "n_jobs": -1,
    }
    if num_class is not None:
        kw["num_class"] = num_class
    m = LGBMClassifier(**kw)
    m.fit(
        X_train,
        y_train,
        sample_weight=sw_train,
        eval_set=[(X_val, y_val)],
        eval_sample_weight=[sw_val],
        eval_metric=eval_metric,
        callbacks=[early_stopping(stopping_rounds=args.early_stopping_rounds, verbose=True), log_evaluation(50)],
    )
    return m


def fit_lgbm_regressor(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_val: np.ndarray,
    y_val: np.ndarray,
    sw_train: np.ndarray,
    sw_val: np.ndarray,
    args: argparse.Namespace,
) -> LGBMRegressor:
    m = LGBMRegressor(
        objective="regression",
        num_leaves=args.num_leaves,
        max_depth=args.max_depth,
        learning_rate=args.learning_rate,
        n_estimators=args.n_estimators,
        subsample=args.subsample,
        colsample_bytree=args.colsample_bytree,
        min_child_samples=args.min_child_samples,
        reg_lambda=args.reg_lambda,
        random_state=args.seed,
        n_jobs=-1,
    )
    m.fit(
        X_train,
        y_train.astype(np.float32),
        sample_weight=sw_train,
        eval_set=[(X_val, y_val.astype(np.float32))],
        eval_sample_weight=[sw_val],
        eval_metric="l1",
        callbacks=[early_stopping(stopping_rounds=args.early_stopping_rounds, verbose=True), log_evaluation(50)],
    )
    return m


def decide_viz_mode(mode: str, info_val: Optional[np.ndarray], oracle_clip_dir: Optional[str]) -> str:
    if mode == "from_info":
        return "from_info"
    if mode == "from_oracle_clip":
        return "from_oracle_clip"
    if info_val is not None:
        return "from_info"
    if oracle_clip_dir is not None and Path(oracle_clip_dir).is_dir():
        return "from_oracle_clip"
    return "none"

def main() -> None:
    args = parse_args()
    np.random.seed(args.seed)
    use_log1p = parse_bool(args.log1p_features)
    use_drop_constant = parse_bool(args.drop_constant_features)
    use_expected = parse_bool(args.use_expected_w)
    expected_only_for_viz = parse_bool(args.expected_only_for_viz)

    shard_dir = Path(args.shard_dir)
    if not shard_dir.is_dir():
        raise SystemExit(f"shard_dir 不存在: {shard_dir}")
    out = ensure_dirs(Path(args.out_dir))

    ds = load_shards(shard_dir, args.max_shards, args.max_rows_per_shard, args.seed)
    X = ds["X"]; y = ds["y"]; shard_ids = ds["shard_ids"]; info_all = ds["info"]; feature_names = ds["feature_names"]; w_set = ds["w_set"]

    log1p_applied: List[str] = []
    if use_log1p:
        X, log1p_applied = apply_log1p_features(X, feature_names, parse_csv_keys(args.log1p_keys))

    X_train, y_train, X_val, y_val, _, val_idx = split_data(X, y, shard_ids, args.split_mode, args.val_ratio, args.val_shards, args.seed)
    shard_ids_val = shard_ids[val_idx]
    info_val = info_all[val_idx] if info_all is not None else None

    dropped_features: List[str] = []
    if use_drop_constant:
        X_train, X_val, feature_names, dropped_features = drop_constant_columns(X_train, X_val, feature_names, args.constant_eps)

    cls_w = compute_class_weights(y_train, w_set, args.class_weight, args.min_class_weight, args.max_class_weight)
    sw_train = make_sample_weights(y_train, cls_w)
    sw_val = make_sample_weights(y_val, cls_w)

    metrics_extra: Dict[str, Any] = {}
    model_kind = args.task
    pred_tag_metric = "raw"
    pred_tag_viz = "raw"
    mae_w: Optional[float] = None
    model_save_targets: List[str] = []

    def predict_for_viz_fn(x: np.ndarray) -> np.ndarray:
        raise RuntimeError("predict_for_viz_fn 未初始化")

    if args.task == "multiclass":
        m = fit_lgbm_classifier(X_train, y_train, X_val, y_val, sw_train, sw_val, args, "multiclass", len(w_set), "multi_logloss")
        y_pred_raw = m.predict(X_val).astype(np.uint8)
        y_pred_expected = y_pred_raw
        if use_expected:
            y_pred_expected = postprocess_expected_w(m.predict_proba(X_val), w_set, np.asarray(m.classes_) if hasattr(m, "classes_") else w_set, args.quantize_method)
        if expected_only_for_viz and use_expected:
            y_pred_metric = y_pred_raw
            y_pred_viz = y_pred_expected
            pred_tag_metric = "raw"
            pred_tag_viz = "expected"
        else:
            y_pred_metric = y_pred_expected if use_expected else y_pred_raw
            y_pred_viz = y_pred_metric
            pred_tag_metric = "expected" if use_expected else "raw"
            pred_tag_viz = pred_tag_metric
        gains = m.booster_.feature_importance(importance_type="gain")
        m_path = out["models"] / "lgbm_model_multiclass.txt"
        m.booster_.save_model(str(m_path))
        model_save_targets = [str(m_path)]

        def predict_for_viz_fn(x: np.ndarray) -> np.ndarray:
            y_raw = m.predict(x).astype(np.uint8)
            if not use_expected:
                return y_raw
            y_exp = postprocess_expected_w(m.predict_proba(x), w_set, np.asarray(m.classes_) if hasattr(m, "classes_") else w_set, args.quantize_method)
            return y_exp if pred_tag_viz == "expected" else y_raw

    elif args.task == "reg":
        m = fit_lgbm_regressor(X_train, y_train, X_val, y_val, sw_train, sw_val, args)
        y_hat = m.predict(X_val).astype(np.float32)
        y_pred_metric = quantize_to_wset(y_hat, w_set, args.quantize_method)
        y_pred_viz = y_pred_metric
        pred_tag_metric = f"q_{args.quantize_method}"
        pred_tag_viz = pred_tag_metric
        mae_w = float(mean_absolute_error(y_val.astype(np.float32), y_hat))
        gains = m.booster_.feature_importance(importance_type="gain")
        m_path = out["models"] / "lgbm_model_reg.txt"
        m.booster_.save_model(str(m_path))
        model_save_targets = [str(m_path)]

        def predict_for_viz_fn(x: np.ndarray) -> np.ndarray:
            return quantize_to_wset(m.predict(x).astype(np.float32), w_set, args.quantize_method)

    else:
        if args.ordinal_strategy != "independent":
            raise ValueError(f"暂不支持 ordinal_strategy={args.ordinal_strategy}")
        thresholds = w_set[:-1].astype(np.uint8)
        models: List[LGBMClassifier] = []
        p_list: List[np.ndarray] = []
        ord_metrics: List[Dict[str, Any]] = []
        for t in thresholds.tolist():
            y_tr_b = (y_train > t).astype(np.uint8)
            y_va_b = (y_val > t).astype(np.uint8)
            bin_w = compute_class_weights(y_tr_b, np.array([0, 1], dtype=np.uint8), args.class_weight, args.min_class_weight, args.max_class_weight)
            sw_tr_b = make_sample_weights(y_tr_b, bin_w)
            sw_va_b = make_sample_weights(y_va_b, bin_w)
            m = fit_lgbm_classifier(X_train, y_tr_b, X_val, y_va_b, sw_tr_b, sw_va_b, args, "binary", None, "binary_logloss")
            p2 = m.predict_proba(X_val)
            p_gt = p2[:, 1].astype(np.float32) if p2.ndim == 2 else m.predict(X_val).astype(np.float32)
            p_list.append(p_gt)
            yb = (p_gt > 0.5).astype(np.uint8)
            acc_b = float(accuracy_score(y_va_b, yb))
            try:
                auc_b = float(roc_auc_score(y_va_b, p_gt))
            except Exception:
                auc_b = None
            ord_metrics.append({"threshold": int(t), "acc": acc_b, "auc": auc_b, "pos_ratio_val": float(y_va_b.mean())})
            models.append(m)
        p_val = np.stack(p_list, axis=1)
        rk = np.clip((p_val > 0.5).sum(axis=1), 0, len(w_set) - 1)
        y_pred_metric = w_set[rk].astype(np.uint8)
        y_pred_viz = y_pred_metric
        pred_tag_metric = "indep05"
        pred_tag_viz = pred_tag_metric
        class_prob = cumulative_probs_to_class_probs(p_val)
        w_exp = (class_prob * w_set.astype(np.float32)[None, :]).sum(axis=1)
        mae_w = float(mean_absolute_error(y_val.astype(np.float32), w_exp))
        gains = np.mean(np.stack([m.booster_.feature_importance(importance_type="gain") for m in models], axis=0), axis=0)
        metrics_extra["ordinal_debug"] = {"thresholds": [int(x) for x in thresholds.tolist()], "per_threshold": ord_metrics}
        model_save_targets = []
        for i, m in enumerate(models):
            path_i = out["models"] / f"lgbm_model_ordinal_t{i:02d}_{int(thresholds[i])}.txt"
            m.booster_.save_model(str(path_i))
            model_save_targets.append(str(path_i))

        def predict_for_viz_fn(x: np.ndarray) -> np.ndarray:
            pp = []
            for m in models:
                p2 = m.predict_proba(x)
                pp.append(p2[:, 1].astype(np.float32) if p2.ndim == 2 else m.predict(x).astype(np.float32))
            p = np.stack(pp, axis=1)
            r = np.clip((p > 0.5).sum(axis=1), 0, len(w_set) - 1)
            return w_set[r].astype(np.uint8)

    metrics = build_metrics(y_val, y_pred_metric, w_set, args.support_warn_threshold)
    if mae_w is not None:
        metrics["mae_w"] = float(mae_w)
    metrics.update(metrics_extra)

    labels = [int(w) for w in w_set.tolist()]
    cm = confusion_matrix(y_val, y_pred_metric, labels=labels)
    cm_norm = cm.astype(np.float64) / np.maximum(cm.sum(axis=1, keepdims=True), 1.0)
    suffix = f"{model_kind}_{pred_tag_metric}"
    viz_suffix = f"{model_kind}_{pred_tag_viz}"

    config = vars(args).copy()
    config["class_weights"] = {str(k): float(v) for k, v in cls_w.items()}
    config["log1p_applied"] = log1p_applied
    config["dropped_constant_features"] = dropped_features
    config["prediction_mode_metric"] = pred_tag_metric
    config["prediction_mode_viz"] = pred_tag_viz
    config["model_saved_files"] = model_save_targets
    config["dataset"] = {
        "num_rows_total": int(X.shape[0]),
        "num_rows_train": int(X_train.shape[0]),
        "num_rows_val": int(X_val.shape[0]),
        "feature_dim_after_drop": int(X_train.shape[1]),
        "num_shards_loaded": int(len(np.unique(shard_ids))),
        "w_set": [int(v) for v in w_set.tolist()],
        "feature_names_after_drop": [str(v) for v in feature_names.tolist()],
    }
    with open(out["models"] / "train_config.json", "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)

    np.save(out["report"] / f"confusion_matrix_{suffix}.npy", cm)
    np.save(out["report"] / f"confusion_matrix_norm_{suffix}.npy", cm_norm)
    with open(out["report"] / f"metrics_{suffix}.json", "w", encoding="utf-8") as f:
        json.dump(metrics, f, ensure_ascii=False, indent=2)

    save_confusion_fig(out["figures"] / f"confusion_matrix_{suffix}.png", cm, labels, f"Confusion Matrix ({suffix})", "d")
    save_confusion_fig(out["figures"] / f"confusion_matrix_norm_{suffix}.png", cm_norm, labels, f"Confusion Matrix Normalized ({suffix})", ".2f")
    save_feature_importance(out["figures"] / f"feature_importance_gain_{model_kind}.png", feature_names, gains)
    save_error_distance_hist(out["figures"] / f"error_distance_hist_{suffix}.png", y_val, y_pred_metric)

    name_to_idx = {str(n): i for i, n in enumerate(feature_names.tolist())}
    if "mv_mag" in name_to_idx and "margin" in name_to_idx:
        mv = X_val[:, name_to_idx["mv_mag"]]
        mg = X_val[:, name_to_idx["margin"]]
        ho, co = build_bucket_mean_map(mv, mg, y_val)
        hs, cs = build_bucket_mean_map(mv, mg, y_pred_metric)
        save_heatmap(out["figures"] / f"bucket_mv_margin_vs_w_oracle_{suffix}.png", ho, co, f"Oracle: E[w] by mv_mag x margin ({suffix})")
        save_heatmap(out["figures"] / f"bucket_mv_margin_vs_w_student_{suffix}.png", hs, cs, f"Student: E[w] by mv_mag x margin ({suffix})")

    made = 0
    if args.viz_samples > 0:
        actual = decide_viz_mode(args.viz_mode, info_val, args.oracle_clip_dir)
        if actual == "from_info":
            if info_val is None:
                print("[WARNING] 可视化模式 from_info 但 val 无 info，已跳过")
            else:
                made = viz_from_info(out["figures"], y_val, y_pred_viz, info_val, shard_ids_val, args.mb_h, args.mb_w, args.mb_up, args.viz_samples, viz_suffix)
        elif actual == "from_oracle_clip":
            if args.oracle_clip_dir is None:
                raise RuntimeError("viz_mode=from_oracle_clip 时必须提供 --oracle_clip_dir")
            od = Path(args.oracle_clip_dir)
            if not od.is_dir():
                raise RuntimeError(f"oracle_clip_dir 不存在: {od}")
            made = viz_from_oracle_clip(out["figures"], predict_for_viz_fn, feature_names, od, args.mb_h, args.mb_w, args.mb_up, args.viz_samples, viz_suffix)
        else:
            print("[WARNING] viz_mode=auto 但无法可视化: val 无 info，且未提供有效 oracle_clip_dir。")

    print("[完成] 训练结束")
    print(f"[任务] {args.task}")
    print(f"[指标] accuracy={metrics['accuracy']:.4f}, macro_f1={metrics['macro_f1']:.4f}, mean_abs_class_error={metrics['mean_abs_class_error']:.4f}")
    if "mae_w" in metrics:
        print(f"[指标] mae_w={metrics['mae_w']:.4f}")
    print("[尾部类 recall]")
    for k, v in metrics["tail_recall"].items():
        print(f"  - w={k}: recall={v:.4f}")
    if metrics["low_support_classes"]:
        print("[WARNING] 以下类别在验证集 support 过低，指标可能不稳定：")
        for rec in metrics["low_support_classes"]:
            print(f"  - w={rec['class']}: support={rec['support']}")
    print(f"[可视化] w_map 生成数量: {made}")
    print(f"[预测] metric={pred_tag_metric}, viz={pred_tag_viz}")
    if dropped_features:
        print(f"[特征] 已删除常数列: {dropped_features}")
    print(f"[特征] log1p 应用列: {log1p_applied}")
    print(f"[输出] models: {out['models']}")
    print(f"[输出] report: {out['report']}")
    print(f"[输出] figures: {out['figures']}")


if __name__ == "__main__":
    main()
