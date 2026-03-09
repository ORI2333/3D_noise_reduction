#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script 03A: 对单个 noisy+gt clip 生成特征与 Oracle 标签，并导出可视化。
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List, Tuple

import numpy as np
from PIL import Image

import oracle_lib as olib


def parse_args() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(
        description="对单个 noisy+gt clip 生成宏块特征 + oracle w 标签。"
    )
    parser.add_argument("--input_npz", type=str, required=True, help="Script02 输出 npz")
    parser.add_argument("--out_dir", type=str, required=True, help="输出目录")
    parser.add_argument(
        "--w_set",
        type=str,
        default="0,4,8,12,16,20,24,28,31",
        help='候选权重集合，例如 "0,4,8,12,16,20,24,28,31"',
    )
    parser.add_argument(
        "--frame_idx",
        type=int,
        default=1,
        help="打标签帧索引，默认 1（reference 使用 frame_idx-1）",
    )
    parser.add_argument("--h_disp", type=int, default=480, help="宽度，默认 480")
    parser.add_argument("--v_disp", type=int, default=320, help="高度，默认 320")
    parser.add_argument("--mb_size", type=int, default=4, help="宏块大小，默认 4")
    parser.add_argument(
        "--save_png",
        type=str,
        default="true",
        help="是否导出可视化 png，true/false，默认 true",
    )
    return parser.parse_args()


def parse_bool(x: str) -> bool:
    """解析 true/false 字符串。"""
    return x.strip().lower() in {"1", "true", "yes", "y", "on"}


def parse_w_set(w_set_str: str) -> np.ndarray:
    """解析并规范化 w_set（去重、升序、限制到 [0,31]）。"""
    return olib.parse_w_set(w_set_str)


def load_tdnr_module() -> object:
    """从 image_py/3dnr.py 动态加载 ThreeDNR 相关实现。"""
    return olib.load_tdnr_module(Path(__file__).resolve().parent)


def compute_grad_energy_map(luma: np.ndarray, mb_size: int) -> np.ndarray:
    """计算每个 4x4 宏块的梯度能量：相邻像素差绝对值和。"""
    return olib.compute_grad_energy_map(luma, mb_size)


