#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script 02: 读取 clip npz，添加高斯噪声，输出 noisy+gt npz，并做抽检与预览导出。
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List

import numpy as np
from PIL import Image


def parse_args() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(
        description="将 Script01 产出的 clips npz 转成带噪训练数据。"
    )
    parser.add_argument("--in_dir", type=str, required=True, help="输入目录（包含 *.npz）")
    parser.add_argument("--out_dir", type=str, required=True, help="输出目录")
    parser.add_argument("--sigma_min", type=float, default=5.0, help="sigma 下限，默认 5")
    parser.add_argument("--sigma_max", type=float, default=50.0, help="sigma 上限，默认 50")
    parser.add_argument("--seed", type=int, default=123, help="全局随机种子，默认 123")
    parser.add_argument(
        "--verify_samples",
        type=int,
        default=3,
        help="处理完成后随机抽检输出文件数量，默认 3",
    )
    parser.add_argument(
        "--max_files",
        type=int,
        default=None,
        help="可选，仅处理前 N 个输入文件（按文件名排序）",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="若输出已有同名文件则覆盖（默认不覆盖）",
    )
    return parser.parse_args()


def list_input_files(in_dir: Path, max_files: int | None) -> List[Path]:
    """列出待处理 npz 文件，按文件名排序。"""
    files = sorted(in_dir.glob("*.npz"))
    if max_files is not None:
        files = files[: max(0, max_files)]
    return files


def validate_frames(frames: np.ndarray, src_name: str) -> None:
    """校验输入 frames 的 dtype 与 shape。"""
    if frames.dtype != np.uint8:
        raise ValueError(f"{src_name}: frames dtype 必须是 uint8，实际 {frames.dtype}")
    if frames.ndim != 4:
        raise ValueError(f"{src_name}: frames 维度必须是 4，实际 ndim={frames.ndim}")
    if frames.shape[1:] != (320, 480, 3):
        raise ValueError(
            f"{src_name}: frames shape 后三维必须是 (320,480,3)，实际 {frames.shape}"
        )


def add_gaussian_noise(
    frames: np.ndarray,
    sigma: float,
    clip_seed: int,
) -> np.ndarray:
    """为一个 clip 添加高斯噪声，输出 uint8。"""
    rng = np.random.default_rng(clip_seed)
    noise = rng.normal(loc=0.0, scale=sigma, size=frames.shape).astype(np.float32)
    noisy = np.rint(frames.astype(np.float32) + noise)
    noisy = np.clip(noisy, 0, 255).astype(np.uint8)
    return noisy


def save_output_npz(
    out_path: Path,
    src_file: Path,
    frames_gt: np.ndarray,
    frames_noisy: np.ndarray,
    sigma: float,
    clip_seed: int,
    src_npz: np.lib.npyio.NpzFile,
) -> None:
    """保存输出 npz，并带上可用的原始元信息字段。"""
    payload = {
        "frames_gt": frames_gt,
        "frames_noisy": frames_noisy,
        "sigma": np.float32(sigma),
        "seed": np.int32(clip_seed),
        "src_file": np.array(src_file.name),
    }

    # 可选元信息字段：若存在则原样透传
    for key in ("video", "t0", "orig_hw", "scale_hw", "crop_xy"):
        if key in src_npz.files:
            payload[key] = src_npz[key]

    np.savez_compressed(out_path, **payload)


