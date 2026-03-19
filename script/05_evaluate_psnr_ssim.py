#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Stage-5: Evaluate PSNR / SSIM for 3DNR variants.

Methods:
1) noisy_input          : noisy frame vs GT
2) traditional_baseline : legacy 3DNR (fixed threshold + fixed temporal weight)
3) ours_ootw_3dnr       : ordinal model + tuned monotone tau -> w_map_student
4) oracle_upper_bound   : oracle w_label map
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


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Evaluate PSNR/SSIM for noisy/baseline/ours/oracle")
    p.add_argument("--oracle_dir", type=str, default="./oracle_batch_out_v2")
    p.add_argument("--noisy_dir", type=str, default="./davis_clips_noisy_npz")
    p.add_argument("--model_dir", type=str, default="./out_train_ord_v2_full/models")
    p.add_argument("--tau_json", type=str, default="./out_ordinal_tune_v2_full/report/taus_monotone.json")
    p.add_argument("--tdnr_py", type=str, default="./3dnr.py")
    p.add_argument("--videos", type=str, default="surf,bear,bmx-trees")
    p.add_argument("--max_samples_per_video", type=int, default=12)
    p.add_argument("--seed", type=int, default=123)
    p.add_argument("--baseline_temporal_weight", type=int, default=16)
    p.add_argument("--baseline_threshold", type=int, default=4095)
    p.add_argument("--mb_size", type=int, default=4)
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
    p.add_argument("--out_dir", type=str, default="./out_psnr_ssim_eval")
    return p.parse_args()


def parse_csv(s: str) -> List[str]:
    return [x.strip() for x in s.split(",") if x.strip()]


