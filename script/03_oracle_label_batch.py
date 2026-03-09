#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script 03B: 批量生成 Oracle 标签（改进特征版）。

特征使用：
  sad1_ds, sad2_ds, margin_ds, sad1_mb_best, mv_mag, sum, grad_energy, prev_w
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
    parser = argparse.ArgumentParser(description="批量生成 Oracle 特征与标签。")
    parser.add_argument("--in_dir", type=str, required=True, help="Script02 输出目录（*.npz）")
    parser.add_argument("--out_dir", type=str, required=True, help="输出目录")
    parser.add_argument(
        "--w_set",
        type=str,
        default="0,4,8,12,16,20,24,28,31",
        help='候选权重集合，例如 "0,4,8,12,16,20,24,28,31"',
    )
    parser.add_argument("--frame_idx", type=int, default=1, help="打标签帧索引，默认 1")
    parser.add_argument("--h_disp", type=int, default=480, help="宽度，默认 480")
    parser.add_argument("--v_disp", type=int, default=320, help="高度，默认 320")
    parser.add_argument("--mb_size", type=int, default=4, help="宏块大小，默认 4")
    parser.add_argument("--seed", type=int, default=123, help="随机种子（用于抽检），默认 123")
    parser.add_argument("--verify_samples", type=int, default=3, help="抽检样本数，默认 3")
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
    parser.add_argument(
        "--save_png",
        type=str,
        default="false",
        help="是否导出抽检可视化图（true/false），默认 false",
    )
    return parser.parse_args()


def parse_bool(x: str) -> bool:
    """解析 true/false 字符串。"""
    return x.strip().lower() in {"1", "true", "yes", "y", "on"}


def parse_w_set(w_set_str: str) -> np.ndarray:
    """解析并规范化 w_set（去重、升序、限制到 [0,31]）。"""
    return olib.parse_w_set(w_set_str)


def load_tdnr_module() -> object:
    """动态加载 image_py/3dnr.py。"""
    return olib.load_tdnr_module(Path(__file__).resolve().parent)


def compute_grad_energy_map(luma: np.ndarray, mb_size: int) -> np.ndarray:
    """计算每个 4x4 宏块的梯度能量。"""
    return olib.compute_grad_energy_map(luma, mb_size)


