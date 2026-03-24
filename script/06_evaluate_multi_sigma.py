#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Evaluate Noisy/Baseline/Ours PSNR-SSIM under multiple AWGN sigma levels.

Target clips (DAVIS 480p): surf, bear, bmx-trees
Sigma list: [10, 20, 30] by default.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np
from lightgbm import Booster
from skimage.metrics import peak_signal_noise_ratio as psnr
from skimage.metrics import structural_similarity as ssim

try:
    from PIL import Image
except Exception as exc:  # pragma: no cover
    raise RuntimeError("Pillow is required. Please `pip install pillow`.") from exc


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Evaluate Baseline vs Ours across multiple AWGN sigmas.")
    p.add_argument(
        "--base_root",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script",
        help="Project script root that contains 3dnr.py, oracle_lib.py, models, DAVIS.",
    )
    p.add_argument(
        "--davis_jpeg_dir",
        type=str,
        default="",
        help="Optional override. Default: <base_root>/DAVIS-2017-trainval-480p/DAVIS/JPEGImages/480p",
    )
    p.add_argument("--model_dir", type=str, default="", help="Optional override. Default: <base_root>/out_train_ord_v2_full/models")
    p.add_argument("--tau_json", type=str, default="", help="Optional override. Default: <base_root>/out_ordinal_tune_v2_full/report/taus_monotone.json")
    p.add_argument("--tdnr_py", type=str, default="", help="Optional override. Default: <base_root>/3dnr.py")
    p.add_argument("--oracle_lib_py", type=str, default="", help="Optional override. Default: <base_root>/oracle_lib.py")
    p.add_argument("--clips", type=str, default="surf,bear,bmx-trees")
    p.add_argument("--sigmas", type=str, default="10,20,30")
    p.add_argument("--seed", type=int, default=123)
    p.add_argument("--h_disp", type=int, default=480, help="3DNR width")
    p.add_argument("--v_disp", type=int, default=320, help="3DNR height")
    p.add_argument("--mb_size", type=int, default=4)
    p.add_argument("--baseline_temporal_weight", type=int, default=16)
    p.add_argument("--baseline_threshold", type=int, default=4095)
    p.add_argument("--w_set", type=str, default="0,4,8,12,16,20,24,28,31")
    p.add_argument("--max_frames_per_clip", type=int, default=0, help="0 means all frames")
    p.add_argument("--out_json", type=str, default="metrics_multi_sigma.json")
    p.add_argument(
        "--default_model_feature_names",
        type=str,
        default="sad1_ds,sad2_ds,margin_ds,sad1_mb_best,mv_mag,sum,grad_energy",
    )
    p.add_argument(
        "--default_log1p_keys",
        type=str,
        default="sad1_ds,sad2_ds,margin_ds,sad1_mb_best,grad_energy,sum",
    )
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


def load_ordinal_models(model_dir: Path) -> Tuple[List[Booster], np.ndarray]:
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
        raise RuntimeError(f"cannot parse thresholds from model files in {model_dir}")
    models = [Booster(model_file=str(p)) for _, p in items]
    t_list = np.asarray([t for t, _ in items], dtype=np.int32)
    return models, t_list


def load_tau_json(path: Path) -> Tuple[np.ndarray, np.ndarray]:
    with open(path, "r", encoding="utf-8") as f:
        d = json.load(f)
    t_list = np.asarray(d["thresholds_T"], dtype=np.int32)
    tau = np.asarray(d["tau"], dtype=np.float32)
    return t_list, tau


def load_train_config_feature_recipe(
    model_dir: Path,
    fallback_feature_names: Sequence[str],
    fallback_log1p_keys: Sequence[str],
) -> Tuple[List[str], List[str]]:
    cfg_path = model_dir / "train_config.json"
    if not cfg_path.is_file():
        return list(fallback_feature_names), list(fallback_log1p_keys)
    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    feat = cfg.get("dataset", {}).get("feature_names_after_drop", None)
    if not feat:
        feat = list(fallback_feature_names)
    log1p = cfg.get("log1p_applied", None)
    if log1p is None:
        log1p = list(fallback_log1p_keys)
    return [str(x) for x in feat], [str(x) for x in log1p]


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


