#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Oracle 相关公共函数库：
- 动态加载 3dnr.py
- 特征提取（v1 / v2）
- Oracle 标签生成
"""

from __future__ import annotations

import importlib.util
from pathlib import Path
from typing import Tuple

import numpy as np


def parse_w_set(w_set_str: str) -> np.ndarray:
    """解析并规范化 w_set（去重、升序、限制到 [0,31]）。"""
    ws = []
    for s in w_set_str.split(","):
        s = s.strip()
        if not s:
            continue
        ws.append(int(s))
    if not ws:
        raise ValueError("w_set 不能为空")
    ws = sorted(set(ws))
    for w in ws:
        if w < 0 or w > 31:
            raise ValueError(f"w_set 中存在超范围值 {w}，必须在 [0,31]")
    return np.array(ws, dtype=np.uint8)


def load_tdnr_module(base_dir: Path | None = None) -> object:
    """从 image_py/3dnr.py 动态加载 ThreeDNR 相关实现。"""
    if base_dir is None:
        base_dir = Path(__file__).resolve().parent
    module_path = base_dir / "image_py" / "3dnr.py"
    if not module_path.is_file():
        raise FileNotFoundError(f"未找到 3dnr.py: {module_path}")

    spec = importlib.util.spec_from_file_location("tdnr_module", str(module_path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"无法加载模块: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def compute_grad_energy_map(luma: np.ndarray, mb_size: int) -> np.ndarray:
    """计算每个 4x4 宏块的梯度能量：相邻像素差绝对值和。"""
    h, w = luma.shape
    mb_h, mb_w = h // mb_size, w // mb_size
    out = np.zeros((mb_h, mb_w), dtype=np.int32)

    for br in range(mb_h):
        for bc in range(mb_w):
            r0, c0 = br * mb_size, bc * mb_size
            block = luma[r0 : r0 + mb_size, c0 : c0 + mb_size].astype(np.int32)
            gx = np.abs(block[:, 1:] - block[:, :-1]).sum()
            gy = np.abs(block[1:, :] - block[:-1, :]).sum()
            out[br, bc] = int(gx + gy)
    return out


def rgb_to_luma_u8(rgb: np.ndarray) -> np.ndarray:
    """
    统一的 RGB->Luma 转换（与现有 3dnr.py 浮点策略一致）：
      luma = 0.299*R + 0.587*G + 0.114*B
      再转 uint8（截断）。
    """
    if rgb.ndim != 3 or rgb.shape[-1] != 3:
        raise ValueError(f"期望 RGB 形状 (H,W,3)，实际 {rgb.shape}")
    r = rgb[..., 0].astype(np.float32)
    g = rgb[..., 1].astype(np.float32)
    b = rgb[..., 2].astype(np.float32)
    return (0.299 * r + 0.587 * g + 0.114 * b).astype(np.uint8)


def extract_me_features(
    proc_mb: np.ndarray,
    ref_mb: np.ndarray,
    ref_sub: np.ndarray,
    me: object,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    v1 特征：sad1/sad2/margin/mv_mag。
    mv_mag 仅依赖 DS 阶段最佳位置，4pt 不覆盖位置。
    """
    mb_h, mb_w = proc_mb.shape
    sad1 = np.zeros((mb_h, mb_w), dtype=np.int32)
    sad2 = np.zeros((mb_h, mb_w), dtype=np.int32)
    margin = np.zeros((mb_h, mb_w), dtype=np.int32)
    mv_mag = np.zeros((mb_h, mb_w), dtype=np.int32)

    for br in range(mb_h):
        for bc in range(mb_w):
            proc_val = int(proc_mb[br, bc])
            ds_row = br * 2
            ds_col = bc * 2

            best1 = 0x7FFFFFFF
            best2 = 0x7FFFFFFF
            best_pos_ds = (ds_row, ds_col)

            def update_top2_ds(sad_val: int, pos_ds: Tuple[int, int]) -> None:
                nonlocal best1, best2, best_pos_ds
                if sad_val < best1:
                    best2 = best1
                    best1 = sad_val
                    best_pos_ds = pos_ds
                elif sad_val < best2:
                    best2 = sad_val

            for dr, dc in me._OFFSETS_9PT:
                r = ds_row + dr
                c = ds_col + dc
                sad = int(me._sad_sub(proc_val >> 2, ref_sub, r, c))
                update_top2_ds(sad, (r, c))

            p2_center = best_pos_ds
            for dr, dc in me._OFFSETS_5PT:
                r = p2_center[0] + dr
                c = p2_center[1] + dc
                sad = int(me._sad_sub(proc_val >> 2, ref_sub, r, c))
                update_top2_ds(sad, (r, c))

            mb_row_best = best_pos_ds[0] // 2
            mb_col_best = best_pos_ds[1] // 2
            for dr, dc in me._OFFSETS_4PT:
                r_mb = mb_row_best + dr
                c_mb = mb_col_best + dc
                sad = int(me._sad_mb(proc_val, ref_mb, r_mb, c_mb))
                if sad < best1:
                    best2 = best1
                    best1 = sad
                elif sad < best2:
                    best2 = sad

            if best2 == 0x7FFFFFFF:
                best2 = best1

            sad1[br, bc] = np.int32(best1)
            sad2[br, bc] = np.int32(best2)
            margin[br, bc] = np.int32(best2 - best1)
            mv_mag[br, bc] = np.int32(
                abs(best_pos_ds[1] - ds_col) + abs(best_pos_ds[0] - ds_row)
            )

    return sad1, sad2, margin, mv_mag