def load_tdnr_module(path: Path) -> Any:
    if not path.is_file():
        raise FileNotFoundError(f"tdnr python file not found: {path}")
    spec = importlib.util.spec_from_file_location("tdnr_module", str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load module: {path}")
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
        raise RuntimeError(f"cannot parse ordinal thresholds from {model_dir}")
    models = [Booster(model_file=str(p)) for _, p in items]
    t_list = np.array([t for t, _ in items], dtype=np.int32)
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
            raise RuntimeError(f"oracle features missing column: {n}")
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
    x = align_and_preprocess_features(feat_3d, feat_names, model_feature_names, log1p_keys)
    p_list = [np.asarray(m.predict(x), dtype=np.float32) for m in models]
    p = np.stack(p_list, axis=1)
    if p.shape[1] != tau.shape[0]:
        raise RuntimeError(f"tau dim mismatch: p={p.shape}, tau={tau.shape}")
    rank = (p >= tau[None, :]).sum(axis=1)
    rank = np.clip(rank, 0, len(w_set) - 1)
    return w_set[rank].astype(np.uint8).reshape(h, w)


def temporal_blend_with_wmap(cur: np.ndarray, ref: np.ndarray, w_map: np.ndarray, mb_size: int) -> np.ndarray:
    h, w = cur.shape[:2]
    expected_h = (h // mb_size) * mb_size
    expected_w = (w // mb_size) * mb_size
    if w_map.shape != (expected_h // mb_size, expected_w // mb_size):
        raise ValueError(f"w_map shape mismatch: got {w_map.shape}, expect {(expected_h // mb_size, expected_w // mb_size)}")
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


def parse_video_name(fp: Path) -> str:
    m = re.match(r"(.+)_t\d+_f\d+_oracle\.npz$", fp.name)
    if m:
        return m.group(1)
    return fp.stem


def pick_oracle_files(oracle_dir: Path, videos: Sequence[str], max_per_video: int, seed: int) -> List[Path]:
    rng = np.random.default_rng(seed)
    out: List[Path] = []
    for v in videos:
        files = sorted(oracle_dir.glob(f"{v}_t*_f*_oracle.npz"))
        if len(files) == 0:
            print(f"[WARNING] no oracle files for video={v}")
            continue
        if max_per_video > 0 and len(files) > max_per_video:
            idx = rng.choice(len(files), size=max_per_video, replace=False)
            idx.sort()
            files = [files[int(i)] for i in idx]
        out.extend(files)
    return sorted(out)


def summarize(values: Sequence[float]) -> Dict[str, float]:
    a = np.asarray(values, dtype=np.float64)
    if a.size == 0:
        return {"mean": float("nan"), "std": float("nan")}
    return {"mean": float(a.mean()), "std": float(a.std(ddof=0))}


def main() -> None:
    args = parse_args()
    oracle_dir = Path(args.oracle_dir)
    noisy_dir = Path(args.noisy_dir)
    model_dir = Path(args.model_dir)
    tau_json = Path(args.tau_json)
    tdnr_py = Path(args.tdnr_py)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not oracle_dir.is_dir():
        raise SystemExit(f"oracle_dir not found: {oracle_dir}")
    if not noisy_dir.is_dir():
        raise SystemExit(f"noisy_dir not found: {noisy_dir}")

    tdnr = load_tdnr_module(tdnr_py)
    baseline_nr = tdnr.ThreeDNR(
        h_disp=480,
        v_disp=320,
        temporal_weight=args.baseline_temporal_weight,
        mb_threshold=args.baseline_threshold,
    )

    models, t_model = load_ordinal_models(model_dir)
    t_tau, tau = load_tau_json(tau_json)
    if not np.array_equal(t_model.astype(np.int32), t_tau.astype(np.int32)):
        raise RuntimeError(f"threshold mismatch: model={t_model.tolist()} vs tau={t_tau.tolist()}")

    fallback_feat = parse_csv(args.default_model_feature_names)
    fallback_log1p = parse_csv(args.default_log1p_keys)
    model_feature_names, log1p_keys = load_train_config_feature_recipe(model_dir, fallback_feat, fallback_log1p)

    videos = parse_csv(args.videos)
    eval_files = pick_oracle_files(oracle_dir, videos, args.max_samples_per_video, args.seed)
    if len(eval_files) == 0:
        raise SystemExit("no evaluation files selected")

    print("[INFO] videos:", videos)
    print("[INFO] selected oracle samples:", len(eval_files))
    print("[INFO] model_feature_names:", model_feature_names)
    print("[INFO] log1p_keys:", log1p_keys)

    methods = ["noisy_input", "traditional_baseline", "ours_ootw_3dnr", "oracle_upper_bound"]
    per_method_psnr: Dict[str, List[float]] = {m: [] for m in methods}
    per_method_ssim: Dict[str, List[float]] = {m: [] for m in methods}
    per_video_method_psnr: Dict[str, Dict[str, List[float]]] = defaultdict(lambda: {m: [] for m in methods})
    per_video_method_ssim: Dict[str, Dict[str, List[float]]] = defaultdict(lambda: {m: [] for m in methods})
    sample_rows: List[Dict[str, Any]] = []

    for i, ofp in enumerate(eval_files, start=1):
        with np.load(ofp, allow_pickle=False) as d:
            feat = d["features"]
            feat_names = d["feature_names"]
            w_oracle = d["w_label"].astype(np.uint8)
            w_set = d["w_set"].astype(np.uint8)
            meta = json.loads(str(d["meta"]))

        src_file = str(meta["input_file"])
        frame_idx = int(meta["frame_idx"])
        noisy_path = noisy_dir / src_file
        if not noisy_path.is_file():
            print(f"[WARNING] skip missing noisy file: {noisy_path.name}")
            continue

        with np.load(noisy_path, allow_pickle=False) as n:
            frames_gt = n["frames_gt"]
            frames_noisy = n["frames_noisy"]
        if frame_idx <= 0 or frame_idx >= frames_gt.shape[0]:
            print(f"[WARNING] skip invalid frame_idx={frame_idx} for {src_file}")
            continue

        cur = frames_noisy[frame_idx]
        ref = frames_noisy[frame_idx - 1]
        gt = frames_gt[frame_idx]

        w_ours = predict_wmap_ordinal(
            models=models,
            tau=tau,
            w_set=w_set,
            feat_3d=feat,
            feat_names=feat_names,
            model_feature_names=model_feature_names,
            log1p_keys=log1p_keys,
        )

        baseline_nr.reset()
        out_baseline = baseline_nr.process(cur, ref)
        out_ours = temporal_blend_with_wmap(cur, ref, w_ours, mb_size=args.mb_size)
        out_oracle = temporal_blend_with_wmap(cur, ref, w_oracle, mb_size=args.mb_size)

        eval_pack = {
            "noisy_input": cur,
            "traditional_baseline": out_baseline,
            "ours_ootw_3dnr": out_ours,
            "oracle_upper_bound": out_oracle,
        }

        video = parse_video_name(ofp)
        for m in methods:
            p, s = compute_psnr_ssim(gt, eval_pack[m])
            per_method_psnr[m].append(p)
            per_method_ssim[m].append(s)
            per_video_method_psnr[video][m].append(p)
            per_video_method_ssim[video][m].append(s)
            sample_rows.append(
                {
                    "video": video,
                    "sample": ofp.name,
                    "method": m,
                    "psnr": p,
                    "ssim": s,
                }
            )

        if i % 10 == 0 or i == len(eval_files):
            print(f"[PROGRESS] {i}/{len(eval_files)}")

    summary_overall: Dict[str, Dict[str, Dict[str, float]]] = {}
    for m in methods:
        summary_overall[m] = {
            "psnr": summarize(per_method_psnr[m]),
            "ssim": summarize(per_method_ssim[m]),
            "num_samples": {"count": float(len(per_method_psnr[m]))},
        }

    summary_by_video: Dict[str, Dict[str, Dict[str, Dict[str, float]]]] = {}
    for v in sorted(per_video_method_psnr.keys()):
        summary_by_video[v] = {}
        for m in methods:
            summary_by_video[v][m] = {
                "psnr": summarize(per_video_method_psnr[v][m]),
                "ssim": summarize(per_video_method_ssim[v][m]),
                "num_samples": {"count": float(len(per_video_method_psnr[v][m]))},
            }

    out_json = {
        "config": {
            "oracle_dir": str(oracle_dir),
            "noisy_dir": str(noisy_dir),
            "model_dir": str(model_dir),
            "tau_json": str(tau_json),
            "videos": videos,
            "max_samples_per_video": int(args.max_samples_per_video),
            "baseline_temporal_weight": int(args.baseline_temporal_weight),
            "baseline_threshold": int(args.baseline_threshold),
            "model_feature_names": model_feature_names,
            "log1p_keys": log1p_keys,
        },
        "overall": summary_overall,
        "by_video": summary_by_video,
        "samples": sample_rows,
    }

    out_path = out_dir / "metrics_psnr_ssim.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_json, f, ensure_ascii=False, indent=2)

    print("\n=== Overall (mean ± std) ===")
    for m in methods:
        p = summary_overall[m]["psnr"]
        s = summary_overall[m]["ssim"]
        n = int(summary_overall[m]["num_samples"]["count"])
        print(f"{m:22s}  PSNR={p['mean']:.4f}±{p['std']:.4f}  SSIM={s['mean']:.6f}±{s['std']:.6f}  N={n}")

    print("\n=== By Video (mean) ===")
    for v in sorted(summary_by_video.keys()):
        print(f"[{v}]")
        for m in methods:
            pm = summary_by_video[v][m]["psnr"]["mean"]
            sm = summary_by_video[v][m]["ssim"]["mean"]
            n = int(summary_by_video[v][m]["num_samples"]["count"])
            print(f"  {m:22s}  PSNR={pm:.4f}  SSIM={sm:.6f}  N={n}")

    print(f"\n[OUT] {out_path}")


if __name__ == "__main__":
    main()
