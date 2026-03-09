# 01_prepare_davis_clips 使用说明

## 功能
从 DAVIS2017 TrainVal 480p 数据集中读取每个视频帧序列，采样 clips，并将每个 clip 统一处理为 `320x480` 后保存为 `.npz`。

处理流程严格为：
1. 时间顺序读取 `JPEGImages/480p/<video>/*.jpg`
2. 随机采样起点 `t0`，取连续 `clip_len` 帧
3. 等比例缩放到 `H1>=320` 且 `W1>=480`
4. center crop 到 `320x480`（同一 clip 的所有帧使用同一组参数）
5. 保存 `<video>_t<t0>.npz`

## 环境（Anaconda）
```powershell
conda activate myenv312
```

依赖：
- `numpy`
- `Pillow`

如未安装：
```powershell
conda install -n myenv312 numpy pillow -y
```

## 脚本路径
`01_prepare_davis_clips.py`

## 运行示例
```powershell
python 01_prepare_davis_clips.py `
  --davis_root F:\EngineeringWarehouse\NR\3D_noise_reduction\script\DAVIS-2017-trainval-480p\DAVIS `
  --out_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\davis_clips_npz `
  --clip_len 16 `
  --num_clips_per_video 50 `
  --seed 123
```

## 参数说明
- `--davis_root`：DAVIS 根目录（包含 `JPEGImages/480p/`）
- `--out_dir`：输出目录
- `--clip_len`：clip 长度，默认 `16`
- `--num_clips_per_video`：每视频采样数，默认 `50`
- `--seed`：随机种子，默认 `123`
- `--verify_samples`：随机抽检 npz 数量，默认 `3`

## 输出格式
每个 clip 一个文件：`<video>_t<t0>.npz`，包含：
- `frames`: `uint8`，shape `(clip_len, 320, 480, 3)`，RGB
- `video`: 视频名字符串
- `t0`: 起点帧 index
- `orig_hw`: 原始高宽 `[H0, W0]`
- `scale_hw`: 缩放后高宽 `[H1, W1]`
- `crop_xy`: 裁剪左上角坐标 `[x, y]`

## 运行日志（脚本会打印）
- 总视频数
- 总 clip 数
- 每个视频成功生成 clip 数
- 抽检样本的 shape 与 dtype

## 验收方式
脚本会自动做两件事：
1. 随机抽取 3 个 `.npz`，打印 shape 与 dtype（应为 `(16, 320, 480, 3)` 和 `uint8`）
2. 从一个抽中的 clip 导出第 0 帧和第 15 帧到：
   - `<out_dir>/verify_preview/*_f000.png`
   - `<out_dir>/verify_preview/*_f015.png`

你只需查看这两张图是否无形变、且不存在逐帧 crop 抖动。