def verify_outputs(
    out_files: List[Path],
    out_dir: Path,
    verify_samples: int,
    sigma_min: float,
    sigma_max: float,
    seed: int,
) -> None:
    """随机抽检输出，并导出首个样本的预览图。"""
    if not out_files:
        print("[验证] 没有输出文件，跳过抽检。")
        return

    sample_n = min(verify_samples, len(out_files))
    rng = np.random.default_rng(seed + 2026)
    idx = rng.choice(len(out_files), size=sample_n, replace=False)
    sample_files = [out_files[int(i)] for i in idx]

    print(f"[验证] 随机抽检 {sample_n} 个输出 npz：")
    for fp in sample_files:
        data = np.load(fp, allow_pickle=False)
        if "frames_gt" not in data.files or "frames_noisy" not in data.files:
            raise RuntimeError(f"[验证失败] {fp.name}: 缺少 frames_gt 或 frames_noisy")
        if "sigma" not in data.files:
            raise RuntimeError(f"[验证失败] {fp.name}: 缺少 sigma 字段")

        gt = data["frames_gt"]
        noisy = data["frames_noisy"]
        sigma = float(data["sigma"])

        if gt.dtype != np.uint8 or noisy.dtype != np.uint8:
            raise RuntimeError(f"[验证失败] {fp.name}: frames dtype 不是 uint8")
        if gt.shape != noisy.shape:
            raise RuntimeError(f"[验证失败] {fp.name}: gt/noisy shape 不一致")
        if sigma < sigma_min or sigma > sigma_max:
            raise RuntimeError(
                f"[验证失败] {fp.name}: sigma={sigma:.4f} 超出范围 [{sigma_min}, {sigma_max}]"
            )
        print(
            f"  - {fp.name}: shape={gt.shape}, dtype={gt.dtype}, sigma={sigma:.4f}"
        )

    # 导出第 1 个抽检文件的预览图
    preview_fp = sample_files[0]
    preview_data = np.load(preview_fp, allow_pickle=False)
    gt0 = preview_data["frames_gt"][0]
    noisy0 = preview_data["frames_noisy"][0]
    diff0 = np.abs(gt0.astype(np.int16) - noisy0.astype(np.int16)).astype(np.uint8)

    verify_dir = out_dir / "verify_preview"
    verify_dir.mkdir(parents=True, exist_ok=True)
    base = preview_fp.stem
    gt_path = verify_dir / f"{base}_gt_f000.png"
    noisy_path = verify_dir / f"{base}_noisy_f000.png"
    diff_path = verify_dir / f"{base}_diff_f000.png"

    Image.fromarray(gt0).save(gt_path)
    Image.fromarray(noisy0).save(noisy_path)
    # 差值图做放大显示（最多 x8）
    diff_vis = np.clip(diff0.astype(np.int16) * 8, 0, 255).astype(np.uint8)
    Image.fromarray(diff_vis).save(diff_path)

    print(f"[验证] 已导出预览 GT: {gt_path}")
    print(f"[验证] 已导出预览 Noisy: {noisy_path}")
    print(f"[验证] 已导出预览 Diff: {diff_path}")


def main() -> None:
    """主流程。"""
    args = parse_args()
    if args.sigma_min < 0 or args.sigma_max < 0:
        raise ValueError("sigma_min/sigma_max 必须 >= 0")
    if args.sigma_max < args.sigma_min:
        raise ValueError("sigma_max 必须 >= sigma_min")

    in_dir = Path(args.in_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not in_dir.is_dir():
        raise FileNotFoundError(f"输入目录不存在: {in_dir}")

    input_files = list_input_files(in_dir, args.max_files)
    print(f"[信息] 输入文件数: {len(sorted(in_dir.glob('*.npz')))}")
    print(f"[信息] 实际处理文件数: {len(input_files)}")

    rng = np.random.default_rng(args.seed)
    processed = 0
    written = 0
    sigma_values: List[float] = []
    out_files: List[Path] = []

    for idx, src_path in enumerate(input_files, start=1):
        out_path = out_dir / src_path.name
        if out_path.exists() and (not args.overwrite):
            continue

        with np.load(src_path, allow_pickle=False) as src_npz:
            if "frames" not in src_npz.files:
                raise ValueError(f"{src_path.name}: 输入缺少 frames 字段")
            frames = src_npz["frames"]
            validate_frames(frames, src_path.name)

            clip_seed = int(rng.integers(0, np.iinfo(np.int32).max))
            clip_rng = np.random.default_rng(clip_seed)
            sigma = float(clip_rng.uniform(args.sigma_min, args.sigma_max))
            frames_noisy = add_gaussian_noise(frames, sigma=sigma, clip_seed=clip_seed)

            save_output_npz(
                out_path=out_path,
                src_file=src_path,
                frames_gt=frames,
                frames_noisy=frames_noisy,
                sigma=sigma,
                clip_seed=clip_seed,
                src_npz=src_npz,
            )

        processed += 1
        written += 1
        sigma_values.append(sigma)
        out_files.append(out_path)

        if (idx % 200 == 0) or (idx == len(input_files)):
            print(f"[进度] 已扫描 {idx}/{len(input_files)}，已写出 {written}")

    print(f"[信息] 输出文件数: {written}")
    if sigma_values:
        s = np.array(sigma_values, dtype=np.float64)
        print(
            f"[信息] sigma 统计: min={s.min():.4f}, max={s.max():.4f}, mean={s.mean():.4f}"
        )
    else:
        print("[信息] sigma 统计: 无（可能都被 skip 了）")

    verify_outputs(
        out_files=out_files,
        out_dir=out_dir,
        verify_samples=args.verify_samples,
        sigma_min=args.sigma_min,
        sigma_max=args.sigma_max,
        seed=args.seed,
    )


if __name__ == "__main__":
    main()
