# 03_oracle_label_dataset 使用说明

## 功能
遍历 `davis_clips_noisy_npz/*.npz`（Script02 输出），对每个 clip 的单帧（默认 `frame_idx=1`）生成特征与 Oracle 标签，并扁平化为训练数据：
- `X`: `(N, F)`，`float32`
- `y`: `(N,)`，`uint8`
- `info`（可选）: `(N,4)`，`[clip_id, br, bc, frame_idx]`

为避免全量数据时内存峰值过高，脚本支持按文件数分片写出。

## 公共库
脚本通过 `oracle_lib.py` 复用核心函数，不再动态 import 脚本文件。

## 环境
```powershell
conda activate myenv312
```

## 脚本路径
`03_oracle_label_dataset.py`

## 运行示例（全量）
```powershell
python 03_oracle_label_dataset.py `
  --in_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\davis_clips_noisy_npz `
  --out_npz F:\EngineeringWarehouse\NR\3D_noise_reduction\script\train_oracle.npz `
  --out_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\train_oracle_dataset `
  --frame_idx 1 `
  --w_set "0,4,8,12,16,20,24,28,31" `
  --shard_size 200 `
  --save_feature_stats
```

## 参数
- `--in_dir`：Script02 输出目录
- `--out_npz`：输出数据集文件名（分片模式下会自动生成 `_part000` 后缀）
- `--out_dir`：可选，输出目录；不填时默认 `<out_npz_stem>_shards`
- `--frame_idx`：单帧标签索引，默认 `1`
- `--w_set`：候选权重集合
- `--max_files`：可选，仅处理前 N 个文件
- `--seed`：随机种子（保留用于后续扩展）
- `--save_feature_stats`：可选，输出特征统计 JSON
- `--shard_size`：每个分片最多处理文件数，默认 `200`，`<=0` 表示单文件输出
- `--save_info`：可选，保存 `info` 字段（默认不保存以节省空间）

## 输出目录结构
在 `out_dir` 下输出：
- `train_oracle_part000.npz`
- `train_oracle_part001.npz`
- ...
- `train_oracle.feature_stats.json`（开启 `--save_feature_stats` 时）

## 输出字段
每个输出 `npz` 包含：
- `X`：`float32`，`(N,F)`
- `y`：`uint8`，`(N,)`
- `feature_names`：unicode 数组
- `w_set`：`uint8` 数组
- `files`：该分片参与处理的文件名列表（unicode 数组）
- `meta`：json 字符串（参数、统计、分片范围）
- `info`：仅在 `--save_info` 打开时保存（`uint16/uint8` 组合，节省空间）

## 日志与验收
运行时会打印：
- 输入文件数、实际处理数、输出目录
- 进度（每 200 文件）
- 总样本数 `N`
- `y` 直方图（各个 `w` 的计数）
- 每个分片的首 clip 一致性 sanity check