def extract_me_features(
    proc_mb: np.ndarray,
    ref_mb: np.ndarray,
    ref_sub: np.ndarray,
    me: object,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    复用 MotionEstimator 的搜索规则，提取 sad1/sad2/margin/mv_mag。

    mv_mag 定义：在下采样(DS)坐标系中，best_pos_ds 相对中心 (br*2, bc*2) 的 |dx|+|dy|。
    注意：4pt 只更新 SAD 数值，不覆盖 DS 最佳位置，避免 mv_mag 语义混乱。
    """
    return olib.extract_me_features(proc_mb, ref_mb, ref_sub, me)


def frame_to_mb_mae(diff_frame: np.ndarray, mb_size: int) -> np.ndarray:
    """将整帧误差图聚合为每个宏块的平均误差。"""
    h, w, _ = diff_frame.shape
    mb_h = h // mb_size
    mb_w = w // mb_size
    # (MB_H, MB_SIZE, MB_W, MB_SIZE, C) -> (MB_H, MB_W, MB_SIZE, MB_SIZE, C)
    x = diff_frame.reshape(mb_h, mb_size, mb_w, mb_size, 3).transpose(0, 2, 1, 3, 4)
    return x.mean(axis=(2, 3, 4), dtype=np.float32)


def oracle_label_w(
    cur_noisy: np.ndarray,
    ref_noisy: np.ndarray,
    gt: np.ndarray,
    w_set: np.ndarray,
    temporal_iir_filter_fn,
    mb_size: int,
) -> np.ndarray:
    """监督枚举候选 w，逐宏块选择误差最小的 w（并列取更小 w）。"""
    return olib.oracle_label_w(cur_noisy, ref_noisy, gt, w_set, temporal_iir_filter_fn, mb_size)


def normalize_to_u8(x: np.ndarray) -> np.ndarray:
    """线性归一化到 0..255，便于可视化。"""
    xf = x.astype(np.float32)
    x_min = float(xf.min())
    x_max = float(xf.max())
    if x_max <= x_min:
        return np.zeros_like(x, dtype=np.uint8)
    y = (xf - x_min) / (x_max - x_min)
    return np.clip(np.rint(y * 255.0), 0, 255).astype(np.uint8)


def save_maps_png(
    out_dir: Path,
    stem_prefix: str,
    w_label: np.ndarray,
    sad1: np.ndarray,
    margin: np.ndarray,
    mb_size: int,
) -> None:
    """导出 w_label/sad1/margin 可视化图。"""
    up = np.ones((mb_size, mb_size), dtype=np.uint8)

    # w 标签按 0..31 映射到 0..255
    w_img = np.kron((w_label.astype(np.float32) * (255.0 / 31.0)).astype(np.uint8), up)
    sad1_img = np.kron(normalize_to_u8(sad1), up)
    margin_img = np.kron(normalize_to_u8(margin), up)

    w_path = out_dir / f"{stem_prefix}_w_label_map.png"
    sad1_path = out_dir / f"{stem_prefix}_sad1_map.png"
    margin_path = out_dir / f"{stem_prefix}_margin_map.png"

    Image.fromarray(w_img, mode="L").save(w_path)
    Image.fromarray(sad1_img, mode="L").save(sad1_path)
    Image.fromarray(margin_img, mode="L").save(margin_path)

    print(f"[可视化] 已保存: {w_path}")
    print(f"[可视化] 已保存: {sad1_path}")
    print(f"[可视化] 已保存: {margin_path}")


def main() -> None:
    """主流程。"""
    args = parse_args()
    save_png = parse_bool(args.save_png)
    w_set = parse_w_set(args.w_set)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.frame_idx < 1:
        raise ValueError("frame_idx 必须 >= 1（因为 reference 使用 frame_idx-1）")
    if args.mb_size != 4:
        raise ValueError("当前脚本按需求固定 mb_size=4")

    input_npz = Path(args.input_npz)
    if not input_npz.is_file():
        raise FileNotFoundError(f"输入文件不存在: {input_npz}")

    with np.load(input_npz, allow_pickle=False) as data:
        if "frames_gt" not in data.files or "frames_noisy" not in data.files:
            raise ValueError("输入 npz 必须包含 frames_gt 和 frames_noisy")
        frames_gt = data["frames_gt"]
        frames_noisy = data["frames_noisy"]

    if frames_gt.dtype != np.uint8 or frames_noisy.dtype != np.uint8:
        raise ValueError("frames_gt/frames_noisy 必须为 uint8")
    if frames_gt.shape != frames_noisy.shape:
        raise ValueError("frames_gt 与 frames_noisy shape 必须一致")
    if frames_gt.ndim != 4 or frames_gt.shape[-1] != 3:
        raise ValueError(f"期望形状 (T,H,W,3)，实际 {frames_gt.shape}")
    if args.frame_idx >= frames_gt.shape[0]:
        raise ValueError(f"frame_idx 越界: {args.frame_idx}, T={frames_gt.shape[0]}")
    if frames_gt.shape[1:3] != (args.v_disp, args.h_disp):
        raise ValueError(
            f"输入分辨率与参数不一致，输入={frames_gt.shape[1:3]}，参数={(args.v_disp, args.h_disp)}"
        )

    cur_noisy = frames_noisy[args.frame_idx]
    ref_noisy = frames_noisy[args.frame_idx - 1]
    gt = frames_gt[args.frame_idx]

    tdnr = load_tdnr_module()
    nr = tdnr.ThreeDNR(h_disp=args.h_disp, v_disp=args.v_disp)

    luma_cur = olib.rgb_to_luma_u8(cur_noisy)
    luma_ref = olib.rgb_to_luma_u8(ref_noisy)
    proc_mb, _ = tdnr.MBDownSampler.compute(luma_cur)
    ref_mb, ref_sub = tdnr.MBDownSampler.compute(luma_ref)

    sad1, sad2, margin, mv_mag = extract_me_features(
        proc_mb=proc_mb,
        ref_mb=ref_mb,
        ref_sub=ref_sub,
        me=nr.me_td,
    )
    grad_energy = compute_grad_energy_map(luma_cur, mb_size=args.mb_size)
    sum_map = proc_mb.astype(np.int32)
    prev_w = np.zeros_like(sum_map, dtype=np.int32)

    feature_names = np.array(
        ["sad1", "sad2", "margin", "mv_mag", "sum", "grad_energy", "prev_w"],
        dtype="U",
    )
    features = np.stack(
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

    w_label = oracle_label_w(
        cur_noisy=cur_noisy,
        ref_noisy=ref_noisy,
        gt=gt,
        w_set=w_set,
        temporal_iir_filter_fn=tdnr.temporal_iir_filter,
        mb_size=args.mb_size,
    )

    stem_prefix = f"{input_npz.stem}_f{args.frame_idx:03d}"
    out_npz = out_dir / f"{stem_prefix}_oracle.npz"
    meta = {
        "input_file": input_npz.name,
        "frame_idx": int(args.frame_idx),
        "h_disp": int(args.h_disp),
        "v_disp": int(args.v_disp),
        "mb_size": int(args.mb_size),
        "mv_mag_unit": "downsampled_grid_manhattan",
        "w_set": [int(x) for x in w_set.tolist()],
        "oracle_loss": "mean_abs_error_rgb_over_4x4_block",
        "ref_rule": "ref = frame_idx - 1",
    }

    np.savez_compressed(
        out_npz,
        features=features.astype(np.float32),
        feature_names=feature_names,
        w_label=w_label.astype(np.uint8),
        w_set=w_set.astype(np.uint8),
        sad1=sad1.astype(np.int32),
        sad2=sad2.astype(np.int32),
        margin=margin.astype(np.int32),
        mv_mag=mv_mag.astype(np.int32),
        meta=np.array(json.dumps(meta, ensure_ascii=False), dtype="U"),
    )

    print(f"[输出] Oracle 文件: {out_npz}")
    print("[统计] w_label 直方图：")
    hist = {int(w): int((w_label == w).sum()) for w in w_set.tolist()}
    for w in w_set.tolist():
        print(f"  - w={int(w):2d}: {hist[int(w)]}")

    sad1f = sad1.astype(np.float32)
    marginf = margin.astype(np.float32)
    print(
        "[统计] sad1: "
        f"min={sad1f.min():.2f}, max={sad1f.max():.2f}, mean={sad1f.mean():.2f}"
    )
    print(
        "[统计] margin: "
        f"min={marginf.min():.2f}, max={marginf.max():.2f}, mean={marginf.mean():.2f}"
    )

    if save_png:
        save_maps_png(
            out_dir=out_dir,
            stem_prefix=stem_prefix,
            w_label=w_label,
            sad1=sad1,
            margin=margin,
            mb_size=args.mb_size,
        )


if __name__ == "__main__":
    main()
