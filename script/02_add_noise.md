# 02_add_noise 使用说明

## 功能
读取 Script01 输出的 clip `.npz`（字段 `frames`），对每个 clip 添加高斯噪声，输出新的 `.npz`：
- `frames_gt`：干净帧
- `frames_noisy`：带噪帧
- `sigma`：该 clip 使用的噪声标准差
- `seed`：该 clip 的随机种子
- `src_file`：原始文件名

并在完成后自动抽检与导出预览图。

## 环境（Anaconda）
```powershell
conda activate myenv312
```

依赖：
- `numpy`
- `Pillow`

## 脚本路径
`02_add_noise.py`

## 运行示例
```powershell
python 02_add_noise.py `
  --in_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\davis_clips_npz `
  --out_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\davis_clips_noisy_npz `
  --sigma_min 5 `
  --sigma_max 50 `
  --seed 123 `
  --verify_samples 3
```

快速试跑（只处理前 20 个）：
```powershell
python 02_add_noise.py `
  --in_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\davis_clips_npz `
  --out_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\davis_clips_noisy_npz_smoke `
  --max_files 20
```

## 参数说明
- `--in_dir`：输入目录（包含 `*.npz`）
- `--out_dir`：输出目录
- `--sigma_min`：sigma 下限，默认 `5`
- `--sigma_max`：sigma 上限，默认 `50`
- `--seed`：全局随机种子，默认 `123`
- `--verify_samples`：抽检样本数，默认 `3`
- `--max_files`：可选，仅处理前 N 个文件
- `--overwrite`：可选，若给出则覆盖同名输出

## 处理规则
对每个输入 clip：
1. 读取 `frames`，要求 `dtype=uint8` 且 shape 为 `(T,320,480,3)`
2. 采样单个 `sigma ~ Uniform(sigma_min, sigma_max)`（每个 clip 一个 sigma）
3. 生成噪声 `Normal(0, sigma)` 并加到所有帧
4. `round + clip[0,255] + uint8` 得到 `frames_noisy`
5. 保存输出 `.npz`，并尽量透传原元信息字段：`video/t0/orig_hw/scale_hw/crop_xy`

## 脚本日志
运行时会打印：
- 输入文件数、实际处理文件数、输出文件数
- 进度（每 200 个文件）
- sigma 统计（min/max/mean）

## 验收（脚本自动执行）
处理后自动：
1. 随机抽取 `verify_samples` 个输出 `.npz`，检查：
   - `frames_gt` 与 `frames_noisy` 的 shape 一致
   - dtype 都是 `uint8`
   - `sigma` 在指定范围内
2. 对抽检的第 1 个文件导出预览到 `out_dir/verify_preview/`：
   - `*_gt_f000.png`
   - `*_noisy_f000.png`
   - `*_diff_f000.png`（`abs(gt-noisy)` 放大显示）
