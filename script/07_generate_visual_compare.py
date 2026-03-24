#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Generate visual comparison figures for paper presentation.

Outputs under: script/fig_visual_compare
  - Clean_GT_full.png
  - Noisy_sigma30_full.png
  - Baseline_full.png
  - Ours_full.png
  - Clean_GT_patch.png
  - Noisy_patch.png
  - Baseline_patch.png
  - Ours_patch.png
  - Combined_Patches.png (optional, if matplotlib is available)
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np
from lightgbm import Booster
from PIL import Image, ImageDraw


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate visual full-frame + ROI patch comparison for bmx-trees.")
    p.add_argument(
        "--base_root",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script",
        help="Root containing 3dnr.py, oracle_lib.py, DAVIS, model outputs.",
    )
    p.add_argument("--clip", type=str, default="bmx-trees")
    p.add_argument("--sigma", type=int, default=30)
    p.add_argument("--target_frame", type=int, default=40, help="0-based frame index in sequence.")
    p.add_argument("--seed", type=int, default=123)
    p.add_argument("--h_disp", type=int, default=480)
    p.add_argument("--v_disp", type=int, default=320)
    p.add_argument("--mb_size", type=int, default=4)
    p.add_argument("--baseline_temporal_weight", type=int, default=16)
    p.add_argument("--baseline_threshold", type=int, default=4095)
    p.add_argument("--w_set", type=str, default="0,4,8,12,16,20,24,28,31")

    # ROI settings (adjustable)
    p.add_argument("--roi_x", type=int, default=140)
    p.add_argument("--roi_y", type=int, default=95)
    p.add_argument("--roi_w", type=int, default=150)
    p.add_argument("--roi_h", type=int, default=150)

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

    p.add_argument(
        "--out_dir",
        type=str,
        default="",
        help="Optional override. Default: script/fig_visual_compare beside this script.",
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


def list_frames(clip_dir: Path) -> List[Path]:
    files = sorted(clip_dir.glob("*.jpg"))
    if not files:
        files = sorted(clip_dir.glob("*.png"))
    return files


def load_rgb(path: Path) -> np.ndarray:
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8)


def draw_roi_and_save(img: np.ndarray, out_path: Path, x1: int, y1: int, x2: int, y2: int, width: int = 4) -> None:
    pil = Image.fromarray(img)
    draw = ImageDraw.Draw(pil)
    draw.rectangle((x1, y1, x2 - 1, y2 - 1), outline=(255, 0, 0), width=width)
    pil.save(out_path)