def predict_wmap_ordinal(
    models: Sequence[Booster],
    tau: np.ndarray,
    w_set: np.ndarray,
    feat_3d: np.ndarray,
    feat_names: np.ndarray,
    model_feature_names: Sequence[str],
    log1p_keys: Sequence[str],
) -> np.ndarray:
    h, w, _ = feat_3d.shape
    x = align_and_preprocess_features(
        feat_3d=feat_3d,
        feat_names=feat_names,
        model_feature_names=model_feature_names,
        log1p_keys=log1p_keys,
    )
    p_list = [np.asarray(m.predict(x), dtype=np.float32) for m in models]
    p = np.stack(p_list, axis=1)
    if p.shape[1] != tau.shape[0]:
        raise RuntimeError(f"tau dim mismatch: p={p.shape}, tau={tau.shape}")
    rank = (p >= tau[None, :]).sum(axis=1)
    rank = np.clip(rank, 0, len(w_set) - 1)
    return w_set[rank].astype(np.uint8).reshape(h, w)


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


def compute_psnr_ssim(gt: np.ndarray, pred: np.ndarray) -> Tuple[float, float]:
    p = float(psnr(gt, pred, data_range=255))
    try:
        s = float(ssim(gt, pred, data_range=255, channel_axis=2))
    except TypeError:
        s = float(ssim(gt, pred, data_range=255, multichannel=True))
    return p, s


def summarize(values: Sequence[float]) -> Dict[str, float]:
    arr = np.asarray(values, dtype=np.float64)
    if arr.size == 0:
        return {"mean": float("nan"), "std": float("nan")}
    return {"mean": float(arr.mean()), "std": float(arr.std(ddof=0))}


def list_clip_frames(clip_dir: Path, max_frames: int) -> List[Path]:
    files = sorted(clip_dir.glob("*.jpg"))
    if not files:
        files = sorted(clip_dir.glob("*.png"))
    if max_frames > 0:
        files = files[:max_frames]
    return files


def load_rgb(path: Path) -> np.ndarray:
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8)


def build_feature_v2_for_ours(
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
        proc_mb=proc_mb,
        ref_mb=ref_mb,
        ref_sub=ref_sub,
        me=me_obj,
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
        [
            "sad1_ds",
            "sad2_ds",
            "margin_ds",
            "sad1_mb_best",
            "mv_mag",
            "sum",
            "grad_energy",
            "prev_w",
        ],
        dtype="U",
    )
    return features, feature_names


