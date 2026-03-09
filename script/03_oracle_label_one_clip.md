# 03_oracle_label_one_clip 使用说明

## 功能
对单个 `Script02` 输出的 noisy+gt clip（`.npz`）执行：
1. 基于现有 `image_py/3dnr.py` 的 MBDS + ME 搜索提取宏块特征
2. 监督 Oracle 枚举 `w_set` 生成每个宏块 `w_label`
3. 保存 `*_oracle.npz`
4. 导出可视化图（`w_label/sad1/margin`）

只做单样本跑通，不训练，不批量遍历全数据集。

## 环境（Anaconda）
```powershell
conda activate myenv312
```

依赖：
- `numpy`
- `Pillow`

## 脚本路径
`03_oracle_label_one_clip.py`

## 运行示例
```powershell
python 03_oracle_label_one_clip.py `
  --input_npz F:\EngineeringWarehouse\NR\3D_noise_reduction\script\davis_clips_noisy_npz\bear_t00000.npz `
  --out_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\oracle_one_clip_out `
  --w_set "0,4,8,12,16,20,24,28,31" `
  --frame_idx 1 `
  --h_disp 480 `
  --v_disp 320 `
  --mb_size 4 `
  --save_png true



```

## 输入要求
输入 `.npz` 需包含：
- `frames_gt`
- `frames_noisy`

两者 shape 必须一致，且为 `(T, 320, 480, 3)`，dtype `uint8`。

## 输出文件
输出到 `out_dir`：
- `<clip_stem>_f{frame_idx:03d}_oracle.npz`

包含字段：
- `features`：`float32`，shape `(MB_H, MB_W, 7)`
- `feature_names`：`["sad1","sad2","margin","mv_mag","sum","grad_energy","prev_w"]`
- `w_label`：`uint8`，shape `(MB_H, MB_W)`，值来自 `w_set`
- `w_set`：`uint8`
- `sad1`：`int32`
- `sad2`：`int32`
- `margin`：`int32`
- `mv_mag`：`int32`
- `meta`：json string（输入文件名、参数、定义说明）

## 特征定义
对 `frame_idx` 帧（参考帧 `frame_idx-1`）：
- `sad1`：ME 搜索最小 SAD
- `sad2`：ME 搜索第二小 SAD
- `margin = sad2 - sad1`
- `mv_mag`：DS 搜索（9pt+5pt）最佳点相对中心的 `|dx|+|dy|`（4pt 不覆盖该位置）
- `sum`：当前帧 luma 的 4x4 宏块像素和（MBDS）
- `grad_energy`：当前帧 luma 4x4 内相邻差绝对值和
- `prev_w`：固定为 0

## Oracle 规则
逐宏块枚举 `w_set`：
1. `temporal_out = temporal_iir_filter(cur_noisy_mb, ref_noisy_mb, w)`
2. `L = mean(abs(temporal_out - gt_mb))`（RGB+4x4 全平均）
3. 取 `argmin_w L` 作为 `w_label`；并列时取更小 `w`

## 可视化输出
若 `--save_png true`，导出：
- `<stem>_w_label_map.png`
- `<stem>_sad1_map.png`
- `<stem>_margin_map.png`

其中宏块图用 `np.kron` 放大到全分辨率显示。

## 运行日志
脚本会打印：
- `w_label` 直方图（每个 `w` 的宏块数量）
- `sad1` / `margin` 的 `min/max/mean`
