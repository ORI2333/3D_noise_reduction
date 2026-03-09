# 04_2_5_ordinal_threshold_tune 使用说明

## 目标
对 `task=ordinal` 的 8 个阈值模型做后处理阈值搜索（`tau_k`），不改模型训练，仅优化决策：
- baseline: `tau_k = 0.5`
- tuned: 搜索得到 `tau_k`

输出 before/after 的 metrics、confusion、w_map，并导出硬件友好规则文件。

## 输入模式
1. 模式A（推荐）：`--run_dir`
- 从 `run_dir/models` 读取 ordinal 模型与配置。
- 若未提供 `--shard_dir`，优先从 `train_config.json` 读取。

2. 模式B：`--shard_dir` + `--model_dir`
- 直接指定 shards 和 ordinal 模型目录。

## 关键参数
- `--tau_min --tau_max --tau_step`：阈值扫描范围
- `--search_method`：`per_threshold_greedy` / `global_shared_tau` / `coordinate_descent`
- `--objective`：`macro_f1` / `mean_abs_class_error` / `hybrid`
- `--hybrid_alpha`：`hybrid` 目标系数
- `--save_wmap --viz_samples`

## 决策规则
- 阈值列表 `T=[0,4,8,12,16,20,24,28]`
- 模型输出 `p_k = P(y > T[k])`
- 给定 `tau_k`：
  - `b_k = 1 if p_k >= tau_k else 0`
  - `rank = sum_k b_k`
  - `w_pred = w_set[rank]`

## 输出
`out_dir/report`：
- `metrics_before.json`
- `metrics_after.json`
- `taus.json`
- `confusion_before.npy`
- `confusion_after.npy`
- `confusion_before_norm.npy`
- `confusion_after_norm.npy`

`out_dir/figures`：
- `confusion_before_norm.png`
- `confusion_after_norm.png`
- `tau_curve_kXX.png`
- `wmap_*_triple_before.png`
- `wmap_*_triple_after.png`

`out_dir/export`：
- `ordinal_thresholds.json`
- `ordinal_thresholds.csv`
- `rtl_snippet.sv`
- `ordinal_rules.md`

## 运行示例
```powershell
python .\04_2_5_ordinal_threshold_tune.py `
  --shard_dir .\train_oracle_dataset_info `
  --model_dir .\out_train_ord\models `
  --out_dir .\out_ordinal_tune `
  --split_mode by_shard --val_shards 2 `
  --max_rows_per_shard 200000 `
  --seed 123 `
  --tau_min 0.2 --tau_max 0.8 --tau_step 0.02 `
  --search_method per_threshold_greedy `
  --objective hybrid --hybrid_alpha 0.5 `
  --save_wmap true --viz_samples 10
```

## Task B 新增能力（Tail Recall Targeting）
- 新目标：`--objective hybrid_tail24`
- 权重参数：`--tail24_beta`（默认 0.03）
- 下限参数：`--tail24_floor`（默认 0.04），低于下限会加惩罚
- 后段联合搜索：
  - `--late_threshold_joint_search true/false`
  - `--joint_tau20_grid`（默认 `0.56:0.72:0.02`）
  - `--joint_tau24_grid`（默认 `0.46:0.66:0.02`）
  - `--joint_tau28_grid`（默认 `0.40:0.60:0.02`）

新增图：
- `figures/tail_recall_compare.png`（24/28/31 的 before vs after）

示例：
```powershell
python .\04_2_5_ordinal_threshold_tune.py `
  --shard_dir .\train_oracle_dataset_info `
  --model_dir .\out_train_ord\models `
  --out_dir .\out_ordinal_tune_tail24 `
  --split_mode by_shard --val_shards 2 `
  --max_rows_per_shard 200000 `
  --objective hybrid_tail24 --hybrid_alpha 0.5 `
  --tail24_beta 0.03 --tail24_floor 0.04 `
  --late_threshold_joint_search true `
  --joint_tau20_grid "0.56:0.72:0.02" `
  --joint_tau24_grid "0.46:0.66:0.02" `
  --joint_tau28_grid "0.40:0.60:0.02" `
  --enforce_tau_monotonic project `
  --save_wmap true --viz_samples 10
```

python .\04_2_5_ordinal_threshold_tune.py `
  --shard_dir .\train_oracle_dataset_info `
  --model_dir .\out_train_ord\models `
  --out_dir .\out_ordinal_tune_tail24 `
  --split_mode by_shard --val_shards 2 `
  --max_rows_per_shard 200000 `
  --objective hybrid_tail24 --hybrid_alpha 0.5 `
  --tail24_beta 0.03 --tail24_floor 0.04 `
  --late_threshold_joint_search true `
  --joint_tau20_grid "0.56:0.72:0.02" `
  --joint_tau24_grid "0.46:0.66:0.02" `
  --joint_tau28_grid "0.40:0.60:0.02" `
  --enforce_tau_monotonic project `
  --save_wmap true --viz_samples 10
