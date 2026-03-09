# 04_1_dataset_audit 使用说明

## 目的（不训练）
`04_1_dataset_audit.py` 只做数据读取、健康检查、统计输出：
- 不引入 LightGBM
- 不做训练
- 不需要 GPU
- 用于 Script04-2 训练前输入验收

## 参数
- `--shard_dir` (required): shard 目录（`*.npz`）
- `--out_dir` (required): 输出目录（`report/` + `figures/`）
- `--max_shards` (optional): 扫描前 N 个 shard
- `--max_rows_per_shard` (optional): 每个 shard 最多读取 N 行
  - 注意：是“随机抽样 N 行”，不是“前 N 行截断”
- `--require_info` (flag): 强制要求 `info` 字段
- `--w_set_expected` (optional): 预期 w_set 校验
- `--save_plots` (optional, default true): 是否输出图
- `--sample_seed` (optional, default 123): 抽样随机种子

## 契约校验
每个 shard 至少包含：
- `X`: float32, `(N,F)`
- `y`: uint8, `(N,)`
- `feature_names`: unicode, `(F,)`
- `w_set`: uint8, `(K,)`
- `files`: unicode
- `meta`: unicode json string

可选：
- `info`: `(N,4)`，`[clip_id, br, bc, frame_idx]`

致命错误（`exit(1)`）：
- 缺字段、dtype/shape 不符
- `feature_names` 跨 shard 不一致
- `w_set` 跨 shard 不一致
- `y` 不在 `w_set`
- `X` 含 NaN/Inf

非致命异常：
- 记录 WARNING，并写入 `dataset_audit.md`

## 输出
在 `out_dir` 下生成：

- `report/dataset_audit.json`
- `report/dataset_audit.md`

若 `--save_plots true`：
- `figures/label_hist_global.png`
- `figures/feature_stats_table.png`
- `figures/bucket_mv_mag_vs_w.png`
- `figures/bucket_margin_vs_w.png`
- `figures/bucket_sad1_vs_w.png`

## 统计内容
- 全局规模：shard 数、扫描数、每 shard N/F、总样本数
- 标签分布：全局直方图 + 每 shard 直方图 + 偏置 Top10
- 特征统计（流式）：`min/max/mean/std`
- 近似分位数：`p1/p5/p50/p95/p99`（approx）
- 叙事分桶：
  - `mv_mag`（0/1/2/3/4/>=5）→ `E[w]` + 类别比例
  - `margin`（分位数桶，approx）→ `E[w]`
  - `sad1`（分位数桶，approx）→ `E[w]`

说明：`E[w]` 是 `w_set` 离散档位的数学期望，不是连续权重。

## 运行示例
```powershell
python 04_1_dataset_audit.py `
  --shard_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\train_oracle_dataset `
  --out_dir F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_audit `
  --max_shards 10 `
  --max_rows_per_shard 200000 `
  --w_set_expected "0,4,8,12,16,20,24,28,31"
```

建议：
- 先快速抽样体检（`max_shards/max_rows_per_shard`）
- 再至少跑一次全 shard 审计，确保结论稳定