def main() -> None:
    args = parse_args()

    base_root = Path(args.base_root)
    davis_jpeg_dir = base_root / "DAVIS-2017-trainval-480p" / "DAVIS" / "JPEGImages" / "480p"
    model_dir = base_root / "out_train_ord_v2_full" / "models"
    tau_json = base_root / "out_ordinal_tune_v2_full" / "report" / "taus_monotone.json"
    tdnr_py = base_root / "3dnr.py"
    oracle_lib_py = base_root / "oracle_lib.py"
    out_dir = Path(args.out_dir) if args.out_dir else (Path(__file__).resolve().parent / "fig_visual_compare")
    out_dir.mkdir(parents=True, exist_ok=True)

    for p in [davis_jpeg_dir, model_dir]:
        if not p.exists():
            raise SystemExit(f"path not found: {p}")
    if not tau_json.is_file():
        raise SystemExit(f"tau_json not found: {tau_json}")

    clip_dir = davis_jpeg_dir / args.clip
    frames = list_frames(clip_dir)
    if not frames:
        raise SystemExit(f"no frames found for clip: {clip_dir}")
    if args.target_frame < 0 or args.target_frame >= len(frames):
        raise SystemExit(f"target_frame out of range: {args.target_frame}, total={len(frames)}")
    if args.target_frame == 0:
        raise SystemExit("target_frame should be >= 1 to have previous frame reference.")

    tdnr_mod = load_module(tdnr_py, "tdnr_module_for_visual")
    oracle_mod = load_module(oracle_lib_py, "oracle_module_for_visual")

    models, t_model = load_ordinal_models(model_dir)
    t_tau, tau = load_tau_json(tau_json)
    if not np.array_equal(t_model.astype(np.int32), t_tau.astype(np.int32)):
        raise RuntimeError(f"threshold mismatch: model={t_model.tolist()} vs tau={t_tau.tolist()}")

    w_set = np.asarray(parse_csv_int(args.w_set), dtype=np.uint8)
    fallback_feat = parse_csv_str(args.default_model_feature_names)
    fallback_log1p = parse_csv_str(args.default_log1p_keys)
    model_feature_names, log1p_keys = load_train_config_feature_recipe(
        model_dir=model_dir,
        fallback_feature_names=fallback_feat,
        fallback_log1p_keys=fallback_log1p,
    )

    shape_helper = tdnr_mod.ThreeDNR(
        h_disp=args.h_disp,
        v_disp=args.v_disp,
        temporal_weight=args.baseline_temporal_weight,
        mb_threshold=args.baseline_threshold,
    )
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

    rng = np.random.default_rng(args.seed + args.sigma * 10007)
    prev_baseline = None
    prev_ours = None

    clean_tgt = None
    noisy_tgt = None
    baseline_tgt = None
    ours_tgt = None

    print(f"[INFO] clip={args.clip}, target_frame={args.target_frame}, sigma={args.sigma}")
    for idx in range(args.target_frame + 1):
        clean_raw = load_rgb(frames[idx])
        clean = shape_helper._ensure_resolution(clean_raw)
        noise = rng.normal(0.0, float(args.sigma), clean.shape).astype(np.float32)
        noisy = np.clip(clean.astype(np.float32) + noise, 0.0, 255.0).astype(np.uint8)

        ref_baseline = prev_baseline if prev_baseline is not None else noisy
        out_baseline = baseline_nr.process(noisy, ref_baseline)
        prev_baseline = out_baseline

        ref_ours = prev_ours if prev_ours is not None else noisy
        feat_3d, feat_names = build_feature_v2_for_ours(
            cur_noisy=noisy,
            ref_img=ref_ours,
            tdnr_mod=tdnr_mod,
            oracle_mod=oracle_mod,
            me_obj=me_holder.me_td,
            mb_size=args.mb_size,
        )
        w_map = predict_wmap_ordinal(
            models=models,
            tau=tau,
            w_set=w_set,
            feat_3d=feat_3d,
            feat_names=feat_names,
            model_feature_names=model_feature_names,
            log1p_keys=log1p_keys,
        )
        out_ours = temporal_blend_with_wmap(noisy, ref_ours, w_map, mb_size=args.mb_size)
        prev_ours = out_ours

        if idx == args.target_frame:
            clean_tgt = clean
            noisy_tgt = noisy
            baseline_tgt = out_baseline
            ours_tgt = out_ours
            break

    if clean_tgt is None:
        raise RuntimeError("failed to capture target frame outputs")

    h, w = clean_tgt.shape[:2]
    x1 = max(0, min(args.roi_x, w - 1))
    y1 = max(0, min(args.roi_y, h - 1))
    x2 = max(x1 + 1, min(x1 + args.roi_w, w))
    y2 = max(y1 + 1, min(y1 + args.roi_h, h))

    full_clean = out_dir / "Clean_GT_full.png"
    full_noisy = out_dir / f"Noisy_sigma{args.sigma}_full.png"
    full_base = out_dir / "Baseline_full.png"
    full_ours = out_dir / "Ours_full.png"
    draw_roi_and_save(clean_tgt, full_clean, x1, y1, x2, y2)
    draw_roi_and_save(noisy_tgt, full_noisy, x1, y1, x2, y2)
    draw_roi_and_save(baseline_tgt, full_base, x1, y1, x2, y2)
    draw_roi_and_save(ours_tgt, full_ours, x1, y1, x2, y2)

    clean_patch = clean_tgt[y1:y2, x1:x2]
    noisy_patch = noisy_tgt[y1:y2, x1:x2]
    base_patch = baseline_tgt[y1:y2, x1:x2]
    ours_patch = ours_tgt[y1:y2, x1:x2]

    patch_clean_p = out_dir / "Clean_GT_patch.png"
    patch_noisy_p = out_dir / "Noisy_patch.png"
    patch_base_p = out_dir / "Baseline_patch.png"
    patch_ours_p = out_dir / "Ours_patch.png"
    Image.fromarray(clean_patch).save(patch_clean_p)
    Image.fromarray(noisy_patch).save(patch_noisy_p)
    Image.fromarray(base_patch).save(patch_base_p)
    Image.fromarray(ours_patch).save(patch_ours_p)

    combined_path = out_dir / "Combined_Patches.png"
    try:
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 4, figsize=(16, 4), dpi=180)
        titles = ["Clean GT", f"Noisy (sigma={args.sigma})", "Baseline", "Ours"]
        imgs = [clean_patch, noisy_patch, base_patch, ours_patch]
        for ax, title, img in zip(axes, titles, imgs):
            ax.imshow(img)
            ax.set_title(title, fontsize=10)
            ax.axis("off")
        plt.tight_layout()
        fig.savefig(combined_path, bbox_inches="tight")
        plt.close(fig)
    except Exception as exc:
        print(f"[WARNING] Combined patch figure skipped: {exc}")

    meta = {
        "clip": args.clip,
        "sigma": int(args.sigma),
        "target_frame": int(args.target_frame),
        "frame_file": frames[args.target_frame].name,
        "roi": {"x1": int(x1), "y1": int(y1), "x2": int(x2), "y2": int(y2), "w": int(x2 - x1), "h": int(y2 - y1)},
        "paths": {
            "Clean_GT_full": str(full_clean),
            "Noisy_full": str(full_noisy),
            "Baseline_full": str(full_base),
            "Ours_full": str(full_ours),
            "Clean_GT_patch": str(patch_clean_p),
            "Noisy_patch": str(patch_noisy_p),
            "Baseline_patch": str(patch_base_p),
            "Ours_patch": str(patch_ours_p),
            "Combined_Patches": str(combined_path),
        },
    }
    with open(out_dir / "visual_compare_meta.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    print("\n[OUT] Generated files:")
    for k, v in meta["paths"].items():
        print(f"  - {k}: {v}")
    print(f"[OUT] metadata: {out_dir / 'visual_compare_meta.json'}")


if __name__ == "__main__":
    main()
