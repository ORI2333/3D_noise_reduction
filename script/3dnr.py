# -*- coding: utf-8 -*-
"""
3D 噪声消除（3DNR）—— FPGA RTL 设计的 Python 复现
=========================================================================
架构复现自 ``FPGA/rtl/``：

  +---------------------------------------------------------------------+
  |  输入帧（H_DISP x V_DISP，每通道 8 bit）                           |
  |       |                                                             |
  |  [MBDS]  宏块下采样                                                 |
  |   +-- mb_image   : (H_DISP/4 x V_DISP/4)  宏块求和图（12 bit）    |
  |   +-- sub_image  : (H_DISP/2 x V_DISP/2)  2 倍下采样图            |
  |       |                                                             |
  |  [ME/TD] 运动估计 / 时域判决（逐宏块）                              |
  |   分层 SAD 搜索：9 点 -> 5 点 -> 4 点                              |
  |   输出：select_temporal[MB_H x MB_W] 布尔判决图                   |
  |       |                                                             |
  |  [算法] 逐 4x4 宏块处理                                            |
  |   +-- 时域滤波  : out = cur*(32-w)/32 + ref*w/32                  |
  |   +-- 空域滤波  : 逐像素 3x3 双边滤波                              |
  |       （值域权重来自 LUT 高斯表，空间权重固定高斯近似）             |
  +---------------------------------------------------------------------+

RTL 模块对应关系：
  U2_MBDS_8CH                -> MBDownSampler
  U4_MotionEstimate_ThresholdDetect + U4_1_Addr_Gen + U4_2_Max_reg_SAD_Vector
                             -> MotionEstimator
  U6_0_Spatial_algorithm + U6_0_0_Calculator + U6_0_0_0_LUT_Parameter
                             -> spatial_bilateral_filter / _build_range_lut
  U6_1_Temporal_algorithm    -> temporal_iir_filter
  U6_Algorithm_sys           -> AlgorithmSubsys
  3DNR_8CH (顶层)            -> ThreeDNR

命令行用法示例::

    python 3dnr.py --cur frame0.png --ref frame1.png -o denoised.png

作为库调用::

    import importlib.util
    spec = importlib.util.spec_from_file_location("tdnr", "3dnr.py")
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    nr = m.ThreeDNR()
    out = nr.process(current_frame_rgb, reference_frame_rgb)
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path
from typing import Optional

import numpy as np

# ---------------------------------------------------------------------------
# 可选依赖：Pillow（仅 CLI 演示模式需要）
# ---------------------------------------------------------------------------
try:
    from PIL import Image as _PIL_Image
    _PILLOW_OK = True
except ImportError:
    _PILLOW_OK = False


# ===========================================================================
# 全局常量（与 RTL 参数默认值一致）
# ===========================================================================
H_DISP: int = 480          # 图像宽度（列数）
V_DISP: int = 320          # 图像高度（行数）
MB_SIZE: int = 4           # 宏块边长（4x4 像素）
BILATERAL_SIGMA: float = 25.0   # 值域高斯标准差（与 RTL 注释一致）
TEMPORAL_WEIGHT_DEFAULT: int = 16  # 时域混合权重，分母为 32（RTL: TEMPORAL_CALCULATE_PARAM=16）
MACROBLOCK_THRESHOLD: int = 4095   # 时域判决 SAD 阈值

# 空间高斯权重（按中心距离分级：0=中心，1=边，sqrt2=角）
# RTL s_weight[0]=128, s_weight[1]=77, s_weight[2]=47
_SP_W_CTR: int = 128   # 中心（距离 0）
_SP_W_EDG: int = 77    # 上下左右邻居（距离 1）
_SP_W_CRN: int = 47    # 四角邻居（距离 sqrt2）

# 3x3 核内各位置的空间权重，行优先顺序：左上 上 右上 左 中 右 左下 下 右下
_SPATIAL_WEIGHT_MAP: np.ndarray = np.array(
    [_SP_W_CRN, _SP_W_EDG, _SP_W_CRN,
     _SP_W_EDG, _SP_W_CTR, _SP_W_EDG,
     _SP_W_CRN, _SP_W_EDG, _SP_W_CRN],
    dtype=np.uint32
)                        # shape (9,)


# ===========================================================================
# 第一部分：双边滤波值域权重 LUT
# ===========================================================================

def _build_range_lut(sigma: float = BILATERAL_SIGMA) -> np.ndarray:
    """
    生成 256 项 LUT：lut[d] = round( 255 * exp(-d² / (2*sigma²)) )

    对应 RTL U6_0_0_0_LUT_Parameter / multi_bram 中加载的 ROM 表。
    输入为像素绝对差 |中心 - 邻居|（0~255），输出为 8-bit 权重。
    """
    d = np.arange(256, dtype=np.float64)
    lut = np.round(255.0 * np.exp(-(d ** 2) / (2.0 * sigma ** 2))).astype(np.uint8)
    return lut


_RANGE_LUT: np.ndarray = _build_range_lut()  # 全局单例


# ===========================================================================
# 第二部分：空域双边滤波（U6_0_Spatial_algorithm + U6_0_0_Calculator）
# ===========================================================================

def _bilateral_pixel(patch: np.ndarray, range_lut: np.ndarray) -> int:
    """
    对 3x3 邻域块做双边滤波，返回中心像素的滤波结果。

    对应 RTL U6_0_0_Calculator 的计算流程：
      1. 对 9 个邻居计算差绝对值 diff = |中心 - 邻居|。
      2. 查 LUT 得到值域权重  c_weight[i] = lut[diff_i]。
      3. 联合权重 = c_weight[i] * s_weight[i]  （RTL：c_mul_s）。
      4. 加权像素 = combined_weight[i] * pixel[i]  （RTL：MUL2）。
      5. 输出     = 加权像素和 / 权重和            （RTL：SUM2/SUM1，18拍除法器）。

    参数
    ----
    patch     : ndarray shape (3, 3)，dtype uint8
    range_lut : ndarray shape (256,)，dtype uint8

    返回
    ----
    int  滤波后的像素值 [0, 255]
    """
    flat = patch.ravel()          # 展开为 9 元素，中心 = flat[4]
    center = int(flat[4])

    diffs = np.abs(flat.astype(np.int32) - center).astype(np.uint8)
    c_weight = range_lut[diffs].astype(np.uint32)  # 值域权重

    combined = c_weight * _SPATIAL_WEIGHT_MAP       # 联合权重，shape (9,)
    sum1 = int(combined.sum())                      # 分母 SUM1
    sum2 = int((combined * flat.astype(np.uint32)).sum())  # 分子 SUM2

    if sum1 == 0:
        return center
    return int(np.clip(sum2 // sum1, 0, 255))


def spatial_bilateral_filter(
    macroblock: np.ndarray,
    range_lut: Optional[np.ndarray] = None,
) -> np.ndarray:
    """
    对 4x4 宏块内每个像素执行双边滤波。

    宏块在处理前先零填充至 6x6（对应 RTL 中
    pixel_image[0] 和 pixel_image[5] 行/列固定为 0）。

    参数
    ----
    macroblock : ndarray shape (4, 4)，dtype uint8
    range_lut  : 可选，预构建的值域 LUT

    返回
    ----
    ndarray shape (4, 4)，dtype uint8
    """
    if range_lut is None:
        range_lut = _RANGE_LUT

    # 零填充至 6x6（对应 RTL pixel_image[0/5][*] 和 pixel_image[*][0/5] 硬接地）
    padded = np.zeros((6, 6), dtype=np.uint8)
    padded[1:5, 1:5] = macroblock

    out = np.empty((4, 4), dtype=np.uint8)
    for r in range(4):
        for c in range(4):
            patch = padded[r: r + 3, c: c + 3]   # 以 padded[r+1, c+1] 为中心的 3x3 块
            out[r, c] = _bilateral_pixel(patch, range_lut)
    return out


def spatial_filter_image(
    image: np.ndarray,
    range_lut: Optional[np.ndarray] = None,
) -> np.ndarray:
    """
    对整幅图像（所有 4x4 宏块）执行空域双边滤波。

    参数
    ----
    image     : ndarray shape (V_DISP, H_DISP) 单通道，
                或 (V_DISP, H_DISP, C) 多通道
    range_lut : 可选，预构建的值域 LUT

    返回
    ----
    ndarray 与 *image* 形状相同，dtype uint8
    """
    if range_lut is None:
        range_lut = _RANGE_LUT

    h, w = image.shape[:2]
    mb_rows = h // MB_SIZE
    mb_cols = w // MB_SIZE
    result = np.zeros_like(image)

    if image.ndim == 2:
        # 单通道
        for br in range(mb_rows):
            for bc in range(mb_cols):
                r0, c0 = br * MB_SIZE, bc * MB_SIZE
                mb = image[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE]
                result[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE] = \
                    spatial_bilateral_filter(mb, range_lut)
    else:
        # 多通道，逐通道处理
        for ch in range(image.shape[2]):
            result[..., ch] = spatial_filter_image(image[..., ch], range_lut)
    return result


# ===========================================================================
# 第三部分：时域 IIR 滤波（U6_1_Temporal_algorithm）
# ===========================================================================

def temporal_iir_filter(
    current: np.ndarray,
    reference: np.ndarray,
    weight: int = TEMPORAL_WEIGHT_DEFAULT,
) -> np.ndarray:
    """
    时域 IIR 混合滤波。

    RTL 公式（U6_1_Temporal_algorithm）：
        d_out = (current * (32 - weight) + reference * weight) >> 5

    weight 为 6-bit 无符号整数（0~31），0=全保留当前帧，31=几乎全保留参考帧。

    参数
    ----
    current   : ndarray uint8，当前（待处理）帧
    reference : ndarray uint8，参考（match）帧
    weight    : 向参考帧的混合权重，范围 [0, 31]

    返回
    ----
    ndarray uint8，混合结果
    """
    w = int(np.clip(weight, 0, 31))
    cur = current.astype(np.uint16)
    ref = reference.astype(np.uint16)
    result = (cur * (32 - w) + ref * w) >> 5
    return result.astype(np.uint8)


# ===========================================================================
# 第四部分：宏块下采样（U2_MBDS_8CH）
# ===========================================================================

class MBDownSampler:
    """
    复现 U2_MBDS_8CH：

    对每个 4x4 宏块：
      mb_value   = 全部16个像素之和（12-bit，未归一化）
    对每个 2x2 超像素（sub-sample）：
      sub_value  = 4 个像素均值（8-bit）

    这两张缩小图供 ME/TD 模块使用。
    """

    @staticmethod
    def compute(image: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        """
        参数
        ----
        image : ndarray (V_DISP, H_DISP) 单通道 uint8

        返回
        ----
        mb_image  : ndarray (V_DISP//4, H_DISP//4) uint16  — 宏块求和图
        sub_image : ndarray (V_DISP//2, H_DISP//2) uint8   — 2倍下采样图
        """
        h, w = image.shape[:2]
        img = image.astype(np.uint16)

        # --- 宏块图：4x4 块求和 ---
        mb_h, mb_w = h // MB_SIZE, w // MB_SIZE
        mb_image = np.zeros((mb_h, mb_w), dtype=np.uint16)
        for br in range(mb_h):
            for bc in range(mb_w):
                r0, c0 = br * MB_SIZE, bc * MB_SIZE
                mb_image[br, bc] = np.sum(img[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE])

        # --- 下采样图：2x2 块均值（2 倍下采样）---
        sub_h, sub_w = h // 2, w // 2
        sub_image = np.zeros((sub_h, sub_w), dtype=np.uint8)
        for r in range(sub_h):
            for c in range(sub_w):
                r0, c0 = r * 2, c * 2
                sub_image[r, c] = int(img[r0: r0 + 2, c0: c0 + 2].mean())

        return mb_image, sub_image


# ===========================================================================
# 第五部分：运动估计与时域判决（U4_MotionEstimate_ThresholdDetect）
# ===========================================================================

class MotionEstimator:
    """
    复现 U4_MotionEstimate_ThresholdDetect 与 U4_1_Addr_Gen。

    分层 SAD 搜索：
      第一阶段（gen_type 00/11）— 9 点粗搜索，下采样空间步长 ±2
      第二阶段（gen_type 01）    — 5 点精细搜索，步长 ±1
      第三阶段（gen_type 10）    — 4 点像素级验证（回宏块坐标）

    最小 SAD < 阈值 → select_temporal = True（取时域滤波）。
    """

    # Offsets for each search phase in (row, col) of downsampled / MB image
    _OFFSETS_9PT = [
        (0,  0), (-2, 0), (2,  0), (0, -2), (0,  2),
        (-2, -2), (-2, 2), (2, -2), (2,  2),
    ]
    _OFFSETS_5PT = [
        (0, 0), (-1, 0), (1, 0), (0, -1), (0, 1),
    ]
    _OFFSETS_4PT = [
        (0, 0), (0, 1), (1, 0), (1, 1),
    ]

    def __init__(
        self,
        h_disp: int = H_DISP,
        v_disp: int = V_DISP,
        threshold: int = MACROBLOCK_THRESHOLD,
    ):
        self.h_disp = h_disp
        self.v_disp = v_disp
        self.threshold = threshold
        self.mb_w = h_disp // MB_SIZE
        self.mb_h = v_disp // MB_SIZE
        self.ds_w = h_disp // 2          # 下采样图宽度
        self.ds_h = v_disp // 2          # 下采样图高度

    # ------------------------------------------------------------------
    def _sad_mb(
        self,
        proc_mb: int,
        ref_mb_image: np.ndarray,
        row: int,
        col: int,
    ) -> int:
        """计算 proc_mb（标量宏块和）与参考帧 (row,col) 位置的 SAD。"""
        if 0 <= row < self.mb_h and 0 <= col < self.mb_w:
            return int(abs(int(proc_mb) - int(ref_mb_image[row, col])))
        return 0xFFFF   # 越界 → SAD 设为最大值

    def _sad_sub(
        self,
        proc_val: int,
        ref_sub: np.ndarray,
        row: int,
        col: int,
    ) -> int:
        """计算 proc_val 与下采样参考帧 (row,col) 的 SAD。"""
        if 0 <= row < self.ds_h and 0 <= col < self.ds_w:
            return int(abs(int(proc_val) - int(ref_sub[row, col])))
        return 0xFFFF

    # ------------------------------------------------------------------
    def detect(
        self,
        proc_mb_image: np.ndarray,
        ref_mb_image:  np.ndarray,
        ref_sub_image: np.ndarray,
    ) -> np.ndarray:
        """
        对每个宏块执行 ME/TD 判决。

        参数
        ----
        proc_mb_image  : (MB_H, MB_W) uint16  当前帧宏块求和图
        ref_mb_image   : (MB_H, MB_W) uint16  参考帧宏块求和图
        ref_sub_image  : (DS_H, DS_W) uint8   参考帧 2 倍下采样图

        返回
        ----
        select_temporal : ndarray (MB_H, MB_W) bool
            True  → 使用时域 IIR 滤波
            False → 使用空域双边滤波
        """
        sel = np.zeros((self.mb_h, self.mb_w), dtype=bool)

        for br in range(self.mb_h):
            for bc in range(self.mb_w):
                proc_val = int(proc_mb_image[br, bc])

                # --- 第一阶段：9 点粗搜索（在下采样图空间）---
                # 将宏块坐标转换到下采样图坐标（宏块块 → 2 个 DS 像素）
                ds_row = br * 2      # 宏块 -> 下采样 层级比
                ds_col = bc * 2

                best_sad = 0xFFFF
                best_pos = (ds_row, ds_col)

                for dr, dc in self._OFFSETS_9PT:
                    r, c = ds_row + dr, ds_col + dc
                    sad = self._sad_sub(proc_val >> 2, ref_sub_image, r, c)
                    if sad < best_sad:
                        best_sad = sad
                        best_pos = (r, c)

                # --- 第二阶段：5 点精细搜索（围绕最优候选）---
                for dr, dc in self._OFFSETS_5PT:
                    r = best_pos[0] + dr
                    c = best_pos[1] + dc
                    sad = self._sad_sub(proc_val >> 2, ref_sub_image, r, c)
                    if sad < best_sad:
                        best_sad = sad
                        best_pos = (r, c)

                # --- 第三阶段：4 点像素级验证（回宏块坐标空间）---
                # 将最优 DS 坐标映射回宏块坐标
                mb_row_best = best_pos[0] // 2
                mb_col_best = best_pos[1] // 2

                for dr, dc in self._OFFSETS_4PT:
                    r = mb_row_best + dr
                    c = mb_col_best + dc
                    sad = self._sad_mb(proc_val, ref_mb_image, r, c)
                    if sad < best_sad:
                        best_sad = sad

                # --- 阈值判决 ---
                sel[br, bc] = best_sad < self.threshold

        return sel


# ===========================================================================
# 第六部分：算法子系统（U6_Algorithm_sys）
# ===========================================================================

class AlgorithmSubsys:
    """
    复现 U6_Algorithm_sys：

    对每个 4x4 宏块，根据判决 select_temporal 选择：
      - 时域 IIR 滤波（select_temporal == True）
      - 空域双边滤波（select_temporal == False）
    """

    def __init__(self, temporal_weight: int = TEMPORAL_WEIGHT_DEFAULT):
        self.temporal_weight = temporal_weight
        self._range_lut = _build_range_lut()

    def process_frame(
        self,
        current: np.ndarray,
        reference: np.ndarray,
        select_temporal: np.ndarray,
    ) -> np.ndarray:
        """
        参数
        ----
        current          : (H, W) 或 (H, W, C) uint8 — 待处理帧
        reference        : 同形状 — 参考（match）帧
        select_temporal  : (H//4, W//4) bool  — 逐宏块判决图

        返回
        ----
        output : 与 *current* 形状相同，uint8
        """
        h, w = current.shape[:2]
        mb_rows = h // MB_SIZE
        mb_cols = w // MB_SIZE
        output = np.empty_like(current)

        multichannel = current.ndim == 3

        for br in range(mb_rows):
            for bc in range(mb_cols):
                r0, c0 = br * MB_SIZE, bc * MB_SIZE
                use_tmp = bool(select_temporal[br, bc])

                if multichannel:
                    for ch in range(current.shape[2]):
                        mb_cur = current[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE, ch]
                        mb_ref = reference[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE, ch]
                        if use_tmp:
                            output[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE, ch] = \
                                temporal_iir_filter(mb_cur, mb_ref, self.temporal_weight)
                        else:
                            output[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE, ch] = \
                                spatial_bilateral_filter(mb_cur, self._range_lut)
                else:
                    mb_cur = current[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE]
                    mb_ref = reference[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE]
                    if use_tmp:
                        output[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE] = \
                            temporal_iir_filter(mb_cur, mb_ref, self.temporal_weight)
                    else:
                        output[r0: r0 + MB_SIZE, c0: c0 + MB_SIZE] = \
                            spatial_bilateral_filter(mb_cur, self._range_lut)
        return output


# ===========================================================================
# 第七部分：顶层 3DNR 处理器（DDD_Noise_8CH / 3DNR_8CH）
# ===========================================================================

class ThreeDNR:
    """
    3D 噪声消除顶层处理器。

    复现 ``DDD_Noise_8CH``（3DNR_8CH.sv）的主流水线：
      1. 对当前帧（process buffer）运行 MBDS
      2. 对参考帧（match  buffer）运行 MBDS
      3. ME/TD 逐宏块判决时域还是空域滤波
      4. 算法子系统逐宏块执行对应滤波

    参数
    ----
    h_disp          : 图像宽度（默认 480）
    v_disp          : 图像高度（默认 320）
    temporal_weight : 时域 IIR 混合权重 [0-31]（默认 16）
    mb_threshold    : 时域判决 SAD 阈值（默认 4095）
    """

    def __init__(
        self,
        h_disp: int = H_DISP,
        v_disp: int = V_DISP,
        temporal_weight: int = TEMPORAL_WEIGHT_DEFAULT,
        mb_threshold: int = MACROBLOCK_THRESHOLD,
    ):
        self.h_disp = h_disp
        self.v_disp = v_disp
        self.mbds = MBDownSampler()
        self.me_td = MotionEstimator(h_disp, v_disp, mb_threshold)
        self.algo  = AlgorithmSubsys(temporal_weight)

        # 内部状态：最近一帧的去噪结果（作为下一帧的参考帧）
        self._ref_frame: Optional[np.ndarray] = None

    # ------------------------------------------------------------------
    def reset(self) -> None:
        """清除内部参考帧（如内容切换时使用）。"""
        self._ref_frame = None

    # ------------------------------------------------------------------
    def process(
        self,
        current: np.ndarray,
        reference: Optional[np.ndarray] = None,
    ) -> np.ndarray:
        """
        对单帧图像进行去噪处理。

        参数
        ----
        current   : ndarray (V_DISP, H_DISP) 或 (V_DISP, H_DISP, C)，uint8
                    待处理的带噪输入帧。
        reference : ndarray 同形状，uint8（可选）。
                    参考帧。如果为 None，则使用上一帧的输出
                    （时域反馈模式）。首帧无参考时仅运行空域滤波。

        返回
        ----
        output : ndarray 与 *current* 形状相同，uint8
        """
        # Validate / resize to configured resolution
        cur = self._ensure_resolution(current)

        if reference is not None:
            ref = self._ensure_resolution(reference)
        elif self._ref_frame is not None:
            ref = self._ref_frame
        else:
            # 无参考帧 → 纯空域处理
            ref = cur

        # --- 第一步：对单亮度通道运行 MBDS（供 ME/TD 使用）---
        if cur.ndim == 3:
            # 近似亮度信道供运动估计使用
            luma_cur = self._to_luma(cur)
            luma_ref = self._to_luma(ref)
        else:
            luma_cur = cur
            luma_ref = ref

        proc_mb, _      = self.mbds.compute(luma_cur)
        ref_mb, ref_sub = self.mbds.compute(luma_ref)

        # --- 第二步：ME/TD ---
        select_temporal = self.me_td.detect(proc_mb, ref_mb, ref_sub)

        # --- 第三步：算法子系统（逐宏块滤波）---
        output = self.algo.process_frame(cur, ref, select_temporal)

        # 更新内部参考帧
        self._ref_frame = output.copy()
        return output

    # ------------------------------------------------------------------
    @staticmethod
    def _to_luma(rgb: np.ndarray) -> np.ndarray:
        """BT.601 帧格亮度（H, W, 3）uint8 → （H, W）uint8。"""
        r, g, b = rgb[..., 0].astype(np.float32), \
                  rgb[..., 1].astype(np.float32), \
                  rgb[..., 2].astype(np.float32)
        luma = 0.299 * r + 0.587 * g + 0.114 * b
        return luma.astype(np.uint8)

    def _ensure_resolution(self, img: np.ndarray) -> np.ndarray:
        """如有必要，将 *img* 最近邻缩放到（V_DISP, H_DISP, ...）尺寸。"""
        h, w = img.shape[:2]
        if h == self.v_disp and w == self.h_disp:
            return img.astype(np.uint8)
        # 最近邻缩放（纯 numpy 实现）
        row_idx = (np.arange(self.v_disp) * h // self.v_disp)
        col_idx = (np.arange(self.h_disp) * w // self.h_disp)
        resized = img[np.ix_(row_idx, col_idx)] if img.ndim == 2 else \
                  img[row_idx[:, None], col_idx[None, :]]
        return resized.astype(np.uint8)


# ===========================================================================
# 第八部分：诊断辅助函数
# ===========================================================================

def print_lut_sample(sigma: float = BILATERAL_SIGMA, n: int = 32) -> None:
    """打印双边滤波值域权重 LUT 的前 *n* 项。"""
    lut = _build_range_lut(sigma)
    print(f"双边滤波值域权重 LUT（sigma={sigma}），前 {n} 项：")
    for i in range(0, n, 8):
        row = "  ".join(f"lut[{j:3d}]={lut[j]:3d}" for j in range(i, min(i + 8, n)))
        print("  " + row)


def compute_motionmap(
    current: np.ndarray,
    reference: np.ndarray,
    h_disp: int = H_DISP,
    v_disp: int = V_DISP,
    threshold: int = MACROBLOCK_THRESHOLD,
) -> np.ndarray:
    """
    返回 uint8 时域判决图可视化结果：
      255 = 该宏块使用时域滤波
        0 = 该宏块使用空域滤波
    """
    nr = ThreeDNR(h_disp, v_disp, mb_threshold=threshold)
    cur  = nr._ensure_resolution(current)
    ref  = nr._ensure_resolution(reference)
    luma_cur = nr._to_luma(cur) if cur.ndim == 3 else cur
    luma_ref = nr._to_luma(ref) if ref.ndim == 3 else ref
    proc_mb, _      = MBDownSampler.compute(luma_cur)
    ref_mb, ref_sub = MBDownSampler.compute(luma_ref)
    sel = nr.me_td.detect(proc_mb, ref_mb, ref_sub)
    # 映射到全分辨率图像
    motion_img = np.kron(sel.astype(np.uint8) * 255,
                         np.ones((MB_SIZE, MB_SIZE), dtype=np.uint8))
    return motion_img


# ===========================================================================
# 命令行入口
# ===========================================================================

def _load_image(path: str) -> np.ndarray:
    if not _PILLOW_OK:
        raise ImportError("pip install pillow  to use the CLI image I/O")
    with _PIL_Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8)


def _save_image(arr: np.ndarray, path: str) -> None:
    if not _PILLOW_OK:
        raise ImportError("pip install pillow  to use the CLI image I/O")
    _PIL_Image.fromarray(arr).save(path)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="3DNR 处理器 —— FPGA 逻辑 Python 复现版"
    )
    parser.add_argument("--cur",    required=True,  help="当前（带噪）输入帧图像")
    parser.add_argument("--ref",    default=None,   help="参考帧（可选）")
    parser.add_argument("-o", "--output", default=None, help="输出去噪图像路径")
    parser.add_argument("--width",  type=int, default=H_DISP)
    parser.add_argument("--height", type=int, default=V_DISP)
    parser.add_argument("--temporal-weight", type=int, default=TEMPORAL_WEIGHT_DEFAULT,
                        help="时域 IIR 权重 [0-31]（默认：16）")
    parser.add_argument("--threshold", type=int, default=MACROBLOCK_THRESHOLD,
                        help="时域判决 SAD 阈值")
    parser.add_argument("--motion-map", default=None,
                        help="将时域判决图保存到此路径")
    parser.add_argument("--lut-info", action="store_true",
                        help="打印 LUT 采样后退出")
    args = parser.parse_args()

    if args.lut_info:
        print_lut_sample()
        return 0

    nr = ThreeDNR(
        h_disp=args.width,
        v_disp=args.height,
        temporal_weight=args.temporal_weight,
        mb_threshold=args.threshold,
    )

    cur = _load_image(args.cur)
    ref = _load_image(args.ref) if args.ref else None

    print(f"处理中: {args.cur}  ({cur.shape[1]}x{cur.shape[0]})")
    output = nr.process(cur, ref)

    out_dir = Path(__file__).parent / "out"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = args.output if args.output else str(out_dir / "3dnr_output.png")
    _save_image(output, out_path)
    print(f"已保存去噪图像 → {out_path}")

    if args.motion_map:
        if ref is None:
            print("警告：--motion-map 需要指定 --ref，已跳过。")
        else:
            mm = compute_motionmap(cur, ref, args.width, args.height, args.threshold)
            _save_image(mm, args.motion_map)
            print(f"已保存运动图      → {args.motion_map}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
