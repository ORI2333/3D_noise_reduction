#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Batch visual generation for three representative DAVIS scenes.

Output directory:
  script/fig_visual_compare_multi
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np
from lightgbm import Booster
from PIL import Image, ImageDraw


@dataclass
class SceneConfig:
    name: str
    output_prefix: str
    clip_candidates: List[str]
    sigma: int
    target_frame: int
    roi_x: int
    roi_y: int
    roi_w: int
    roi_h: int


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate multiple visual comparison scenes for paper figures.")
    p.add_argument(
        "--base_root",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script",
        help="Root containing 3dnr.py, oracle_lib.py, DAVIS, model outputs.",
    )
    p.add_argument("--h_disp", type=int, default=480)
    p.add_argument("--v_disp", type=int, default=320)
    p.add_argument("--mb_size", type=int, default=4)
    p.add_argument("--baseline_temporal_weight", type=int, default=16)
    p.add_argument("--baseline_threshold", type=int, default=4095)
    p.add_argument("--w_set", type=str, default="0,4,8,12,16,20,24,28,31")
    p.add_argument("--seed", type=int, default=123)
    p.add_argument(
        "--out_dir",
        type=str,
        default="",
        help="Optional override. Default: script/fig_visual_compare_multi beside this script.",
    )
    p.add_argument(
        "--only_prefix",
        type=str,
        default="",
        help="Run only one scene by prefix, e.g. SceneB_Flat_.",
    )
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


def pick_existing_clip(scene: SceneConfig, available: set[str]) -> str:
    for c in scene.clip_candidates:
        if c in available:
            return c
    raise RuntimeError(f"No candidate clip found for {scene.name}. Candidates={scene.clip_candidates}")


def build_scene_configs() -> List[SceneConfig]:
    return [
        SceneConfig(
            name="Scene A: Occlusion & Complex Motion",
            output_prefix="SceneA_Motion_",
            clip_candidates=["motocross-jump", "bmx-trees"],
            sigma=40,
            target_frame=30,
            roi_x=170,
            roi_y=95,
            roi_w=150,
            roi_h=150,
        ),
        SceneConfig(
            name="Scene B: Flat areas & Background Noise",
            output_prefix="SceneB_Flat_",
            clip_candidates=["kite-surf", "surf"],
            sigma=40,
            target_frame=40,
            roi_x=20,
            roi_y=10,
            roi_w=170,
            roi_h=150,
        ),
        SceneConfig(
            name="Scene C: Fine details & Texture",
            output_prefix="SceneC_Texture_",
            clip_candidates=["scooter-black", "bear"],
            sigma=50,
            target_frame=30,
            roi_x=150,
            roi_y=100,
            roi_w=150,
            roi_h=150,
        ),
    ]


def save_combined_patch(combined_path: Path, sigma: int, clean_patch: np.ndarray, noisy_patch: np.ndarray, base_patch: np.ndarray, ours_patch: np.ndarray) -> str:
    try:
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 4, figsize=(16, 4), dpi=180)
        titles = ["Clean GT", f"Noisy (sigma={sigma})", "Baseline", "Ours"]
        imgs = [clean_patch, noisy_patch, base_patch, ours_patch]
        for ax, title, img in zip(axes, titles, imgs):
            ax.imshow(img)
            ax.set_title(title, fontsize=10)
            ax.axis("off")
        plt.tight_layout()
        fig.savefig(combined_path, bbox_inches="tight")
        plt.close(fig)
        return "ok"
    except Exception as exc:  # pragma: no cover
        return f"skipped: {exc}"


