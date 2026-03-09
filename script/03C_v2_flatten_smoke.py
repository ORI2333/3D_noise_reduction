#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script V2-S2: V2 per-clip Oracle -> V2 shards（带 info）Smoke

字段契约（与现有训练脚本对齐）：
- X: float32 (N,F)
- y: uint8 (N,)
- feature_names: unicode (F,)
- w_set: uint8 (9,)
- files: unicode (num_clips,)
- meta: unicode json string
- info: int32 (N,4), schema [clip_id, br, bc, frame_idx]
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import List, Optional

import numpy as np

import oracle_lib as olib


def parse_args() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(description="V2 per-clip Oracle 扁平化为 shards（smoke）。")
    parser.add_argument("--oracle_dir", type=str, required=True, help="V2 per-clip oracle 目录")
    parser.add_argument("--out_dir", type=str, required=True, help="输出 shard 目录")
    parser.add_argument("--shard_size", type=int, default=2_000_000, help="单 shard 最大样本数")
    parser.add_argument("--mb_h", type=int, default=80, help="宏块高，默认 80")
    parser.add_argument("--mb_w", type=int, default=120, help="宏块宽，默认 120")
    parser.add_argument(
        "--frame_idx_mode",
        type=str,
        default="zero",
        choices=["zero", "from_name"],
        help="frame_idx 写入策略：zero 或 from_name",
    )
    parser.add_argument("--seed", type=int, default=123, help="随机种子（用于元信息记录）")
    parser.add_argument(
        "--pattern",
        type=str,
        default="*_oracle_v2.npz",
        help="输入文件 glob，默认 *_oracle_v2.npz",
    )
    parser.add_argument(
        "--w_set",
        type=str,
        default="0,4,8,12,16,20,24,28,31",
        help='兜底 w_set，默认 "0,4,8,12,16,20,24,28,31"',
    )
    return parser.parse_args()


def parse_frame_idx_from_name(name: str) -> int:
    """从文件名提取 frame_idx（形如 *_f001_*），提取失败返回 0。"""
    m = re.search(r"_f(\d+)", name)
    if not m:
        return 0
    return int(m.group(1))


def flush_shard(
    out_dir: Path,
    shard_idx: int,
    X_list: List[np.ndarray],
    y_list: List[np.ndarray],
    info_list: List[np.ndarray],
    files_list: List[str],
    feature_names: np.ndarray,
    w_set: np.ndarray,
    oracle_dir: Path,
    frame_idx_mode: str,
    sample_seed: int,
) -> Path:
    """落盘一个 shard。"""
    X = np.concatenate(X_list, axis=0).astype(np.float32)
    y = np.concatenate(y_list, axis=0).astype(np.uint8)
    info = np.concatenate(info_list, axis=0).astype(np.int32)

    meta = {
        "source": "v2_oracle_smoke_flatten",
        "oracle_dir": str(oracle_dir),
        "frame_idx_mode": frame_idx_mode,
        "sample_seed": int(sample_seed),
        "num_samples": int(X.shape[0]),
        "feature_dim": int(X.shape[1]),
        "num_clips": int(len(files_list)),
        "shard_index": int(shard_idx),
        "info_schema": "[clip_id, br, bc, frame_idx]",
        "feature_version": "v2_ds_mb_split",
        "w_set": [int(v) for v in w_set.tolist()],
    }

    out_path = out_dir / f"train_oracle_dataset_v2_smoke_info_part{shard_idx:03d}.npz"
    np.savez_compressed(
        out_path,
        X=X,
        y=y,
        feature_names=feature_names,
        w_set=w_set.astype(np.uint8),
        files=np.array(files_list, dtype="U"),
        meta=np.array(json.dumps(meta, ensure_ascii=False), dtype="U"),
        info=info,
    )
    return out_path


