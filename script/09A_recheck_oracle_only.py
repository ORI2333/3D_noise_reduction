#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import annotations

import argparse
import gc
import importlib.util
import json
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np
from PIL import Image
from sklearn.metrics import accuracy_score, f1_score, precision_recall_fscore_support
from skimage.metrics import peak_signal_noise_ratio as psnr
from skimage.metrics import structural_similarity as ssim


IMG_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Re-evaluate oracle branch only and patch Group-A metrics JSON.")
    p.add_argument(
        "--base_metrics_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_groupA_paperA\metrics_groupA_full.json",
    )
    p.add_argument(
        "--out_metrics_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_groupA_paperA_oraclefix\metrics_groupA_full.json",
    )
    return p.parse_args()


def load_module(module_path: Path, module_name: str) -> Any:
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


def main() -> None:
    args = parse_args()
    base_metrics = Path(args.base_metrics_json)
    out_metrics = Path(args.out_metrics_json)
    out_metrics.parent.mkdir(parents=True, exist_ok=True)

    payload = json.loads(base_metrics.read_text(encoding="utf-8"))
    cfg = payload["config"]

    base_root = Path(cfg["base_root"])
    davis_jpeg_dir = Path(cfg["davis_jpeg_dir"])
    set8_dir = Path(cfg["set8_dir"])
    davis_clips = list(cfg["davis_clips"])
    sigmas = [int(x) for x in cfg["sigmas"]]
    max_frames_per_seq = int(cfg["max_frames_per_seq"])
    seed = int(cfg["seed"])
    mb_size = int(cfg["mb_size"])
    w_set = np.asarray(cfg["w_set"], dtype=np.uint8)

    tdnr_py = base_root / "3dnr.py"
    oracle_lib_py = base_root / "oracle_lib.py"
    tdnr_mod = load_module(tdnr_py, "tdnr_mod_oracle_recheck")
    oracle_mod = load_module(oracle_lib_py, "oracle_mod_oracle_recheck")

    shape_helper = tdnr_mod.ThreeDNR(
        h_disp=int(cfg["h_disp"]),
        v_disp=int(cfg["v_disp"]),
        temporal_weight=int(cfg["baseline_temporal_weight"]),
        mb_threshold=int(cfg["baseline_threshold"]),
    )

    davis_sequences: Dict[str, List[Path]] = {}
    for clip in davis_clips:
        cdir = davis_jpeg_dir / clip
        if not cdir.is_dir():
            continue
        frames = list_image_frames(cdir, max_frames_per_seq)
        if frames:
            davis_sequences[clip] = frames
    set8_sequences = discover_set8_sequences(set8_dir, max_frames_per_seq)
    datasets = {"DAVIS": davis_sequences, "Set8": set8_sequences}

    decision_true: List[np.ndarray] = []
    decision_pred: List[np.ndarray] = []

    for dsi, (dataset_name, seq_map) in enumerate(datasets.items()):
        for sigma in sigmas:
            sigma_key = f"sigma_{sigma}"
            for seqi, (seq_name, frames) in enumerate(seq_map.items()):
                seq_seed = int(seed) + int(sigma) * 10007 + int(dsi) * 1000003 + int(seqi) * 1009
                rng = np.random.default_rng(seq_seed)
                prev_oracle: np.ndarray | None = None
                n = len(frames)

                psnr_list: List[float] = []
                ssim_list: List[float] = []

                for fi, fp in enumerate(frames, start=1):
                    clean_raw = load_rgb(fp)
                    clean = shape_helper._ensure_resolution(clean_raw)
                    noisy = np.clip(
                        clean.astype(np.float32) + rng.normal(0.0, float(sigma), clean.shape),
                        0.0,
                        255.0,
                    ).astype(np.uint8)
                    ref_oracle = prev_oracle if prev_oracle is not None else noisy

                    w_oracle = oracle_mod.oracle_label_w(
                        cur_noisy=noisy,
                        ref_noisy=ref_oracle,
                        gt=clean,
                        w_set=w_set,
                        temporal_iir_filter_fn=tdnr_mod.temporal_iir_filter,
                        mb_size=mb_size,
                    ).astype(np.uint8)
                    out_oracle = temporal_blend_with_wmap(noisy, ref_oracle, w_oracle, mb_size=mb_size)
                    prev_oracle = out_oracle

                    p, s = compute_psnr_ssim(clean, out_oracle)
                    psnr_list.append(p)
                    ssim_list.append(s)

                    decision_true.append(w_oracle.reshape(-1))
                    decision_pred.append(w_oracle.reshape(-1))

                    print(
                        f"[ORACLE-RECHECK] [{dataset_name}] '{seq_name}' sigma={sigma} frame {fi}/{n}"
                    )

                payload["results"][dataset_name][sigma_key]["clips"][seq_name]["oracle"] = {
                    "psnr": summarize(psnr_list),
                    "ssim": summarize(ssim_list),
                    "num_frames": int(len(psnr_list)),
                }
                gc.collect()

            all_ps: List[float] = []
            all_ss: List[float] = []
            for seq_name in payload["results"][dataset_name][sigma_key]["clips"]:
                x = payload["results"][dataset_name][sigma_key]["clips"][seq_name]["oracle"]
                if x["num_frames"] > 0:
                    # approximate weighted aggregation by frame count when only mean is kept
                    all_ps.extend([float(x["psnr"]["mean"])] * int(x["num_frames"]))
                    all_ss.extend([float(x["ssim"]["mean"])] * int(x["num_frames"]))
            payload["results"][dataset_name][sigma_key]["dataset_mean"]["oracle"] = {
                "psnr": summarize(all_ps),
                "ssim": summarize(all_ss),
                "num_frames": int(len(all_ps)),
            }

    yt = np.concatenate(decision_true, axis=0).astype(np.uint8) if decision_true else np.array([], dtype=np.uint8)
    yp = np.concatenate(decision_pred, axis=0).astype(np.uint8) if decision_pred else np.array([], dtype=np.uint8)
    payload["decision_metrics"]["oracle"] = compute_decision_metrics(yt, yp, w_set)

    with open(out_metrics, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(f"[OUT] {out_metrics}")


if __name__ == "__main__":
    main()

