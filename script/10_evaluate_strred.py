#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Evaluate Baseline and OOTW-3DNR on DAVIS + Set8 under multiple AWGN sigmas
with video-level ST-RRED metric.

Protocol:
- Sigma list: [10, 20, 30, 40, 50]
- Max 85 frames per sequence
- Datasets:
  DAVIS clips: surf, bear, bmx-trees
  Set8: auto-discover all image-sequence folders under script/Set8
"""

from __future__ import annotations

import argparse
import gc
import importlib.util
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np
from lightgbm import Booster
from PIL import Image

# Compatibility shim for old scikit-video code paths on newer NumPy.
if not hasattr(np, "int"):
    np.int = int  # type: ignore[attr-defined]

try:
    from skvideo.measure import strred
except Exception as e:
    raise ImportError(
        "Failed to import skvideo.measure.strred. "
        "Please install scikit-video first, e.g. `pip install scikit-video`."
    ) from e


IMG_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Full DAVIS+Set8 ST-RRED evaluation for Baseline vs OOTW-3DNR.")
    p.add_argument(
        "--base_root",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script",
        help="Root containing 3dnr.py, oracle_lib.py, DAVIS, Set8, model outputs.",
    )
    p.add_argument("--davis_clips", type=str, default="surf,bear,bmx-trees")
    p.add_argument("--sigmas", type=str, default="10,20,30,40,50")
    p.add_argument("--max_frames_per_seq", type=int, default=85)
    p.add_argument("--seed", type=int, default=123)
    p.add_argument("--h_disp", type=int, default=480)
    p.add_argument("--v_disp", type=int, default=320)
    p.add_argument("--mb_size", type=int, default=4)
    p.add_argument("--baseline_temporal_weight", type=int, default=16)
    p.add_argument("--baseline_threshold", type=int, default=4095)
    p.add_argument("--w_set", type=str, default="0,4,8,12,16,20,24,28,31")
    p.add_argument("--set8_dir", type=str, default="")
    p.add_argument("--davis_jpeg_dir", type=str, default="")
    p.add_argument("--model_dir", type=str, default="")
    p.add_argument("--tau_json", type=str, default="")
    p.add_argument("--tdnr_py", type=str, default="")
    p.add_argument("--oracle_lib_py", type=str, default="")
    p.add_argument("--out_json", type=str, default="metrics_strred_full.json")
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


def summarize(values: Sequence[float]) -> Dict[str, float]:
    arr = np.asarray(values, dtype=np.float64)
    if arr.size == 0:
        return {"mean": float("nan"), "std": float("nan")}
    return {"mean": float(np.nanmean(arr)), "std": float(np.nanstd(arr, ddof=0))}


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


def reduce_strred_output(val: Any) -> Tuple[float, Dict[str, Any]]:
    def _mean(x: Any) -> float:
        arr = np.asarray(x, dtype=np.float64)
        if arr.size == 0:
            return float("nan")
        return float(np.nanmean(arr))

    detail: Dict[str, Any] = {"type": type(val).__name__}
    if isinstance(val, (tuple, list)):
        parts = [_mean(v) for v in val]
        detail["parts_mean"] = parts
        if len(parts) > 0:
            detail["strred_mean"] = parts[0]
        if len(parts) > 1:
            detail["srred_mean"] = parts[1]
        if len(parts) > 2:
            detail["trred_mean"] = parts[2]
        score = parts[0] if len(parts) > 0 else float("nan")
    else:
        score = _mean(val)
        detail["mean"] = score
    return score, detail


def evaluate_sequence_strred(
    dataset_name: str,
    seq_name: str,
    frames: List[Path],
    sigma: int,
    seed: int,
    shape_helper: Any,
    tdnr_mod: Any,
    oracle_mod: Any,
    models: Sequence[Booster],
    tau: np.ndarray,
    w_set: np.ndarray,
    model_feature_names: Sequence[str],
    log1p_keys: Sequence[str],
    mb_size: int,
    baseline_temporal_weight: int,
    baseline_threshold: int,
) -> Dict[str, Dict[str, Any]]:
    baseline_nr = tdnr_mod.ThreeDNR(
        h_disp=shape_helper.h_disp,
        v_disp=shape_helper.v_disp,
        temporal_weight=baseline_temporal_weight,
        mb_threshold=baseline_threshold,
    )
    me_holder = tdnr_mod.ThreeDNR(
        h_disp=shape_helper.h_disp,
        v_disp=shape_helper.v_disp,
        temporal_weight=baseline_temporal_weight,
        mb_threshold=baseline_threshold,
    )

    rng = np.random.default_rng(seed)
    prev_baseline = None
    prev_ours = None

    list_clean: List[np.ndarray] = []
    list_baseline: List[np.ndarray] = []
    list_ours: List[np.ndarray] = []

    n = len(frames)
    for i, fp in enumerate(frames, start=1):
        clean_raw = load_rgb(fp)
        clean = shape_helper._ensure_resolution(clean_raw)
        noisy = np.clip(
            clean.astype(np.float32) + rng.normal(0.0, float(sigma), clean.shape),
            0.0,
            255.0,
        ).astype(np.uint8)

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
            mb_size=mb_size,
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
        out_ours = temporal_blend_with_wmap(noisy, ref_ours, w_map, mb_size=mb_size)
        prev_ours = out_ours

        # ST-RRED is typically computed on luma video sequence.
        list_clean.append(oracle_mod.rgb_to_luma_u8(clean))
        list_baseline.append(oracle_mod.rgb_to_luma_u8(out_baseline))
        list_ours.append(oracle_mod.rgb_to_luma_u8(out_ours))

        print(f"[{dataset_name}] sequence '{seq_name}' | sigma={sigma} | Frame {i}/{n} Done")

    arr_clean = np.stack(list_clean, axis=0)
    arr_baseline = np.stack(list_baseline, axis=0)
    arr_ours = np.stack(list_ours, axis=0)

    baseline_raw = strred(arr_clean, arr_baseline)
    ours_raw = strred(arr_clean, arr_ours)
    baseline_score, baseline_detail = reduce_strred_output(baseline_raw)
    ours_score, ours_detail = reduce_strred_output(ours_raw)

    # Release memory aggressively for long runs.
    del arr_clean, arr_baseline, arr_ours
    del list_clean, list_baseline, list_ours
    gc.collect()

    return {
        "traditional_baseline": {
            "strred": float(baseline_score),
            "detail": baseline_detail,
            "num_frames": int(n),
        },
        "ours_ootw_3dnr": {
            "strred": float(ours_score),
            "detail": ours_detail,
            "num_frames": int(n),
        },
    }


def build_markdown_table(
    results: Dict[str, Any],
    sigmas: List[int],
    methods: List[str],
    datasets: List[str],
) -> str:
    header = "| Dataset & Method | " + " | ".join([f"sigma={s}" for s in sigmas]) + " |"
    sep = "|" + "---|" * (len(sigmas) + 1)
    lines = [header, sep]
    for ds in datasets:
        for m in methods:
            row = [f"{ds} - {m}"]
            for s in sigmas:
                k = f"sigma_{s}"
                md = results[ds][k]["dataset_mean"][m]
                cell = f"{md['strred']['mean']:.6f}"
                row.append(cell)
            lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    base_root = Path(args.base_root)

    davis_jpeg_dir = (
        Path(args.davis_jpeg_dir)
        if args.davis_jpeg_dir
        else (base_root / "DAVIS-2017-trainval-480p" / "DAVIS" / "JPEGImages" / "480p")
    )
    set8_dir = Path(args.set8_dir) if args.set8_dir else (base_root / "Set8")
    model_dir = Path(args.model_dir) if args.model_dir else (base_root / "out_train_ord_v2_full" / "models")
    tau_json = Path(args.tau_json) if args.tau_json else (base_root / "out_ordinal_tune_v2_full" / "report" / "taus_monotone.json")
    tdnr_py = Path(args.tdnr_py) if args.tdnr_py else (base_root / "3dnr.py")
    oracle_lib_py = Path(args.oracle_lib_py) if args.oracle_lib_py else (base_root / "oracle_lib.py")
    out_json = Path(args.out_json)
    if not out_json.is_absolute():
        out_json = Path.cwd() / out_json

    for p in [davis_jpeg_dir, set8_dir, model_dir, tau_json, tdnr_py, oracle_lib_py]:
        if not Path(p).exists():
            raise SystemExit(f"required path not found: {p}")

    davis_clips = parse_csv_str(args.davis_clips)
    sigmas = parse_csv_int(args.sigmas)
    w_set = np.asarray(parse_csv_int(args.w_set), dtype=np.uint8)
    if w_set.size == 0:
        raise SystemExit("empty w_set")

    tdnr_mod = load_module(tdnr_py, "tdnr_module_eval10")
    oracle_mod = load_module(oracle_lib_py, "oracle_module_eval10")

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

    shape_helper = tdnr_mod.ThreeDNR(
        h_disp=args.h_disp,
        v_disp=args.v_disp,
        temporal_weight=args.baseline_temporal_weight,
        mb_threshold=args.baseline_threshold,
    )

    davis_sequences: Dict[str, List[Path]] = {}
    for clip in davis_clips:
        cdir = davis_jpeg_dir / clip
        if not cdir.is_dir():
            print(f"[WARNING] DAVIS clip not found, skip: {clip}")
            continue
        frames = list_image_frames(cdir, args.max_frames_per_seq)
        if not frames:
            print(f"[WARNING] DAVIS clip has no images, skip: {clip}")
            continue
        davis_sequences[clip] = frames

    set8_sequences = discover_set8_sequences(set8_dir, args.max_frames_per_seq)
    if len(set8_sequences) == 0:
        print("[WARNING] no Set8 sequences discovered")

    print(f"[INFO] DAVIS sequences: {list(davis_sequences.keys())}")
    print(f"[INFO] Set8 discovered sequence count: {len(set8_sequences)}")
    print(f"[INFO] Sigmas: {sigmas}")
    print(f"[INFO] Max frames per sequence: {args.max_frames_per_seq}")
    print(f"[INFO] Model feature names: {model_feature_names}")
    print(f"[INFO] log1p keys: {log1p_keys}")
    print("[INFO] Metric: ST-RRED (lower is better)")

    datasets = {
        "DAVIS": davis_sequences,
        "Set8": set8_sequences,
    }
    methods = ["traditional_baseline", "ours_ootw_3dnr"]
    results: Dict[str, Any] = {"DAVIS": {}, "Set8": {}}

    for dsi, (dataset_name, seq_map) in enumerate(datasets.items()):
        for sigma in sigmas:
            sigma_key = f"sigma_{sigma}"
            results[dataset_name][sigma_key] = {
                "clips": {},
                "dataset_mean": {},
            }
            dataset_method_strred: Dict[str, List[float]] = {m: [] for m in methods}

            for seqi, (seq_name, frames) in enumerate(seq_map.items()):
                seq_seed = (
                    int(args.seed)
                    + int(sigma) * 10007
                    + int(dsi) * 1000003
                    + int(seqi) * 1009
                )
                seq_result = evaluate_sequence_strred(
                    dataset_name=dataset_name,
                    seq_name=seq_name,
                    frames=frames,
                    sigma=sigma,
                    seed=seq_seed,
                    shape_helper=shape_helper,
                    tdnr_mod=tdnr_mod,
                    oracle_mod=oracle_mod,
                    models=models,
                    tau=tau,
                    w_set=w_set,
                    model_feature_names=model_feature_names,
                    log1p_keys=log1p_keys,
                    mb_size=args.mb_size,
                    baseline_temporal_weight=args.baseline_temporal_weight,
                    baseline_threshold=args.baseline_threshold,
                )

                clip_store: Dict[str, Any] = {}
                for m in methods:
                    clip_store[m] = seq_result[m]
                    dataset_method_strred[m].append(float(seq_result[m]["strred"]))
                results[dataset_name][sigma_key]["clips"][seq_name] = clip_store

            for m in methods:
                results[dataset_name][sigma_key]["dataset_mean"][m] = {
                    "strred": summarize(dataset_method_strred[m]),
                    "num_clips": int(len(dataset_method_strred[m])),
                }

    markdown_table = build_markdown_table(
        results=results,
        sigmas=sigmas,
        methods=methods,
        datasets=["DAVIS", "Set8"],
    )

    out_payload = {
        "config": {
            "base_root": str(base_root),
            "davis_jpeg_dir": str(davis_jpeg_dir),
            "set8_dir": str(set8_dir),
            "model_dir": str(model_dir),
            "tau_json": str(tau_json),
            "tdnr_py": str(tdnr_py),
            "oracle_lib_py": str(oracle_lib_py),
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
            "model_feature_names": model_feature_names,
            "log1p_keys": log1p_keys,
            "metric": "ST-RRED",
            "metric_direction": "lower_is_better",
        },
        "results": results,
        "markdown_summary_table_strred": markdown_table,
    }

    out_json.parent.mkdir(parents=True, exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(out_payload, f, ensure_ascii=False, indent=2)

    print("\n=== Markdown Summary Table (ST-RRED, lower is better) ===")
    print(markdown_table)
    print(f"\n[OUT] {out_json}")


if __name__ == "__main__":
    main()