def main() -> None:
    """主流程。"""
    args = parse_args()
    fallback_w_set = olib.parse_w_set(args.w_set)

    oracle_dir = Path(args.oracle_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not oracle_dir.is_dir():
        raise FileNotFoundError(f"输入目录不存在: {oracle_dir}")
    if args.shard_size <= 0:
        raise ValueError("shard_size 必须 > 0")

    files = sorted(oracle_dir.glob(args.pattern))
    if not files:
        raise FileNotFoundError(f"未找到输入文件: {oracle_dir} / {args.pattern}")
    print(f"[信息] 输入 oracle 文件数: {len(files)}")

    ref_feature_names: Optional[np.ndarray] = None
    ref_w_set: Optional[np.ndarray] = None
    global_samples = 0

    shard_idx = 0
    cur_samples = 0
    clip_id_global = 0

    X_list: List[np.ndarray] = []
    y_list: List[np.ndarray] = []
    info_list: List[np.ndarray] = []
    files_list: List[str] = []
    out_paths: List[Path] = []

    for i, fp in enumerate(files, start=1):
        with np.load(fp, allow_pickle=False) as d:
            if "features" not in d.files or "w_label" not in d.files or "feature_names" not in d.files:
                raise ValueError(f"{fp.name}: 缺少 features/w_label/feature_names")
            feat = d["features"]
            w_label = d["w_label"]
            feature_names = d["feature_names"]
            w_set = d["w_set"] if "w_set" in d.files else fallback_w_set

        if feat.dtype != np.float32 or feat.ndim != 3:
            raise ValueError(f"{fp.name}: features 需为 float32 3D，实际 {feat.dtype}/{feat.shape}")
        if w_label.dtype != np.uint8 or w_label.ndim != 2:
            raise ValueError(f"{fp.name}: w_label 需为 uint8 2D，实际 {w_label.dtype}/{w_label.shape}")
        if feature_names.dtype.kind != "U" or feature_names.ndim != 1:
            raise ValueError(f"{fp.name}: feature_names 需为 unicode 1D")
        if tuple(feat.shape[:2]) != (args.mb_h, args.mb_w):
            raise ValueError(f"{fp.name}: features 前两维应为 ({args.mb_h},{args.mb_w})，实际 {feat.shape[:2]}")
        if tuple(w_label.shape) != (args.mb_h, args.mb_w):
            raise ValueError(f"{fp.name}: w_label 应为 ({args.mb_h},{args.mb_w})，实际 {w_label.shape}")
        if feat.shape[2] != feature_names.shape[0]:
            raise ValueError(f"{fp.name}: F 与 feature_names 长度不一致")
        if np.setdiff1d(np.unique(w_label), w_set).size != 0:
            raise ValueError(f"{fp.name}: w_label 存在不在 w_set 的值")

        if ref_feature_names is None:
            ref_feature_names = feature_names.copy()
        elif not np.array_equal(ref_feature_names, feature_names):
            raise ValueError(f"{fp.name}: feature_names 与前序文件不一致")

        if ref_w_set is None:
            ref_w_set = np.array(w_set, dtype=np.uint8).copy()
        elif not np.array_equal(ref_w_set, np.array(w_set, dtype=np.uint8)):
            raise ValueError(f"{fp.name}: w_set 与前序文件不一致")

        x_flat = feat.reshape(args.mb_h * args.mb_w, feat.shape[2]).astype(np.float32)
        y_flat = w_label.reshape(args.mb_h * args.mb_w).astype(np.uint8)

        br, bc = np.indices((args.mb_h, args.mb_w))
        frame_idx_val = 0 if args.frame_idx_mode == "zero" else parse_frame_idx_from_name(fp.name)
        info = np.stack(
            [
                np.full((args.mb_h, args.mb_w), clip_id_global, dtype=np.int32),
                br.astype(np.int32),
                bc.astype(np.int32),
                np.full((args.mb_h, args.mb_w), frame_idx_val, dtype=np.int32),
            ],
            axis=-1,
        ).reshape(args.mb_h * args.mb_w, 4)

        X_list.append(x_flat)
        y_list.append(y_flat)
        info_list.append(info)
        files_list.append(fp.name)
        cur_samples += x_flat.shape[0]
        global_samples += x_flat.shape[0]
        clip_id_global += 1

        if cur_samples >= args.shard_size:
            assert ref_feature_names is not None
            assert ref_w_set is not None
            out_path = flush_shard(
                out_dir=out_dir,
                shard_idx=shard_idx,
                X_list=X_list,
                y_list=y_list,
                info_list=info_list,
                files_list=files_list,
                feature_names=ref_feature_names,
                w_set=ref_w_set,
                oracle_dir=oracle_dir,
                frame_idx_mode=args.frame_idx_mode,
                sample_seed=args.seed,
            )
            out_paths.append(out_path)
            print(f"[输出] {out_path.name}: N={cur_samples}, clips={len(files_list)}")

            shard_idx += 1
            cur_samples = 0
            X_list.clear()
            y_list.clear()
            info_list.clear()
            files_list.clear()

        if (i % 50 == 0) or (i == len(files)):
            print(f"[进度] {i}/{len(files)}")

    if X_list:
        assert ref_feature_names is not None
        assert ref_w_set is not None
        out_path = flush_shard(
            out_dir=out_dir,
            shard_idx=shard_idx,
            X_list=X_list,
            y_list=y_list,
            info_list=info_list,
            files_list=files_list,
            feature_names=ref_feature_names,
            w_set=ref_w_set,
            oracle_dir=oracle_dir,
            frame_idx_mode=args.frame_idx_mode,
            sample_seed=args.seed,
        )
        out_paths.append(out_path)
        print(f"[输出] {out_path.name}: N={cur_samples}, clips={len(files_list)}")

    print(f"[信息] shard 总数: {len(out_paths)}")
    print(f"[信息] 总样本数: {global_samples}")

    if out_paths:
        with np.load(out_paths[0], allow_pickle=False) as d:
            print(f"[抽检] 首 shard: {out_paths[0].name}")
            print(f"[抽检] X: {d['X'].shape}/{d['X'].dtype}")
            print(f"[抽检] y: {d['y'].shape}/{d['y'].dtype}")
            print(f"[抽检] info: {d['info'].shape}/{d['info'].dtype}")
            print(f"[抽检] feature_names: {d['feature_names'].tolist()}")


if __name__ == "__main__":
    main()

