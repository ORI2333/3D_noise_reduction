#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import annotations

import argparse
import gc
import importlib.util
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

import matplotlib.pyplot as plt
import numpy as np
from lightgbm import Booster
from PIL import Image
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_recall_fscore_support
from skimage.metrics import peak_signal_noise_ratio as psnr
from skimage.metrics import structural_similarity as ssim


IMG_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"}
METHODS = ["baseline", "multiclass", "reg_nearest", "ordinal_raw", "ordinal_tuned", "oracle"]


@dataclass
class CaseSpec:
    name: str
    dataset: str
    clip: str
    sigma: int
    frame_idx: int  # 1-based
    y1: int
    y2: int
    x1: int
    x2: int


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Unified Group-A evaluation on DAVIS + Set8.")
    p.add_argument(
        "--base_root",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script",
        help="Script root containing 3dnr.py/oracle_lib.py/DAVIS/Set8.",
    )
    p.add_argument("--davis_jpeg_dir", type=str, default="")
    p.add_argument("--set8_dir", type=str, default="")
    p.add_argument("--davis_clips", type=str, default="surf,bear,bmx-trees")
    p.add_argument("--sigmas", type=str, default="10,20,30")
    p.add_argument("--max_frames_per_seq", type=int, default=85)
    p.add_argument("--seed", type=int, default=123)
    p.add_argument("--h_disp", type=int, default=480)
    p.add_argument("--v_disp", type=int, default=320)
    p.add_argument("--mb_size", type=int, default=4)

    p.add_argument("--baseline_temporal_weight", type=int, default=16)
    p.add_argument("--baseline_threshold", type=int, default=4095)
    p.add_argument("--w_set", type=str, default="0,4,8,12,16,20,24,28,31")

    p.add_argument("--model_dir_multiclass", type=str, default="")
    p.add_argument("--model_dir_reg", type=str, default="")
    p.add_argument("--model_dir_ordinal", type=str, default="")
    p.add_argument("--tau_tuned_json", type=str, default="")

    p.add_argument("--tdnr_py", type=str, default="")
    p.add_argument("--oracle_lib_py", type=str, default="")

    p.add_argument("--compute_strred", action="store_true")
    p.add_argument("--save_visual_cases", action="store_true")
    p.add_argument(
        "--case_specs",
        type=str,
        default="",
        help=(
            "Semicolon-separated specs: "
            "name,dataset,clip,sigma,frame_idx,y1,y2,x1,x2"
        ),
    )
    p.add_argument("--out_dir", type=str, default="out_eval_groupA_paperA")
    return p.parse_args()


def parse_csv_str(s: str) -> List[str]:
    return [x.strip() for x in s.split(",") if x.strip()]


def parse_csv_int(s: str) -> List[int]:
    return [int(x.strip()) for x in s.split(",") if x.strip()]