def extract_me_features_v2(
    proc_mb: np.ndarray,
    ref_mb: np.ndarray,
    ref_sub: np.ndarray,
    me: object,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    提取改进特征：
      sad1_ds, sad2_ds, margin_ds: 仅来自 DS 9pt+5pt
      sad1_mb_best: 4pt 最小 SAD（MB 坐标）
      mv_mag: DS 最佳点的 |dx|+|dy|
    """
    return olib.extract_me_features_v2(proc_mb, ref_mb, ref_sub, me)


def frame_to_mb_mae(diff_frame: np.ndarray, mb_size: int) -> np.ndarray:
    """整帧误差聚合到宏块平均误差。"""
    h, w, _ = diff_frame.shape
    mb_h = h // mb_size
    mb_w = w // mb_size
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
    """监督枚举 w，逐宏块选最小 L1 误差对应的标签。"""
    return olib.oracle_label_w(cur_noisy, ref_noisy, gt, w_set, temporal_iir_filter_fn, mb_size)


def normalize_to_u8(x: np.ndarray) -> np.ndarray:
    """线性归一化到 0..255。"""
    xf = x.astype(np.float32)
    lo, hi = float(xf.min()), float(xf.max())
    if hi <= lo:
        return np.zeros_like(x, dtype=np.uint8)
    y = (xf - lo) / (hi - lo)
    return np.clip(np.rint(y * 255.0), 0, 255).astype(np.uint8)


def save_preview_maps(
    out_dir: Path,
    stem_prefix: str,
    w_label: np.ndarray,
    sad1_ds: np.ndarray,
    margin_ds: np.ndarray,
    mb_size: int,
) -> None:
    """导出抽检预览图。"""
    vis_dir = out_dir / "verify_preview"
    vis_dir.mkdir(parents=True, exist_ok=True)
    up = np.ones((mb_size, mb_size), dtype=np.uint8)

    w_img = np.kron(np.rint(w_label.astype(np.float32) * (255.0 / 31.0)).astype(np.uint8), up)
    sad_img = np.kron(normalize_to_u8(sad1_ds), up)
    margin_img = np.kron(normalize_to_u8(margin_ds), up)

    p1 = vis_dir / f"{stem_prefix}_w_label_map.png"
    p2 = vis_dir / f"{stem_prefix}_sad1_ds_map.png"
    p3 = vis_dir / f"{stem_prefix}_margin_ds_map.png"
    Image.fromarray(w_img, mode="L").save(p1)
    Image.fromarray(sad_img, mode="L").save(p2)
    Image.fromarray(margin_img, mode="L").save(p3)
    print(f"[验证] 预览已保存: {p1}")
    print(f"[验证] 预览已保存: {p2}")
    print(f"[验证] 预览已保存: {p3}")


def main() -> None:
    """主流程。"""
    args = parse_args()
    save_png = parse_bool(args.save_png)
    w_set = parse_w_set(args.w_set)

    if args.frame_idx < 1:
        raise ValueError("frame_idx 必须 >= 1（因为 reference 使用 frame_idx-1）")
    if args.mb_size != 4:
        raise ValueError("当前脚本按需求固定 mb_size=4")

    in_dir = Path(args.in_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    if not in_dir.is_dir():
        raise FileNotFoundError(f"输入目录不存在: {in_dir}")

    input_files = sorted(in_dir.glob("*.npz"))
    total_input = len(input_files)
    if args.max_files is not None:
        input_files = input_files[: max(0, args.max_files)]
    total_proc = len(input_files)

    print(f"[信息] 输入文件数: {total_input}")
    print(f"[信息] 实际处理文件数: {total_proc}")

    tdnr = load_tdnr_module()
    nr = tdnr.ThreeDNR(h_disp=args.h_disp, v_disp=args.v_disp)

    written = 0
    out_files: List[Path] = []
    w_hist_total = {int(w): 0 for w in w_set.tolist()}
    sad1_ds_means: List[float] = []
    margin_ds_means: List[float] = []

    for idx, src_path in enumerate(input_files, start=1):
        stem_prefix = f"{src_path.stem}_f{args.frame_idx:03d}"
        out_path = out_dir / f"{stem_prefix}_oracle.npz"
        if out_path.exists() and (not args.overwrite):
            continue

        with np.load(src_path, allow_pickle=False) as data:
            if "frames_gt" not in data.files or "frames_noisy" not in data.files:
                raise ValueError(f"{src_path.name}: 缺少 frames_gt 或 frames_noisy")
            frames_gt = data["frames_gt"]
            frames_noisy = data["frames_noisy"]

            if frames_gt.dtype != np.uint8 or frames_noisy.dtype != np.uint8:
                raise ValueError(f"{src_path.name}: frames_gt/frames_noisy 必须为 uint8")
            if frames_gt.shape != frames_noisy.shape:
                raise ValueError(f"{src_path.name}: gt/noisy shape 不一致")
            if frames_gt.ndim != 4 or frames_gt.shape[-1] != 3:
                raise ValueError(f"{src_path.name}: 形状应为 (T,H,W,3)，实际 {frames_gt.shape}")
            if args.frame_idx >= frames_gt.shape[0]:
                raise ValueError(f"{src_path.name}: frame_idx 越界，T={frames_gt.shape[0]}")
            if frames_gt.shape[1:3] != (args.v_disp, args.h_disp):
                raise ValueError(
                    f"{src_path.name}: 分辨率不符，输入={frames_gt.shape[1:3]} 参数={(args.v_disp, args.h_disp)}"
                )

            cur_noisy = frames_noisy[args.frame_idx]
            ref_noisy = frames_noisy[args.frame_idx - 1]
            gt = frames_gt[args.frame_idx]

            luma_cur = olib.rgb_to_luma_u8(cur_noisy)
            luma_ref = olib.rgb_to_luma_u8(ref_noisy)
            proc_mb, _ = tdnr.MBDownSampler.compute(luma_cur)
            ref_mb, ref_sub = tdnr.MBDownSampler.compute(luma_ref)

            sad1_ds, sad2_ds, margin_ds, sad1_mb_best, mv_mag = extract_me_features_v2(
                proc_mb=proc_mb,
                ref_mb=ref_mb,
                ref_sub=ref_sub,
                me=nr.me_td,
            )
            grad_energy = compute_grad_energy_map(luma_cur, mb_size=args.mb_size)
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

            w_label = oracle_label_w(
                cur_noisy=cur_noisy,
                ref_noisy=ref_noisy,
                gt=gt,
                w_set=w_set,
                temporal_iir_filter_fn=tdnr.temporal_iir_filter,
                mb_size=args.mb_size,
            )

            meta = {
                "input_file": src_path.name,
                "frame_idx": int(args.frame_idx),
                "h_disp": int(args.h_disp),
                "v_disp": int(args.v_disp),
                "mb_size": int(args.mb_size),
                "feature_version": "v2_ds_mb_split",
                "mv_mag_unit": "downsampled_grid_manhattan",
                "w_set": [int(x) for x in w_set.tolist()],
                "oracle_loss": "mean_abs_error_rgb_over_4x4_block",
                "ref_rule": "ref = frame_idx - 1",
            }

            np.savez_compressed(
                out_path,
                features=features.astype(np.float32),
                feature_names=feature_names,
                w_label=w_label.astype(np.uint8),
                w_set=w_set.astype(np.uint8),
                sad1_ds=sad1_ds.astype(np.int32),
                sad2_ds=sad2_ds.astype(np.int32),
                margin_ds=margin_ds.astype(np.int32),
                sad1_mb_best=sad1_mb_best.astype(np.int32),
                mv_mag=mv_mag.astype(np.int32),
                meta=np.array(json.dumps(meta, ensure_ascii=False), dtype="U"),
            )

        written += 1
        out_files.append(out_path)
        sad1_ds_means.append(float(sad1_ds.mean()))
        margin_ds_means.append(float(margin_ds.mean()))
        for w in w_set.tolist():
            w_hist_total[int(w)] += int((w_label == w).sum())

        if (idx % 200 == 0) or (idx == total_proc):
            print(f"[进度] 已扫描 {idx}/{total_proc}，已写出 {written}")

    print(f"[信息] 输出文件数: {written}")
    if written > 0:
        s1 = np.array(sad1_ds_means, dtype=np.float32)
        sm = np.array(margin_ds_means, dtype=np.float32)
        print(
            f"[统计] sad1_ds(按文件均值): min={s1.min():.2f}, max={s1.max():.2f}, mean={s1.mean():.2f}"
        )
        print(
            f"[统计] margin_ds(按文件均值): min={sm.min():.2f}, max={sm.max():.2f}, mean={sm.mean():.2f}"
        )
        print("[统计] w_label 全局直方图：")
        for w in w_set.tolist():
            print(f"  - w={int(w):2d}: {w_hist_total[int(w)]}")
    else:
        print("[统计] 无输出，可能都被 skip。")

    if out_files and args.verify_samples > 0:
        sample_n = min(args.verify_samples, len(out_files))
        rng = np.random.default_rng(args.seed + 3030)
        sample_idx = rng.choice(len(out_files), size=sample_n, replace=False)
        samples = [out_files[int(i)] for i in sample_idx]
        print(f"[验证] 随机抽检 {sample_n} 个输出：")
        for fp in samples:
            d = np.load(fp, allow_pickle=False)
            feat = d["features"]
            wlab = d["w_label"]
            print(f"  - {fp.name}: features={feat.shape}/{feat.dtype}, w_label={wlab.shape}/{wlab.dtype}")
            if feat.ndim != 3 or feat.dtype != np.float32:
                raise RuntimeError(f"[验证失败] {fp.name}: features 非期望格式")
            if wlab.dtype != np.uint8:
                raise RuntimeError(f"[验证失败] {fp.name}: w_label dtype 非 uint8")

        if save_png:
            d0 = np.load(samples[0], allow_pickle=False)
            save_preview_maps(
                out_dir=out_dir,
                stem_prefix=samples[0].stem.replace("_oracle", ""),
                w_label=d0["w_label"],
                sad1_ds=d0["sad1_ds"],
                margin_ds=d0["margin_ds"],
                mb_size=args.mb_size,
            )


if __name__ == "__main__":
    main()
