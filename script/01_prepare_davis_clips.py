#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script 01: 准备 DAVIS clips（读取帧序列 + 统一缩放裁剪 + 保存 npz）
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path
from typing import List, Tuple

import numpy as np
from PIL import Image


TARGET_H = 320
TARGET_W = 480


def parse_args() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(
        description="从 DAVIS2017 480p 读取帧并切 clips，保存为 npz。"
    )
    parser.add_argument(
        "--davis_root",
        type=str,
        required=True,
        help="DAVIS 根目录（其下包含 JPEGImages/480p）。",
    )
    parser.add_argument(
        "--out_dir",
        type=str,
        required=True,
        help="输出目录。",
    )
    parser.add_argument(
        "--clip_len",
        type=int,
        default=16,
        help="每段 clip 的长度，默认 16。",
    )
    parser.add_argument(
        "--num_clips_per_video",
        type=int,
        default=50,
        help="每个视频采样 clip 数量，默认 50。",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=123,
        help="随机种子，默认 123。",
    )
    parser.add_argument(
        "--verify_samples",
        type=int,
        default=3,
        help="生成完成后随机抽检的 npz 数量，默认 3。",
    )
    return parser.parse_args()


def list_videos(jpeg_root: Path) -> List[Path]:
    """列出包含 jpg 帧的所有视频目录。"""
    videos = []
    for video_dir in sorted(jpeg_root.iterdir()):
        if not video_dir.is_dir():
            continue
        if any(video_dir.glob("*.jpg")):
            videos.append(video_dir)
    return videos


def compute_resize_and_crop(h0: int, w0: int) -> Tuple[int, int, int, int]:
    """
    计算等比例缩放后的尺寸和中心裁剪坐标。
    规则：先缩放到 H1>=320 且 W1>=480，再中心裁剪到 320x480。
    """
    scale = max(TARGET_H / h0, TARGET_W / w0)
    h1 = int(math.ceil(h0 * scale))
    w1 = int(math.ceil(w0 * scale))
    x = (w1 - TARGET_W) // 2
    y = (h1 - TARGET_H) // 2
    return h1, w1, x, y


def load_resize_crop_rgb(
    image_path: Path,
    scale_hw: Tuple[int, int],
    crop_xy: Tuple[int, int],
) -> np.ndarray:
    """读取单帧，按给定缩放+裁剪参数处理为 RGB uint8。"""
    h1, w1 = scale_hw
    x, y = crop_xy
    with Image.open(image_path) as img:
        img = img.convert("RGB")
        img = img.resize((w1, h1), Image.BILINEAR)
        img = img.crop((x, y, x + TARGET_W, y + TARGET_H))
        arr = np.asarray(img, dtype=np.uint8)
    return arr


def sample_t0_indices(
    rng: np.random.Generator,
    num_frames: int,
    clip_len: int,
    num_clips_per_video: int,
) -> List[int]:
    """随机采样每个 clip 的起点 t0，保证不越界。"""
    max_start = num_frames - clip_len
    if max_start < 0:
        return []
    candidates = np.arange(max_start + 1, dtype=np.int32)
    if num_clips_per_video <= len(candidates):
        t0_list = rng.choice(candidates, size=num_clips_per_video, replace=False)
    else:
        t0_list = rng.choice(candidates, size=num_clips_per_video, replace=True)
    t0_list = sorted(int(t) for t in t0_list)
    return t0_list


