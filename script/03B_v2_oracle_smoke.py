#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script V2-S1: V2 per-clip Oracle 批量 Smoke 生成

功能：
1) 从 noisy clips(*.npz) 中抽样少量文件（默认 20）
2) 生成 V2 per-clip oracle：<clip_name>_oracle_v2.npz
3) 抽检 1 个输出并打印关键信息
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List

import numpy as np

import oracle_lib as olib


def parse_args() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(description="V2 per-clip Oracle smoke 生成。")
    parser.add_argument("--noisy_dir", type=str, required=True, help="Script02 输出目录（*.npz）")
    parser.add_argument("--out_dir", type=str, required=True, help="输出目录")
    parser.add_argument("--max_files", type=int, default=20, help="最多处理文件数，默认 20")
    parser.add_argument("--seed", type=int, default=123, help="随机种子，默认 123")
    parser.add_argument("--pattern", type=str, default="*.npz", help="输入 glob，默认 *.npz")
    parser.add_argument("--frame_idx", type=int, default=1, help="标注帧索引，默认 1")
    parser.add_argument(
        "--w_set",
        type=str,
        default="0,4,8,12,16,20,24,28,31",
        help='候选权重集合，例如 "0,4,8,12,16,20,24,28,31"',
    )
    parser.add_argument(
        "--save_png",
        type=str,
        default="false",
        help="smoke 默认 false（参数保留，不导出 png）",
    )
    return parser.parse_args()


def pick_files(all_files: List[Path], max_files: int, seed: int) -> List[Path]:
    """按随机种子从输入文件中采样。"""
    if max_files <= 0 or max_files >= len(all_files):
        return all_files
    rng = np.random.default_rng(seed)
    idx = rng.choice(len(all_files), size=max_files, replace=False)
    idx.sort()
    return [all_files[int(i)] for i in idx]


def main() -> None:
    """主流程。"""
    args = parse_args()
    w_set = olib.parse_w_set(args.w_set)

    noisy_dir = Path(args.noisy_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not noisy_dir.is_dir():
        raise FileNotFoundError(f"输入目录不存在: {noisy_dir}")
    if args.frame_idx < 1:
        raise ValueError("frame_idx 必须 >= 1")

    all_files = sorted(noisy_dir.glob(args.pattern))
    if not all_files:
        raise FileNotFoundError(f"未找到输入文件: {noisy_dir} / {args.pattern}")
    in_files = pick_files(all_files, args.max_files, args.seed)

    print(f"[信息] 输入文件总数: {len(all_files)}")
    print(f"[信息] 本次处理文件数: {len(in_files)}")

    tdnr = olib.load_tdnr_module(Path(__file__).resolve().parent)
    nr = tdnr.ThreeDNR(h_disp=480, v_disp=320)

    out_files: List[Path] = []
    for i, src_path in enumerate(in_files, start=1):
        with np.load(src_path, allow_pickle=False) as data:
            if "frames_gt" not in data.files or "frames_noisy" not in data.files:
                raise ValueError(f"{src_path.name}: 缺少 frames_gt 或 frames_noisy")
            frames_gt = data["frames_gt"]
            frames_noisy = data["frames_noisy"]

            if frames_gt.dtype != np.uint8 or frames_noisy.dtype != np.uint8:
                raise ValueError(f"{src_path.name}: frames_gt/frames_noisy 必须 uint8")
            if frames_gt.shape != frames_noisy.shape:
                raise ValueError(f"{src_path.name}: frames_gt 与 frames_noisy shape 不一致")
            if frames_gt.ndim != 4 or frames_gt.shape[-1] != 3:
                raise ValueError(f"{src_path.name}: 期望 (T,H,W,3)，实际 {frames_gt.shape}")
            if args.frame_idx >= frames_gt.shape[0]:
                raise ValueError(f"{src_path.name}: frame_idx 越界，T={frames_gt.shape[0]}")
            if tuple(frames_gt.shape[1:3]) != (320, 480):
                raise ValueError(f"{src_path.name}: 分辨率应为 (320,480)，实际 {frames_gt.shape[1:3]}")

            cur_noisy = frames_noisy[args.frame_idx]
            ref_noisy = frames_noisy[args.frame_idx - 1]
            gt = frames_gt[args.frame_idx]

            luma_cur = olib.rgb_to_luma_u8(cur_noisy)
            luma_ref = olib.rgb_to_luma_u8(ref_noisy)
            proc_mb, _ = tdnr.MBDownSampler.compute(luma_cur)
            ref_mb, ref_sub = tdnr.MBDownSampler.compute(luma_ref)

            sad1_ds, sad2_ds, margin_ds, sad1_mb_best, mv_mag = olib.extract_me_features_v2(
                proc_mb=proc_mb,
                ref_mb=ref_mb,
                ref_sub=ref_sub,
                me=nr.me_td,
            )
            sum_map = proc_mb.astype(np.int32)
            grad_energy = olib.compute_grad_energy_map(luma_cur, mb_size=4)
            prev_w = np.zeros_like(sum_map, dtype=np.int32)

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
            w_label = olib.oracle_label_w(
                cur_noisy=cur_noisy,
                ref_noisy=ref_noisy,
                gt=gt,
                w_set=w_set,
                temporal_iir_filter_fn=tdnr.temporal_iir_filter,
                mb_size=4,
            )

            out_path = out_dir / f"{src_path.stem}_oracle_v2.npz"
            meta = {
                "src_file": src_path.name,
                "frame_idx": int(args.frame_idx),
                "feature_version": "v2_ds_mb_split",
                "w_set": [int(v) for v in w_set.tolist()],
                "mb_size": 4,
                "h": 320,
                "w": 480,
            }
            np.savez_compressed(
                out_path,
                features=features.astype(np.float32),
                w_label=w_label.astype(np.uint8),
                feature_names=feature_names,
                w_set=w_set.astype(np.uint8),
                clip_name=np.array(src_path.name, dtype="U"),
                frame_idx=np.int32(args.frame_idx),
                meta=np.array(json.dumps(meta, ensure_ascii=False), dtype="U"),
            )
            out_files.append(out_path)

        if (i % 10 == 0) or (i == len(in_files)):
            print(f"[进度] {i}/{len(in_files)}")

    print(f"[信息] 生成完成，输出文件数: {len(out_files)}")

    if out_files:
        rng = np.random.default_rng(args.seed + 999)
        sample_file = out_files[int(rng.integers(0, len(out_files)))]
        with np.load(sample_file, allow_pickle=False) as d:
            feat = d["features"]
            w_label = d["w_label"]
            names = d["feature_names"]
            uniq = np.unique(w_label)
            bad = np.setdiff1d(uniq, w_set)
            print(f"[抽检] 文件: {sample_file.name}")
            print(f"[抽检] feature_names: {names.tolist()}")
            print(f"[抽检] features shape: {feat.shape}, dtype={feat.dtype}")
            print(f"[抽检] w_label unique: {uniq.tolist()}")
            print(f"[抽检] unique 是否属于 w_set: {'YES' if bad.size == 0 else 'NO'}")
            if bad.size != 0:
                print(f"[抽检] 非法类别: {bad.tolist()}")


if __name__ == "__main__":
    main()