def load_module(module_path: Path, module_name: str) -> Any:
    if not module_path.is_file():
        raise FileNotFoundError(f"module file not found: {module_path}")
    spec = importlib.util.spec_from_file_location(module_name, str(module_path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to import module: {module_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_rgb(path: Path) -> np.ndarray:
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8)


def list_image_frames(seq_dir: Path, max_frames: int) -> List[Path]:
    frames = [p for p in seq_dir.iterdir() if p.is_file() and p.suffix.lower() in IMG_EXTS]
    frames = sorted(frames)
    if max_frames > 0:
        frames = frames[:max_frames]
    return frames


def discover_set8_sequences(set8_root: Path, max_frames: int) -> Dict[str, List[Path]]:
    seqs: Dict[str, List[Path]] = {}
    if not set8_root.is_dir():
        return seqs
    for d in set8_root.rglob("*"):
        if not d.is_dir():
            continue
        frames = list_image_frames(d, max_frames=0)
        if not frames:
            continue
        seq_name = d.name
        if seq_name in seqs:
            seq_name = str(d.relative_to(set8_root)).replace("\\", "/")
        seqs[seq_name] = frames[:max_frames] if max_frames > 0 else frames
    return dict(sorted(seqs.items(), key=lambda kv: kv[0]))


def summarize(values: Sequence[float]) -> Dict[str, float]:
    arr = np.asarray(values, dtype=np.float64)
    if arr.size == 0:
        return {"mean": float("nan"), "std": float("nan")}
    return {"mean": float(arr.mean()), "std": float(arr.std(ddof=0))}


def compute_psnr_ssim(gt: np.ndarray, pred: np.ndarray) -> Tuple[float, float]:
    p = float(psnr(gt, pred, data_range=255))
    try:
        s = float(ssim(gt, pred, data_range=255, channel_axis=2))
    except TypeError:
        s = float(ssim(gt, pred, data_range=255, multichannel=True))
    return p, s


def parse_case_specs(case_text: str, sigmas: Sequence[int]) -> List[CaseSpec]:
    if case_text.strip():
        out: List[CaseSpec] = []
        for seg in [x.strip() for x in case_text.split(";") if x.strip()]:
            parts = [x.strip() for x in seg.split(",")]
            if len(parts) != 9:
                raise ValueError(f"bad case spec: {seg}")
            out.append(
                CaseSpec(
                    name=parts[0],
                    dataset=parts[1],
                    clip=parts[2],
                    sigma=int(parts[3]),
                    frame_idx=int(parts[4]),
                    y1=int(parts[5]),
                    y2=int(parts[6]),
                    x1=int(parts[7]),
                    x2=int(parts[8]),
                )
            )
        return out

    sigma_mid = int(sigmas[len(sigmas) // 2])
    sigma_hi = int(sigmas[-1])
    return [
        CaseSpec("Case_Static", "DAVIS", "surf", sigma_mid, 24, 52, 202, 90, 240),
        CaseSpec("Case_MotionEdge", "DAVIS", "bear", sigma_mid, 30, 90, 240, 120, 270),
        CaseSpec("Case_Occlusion", "DAVIS", "bmx-trees", sigma_hi, 30, 96, 246, 176, 326),
    ]


def draw_box(img: np.ndarray, y1: int, y2: int, x1: int, x2: int, thickness: int = 3) -> np.ndarray:
    out = img.copy()
    h, w = out.shape[:2]
    y1 = int(np.clip(y1, 0, h - 1))
    y2 = int(np.clip(y2, y1 + 1, h))
    x1 = int(np.clip(x1, 0, w - 1))
    x2 = int(np.clip(x2, x1 + 1, w))
    c = np.array([255, 0, 0], dtype=np.uint8)
    for t in range(thickness):
        yy1 = min(h - 1, y1 + t)
        yy2 = max(0, y2 - 1 - t)
        xx1 = min(w - 1, x1 + t)
        xx2 = max(0, x2 - 1 - t)
        out[yy1, x1:x2] = c
        out[yy2, x1:x2] = c
        out[y1:y2, xx1] = c
        out[y1:y2, xx2] = c
    return out


def save_png(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr.astype(np.uint8)).save(path)


def save_case_visuals(
    case: CaseSpec,
    out_root: Path,
    clean: np.ndarray,
    noisy: np.ndarray,
    outputs: Dict[str, np.ndarray],
) -> None:
    case_dir = out_root / "visual_cases" / case.name
    case_dir.mkdir(parents=True, exist_ok=True)
    y1, y2, x1, x2 = case.y1, case.y2, case.x1, case.x2

    full_pack = {"Clean": clean, "Noisy": noisy}
    full_pack.update(outputs)

    for k, img in full_pack.items():
        save_png(draw_box(img, y1, y2, x1, x2), case_dir / f"{k}_full.png")
        patch = img[y1:y2, x1:x2]
        save_png(patch, case_dir / f"{k}_patch.png")

    show_order = ["Clean", "Noisy", "baseline", "ordinal_tuned", "oracle"]
    patches = [full_pack[k][y1:y2, x1:x2] for k in show_order if k in full_pack]
    if patches:
        h = max(p.shape[0] for p in patches)
        canvas = np.zeros((h, sum(p.shape[1] for p in patches), 3), dtype=np.uint8)
        x = 0
        for p in patches:
            canvas[: p.shape[0], x : x + p.shape[1]] = p
            x += p.shape[1]
        save_png(canvas, case_dir / "Combined_Patches.png")


def quantize_to_wset(vals: np.ndarray, w_set: np.ndarray, method: str = "nearest") -> np.ndarray:
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
        raise ValueError(f"unknown quantize method: {method}")
    return ws[idx].astype(np.uint8)


def load_train_config_feature_recipe(
    model_dir: Path,
    fallback_feature_names: Sequence[str],
    fallback_log1p_keys: Sequence[str],
) -> Tuple[List[str], List[str], str]:
    cfg_path = model_dir / "models" / "train_config.json"
    if not cfg_path.is_file():
        cfg_path = model_dir / "train_config.json"
    if not cfg_path.is_file():
        return list(fallback_feature_names), list(fallback_log1p_keys), "raw"
    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    feat = cfg.get("dataset", {}).get("feature_names_after_drop", None)
    if not feat:
        feat = list(fallback_feature_names)
    log1p = cfg.get("log1p_applied", None)
    if log1p is None:
        log1p = list(fallback_log1p_keys)
    pred_mode = str(cfg.get("prediction_mode_metric", "raw"))
    return [str(x) for x in feat], [str(x) for x in log1p], pred_mode


def align_and_preprocess_features(
    feat_3d: np.ndarray,
    feat_names: np.ndarray,
    model_feature_names: Sequence[str],
    log1p_keys: Sequence[str],
) -> np.ndarray:
    src = {str(n): i for i, n in enumerate(feat_names.tolist())}
    idx = []
    for n in model_feature_names:
        if n not in src:
            raise RuntimeError(f"feature missing for model: {n}")
        idx.append(src[n])
    x = feat_3d[..., idx].astype(np.float32, copy=True).reshape(-1, len(idx))
    for k in log1p_keys:
        if k in model_feature_names:
            ci = model_feature_names.index(k)
            x[:, ci] = np.log1p(np.maximum(x[:, ci], 0.0))
    return x


def temporal_blend_with_wmap(cur: np.ndarray, ref: np.ndarray, w_map: np.ndarray, mb_size: int) -> np.ndarray:
    h, w = cur.shape[:2]
    eh = (h // mb_size) * mb_size
    ew = (w // mb_size) * mb_size
    expect_shape = (eh // mb_size, ew // mb_size)
    if w_map.shape != expect_shape:
        raise ValueError(f"w_map shape mismatch: got {w_map.shape}, expect {expect_shape}")
    w_full = np.kron(w_map.astype(np.uint16), np.ones((mb_size, mb_size), dtype=np.uint16))
    w_full = w_full[:h, :w]
    cur16 = cur.astype(np.uint16)
    ref16 = ref.astype(np.uint16)
    out = ((cur16 * (32 - w_full[..., None]) + ref16 * w_full[..., None]) >> 5).astype(np.uint8)
    return out


def build_feature_v2_for_infer(
    cur_noisy: np.ndarray,
    ref_img: np.ndarray,
    tdnr_mod: Any,
    oracle_mod: Any,
    me_obj: Any,
    mb_size: int,
) -> Tuple[np.ndarray, np.ndarray]:
    luma_cur = oracle_mod.rgb_to_luma_u8(cur_noisy)
    luma_ref = oracle_mod.rgb_to_luma_u8(ref_img)
    proc_mb, _ = tdnr_mod.MBDownSampler.compute(luma_cur)
    ref_mb, ref_sub = tdnr_mod.MBDownSampler.compute(luma_ref)
    sad1_ds, sad2_ds, margin_ds, sad1_mb_best, mv_mag = oracle_mod.extract_me_features_v2(
        proc_mb=proc_mb, ref_mb=ref_mb, ref_sub=ref_sub, me=me_obj
    )
    grad_energy = oracle_mod.compute_grad_energy_map(luma_cur, mb_size=mb_size)
    sum_map = proc_mb.astype(np.int32)
    prev_w = np.zeros_like(sum_map, dtype=np.int32)
    features = np.stack(
        [
            sad1_ds.astype(np.float32),
            sad2_ds.astype(np.float32),
            margin_ds.astype(np.float32),
            sad1_mb_best.astype(np.float32),
            mv_mag.astype(np.float32),
            sum_map.astype(np.float32),
            grad_energy.astype(np.float32),
            prev_w.astype(np.float32),
        ],
        axis=-1,
    )
    feature_names = np.array(
        ["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy", "prev_w"],
        dtype="U",
    )
    return features, feature_names


def load_ordinal_models(model_dir: Path) -> Tuple[List[Booster], np.ndarray]:
    pats = sorted((model_dir / "models").glob("lgbm_model_ordinal_t*_*.txt"))
    if not pats:
        pats = sorted(model_dir.glob("lgbm_model_ordinal_t*_*.txt"))
    if not pats:
        raise RuntimeError(f"no ordinal model files in {model_dir}")
    reg = re.compile(r"lgbm_model_ordinal_t\d+_(\d+)\.txt$")
    items: List[Tuple[int, Path]] = []
    for p in pats:
        m = reg.search(p.name)
        if m:
            items.append((int(m.group(1)), p))
    items.sort(key=lambda x: x[0])
    if not items:
        raise RuntimeError(f"cannot parse ordinal thresholds from model files in {model_dir}")
    models = [Booster(model_file=str(p)) for _, p in items]
    t_list = np.asarray([t for t, _ in items], dtype=np.int32)
    return models, t_list


def load_tau_json(path: Path) -> Tuple[np.ndarray, np.ndarray]:
    with open(path, "r", encoding="utf-8") as f:
        d = json.load(f)
    t_list = np.asarray(d["thresholds_T"], dtype=np.int32)
    tau = np.asarray(d["tau"], dtype=np.float32)
    return t_list, tau


class PredictorBase:
    def predict(self, feat_3d: np.ndarray, feat_names: np.ndarray) -> np.ndarray:
        raise NotImplementedError


class PredictorMulticlass(PredictorBase):
    def __init__(
        self,
        model_file: Path,
        feature_names: Sequence[str],
        log1p_keys: Sequence[str],
        w_set: np.ndarray,
        prediction_mode_metric: str = "raw",
    ):
        self.model = Booster(model_file=str(model_file))
        self.feature_names = list(feature_names)
        self.log1p_keys = list(log1p_keys)
        self.w_set = np.asarray(w_set, dtype=np.uint8)
        self.prediction_mode_metric = str(prediction_mode_metric)

    def predict(self, feat_3d: np.ndarray, feat_names: np.ndarray) -> np.ndarray:
        h, w, _ = feat_3d.shape
        x = align_and_preprocess_features(
            feat_3d=feat_3d,
            feat_names=feat_names,
            model_feature_names=self.feature_names,
            log1p_keys=self.log1p_keys,
        )
        raw = np.asarray(self.model.predict(x), dtype=np.float32)
        if raw.ndim == 1 and raw.size == x.shape[0] * len(self.w_set):
            raw = raw.reshape(x.shape[0], len(self.w_set))
        if self.prediction_mode_metric == "expected":
            if raw.ndim != 2:
                raise RuntimeError("multiclass expected mode needs probability matrix")
            exp_w = (raw * self.w_set.astype(np.float32)[None, :]).sum(axis=1)
            pred = quantize_to_wset(exp_w, self.w_set, method="nearest")
        else:
            if raw.ndim == 2:
                idx = np.argmax(raw, axis=1)
                pred = self.w_set[idx].astype(np.uint8)
            else:
                pred = np.clip(np.rint(raw), 0, 31).astype(np.uint8)
        return pred.reshape(h, w)


class PredictorRegNearest(PredictorBase):
    def __init__(
        self,
        model_file: Path,
        feature_names: Sequence[str],
        log1p_keys: Sequence[str],
        w_set: np.ndarray,
    ):
        self.model = Booster(model_file=str(model_file))
        self.feature_names = list(feature_names)
        self.log1p_keys = list(log1p_keys)
        self.w_set = np.asarray(w_set, dtype=np.uint8)

    def predict(self, feat_3d: np.ndarray, feat_names: np.ndarray) -> np.ndarray:
        h, w, _ = feat_3d.shape
        x = align_and_preprocess_features(
            feat_3d=feat_3d,
            feat_names=feat_names,
            model_feature_names=self.feature_names,
            log1p_keys=self.log1p_keys,
        )
        y_hat = np.asarray(self.model.predict(x), dtype=np.float32)
        pred = quantize_to_wset(y_hat, self.w_set, method="nearest")
        return pred.reshape(h, w)


class PredictorOrdinal(PredictorBase):
    def __init__(
        self,
        models: Sequence[Booster],
        tau: np.ndarray,
        feature_names: Sequence[str],
        log1p_keys: Sequence[str],
        w_set: np.ndarray,
    ):
        self.models = list(models)
        self.tau = np.asarray(tau, dtype=np.float32)
        self.feature_names = list(feature_names)
        self.log1p_keys = list(log1p_keys)
        self.w_set = np.asarray(w_set, dtype=np.uint8)

    def predict(self, feat_3d: np.ndarray, feat_names: np.ndarray) -> np.ndarray:
        h, w, _ = feat_3d.shape
        x = align_and_preprocess_features(
            feat_3d=feat_3d,
            feat_names=feat_names,
            model_feature_names=self.feature_names,
            log1p_keys=self.log1p_keys,
        )
        p_cols: List[np.ndarray] = []
        for m in self.models:
            p = np.asarray(m.predict(x), dtype=np.float32)
            if p.ndim == 2 and p.shape[1] == 2:
                p = p[:, 1]
            p_cols.append(p.reshape(-1))
        p_mat = np.stack(p_cols, axis=1)
        if p_mat.shape[1] != self.tau.shape[0]:
            raise RuntimeError(f"tau dim mismatch: p={p_mat.shape}, tau={self.tau.shape}")
        rank = (p_mat >= self.tau[None, :]).sum(axis=1)
        rank = np.clip(rank, 0, len(self.w_set) - 1)
        pred = self.w_set[rank].astype(np.uint8)
        return pred.reshape(h, w)


def build_baseline_wmap(
    cur_noisy: np.ndarray,
    ref_img: np.ndarray,
    baseline_nr: Any,
    tdnr_mod: Any,
    temporal_weight: int,
) -> np.ndarray:
    luma_cur = baseline_nr._to_luma(cur_noisy)
    luma_ref = baseline_nr._to_luma(ref_img)
    proc_mb, _ = tdnr_mod.MBDownSampler.compute(luma_cur)
    ref_mb, ref_sub = tdnr_mod.MBDownSampler.compute(luma_ref)
    sel = baseline_nr.me_td.detect(proc_mb, ref_mb, ref_sub)
    return np.where(sel, np.uint8(temporal_weight), np.uint8(0)).astype(np.uint8)


def compute_decision_metrics(y_true: np.ndarray, y_pred: np.ndarray, labels: np.ndarray) -> Dict[str, Any]:
    labels_i = labels.astype(np.int64)
    acc = float(accuracy_score(y_true, y_pred))
    macro_f1 = float(f1_score(y_true, y_pred, labels=labels_i, average="macro", zero_division=0))
    p, r, f, s = precision_recall_fscore_support(
        y_true, y_pred, labels=labels_i, average=None, zero_division=0
    )
    per_class = {}
    for i, c in enumerate(labels_i.tolist()):
        per_class[str(int(c))] = {
            "precision": float(p[i]),
            "recall": float(r[i]),
            "f1": float(f[i]),
            "support": int(s[i]),
        }
    tail_keys = [0, 24, 28, 31]
    tail_recall = {str(k): per_class[str(k)]["recall"] for k in tail_keys if str(k) in per_class}
    return {
        "accuracy": acc,
        "macro_f1": macro_f1,
        "mean_abs_class_error": float(np.mean(np.abs(y_pred.astype(np.int16) - y_true.astype(np.int16)))),
        "tail_recall": tail_recall,
        "per_class": per_class,
    }


def save_confusion_and_hist(
    out_dir: Path,
    method: str,
    y_true: np.ndarray,
    y_pred: np.ndarray,
    labels: np.ndarray,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    cm = confusion_matrix(y_true, y_pred, labels=labels.astype(np.int64))
    cm_norm = cm.astype(np.float64) / np.maximum(cm.sum(axis=1, keepdims=True), 1.0)
    np.save(out_dir / f"confusion_{method}.npy", cm)
    np.save(out_dir / f"confusion_norm_{method}.npy", cm_norm)

    fig = plt.figure(figsize=(6, 5), dpi=140)
    ax = fig.add_subplot(111)
    im = ax.imshow(cm_norm, interpolation="nearest", cmap="Blues")
    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    ax.set_title(f"Confusion (norm) - {method}")
    tick = np.arange(len(labels))
    ax.set_xticks(tick)
    ax.set_xticklabels([str(int(x)) for x in labels], rotation=45, ha="right")
    ax.set_yticks(tick)
    ax.set_yticklabels([str(int(x)) for x in labels])
    ax.set_ylabel("Oracle Label")
    ax.set_xlabel("Predicted Label")
    fig.tight_layout()
    fig.savefig(out_dir / f"confusion_norm_{method}.png")
    plt.close(fig)

    err = np.abs(y_pred.astype(np.int16) - y_true.astype(np.int16)).astype(np.int16)
    bins = np.arange(0, int(err.max()) + 2, 1) if err.size else np.arange(0, 2, 1)
    hist, edges = np.histogram(err, bins=bins)
    with open(out_dir / f"error_hist_{method}.json", "w", encoding="utf-8") as f:
        json.dump(
            {
                "bin_left": [int(x) for x in edges[:-1].tolist()],
                "count": [int(x) for x in hist.tolist()],
            },
            f,
            ensure_ascii=False,
            indent=2,
        )
    fig2 = plt.figure(figsize=(6, 4), dpi=140)
    ax2 = fig2.add_subplot(111)
    ax2.bar(edges[:-1], hist, width=1.0, align="edge")
    ax2.set_xlabel("Absolute Class Error |pred - oracle|")
    ax2.set_ylabel("Count")
    ax2.set_title(f"Error Distance Histogram - {method}")
    fig2.tight_layout()
    fig2.savefig(out_dir / f"error_hist_{method}.png")
    plt.close(fig2)


def safe_strred_scalar(clean_gray: np.ndarray, pred_gray: np.ndarray) -> float:
    if not hasattr(np, "int"):
        np.int = int  # type: ignore[attr-defined]
    from skvideo.measure import strred

    val = strred(clean_gray, pred_gray)
    if isinstance(val, tuple):
        if len(val) == 0:
            return float("nan")
        return float(np.mean(np.asarray(val[0], dtype=np.float64)))
    arr = np.asarray(val, dtype=np.float64)
    return float(np.mean(arr))


def method_display_name(method: str) -> str:
    mapping = {
        "baseline": "Heuristic baseline",
        "multiclass": "Multiclass LightGBM",
        "reg_nearest": "Regression-quantization LightGBM",
        "ordinal_raw": "Ordinal LightGBM",
        "ordinal_tuned": "Ordinal + threshold tuning",
        "oracle": "Oracle upper bound",
    }
    return mapping.get(method, method)


def build_a1_table(decision_metrics: Dict[str, Dict[str, Any]]) -> str:
    lines = [
        "| Method | Accuracy | Macro-F1 | MeanAbsClassError | TailRecall@0 | TailRecall@24 | TailRecall@28 | TailRecall@31 |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for m in METHODS:
        met = decision_metrics[m]
        tr = met["tail_recall"]
        lines.append(
            "| "
            + " | ".join(
                [
                    method_display_name(m),
                    f"{met['accuracy']:.4f}",
                    f"{met['macro_f1']:.4f}",
                    f"{met['mean_abs_class_error']:.4f}",
                    f"{float(tr.get('0', float('nan'))):.4f}",
                    f"{float(tr.get('24', float('nan'))):.4f}",
                    f"{float(tr.get('28', float('nan'))):.4f}",
                    f"{float(tr.get('31', float('nan'))):.4f}",
                ]
            )
            + " |"
        )
    return "\n".join(lines)


def build_a2_table(results: Dict[str, Any], sigmas: List[int]) -> str:
    header = "| Dataset & Method | " + " | ".join([f"sigma={s}" for s in sigmas]) + " |"
    sep = "|" + "---|" * (len(sigmas) + 1)
    lines = [header, sep]
    for ds in ["DAVIS", "Set8"]:
        for m in METHODS:
            row = [f"{ds} - {method_display_name(m)}"]
            for s in sigmas:
                key = f"sigma_{s}"
                md = results[ds][key]["dataset_mean"][m]
                cell = f"{md['psnr']['mean']:.4f}/{md['ssim']['mean']:.6f}"
                row.append(cell)
            lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def build_markdown_report(
    out_dir: Path,
    config: Dict[str, Any],
    decision_metrics: Dict[str, Dict[str, Any]],
    a1_table: str,
    a2_table: str,
) -> None:
    obs_lines = []
    if "baseline" in decision_metrics and "ordinal_tuned" in decision_metrics:
        b = decision_metrics["baseline"]
        o = decision_metrics["ordinal_tuned"]
        obs_lines.append(
            f"- Ordinal+tuned vs baseline macro-F1 gain: {o['macro_f1'] - b['macro_f1']:+.4f}"
        )
        obs_lines.append(
            f"- Ordinal+tuned vs baseline mean abs class error: {o['mean_abs_class_error'] - b['mean_abs_class_error']:+.4f}"
        )

    cmd_example = (
        "python -u .\\script\\09A_evaluate_groupA_full.py "
        "--sigmas 10,30,50 --max_frames_per_seq 85 "
        "--out_dir .\\script\\out_eval_groupA_paperA"
    )

    text = [
        "# Group-A Unified Evaluation Report",
        "",
        "## Run Command",
        "",
        "```powershell",
        cmd_example,
        "```",
        "",
        "## Experiment Config",
        "",
        "```json",
        json.dumps(config, ensure_ascii=False, indent=2),
        "```",
        "",
        "## Table A1: Decision-level Metrics",
        "",
        a1_table,
        "",
        "## Table A2: Image-level Metrics (PSNR/SSIM)",
        "",
        a2_table,
        "",
        "## Key Observations",
        "",
    ]
    if obs_lines:
        text.extend(obs_lines)
    else:
        text.append("- Metrics generated successfully.")
    text.extend(
        [
            "",
            "## Ready for Paper A Group",
            "",
            "- Table A1 can be used directly after formatting.",
            "- Table A2 can be used directly after formatting.",
            "- Confusion matrices and error histograms are in `figures/`.",
            "- Visual cases are in `visual_cases/`.",
        ]
    )
    (out_dir / "groupA_report.md").write_text("\n".join(text), encoding="utf-8")


def main() -> None:
    args = parse_args()
    base_root = Path(args.base_root)
    out_dir = Path(args.out_dir)
    if not out_dir.is_absolute():
        out_dir = Path.cwd() / out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    davis_jpeg_dir = Path(args.davis_jpeg_dir) if args.davis_jpeg_dir else (
        base_root / "DAVIS-2017-trainval-480p" / "DAVIS" / "JPEGImages" / "480p"
    )
    set8_dir = Path(args.set8_dir) if args.set8_dir else (base_root / "Set8")

    model_dir_mc = Path(args.model_dir_multiclass) if args.model_dir_multiclass else (base_root / "out_train_multiclass")
    model_dir_reg = Path(args.model_dir_reg) if args.model_dir_reg else (base_root / "out_train_reg")
    model_dir_ord = Path(args.model_dir_ordinal) if args.model_dir_ordinal else (base_root / "out_train_ord_v2_full")
    tau_tuned_json = Path(args.tau_tuned_json) if args.tau_tuned_json else (
        base_root / "out_ordinal_tune_v2_full" / "report" / "taus_monotone.json"
    )

    tdnr_py = Path(args.tdnr_py) if args.tdnr_py else (base_root / "3dnr.py")
    oracle_lib_py = Path(args.oracle_lib_py) if args.oracle_lib_py else (base_root / "oracle_lib.py")

    for p in [davis_jpeg_dir, set8_dir, model_dir_mc, model_dir_reg, model_dir_ord, tau_tuned_json, tdnr_py, oracle_lib_py]:
        if not p.exists():
            raise SystemExit(f"required path not found: {p}")

    sigmas = parse_csv_int(args.sigmas)
    if len(sigmas) == 0:
        raise SystemExit("sigmas is empty")
    w_set = np.asarray(parse_csv_int(args.w_set), dtype=np.uint8)
    if len(w_set) == 0:
        raise SystemExit("w_set is empty")
    davis_clips = parse_csv_str(args.davis_clips)
    case_specs = parse_case_specs(args.case_specs, sigmas)

    tdnr_mod = load_module(tdnr_py, "tdnr_mod_eval09A")
    oracle_mod = load_module(oracle_lib_py, "oracle_mod_eval09A")

    # Load multiclass model + recipe
    mc_cfg_feat, mc_cfg_log1p, mc_pred_mode = load_train_config_feature_recipe(
        model_dir_mc,
        fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
        fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
    )
    mc_model_file = model_dir_mc / "models" / "lgbm_model_multiclass.txt"
    if not mc_model_file.is_file():
        mc_model_file = model_dir_mc / "lgbm_model_multiclass.txt"
    predictor_mc = PredictorMulticlass(
        model_file=mc_model_file,
        feature_names=mc_cfg_feat,
        log1p_keys=mc_cfg_log1p,
        w_set=w_set,
        prediction_mode_metric=mc_pred_mode,
    )

    # Load regression model + recipe
    reg_cfg_feat, reg_cfg_log1p, _ = load_train_config_feature_recipe(
        model_dir_reg,
        fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
        fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
    )
    reg_model_file = model_dir_reg / "models" / "lgbm_model_reg.txt"
    if not reg_model_file.is_file():
        reg_model_file = model_dir_reg / "lgbm_model_reg.txt"
    predictor_reg = PredictorRegNearest(
        model_file=reg_model_file,
        feature_names=reg_cfg_feat,
        log1p_keys=reg_cfg_log1p,
        w_set=w_set,
    )

    # Load ordinal models + recipe
    ord_cfg_feat, ord_cfg_log1p, _ = load_train_config_feature_recipe(
        model_dir_ord,
        fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
        fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
    )
    ord_models, ord_thresholds = load_ordinal_models(model_dir_ord)
    tau_t_list, tau_tuned = load_tau_json(tau_tuned_json)
    if not np.array_equal(ord_thresholds.astype(np.int32), tau_t_list.astype(np.int32)):
        raise RuntimeError(
            f"ordinal threshold mismatch: model={ord_thresholds.tolist()} vs tuned={tau_t_list.tolist()}"
        )
    tau_raw = np.full_like(tau_tuned, 0.5, dtype=np.float32)
    predictor_ord_raw = PredictorOrdinal(
        models=ord_models,
        tau=tau_raw,
        feature_names=ord_cfg_feat,
        log1p_keys=ord_cfg_log1p,
        w_set=w_set,
    )
    predictor_ord_tuned = PredictorOrdinal(
        models=ord_models,
        tau=tau_tuned,
        feature_names=ord_cfg_feat,
        log1p_keys=ord_cfg_log1p,
        w_set=w_set,
    )

    # Prepare sequences
    davis_sequences: Dict[str, List[Path]] = {}
    for clip in davis_clips:
        cdir = davis_jpeg_dir / clip
        if not cdir.is_dir():
            print(f"[WARN] DAVIS clip not found, skip: {clip}")
            continue
        frames = list_image_frames(cdir, args.max_frames_per_seq)
        if not frames:
            print(f"[WARN] DAVIS clip has no images, skip: {clip}")
            continue
        davis_sequences[clip] = frames

    set8_sequences = discover_set8_sequences(set8_dir, args.max_frames_per_seq)
    if not set8_sequences:
        print("[WARN] no Set8 sequences discovered")

    datasets = {"DAVIS": davis_sequences, "Set8": set8_sequences}

    # Storage
    results: Dict[str, Any] = {"DAVIS": {}, "Set8": {}}
    frame_values: Dict[str, Dict[str, Dict[str, Dict[str, List[float]]]]] = {
        "DAVIS": {},
        "Set8": {},
    }
    decision_true: Dict[str, List[np.ndarray]] = {m: [] for m in METHODS}
    decision_pred: Dict[str, List[np.ndarray]] = {m: [] for m in METHODS}
    strred_values: Dict[str, Dict[str, Dict[str, List[float]]]] = {"DAVIS": {}, "Set8": {}}
    captured_cases: Dict[str, bool] = {c.name: False for c in case_specs}

    shape_helper = tdnr_mod.ThreeDNR(
        h_disp=args.h_disp,
        v_disp=args.v_disp,
        temporal_weight=args.baseline_temporal_weight,
        mb_threshold=args.baseline_threshold,
    )

    print(f"[INFO] DAVIS clips: {list(davis_sequences.keys())}")
    print(f"[INFO] Set8 sequence count: {len(set8_sequences)}")
    print(f"[INFO] sigmas: {sigmas}")
    print(f"[INFO] max_frames_per_seq: {args.max_frames_per_seq}")
    print(f"[INFO] out_dir: {out_dir}")

    for dsi, (dataset_name, seq_map) in enumerate(datasets.items()):
        for sigma in sigmas:
            sigma_key = f"sigma_{sigma}"
            results[dataset_name][sigma_key] = {"clips": {}, "dataset_mean": {}}
            frame_values[dataset_name][sigma_key] = {}
            if args.compute_strred:
                strred_values[dataset_name].setdefault(sigma_key, {m: [] for m in METHODS})

            for seqi, (seq_name, frames) in enumerate(seq_map.items()):
                seq_seed = int(args.seed) + int(sigma) * 10007 + int(dsi) * 1000003 + int(seqi) * 1009
                rng = np.random.default_rng(seq_seed)

                baseline_nr = tdnr_mod.ThreeDNR(
                    h_disp=args.h_disp,
                    v_disp=args.v_disp,
                    temporal_weight=args.baseline_temporal_weight,
                    mb_threshold=args.baseline_threshold,
                )
                me_holder = tdnr_mod.ThreeDNR(
                    h_disp=args.h_disp,
                    v_disp=args.v_disp,
                    temporal_weight=args.baseline_temporal_weight,
                    mb_threshold=args.baseline_threshold,
                )
                prev_out: Dict[str, Optional[np.ndarray]] = {m: None for m in METHODS}
                prev_noisy_common: Optional[np.ndarray] = None

                if seq_name not in frame_values[dataset_name][sigma_key]:
                    frame_values[dataset_name][sigma_key][seq_name] = {
                        m: {"psnr": [], "ssim": []} for m in METHODS
                    }

                if args.compute_strred:
                    seq_clean_gray: List[np.ndarray] = []
                    seq_pred_gray: Dict[str, List[np.ndarray]] = {m: [] for m in METHODS}

                n = len(frames)
                for fi, fp in enumerate(frames, start=1):
                    clean_raw = load_rgb(fp)
                    clean = shape_helper._ensure_resolution(clean_raw)
                    noisy = np.clip(
                        clean.astype(np.float32) + rng.normal(0.0, float(sigma), clean.shape),
                        0.0,
                        255.0,
                    ).astype(np.uint8)
                    ref_common = prev_noisy_common if prev_noisy_common is not None else noisy
                    oracle_common = oracle_mod.oracle_label_w(
                        cur_noisy=noisy,
                        ref_noisy=ref_common,
                        gt=clean,
                        w_set=w_set,
                        temporal_iir_filter_fn=tdnr_mod.temporal_iir_filter,
                        mb_size=args.mb_size,
                    ).astype(np.uint8)
                    prev_noisy_common = noisy

                    outputs: Dict[str, np.ndarray] = {}

                    ref_baseline = prev_out["baseline"] if prev_out["baseline"] is not None else noisy
                    w_base = build_baseline_wmap(
                        cur_noisy=noisy,
                        ref_img=ref_baseline,
                        baseline_nr=baseline_nr,
                        tdnr_mod=tdnr_mod,
                        temporal_weight=args.baseline_temporal_weight,
                    )
                    out_base = baseline_nr.process(noisy, ref_baseline)
                    prev_out["baseline"] = out_base
                    outputs["baseline"] = out_base
                    decision_true["baseline"].append(oracle_common.reshape(-1))
                    decision_pred["baseline"].append(w_base.reshape(-1))

                    ref_mc = prev_out["multiclass"] if prev_out["multiclass"] is not None else noisy
                    feat_mc, feat_names_mc = build_feature_v2_for_infer(
                        cur_noisy=noisy,
                        ref_img=ref_mc,
                        tdnr_mod=tdnr_mod,
                        oracle_mod=oracle_mod,
                        me_obj=me_holder.me_td,
                        mb_size=args.mb_size,
                    )
                    w_mc = predictor_mc.predict(feat_mc, feat_names_mc)
                    out_mc = temporal_blend_with_wmap(noisy, ref_mc, w_mc, mb_size=args.mb_size)
                    prev_out["multiclass"] = out_mc
                    outputs["multiclass"] = out_mc
                    decision_true["multiclass"].append(oracle_common.reshape(-1))
                    decision_pred["multiclass"].append(w_mc.reshape(-1))

                    ref_reg = prev_out["reg_nearest"] if prev_out["reg_nearest"] is not None else noisy
                    feat_reg, feat_names_reg = build_feature_v2_for_infer(
                        cur_noisy=noisy,
                        ref_img=ref_reg,
                        tdnr_mod=tdnr_mod,
                        oracle_mod=oracle_mod,
                        me_obj=me_holder.me_td,
                        mb_size=args.mb_size,
                    )
                    w_reg = predictor_reg.predict(feat_reg, feat_names_reg)
                    out_reg = temporal_blend_with_wmap(noisy, ref_reg, w_reg, mb_size=args.mb_size)
                    prev_out["reg_nearest"] = out_reg
                    outputs["reg_nearest"] = out_reg
                    decision_true["reg_nearest"].append(oracle_common.reshape(-1))
                    decision_pred["reg_nearest"].append(w_reg.reshape(-1))

                    ref_or = prev_out["ordinal_raw"] if prev_out["ordinal_raw"] is not None else noisy
                    feat_or, feat_names_or = build_feature_v2_for_infer(
                        cur_noisy=noisy,
                        ref_img=ref_or,
                        tdnr_mod=tdnr_mod,
                        oracle_mod=oracle_mod,
                        me_obj=me_holder.me_td,
                        mb_size=args.mb_size,
                    )
                    w_or = predictor_ord_raw.predict(feat_or, feat_names_or)
                    out_or = temporal_blend_with_wmap(noisy, ref_or, w_or, mb_size=args.mb_size)
                    prev_out["ordinal_raw"] = out_or
                    outputs["ordinal_raw"] = out_or
                    decision_true["ordinal_raw"].append(oracle_common.reshape(-1))
                    decision_pred["ordinal_raw"].append(w_or.reshape(-1))

                    ref_ot = prev_out["ordinal_tuned"] if prev_out["ordinal_tuned"] is not None else noisy
                    feat_ot, feat_names_ot = build_feature_v2_for_infer(
                        cur_noisy=noisy,
                        ref_img=ref_ot,
                        tdnr_mod=tdnr_mod,
                        oracle_mod=oracle_mod,
                        me_obj=me_holder.me_td,
                        mb_size=args.mb_size,
                    )
                    w_ot = predictor_ord_tuned.predict(feat_ot, feat_names_ot)
                    out_ot = temporal_blend_with_wmap(noisy, ref_ot, w_ot, mb_size=args.mb_size)
                    prev_out["ordinal_tuned"] = out_ot
                    outputs["ordinal_tuned"] = out_ot
                    decision_true["ordinal_tuned"].append(oracle_common.reshape(-1))
                    decision_pred["ordinal_tuned"].append(w_ot.reshape(-1))

                    # Oracle upper-bound for image-level quality should be computed on
                    # the same recursive reference policy as deployed methods.
                    # Use oracle's own previous output as reference (frame t-1),
                    # then solve per-macroblock discrete argmin on that reference.
                    ref_oracle = prev_out["oracle"] if prev_out["oracle"] is not None else noisy
                    w_oracle_eval = oracle_mod.oracle_label_w(
                        cur_noisy=noisy,
                        ref_noisy=ref_oracle,
                        gt=clean,
                        w_set=w_set,
                        temporal_iir_filter_fn=tdnr_mod.temporal_iir_filter,
                        mb_size=args.mb_size,
                    ).astype(np.uint8)
                    out_oracle = temporal_blend_with_wmap(noisy, ref_oracle, w_oracle_eval, mb_size=args.mb_size)
                    prev_out["oracle"] = out_oracle
                    outputs["oracle"] = out_oracle
                    decision_true["oracle"].append(w_oracle_eval.reshape(-1))
                    decision_pred["oracle"].append(w_oracle_eval.reshape(-1))

                    for m in METHODS:
                        p, s = compute_psnr_ssim(clean, outputs[m])
                        frame_values[dataset_name][sigma_key][seq_name][m]["psnr"].append(p)
                        frame_values[dataset_name][sigma_key][seq_name][m]["ssim"].append(s)

                    if args.compute_strred:
                        clean_gray = oracle_mod.rgb_to_luma_u8(clean)
                        seq_clean_gray.append(clean_gray)
                        for m in METHODS:
                            seq_pred_gray[m].append(oracle_mod.rgb_to_luma_u8(outputs[m]))

                    if args.save_visual_cases:
                        for c in case_specs:
                            if captured_cases.get(c.name, False):
                                continue
                            if (
                                c.dataset == dataset_name
                                and c.clip == seq_name
                                and c.sigma == int(sigma)
                                and c.frame_idx == int(fi)
                            ):
                                save_case_visuals(
                                    case=c,
                                    out_root=out_dir,
                                    clean=clean,
                                    noisy=noisy,
                                    outputs=outputs,
                                )
                                captured_cases[c.name] = True

                    print(
                        f"[{dataset_name}] sequence '{seq_name}' | sigma={sigma} | "
                        f"Frame {fi}/{n} Done"
                    )

                clip_store: Dict[str, Any] = {}
                for m in METHODS:
                    ps = frame_values[dataset_name][sigma_key][seq_name][m]["psnr"]
                    ss = frame_values[dataset_name][sigma_key][seq_name][m]["ssim"]
                    clip_store[m] = {
                        "psnr": summarize(ps),
                        "ssim": summarize(ss),
                        "num_frames": int(len(ps)),
                    }
                results[dataset_name][sigma_key]["clips"][seq_name] = clip_store

                if args.compute_strred:
                    clean_vid = np.stack(seq_clean_gray, axis=0).astype(np.uint8)
                    for m in METHODS:
                        pred_vid = np.stack(seq_pred_gray[m], axis=0).astype(np.uint8)
                        val = safe_strred_scalar(clean_vid, pred_vid)
                        strred_values[dataset_name][sigma_key][m].append(val)
                    del seq_clean_gray
                    del seq_pred_gray
                    gc.collect()

            for m in METHODS:
                all_ps: List[float] = []
                all_ss: List[float] = []
                for seq_name in frame_values[dataset_name][sigma_key]:
                    all_ps.extend(frame_values[dataset_name][sigma_key][seq_name][m]["psnr"])
                    all_ss.extend(frame_values[dataset_name][sigma_key][seq_name][m]["ssim"])
                results[dataset_name][sigma_key]["dataset_mean"][m] = {
                    "psnr": summarize(all_ps),
                    "ssim": summarize(all_ss),
                    "num_frames": int(len(all_ps)),
                }
                if args.compute_strred:
                    vals = strred_values[dataset_name][sigma_key][m]
                    results[dataset_name][sigma_key]["dataset_mean"][m]["strred"] = summarize(vals)

    decision_metrics: Dict[str, Dict[str, Any]] = {}
    for m in METHODS:
        yt = np.concatenate(decision_true[m], axis=0).astype(np.uint8) if decision_true[m] else np.array([], dtype=np.uint8)
        yp = np.concatenate(decision_pred[m], axis=0).astype(np.uint8) if decision_pred[m] else np.array([], dtype=np.uint8)
        decision_metrics[m] = compute_decision_metrics(yt, yp, w_set)
        save_confusion_and_hist(out_dir / "figures", m, yt, yp, w_set)

    a1_table = build_a1_table(decision_metrics)
    a2_table = build_a2_table(results, sigmas)

    report_payload = {
        "config": {
            "base_root": str(base_root),
            "davis_jpeg_dir": str(davis_jpeg_dir),
            "set8_dir": str(set8_dir),
            "davis_clips": davis_clips,
            "sigmas": sigmas,
            "max_frames_per_seq": int(args.max_frames_per_seq),
            "seed": int(args.seed),
            "h_disp": int(args.h_disp),
            "v_disp": int(args.v_disp),
            "mb_size": int(args.mb_size),
            "baseline_temporal_weight": int(args.baseline_temporal_weight),
            "baseline_threshold": int(args.baseline_threshold),
            "w_set": [int(x) for x in w_set.tolist()],
            "model_dir_multiclass": str(model_dir_mc),
            "model_dir_reg": str(model_dir_reg),
            "model_dir_ordinal": str(model_dir_ord),
            "tau_tuned_json": str(tau_tuned_json),
            "compute_strred": bool(args.compute_strred),
            "save_visual_cases": bool(args.save_visual_cases),
            "case_specs": [c.__dict__ for c in case_specs],
            "ordinal_thresholds": [int(x) for x in ord_thresholds.tolist()],
        },
        "results": results,
        "decision_metrics": decision_metrics,
        "table_A1_decision_markdown": a1_table,
        "table_A2_image_markdown": a2_table,
        "captured_cases": captured_cases,
    }

    out_json = out_dir / "metrics_groupA_full.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(report_payload, f, ensure_ascii=False, indent=2)

    build_markdown_report(
        out_dir=out_dir,
        config=report_payload["config"],
        decision_metrics=decision_metrics,
        a1_table=a1_table,
        a2_table=a2_table,
    )

    print("\n=== Table A1: Decision-level Metrics ===")
    print(a1_table)
    print("\n=== Table A2: Image-level Metrics (PSNR/SSIM) ===")
    print(a2_table)
    print(f"\n[OUT] {out_json}")
    print(f"[OUT] {out_dir / 'groupA_report.md'}")


if __name__ == "__main__":
    main()
