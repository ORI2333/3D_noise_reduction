# 03_oracle_label_batch 使用说明

## 功能
批量读取 Script02 的 noisy+gt clips（`*.npz`），对每个文件的指定帧生成：
- 改进特征（DS/MB 分离）
- Oracle `w_label`
- 输出 `*_oracle.npz`

## 特征定义（v2）
`features` 顺序固定为：
1. `sad1_ds`（DS 9pt+5pt 最小 SAD）
2. `sad2_ds`（DS 9pt+5pt 次小 SAD）
3. `margin_ds = sad2_ds - sad1_ds`
4. `sad1_mb_best`（4pt MB 复核最小 SAD）
5. `mv_mag`（DS 最佳位置相对中心的 `|dx|+|dy|`）
6. `sum`（当前帧 luma 4x4 宏块和）
7. `grad_energy`（当前帧 luma 4x4 邻域差绝对值和）
8. `prev_w`（当前固定为 0）

## 环境
```powershell
conda activate myenv312
```

## 脚本路径
`03_oracle_label_batch.py`

## 运行示例
```powershell
python 03_oracle_label_batch.py `
  --in_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\davis_clips_noisy_npz `
  --out_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\oracle_batch_out `
  --w_set "0,4,8,12,16,20,24,28,31" `
  --frame_idx 1 `
  --max_files 100 `
  --verify_samples 3 `
  --save_png true
```

## 参数
- `--in_dir`：输入目录（Script02 输出）
- `--out_dir`：输出目录
- `--w_set`：候选权重集合
- `--frame_idx`：标签帧索引（reference 使用 `frame_idx-1`）
- `--h_disp/--v_disp`：默认 `480/320`
- `--mb_size`：默认 `4`
- `--seed`：抽检随机种子
- `--verify_samples`：抽检样本数
- `--max_files`：可选，前 N 个文件
- `--overwrite`：可选，覆盖同名输出
- `--save_png`：是否导出抽检样本可视化

## 输出
每个输入文件对应一个：
- `<input_stem>_f{frame_idx:03d}_oracle.npz`

字段包含：
- `features` (`float32`, `MB_H x MB_W x 8`)
- `feature_names` (`U` 字符串数组)
- `w_label` (`uint8`, `MB_H x MB_W`)
- `w_set` (`uint8`)
- `sad1_ds/sad2_ds/margin_ds/sad1_mb_best/mv_mag`（`int32`）
- `meta`（json 字符串，`U`）

## 日志与抽检
脚本会打印：
- 输入文件数、处理文件数、输出文件数
- 处理进度（每 200 个）
- `sad1_ds/margin_ds` 的统计
- 全局 `w_label` 直方图
- 抽检样本的 shape/dtype

若 `--save_png true`，会在 `out_dir/verify_preview/` 导出 1 个抽检样本：
- `*_w_label_map.png`
- `*_sad1_ds_map.png`
- `*_margin_ds_map.png`