def main() -> None:
    args = parse_args()

    base_root = Path(args.base_root)
    davis_jpeg_dir = Path(args.davis_jpeg_dir) if args.davis_jpeg_dir else (base_root / "DAVIS-2017-trainval-480p" / "DAVIS" / "JPEGImages" / "480p")
    model_dir = Path(args.model_dir) if args.model_dir else (base_root / "out_train_ord_v2_full" / "models")
    tau_json = Path(args.tau_json) if args.tau_json else (base_root / "out_ordinal_tune_v2_full" / "report" / "taus_monotone.json")
    tdnr_py = Path(args.tdnr_py) if args.tdnr_py else (base_root / "3dnr.py")
    oracle_lib_py = Path(args.oracle_lib_py) if args.oracle_lib_py else (base_root / "oracle_lib.py")
    out_json = Path(args.out_json)
    if not out_json.is_absolute():
        out_json = Path.cwd() / out_json

    if not davis_jpeg_dir.is_dir():
        raise SystemExit(f"davis_jpeg_dir not found: {davis_jpeg_dir}")
    if not model_dir.is_dir():
        raise SystemExit(f"model_dir not found: {model_dir}")
    if not tau_json.is_file():
        raise SystemExit(f"tau_json not found: {tau_json}")

    clips = parse_csv_str(args.clips)
    sigmas = parse_csv_int(args.sigmas)
    w_set = np.asarray(parse_csv_int(args.w_set), dtype=np.uint8)
    if w_set.ndim != 1 or w_set.size == 0:
        raise SystemExit("invalid w_set")

    tdnr_mod = load_module(tdnr_py, "tdnr_module_for_multi_sigma")
    oracle_mod = load_module(oracle_lib_py, "oracle_lib_for_multi_sigma")

    models, t_model = load_ordinal_models(model_dir)
    t_tau, tau = load_tau_json(tau_json)
    if not np.array_equal(t_model.astype(np.int32), t_tau.astype(np.int32)):
        raise RuntimeError(f"threshold mismatch: model={t_model.tolist()} vs tau={t_tau.tolist()}")

    fallback_feat = parse_csv_str(args.default_model_feature_names)
    fallback_log1p = parse_csv_str(args.default_log1p_keys)
    model_feature_names, log1p_keys = load_train_config_feature_recipe(
        model_dir=model_dir,
        fallback_feature_names=fallback_feat,
        fallback_log1p_keys=fallback_log1p,
    )

    # A helper instance to access the same resize path as pipeline.
    shape_helper = tdnr_mod.ThreeDNR(
        h_disp=args.h_disp,
        v_disp=args.v_disp,
        temporal_weight=args.baseline_temporal_weight,
        mb_threshold=args.baseline_threshold,
    )

    methods = ["noisy_input", "traditional_baseline", "ours_ootw_3dnr"]
    per_sigma_method_psnr: Dict[str, Dict[str, List[float]]] = {}
    per_sigma_method_ssim: Dict[str, Dict[str, List[float]]] = {}
    per_sigma_clip_method: Dict[str, Dict[str, Dict[str, Dict[str, float]]]] = {}

    print("[INFO] base_root:", base_root)
    print("[INFO] davis_jpeg_dir:", davis_jpeg_dir)
    print("[INFO] clips:", clips)
    print("[INFO] sigmas:", sigmas)
    print("[INFO] model_feature_names:", model_feature_names)
    print("[INFO] log1p_keys:", log1p_keys)

    for sigma in sigmas:
        key_sigma = str(sigma)
        rng = np.random.default_rng(args.seed + sigma * 10007)

        method_psnr = {m: [] for m in methods}
        method_ssim = {m: [] for m in methods}
        per_clip_detail: Dict[str, Dict[str, List[float]]] = {
            clip: {f"{m}_psnr": [] for m in methods} | {f"{m}_ssim": [] for m in methods}
            for clip in clips
        }

        print(f"\n[RUN] sigma={sigma}")
        for clip in clips:
            clip_dir = davis_jpeg_dir / clip
            frames = list_clip_frames(clip_dir, args.max_frames_per_clip)
            if not frames:
                print(f"[WARNING] skip clip={clip}, no frames under {clip_dir}")
                continue

            baseline_nr = tdnr_mod.ThreeDNR(
                h_disp=args.h_disp,
                v_disp=args.v_disp,
                temporal_weight=args.baseline_temporal_weight,
                mb_threshold=args.baseline_threshold,
            )
            # For feature extraction we only need me_td internals.
            me_holder = tdnr_mod.ThreeDNR(
                h_disp=args.h_disp,
                v_disp=args.v_disp,
                temporal_weight=args.baseline_temporal_weight,
                mb_threshold=args.baseline_threshold,
            )

            prev_baseline = None
            prev_ours = None

            for idx, fp in enumerate(frames):
                clean_raw = load_rgb(fp)
                clean = shape_helper._ensure_resolution(clean_raw)

                noise = rng.normal(0.0, float(sigma), clean.shape).astype(np.float32)
                noisy = np.clip(clean.astype(np.float32) + noise, 0.0, 255.0).astype(np.uint8)

                # Noisy input metric
                p_noisy, s_noisy = compute_psnr_ssim(clean, noisy)
                method_psnr["noisy_input"].append(p_noisy)
                method_ssim["noisy_input"].append(s_noisy)
                per_clip_detail[clip]["noisy_input_psnr"].append(p_noisy)
                per_clip_detail[clip]["noisy_input_ssim"].append(s_noisy)

                # Baseline: previous processed frame as reference
                ref_baseline = prev_baseline if prev_baseline is not None else noisy
                out_baseline = baseline_nr.process(noisy, ref_baseline)
                prev_baseline = out_baseline

                p_b, s_b = compute_psnr_ssim(clean, out_baseline)
                method_psnr["traditional_baseline"].append(p_b)
                method_ssim["traditional_baseline"].append(s_b)
                per_clip_detail[clip]["traditional_baseline_psnr"].append(p_b)
                per_clip_detail[clip]["traditional_baseline_ssim"].append(s_b)

                # Ours: previous processed frame as reference + frame-wise feature extraction
                ref_ours = prev_ours if prev_ours is not None else noisy
                feat_3d, feat_names = build_feature_v2_for_ours(
                    cur_noisy=noisy,
                    ref_img=ref_ours,
                    tdnr_mod=tdnr_mod,
                    oracle_mod=oracle_mod,
                    me_obj=me_holder.me_td,
                    mb_size=args.mb_size,
                )
                w_ours = predict_wmap_ordinal(
                    models=models,
                    tau=tau,
                    w_set=w_set,
                    feat_3d=feat_3d,
                    feat_names=feat_names,
                    model_feature_names=model_feature_names,
                    log1p_keys=log1p_keys,
                )
                out_ours = temporal_blend_with_wmap(noisy, ref_ours, w_ours, mb_size=args.mb_size)
                prev_ours = out_ours

                p_o, s_o = compute_psnr_ssim(clean, out_ours)
                method_psnr["ours_ootw_3dnr"].append(p_o)
                method_ssim["ours_ootw_3dnr"].append(s_o)
                per_clip_detail[clip]["ours_ootw_3dnr_psnr"].append(p_o)
                per_clip_detail[clip]["ours_ootw_3dnr_ssim"].append(s_o)

                if (idx + 1) % 20 == 0 or (idx + 1) == len(frames):
                    print(f"  [clip={clip}] {idx + 1}/{len(frames)}")

        per_sigma_method_psnr[key_sigma] = method_psnr
        per_sigma_method_ssim[key_sigma] = method_ssim

        clip_summary: Dict[str, Dict[str, Dict[str, float]]] = {}
        for clip in clips:
            clip_summary[clip] = {}
            for m in methods:
                ps = per_clip_detail[clip][f"{m}_psnr"]
                ss = per_clip_detail[clip][f"{m}_ssim"]
                clip_summary[clip][m] = {
                    "psnr_mean": summarize(ps)["mean"],
                    "ssim_mean": summarize(ss)["mean"],
                    "num_frames": int(len(ps)),
                }
        per_sigma_clip_method[key_sigma] = clip_summary

    result: Dict[str, Any] = {
        "config": {
            "base_root": str(base_root),
            "davis_jpeg_dir": str(davis_jpeg_dir),
            "model_dir": str(model_dir),
            "tau_json": str(tau_json),
            "tdnr_py": str(tdnr_py),
            "oracle_lib_py": str(oracle_lib_py),
            "clips": clips,
            "sigmas": sigmas,
            "seed": int(args.seed),
            "h_disp": int(args.h_disp),
            "v_disp": int(args.v_disp),
            "mb_size": int(args.mb_size),
            "baseline_temporal_weight": int(args.baseline_temporal_weight),
            "baseline_threshold": int(args.baseline_threshold),
            "w_set": [int(x) for x in w_set.tolist()],
            "max_frames_per_clip": int(args.max_frames_per_clip),
            "model_feature_names": model_feature_names,
            "log1p_keys": log1p_keys,
        },
        "overall": {},
        "by_clip": per_sigma_clip_method,
    }

    print("\n=== Overall Metrics by Sigma ===")
    for sigma in sigmas:
        key_sigma = str(sigma)
        result["overall"][key_sigma] = {}
        print(f"[sigma={sigma}]")
        for m in methods:
            p_sum = summarize(per_sigma_method_psnr[key_sigma][m])
            s_sum = summarize(per_sigma_method_ssim[key_sigma][m])
            n = len(per_sigma_method_psnr[key_sigma][m])
            result["overall"][key_sigma][m] = {
                "psnr_mean": p_sum["mean"],
                "psnr_std": p_sum["std"],
                "ssim_mean": s_sum["mean"],
                "ssim_std": s_sum["std"],
                "num_frames": int(n),
            }
            print(
                f"  {m:22s} "
                f"PSNR={p_sum['mean']:.4f}±{p_sum['std']:.4f}  "
                f"SSIM={s_sum['mean']:.6f}±{s_sum['std']:.6f}  "
                f"N={n}"
            )

    out_json.parent.mkdir(parents=True, exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"\n[OUT] {out_json}")


if __name__ == "__main__":
    main()