def extract_me_features_v2(
    proc_mb: np.ndarray,
    ref_mb: np.ndarray,
    ref_sub: np.ndarray,
    me: object,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    v2 特征（DS/MB 分离）：
      sad1_ds, sad2_ds, margin_ds, sad1_mb_best, mv_mag
    """
    mb_h, mb_w = proc_mb.shape
    sad1_ds = np.zeros((mb_h, mb_w), dtype=np.int32)
    sad2_ds = np.zeros((mb_h, mb_w), dtype=np.int32)
    margin_ds = np.zeros((mb_h, mb_w), dtype=np.int32)
    sad1_mb_best = np.zeros((mb_h, mb_w), dtype=np.int32)
    mv_mag = np.zeros((mb_h, mb_w), dtype=np.int32)

    for br in range(mb_h):
        for bc in range(mb_w):
            proc_val = int(proc_mb[br, bc])
            ds_row = br * 2
            ds_col = bc * 2

            best1_ds = 0x7FFFFFFF
            best2_ds = 0x7FFFFFFF
            best_pos_ds = (ds_row, ds_col)

            def update_ds(sad_val: int, pos_ds: Tuple[int, int]) -> None:
                nonlocal best1_ds, best2_ds, best_pos_ds
                if sad_val < best1_ds:
                    best2_ds = best1_ds
                    best1_ds = sad_val
                    best_pos_ds = pos_ds
                elif sad_val < best2_ds:
                    best2_ds = sad_val

            for dr, dc in me._OFFSETS_9PT:
                r = ds_row + dr
                c = ds_col + dc
                sad = int(me._sad_sub(proc_val >> 2, ref_sub, r, c))
                update_ds(sad, (r, c))

            p2_center = best_pos_ds
            for dr, dc in me._OFFSETS_5PT:
                r = p2_center[0] + dr
                c = p2_center[1] + dc
                sad = int(me._sad_sub(proc_val >> 2, ref_sub, r, c))
                update_ds(sad, (r, c))

            if best2_ds == 0x7FFFFFFF:
                best2_ds = best1_ds

            mb_row_best = best_pos_ds[0] // 2
            mb_col_best = best_pos_ds[1] // 2
            best_mb = 0x7FFFFFFF
            for dr, dc in me._OFFSETS_4PT:
                r_mb = mb_row_best + dr
                c_mb = mb_col_best + dc
                sad_mb = int(me._sad_mb(proc_val, ref_mb, r_mb, c_mb))
                if sad_mb < best_mb:
                    best_mb = sad_mb

            sad1_ds[br, bc] = np.int32(best1_ds)
            sad2_ds[br, bc] = np.int32(best2_ds)
            margin_ds[br, bc] = np.int32(best2_ds - best1_ds)
            sad1_mb_best[br, bc] = np.int32(best_mb)
            mv_mag[br, bc] = np.int32(
                abs(best_pos_ds[1] - ds_col) + abs(best_pos_ds[0] - ds_row)
            )

    return sad1_ds, sad2_ds, margin_ds, sad1_mb_best, mv_mag


def frame_to_mb_mae(diff_frame: np.ndarray, mb_size: int) -> np.ndarray:
    """将整帧误差图聚合为每个宏块的平均误差。"""
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
    """监督枚举候选 w，逐宏块选择误差最小的 w（并列取更小 w）。"""
    h, w, _ = cur_noisy.shape
    mb_h = h // mb_size
    mb_w = w // mb_size

    best_loss = np.full((mb_h, mb_w), np.float32(np.inf), dtype=np.float32)
    w_label = np.zeros((mb_h, mb_w), dtype=np.uint8)

    for w_val in w_set.tolist():
        temporal_out = temporal_iir_filter_fn(cur_noisy, ref_noisy, int(w_val))
        diff = np.abs(temporal_out.astype(np.int16) - gt.astype(np.int16)).astype(np.float32)
        loss_map = frame_to_mb_mae(diff, mb_size=mb_size)
        better = loss_map < best_loss
        best_loss[better] = loss_map[better]
        w_label[better] = np.uint8(w_val)

    return w_label