def main() -> None:
    args = parse_args()

    base_root = Path(args.base_root)
    davis_jpeg_dir = base_root / "DAVIS-2017-trainval-480p" / "DAVIS" / "JPEGImages" / "480p"
    model_dir = base_root / "out_train_ord_v2_full" / "models"
    tau_json = base_root / "out_ordinal_tune_v2_full" / "report" / "taus_monotone.json"
    tdnr_py = base_root / "3dnr.py"
    oracle_lib_py = base_root / "oracle_lib.py"

    out_dir = Path(args.out_dir) if args.out_dir else (Path(__file__).resolve().parent / "fig_visual_compare_multi")
    out_dir.mkdir(parents=True, exist_ok=True)

    for p in [davis_jpeg_dir, model_dir, tdnr_py, oracle_lib_py, tau_json]:
        if not Path(p).exists():
            raise SystemExit(f"required path not found: {p}")

    available_clips = {p.name for p in davis_jpeg_dir.iterdir() if p.is_dir()}
    scene_cfgs = build_scene_configs()

    tdnr_mod = load_module(tdnr_py, "tdnr_module_for_multi_visual")
    oracle_mod = load_module(oracle_lib_py, "oracle_module_for_multi_visual")

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

    summary: Dict[str, Dict[str, Any]] = {}

    for scene_idx, scene in enumerate(scene_cfgs):
        if args.only_prefix and scene.output_prefix != args.only_prefix:
            continue
        clip = pick_existing_clip(scene, available_clips)
        clip_dir = davis_jpeg_dir / clip
        frames = list_frames(clip_dir)
        if not frames:
            print(f"[WARNING] no frames in clip={clip}, skip {scene.name}")
            continue

        # Ensure frame index is valid; fallback to middle frame if needed.
        target_frame = scene.target_frame
        if target_frame >= len(frames):
            target_frame = len(frames) // 2

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

        rng = np.random.default_rng(args.seed + scene_idx * 100003 + scene.sigma * 10007)
        prev_baseline = None
        prev_ours = None

        clean_tgt = None
        noisy_tgt = None
        baseline_tgt = None
        ours_tgt = None

        print(f"\n[RUN] {scene.name}")
        print(f"  clip={clip}, sigma={scene.sigma}, target_frame={target_frame}")

        for idx in range(target_frame + 1):
            clean_raw = load_rgb(frames[idx])
            clean = shape_helper._ensure_resolution(clean_raw)
            noise = rng.normal(0.0, float(scene.sigma), clean.shape).astype(np.float32)
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

            if idx == target_frame:
                clean_tgt = clean
                noisy_tgt = noisy
                baseline_tgt = out_baseline
                ours_tgt = out_ours
                break

        if clean_tgt is None:
            print(f"  [WARNING] failed to capture target frame for {scene.name}")
            continue

        h, w = clean_tgt.shape[:2]
        x1 = max(0, min(scene.roi_x, w - 1))
        y1 = max(0, min(scene.roi_y, h - 1))
        x2 = max(x1 + 1, min(x1 + scene.roi_w, w))
        y2 = max(y1 + 1, min(y1 + scene.roi_h, h))

        # Export full images with ROI box.
        pref = scene.output_prefix
        full_clean = out_dir / f"{pref}Clean_GT_full.png"
        full_noisy = out_dir / f"{pref}Noisy_sigma{scene.sigma}_full.png"
        full_base = out_dir / f"{pref}Baseline_full.png"
        full_ours = out_dir / f"{pref}Ours_full.png"
        draw_roi_and_save(clean_tgt, full_clean, x1, y1, x2, y2)
        draw_roi_and_save(noisy_tgt, full_noisy, x1, y1, x2, y2)
        draw_roi_and_save(baseline_tgt, full_base, x1, y1, x2, y2)
        draw_roi_and_save(ours_tgt, full_ours, x1, y1, x2, y2)

        # Export patches.
        clean_patch = clean_tgt[y1:y2, x1:x2]
        noisy_patch = noisy_tgt[y1:y2, x1:x2]
        base_patch = baseline_tgt[y1:y2, x1:x2]
        ours_patch = ours_tgt[y1:y2, x1:x2]

        patch_clean = out_dir / f"{pref}Clean_GT_patch.png"
        patch_noisy = out_dir / f"{pref}Noisy_patch.png"
        patch_base = out_dir / f"{pref}Baseline_patch.png"
        patch_ours = out_dir / f"{pref}Ours_patch.png"
        Image.fromarray(clean_patch).save(patch_clean)
        Image.fromarray(noisy_patch).save(patch_noisy)
        Image.fromarray(base_patch).save(patch_base)
        Image.fromarray(ours_patch).save(patch_ours)

        combined = out_dir / f"{pref}Combined.png"
        combined_status = save_combined_patch(
            combined_path=combined,
            sigma=scene.sigma,
            clean_patch=clean_patch,
            noisy_patch=noisy_patch,
            base_patch=base_patch,
            ours_patch=ours_patch,
        )

        print(f"  ROI used: x1={x1}, y1={y1}, x2={x2}, y2={y2}, size={x2-x1}x{y2-y1}")
        print("  If ROI is not ideal, please tune roi_x/roi_y/roi_w/roi_h in build_scene_configs().")

        summary[scene.output_prefix] = {
            "scene_name": scene.name,
            "clip": clip,
            "sigma": int(scene.sigma),
            "target_frame": int(target_frame),
            "frame_file": frames[target_frame].name,
            "roi": {"x1": int(x1), "y1": int(y1), "x2": int(x2), "y2": int(y2), "w": int(x2 - x1), "h": int(y2 - y1)},
            "files": {
                "clean_full": str(full_clean),
                "noisy_full": str(full_noisy),
                "baseline_full": str(full_base),
                "ours_full": str(full_ours),
                "clean_patch": str(patch_clean),
                "noisy_patch": str(patch_noisy),
                "baseline_patch": str(patch_base),
                "ours_patch": str(patch_ours),
                "combined": str(combined),
            },
            "combined_status": combined_status,
        }

    meta_path = out_dir / "visual_compare_multi_meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    print("\n[OUT] Done. Scene files saved to:")
    print(f"  {out_dir}")
    print(f"[OUT] Metadata: {meta_path}")


if __name__ == "__main__":
    main()


