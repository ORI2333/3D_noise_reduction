#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script 03B: 批量生成 features->w_label 训练数据集（扁平化 X/y，支持分片）。
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List, Optional

import numpy as np

import oracle_lib as olib


def parse_args() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(
        description="遍历 noisy clips，生成扁平化 Oracle 训练数据集。"
    )
    parser.add_argument("--in_dir", type=str, required=True, help="Script02 输出目录（*.npz）")
    parser.add_argument("--out_npz", type=str, required=True, help="输出训练集 npz 文件名")
    parser.add_argument(
        "--out_dir",
        type=str,
        default=None,
        help="可选，输出目录；默认自动使用 <out_npz_stem>_shards",
    )
    parser.add_argument("--frame_idx", type=int, default=1, help="用于打标签的帧索引，默认 1")
    parser.add_argument(
        "--w_set",
        type=str,
        default="0,4,8,12,16,20,24,28,31",
        help='候选权重集合，例如 "0,4,8,12,16,20,24,28,31"',
    )
    parser.add_argument(
        "--max_files",
        type=int,
        default=None,
        help="可选，仅处理前 N 个输入文件（按文件名排序）",
    )
    parser.add_argument("--seed", type=int, default=123, help="随机种子（保留用于扩展）")
    parser.add_argument(
        "--save_feature_stats",
        action="store_true",
        help="保存每个特征的 min/max/mean/std 到 json",
    )
    parser.add_argument(
        "--shard_size",
        type=int,
        default=200,
        help="每个分片最多处理多少个文件，默认 200；<=0 表示单文件输出",
    )
    parser.add_argument(
        "--save_info",
        action="store_true",
        help="是否保存 info(N,4) 调试索引（默认不保存以节省空间）",
    )
    return parser.parse_args()


def compute_feature_stats(X: np.ndarray) -> Dict[str, np.ndarray]:
    """计算单批样本的 min/max/sum/sumsq/count（按列）。"""
    Xf = X.astype(np.float64)
    return {
        "min": Xf.min(axis=0),
        "max": Xf.max(axis=0),
        "sum": Xf.sum(axis=0),
        "sumsq": (Xf * Xf).sum(axis=0),
        "count": np.array([Xf.shape[0]], dtype=np.int64),
    }


def merge_feature_stats(
    dst: Optional[Dict[str, np.ndarray]],
    src: Dict[str, np.ndarray],
) -> Dict[str, np.ndarray]:
    """累计特征统计量。"""
    if dst is None:
        return src
    dst["min"] = np.minimum(dst["min"], src["min"])
    dst["max"] = np.maximum(dst["max"], src["max"])
    dst["sum"] = dst["sum"] + src["sum"]
    dst["sumsq"] = dst["sumsq"] + src["sumsq"]
    dst["count"] = dst["count"] + src["count"]
    return dst


def finalize_feature_stats(stats_acc: Dict[str, np.ndarray], feature_names: np.ndarray) -> Dict[str, Dict[str, float]]:
    """将累计量转成 min/max/mean/std。"""
    n = float(stats_acc["count"][0])
    mean = stats_acc["sum"] / n
    var = stats_acc["sumsq"] / n - mean * mean
    var = np.maximum(var, 0.0)
    std = np.sqrt(var)
    out: Dict[str, Dict[str, float]] = {}
    for i, name in enumerate(feature_names.tolist()):
        out[name] = {
            "min": float(stats_acc["min"][i]),
            "max": float(stats_acc["max"][i]),
            "mean": float(mean[i]),
            "std": float(std[i]),
        }
    return out


def shard_out_path(out_dir: Path, base: Path, shard_idx: int, use_shard: bool) -> Path:
    """计算分片输出路径。"""
    if not use_shard:
        return out_dir / base.name
    return out_dir / f"{base.stem}_part{shard_idx:03d}{base.suffix}"