def prepare_video_clips(
    video_dir: Path,
    out_dir: Path,
    clip_len: int,
    num_clips_per_video: int,
    rng: np.random.Generator,
) -> int:
    """处理单个视频并保存其 clips，返回成功数量。"""
    frame_paths = sorted(video_dir.glob("*.jpg"))
    num_frames = len(frame_paths)
    t0_list = sample_t0_indices(rng, num_frames, clip_len, num_clips_per_video)
    if not t0_list:
        return 0

    # 用首帧确定原图尺寸和缩放/裁剪参数，并对该视频内所有 clip 保持一致
    with Image.open(frame_paths[0]) as img0:
        w0, h0 = img0.size
    h1, w1, x, y = compute_resize_and_crop(h0, w0)

    video_name = video_dir.name
    success = 0
    for t0 in t0_list:
        clip_frame_paths = frame_paths[t0 : t0 + clip_len]
        if len(clip_frame_paths) < clip_len:
            continue

        frames = np.empty((clip_len, TARGET_H, TARGET_W, 3), dtype=np.uint8)
        for i, frame_path in enumerate(clip_frame_paths):
            frames[i] = load_resize_crop_rgb(
                frame_path,
                scale_hw=(h1, w1),
                crop_xy=(x, y),
            )

        out_name = f"{video_name}_t{t0:05d}.npz"
        out_path = out_dir / out_name
        np.savez_compressed(
            out_path,
            frames=frames,
            video=np.array(video_name),
            t0=np.int32(t0),
            orig_hw=np.array([h0, w0], dtype=np.int32),
            scale_hw=np.array([h1, w1], dtype=np.int32),
            crop_xy=np.array([x, y], dtype=np.int32),
        )
        success += 1
    return success


def verify_outputs(out_dir: Path, clip_len: int, verify_samples: int, seed: int) -> None:
    """按验收要求随机抽检 npz，并导出一个 clip 的首尾帧 png。"""
    npz_files = sorted(out_dir.glob("*.npz"))
    if not npz_files:
        print("[验证] 未找到 npz 文件，跳过抽检。")
        return

    sample_n = min(verify_samples, len(npz_files))
    rng = np.random.default_rng(seed + 999)
    sample_idx = rng.choice(len(npz_files), size=sample_n, replace=False)
    print(f"[验证] 随机抽检 {sample_n} 个 npz：")
    sampled_files = [npz_files[int(i)] for i in sample_idx]
    for p in sampled_files:
        data = np.load(p, allow_pickle=False)
        frames = data["frames"]
        print(f"  - {p.name}: shape={frames.shape}, dtype={frames.dtype}")
        expected_shape = (clip_len, TARGET_H, TARGET_W, 3)
        if frames.shape != expected_shape or frames.dtype != np.uint8:
            raise RuntimeError(
                f"[验证失败] {p.name} 形状或 dtype 不符，"
                f"期望 {expected_shape}/uint8，实际 {frames.shape}/{frames.dtype}"
            )

    preview_file = sampled_files[0]
    preview = np.load(preview_file, allow_pickle=False)["frames"]
    verify_dir = out_dir / "verify_preview"
    verify_dir.mkdir(parents=True, exist_ok=True)

    frame0_path = verify_dir / f"{preview_file.stem}_f000.png"
    frame_last_path = verify_dir / f"{preview_file.stem}_f{clip_len - 1:03d}.png"
    Image.fromarray(preview[0]).save(frame0_path)
    Image.fromarray(preview[clip_len - 1]).save(frame_last_path)

    print(f"[验证] 已导出首帧: {frame0_path}")
    print(f"[验证] 已导出尾帧: {frame_last_path}")


def main() -> None:
    """主流程。"""
    args = parse_args()
    rng = np.random.default_rng(args.seed)

    davis_root = Path(args.davis_root)
    jpeg_root = davis_root / "JPEGImages" / "480p"
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not jpeg_root.is_dir():
        raise FileNotFoundError(f"未找到目录: {jpeg_root}")

    video_dirs = list_videos(jpeg_root)
    print(f"[信息] 视频总数: {len(video_dirs)}")

    total_clips = 0
    per_video_counts = []
    for video_dir in video_dirs:
        num_ok = prepare_video_clips(
            video_dir=video_dir,
            out_dir=out_dir,
            clip_len=args.clip_len,
            num_clips_per_video=args.num_clips_per_video,
            rng=rng,
        )
        per_video_counts.append((video_dir.name, num_ok))
        total_clips += num_ok

    print(f"[信息] 生成 clip 总数: {total_clips}")
    print("[信息] 每个视频成功生成的 clip 数:")
    for video_name, count in per_video_counts:
        print(f"  - {video_name}: {count}")

    verify_outputs(
        out_dir=out_dir,
        clip_len=args.clip_len,
        verify_samples=args.verify_samples,
        seed=args.seed,
    )


if __name__ == "__main__":
    main()