def main() -> None:
    """主流程。"""
    args = parse_args()
    w_set = olib.parse_w_set(args.w_set)

    in_dir = Path(args.in_dir)
    out_npz = Path(args.out_npz)
    if args.out_dir is not None:
        out_dir = Path(args.out_dir)
    else:
        out_dir = out_npz.parent / f"{out_npz.stem}_shards"
    out_dir.mkdir(parents=True, exist_ok=True)

    if not in_dir.is_dir():
        raise FileNotFoundError(f"输入目录不存在: {in_dir}")
    if args.frame_idx < 1:
        raise ValueError("frame_idx 必须 >= 1（因为 reference 使用 frame_idx-1）")

    input_files = sorted(in_dir.glob("*.npz"))
    total_input = len(input_files)
    if args.max_files is not None:
        input_files = input_files[: max(0, args.max_files)]
    total_proc = len(input_files)
    print(f"[信息] 输入文件数: {total_input}")
    print(f"[信息] 实际处理文件数: {total_proc}")
    print(f"[信息] 输出目录: {out_dir}")

    feature_names = np.array(
        ["sad1", "sad2", "margin", "mv_mag", "sum", "grad_energy", "prev_w"],
        dtype="U",
    )

    tdnr_mod = olib.load_tdnr_module(Path(__file__).resolve().parent)
    me = tdnr_mod.MotionEstimator(h_disp=480, v_disp=320)

    use_shard = args.shard_size is not None and args.shard_size > 0
    shard_size = args.shard_size if use_shard else max(total_proc, 1)

    global_hist = {int(w): 0 for w in w_set.tolist()}
    total_samples = 0
    stats_acc = None

    shard_idx = 0
    shard_file_begin = 0
    x_list: List[np.ndarray] = []
    y_list: List[np.ndarray] = []
    info_list: List[np.ndarray] = []
    shard_files: List[str] = []
    shard_clip_counter = 0
    first_clip_debug = None

    for idx, src_path in enumerate(input_files, start=1):
        with np.load(src_path, allow_pickle=False) as data:
            if "frames_gt" not in data.files or "frames_noisy" not in data.files:
                raise ValueError(f"{src_path.name}: 缺少 frames_gt 或 frames_noisy")
            frames_gt = data["frames_gt"]
            frames_noisy = data["frames_noisy"]

            if frames_gt.dtype != np.uint8 or frames_noisy.dtype != np.uint8:
                raise ValueError(f"{src_path.name}: frames_gt/frames_noisy 必须为 uint8")
            if frames_gt.shape != frames_noisy.shape:
                raise ValueError(f"{src_path.name}: frames_gt 与 frames_noisy shape 不一致")
            if frames_gt.ndim != 4 or frames_gt.shape[-1] != 3:
                raise ValueError(f"{src_path.name}: 期望 (T,H,W,3)，实际 {frames_gt.shape}")
            if args.frame_idx >= frames_gt.shape[0]:
                raise ValueError(f"{src_path.name}: frame_idx 越界，T={frames_gt.shape[0]}")
            if frames_gt.shape[1:3] != (320, 480):
                raise ValueError(f"{src_path.name}: 分辨率应为 (320,480)，实际 {frames_gt.shape[1:3]}")

            cur_noisy = frames_noisy[args.frame_idx]
            ref_noisy = frames_noisy[args.frame_idx - 1]
            gt = frames_gt[args.frame_idx]
            luma_cur = olib.rgb_to_luma_u8(cur_noisy)
            luma_ref = olib.rgb_to_luma_u8(ref_noisy)
            proc_mb, _ = tdnr_mod.MBDownSampler.compute(luma_cur)
            ref_mb, ref_sub = tdnr_mod.MBDownSampler.compute(luma_ref)
            sad1, sad2, margin, mv_mag = olib.extract_me_features(proc_mb, ref_mb, ref_sub, me)
            grad_energy = olib.compute_grad_energy_map(luma_cur, mb_size=4)
            sum_map = proc_mb.astype(np.int32)
            prev_w = np.zeros_like(sum_map, dtype=np.int32)

            features_mb = np.stack(
                [
                    sad1.astype(np.float32),
                    sad2.astype(np.float32),
                    margin.astype(np.float32),
                    mv_mag.astype(np.float32),
                    sum_map.astype(np.float32),
                    grad_energy.astype(np.float32),
                    prev_w.astype(np.float32),
                ],
                axis=-1,
            )
            w_label_mb = olib.oracle_label_w(
                cur_noisy=cur_noisy,
                ref_noisy=ref_noisy,
                gt=gt,
                w_set=w_set,
                temporal_iir_filter_fn=tdnr_mod.temporal_iir_filter,
                mb_size=4,
            )

        mb_h, mb_w, feat_dim = features_mb.shape
        x_flat = features_mb.reshape(mb_h * mb_w, feat_dim).astype(np.float32)
        y_flat = w_label_mb.reshape(mb_h * mb_w).astype(np.uint8)

        x_list.append(x_flat)
        y_list.append(y_flat)

        if args.save_info:
            br_grid, bc_grid = np.indices((mb_h, mb_w))
            info = np.stack(
                [
                    np.full((mb_h, mb_w), shard_clip_counter, dtype=np.uint16),
                    br_grid.astype(np.uint8),
                    bc_grid.astype(np.uint8),
                    np.full((mb_h, mb_w), args.frame_idx, dtype=np.uint8),
                ],
                axis=-1,
            ).reshape(mb_h * mb_w, 4)
            info_list.append(info)

        if first_clip_debug is None:
            first_clip_debug = {"x": x_flat.copy(), "y": y_flat.copy()}

        shard_files.append(src_path.name)
        shard_clip_counter += 1
        total_samples += int(y_flat.shape[0])
        for w in w_set.tolist():
            global_hist[int(w)] += int((y_flat == w).sum())

        need_flush = (idx % shard_size == 0) or (idx == total_proc)
        if need_flush:
            X = np.concatenate(x_list, axis=0).astype(np.float32)
            y = np.concatenate(y_list, axis=0).astype(np.uint8)
            info = None
            if args.save_info:
                info = np.concatenate(info_list, axis=0)

            if first_clip_debug is not None:
                clip_len = first_clip_debug["x"].shape[0]
                ok_x = np.array_equal(X[:clip_len], first_clip_debug["x"])
                ok_y = np.array_equal(y[:clip_len], first_clip_debug["y"])
                print(f"[验证] 分片{shard_idx:03d} 首 clip 一致性: X={'OK' if ok_x else 'FAIL'}, y={'OK' if ok_y else 'FAIL'}")
                if not (ok_x and ok_y):
                    raise RuntimeError("sanity check 失败：分片首 clip 样本不一致")
                first_clip_debug = None

            stats_acc = merge_feature_stats(stats_acc, compute_feature_stats(X))

            out_path = shard_out_path(out_dir, out_npz, shard_idx, use_shard)
            meta = {
                "in_dir": str(in_dir),
                "frame_idx": int(args.frame_idx),
                "max_files": None if args.max_files is None else int(args.max_files),
                "seed": int(args.seed),
                "num_input_files": int(total_input),
                "num_processed_files_total": int(total_proc),
                "num_processed_files_in_shard": int(len(shard_files)),
                "num_samples_in_shard": int(X.shape[0]),
                "feature_dim": int(X.shape[1]),
                "feature_version": "v1_from_script03A",
                "w_set": [int(v) for v in w_set.tolist()],
                "info_schema": "[clip_id, br, bc, frame_idx] (clip_id/br/bc/frame_idx uint16/uint8/uint8/uint8)",
                "save_info": bool(args.save_info),
                "shard_index": int(shard_idx),
                "file_range": [int(shard_file_begin), int(idx - 1)],
            }

            payload = {
                "X": X.astype(np.float32),
                "y": y.astype(np.uint8),
                "feature_names": feature_names,
                "w_set": w_set.astype(np.uint8),
                "files": np.array(shard_files, dtype="U"),
                "meta": np.array(json.dumps(meta, ensure_ascii=False), dtype="U"),
            }
            if args.save_info:
                payload["info"] = info

            np.savez_compressed(out_path, **payload)
            print(f"[输出] 分片已保存: {out_path}")

            shard_idx += 1
            shard_file_begin = idx
            x_list.clear()
            y_list.clear()
            info_list.clear()
            shard_files.clear()
            shard_clip_counter = 0

        if (idx % 200 == 0) or (idx == total_proc):
            print(f"[进度] 已处理 {idx}/{total_proc}")

    print(f"[信息] 总样本数 N: {total_samples}")
    print("[统计] y 直方图：")
    for w in w_set.tolist():
        print(f"  - w={int(w):2d}: {global_hist[int(w)]}")

    if args.save_feature_stats and stats_acc is not None:
        stats = finalize_feature_stats(stats_acc, feature_names)
        stats_path = out_dir / f"{out_npz.stem}.feature_stats.json"
        with open(stats_path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "feature_names": feature_names.tolist(),
                    "stats": stats,
                    "num_samples": int(total_samples),
                    "num_shards": int(shard_idx if use_shard else 1),
                },
                f,
                ensure_ascii=False,
                indent=2,
            )
        print(f"[输出] 特征统计已保存: {stats_path}")


if __name__ == "__main__":
    main()
