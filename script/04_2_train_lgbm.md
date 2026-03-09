# 04_2_train_lgbm 使用说明

## 目标
从 Script03 shard 数据训练 student，支持三种任务：
- `multiclass`：直接 9 类分类
- `reg`：回归连续 `w`，再量化到 `w_set`
- `ordinal`：8 个阈值二分类（`P(w>t)`）重构有序档位

并输出：metrics、混淆矩阵、特征重要性、w_map 三联图、叙事 heatmap。

## 关键参数
- `--task {multiclass,reg,ordinal}`（默认 `ordinal`）
- `--quantize_method {nearest,floor,ceil}`（默认 `nearest`）
- `--ordinal_strategy independent`
- `--use_expected_w`（仅 `multiclass` 生效）
- `--expected_only_for_viz`（仅 `multiclass` 生效）

其它参数保持原有：
- 抽样/切分：`--max_rows_per_shard`、`--split_mode`、`--val_shards`
- 类不均衡：`--class_weight`、`--min_class_weight`、`--max_class_weight`
- 预处理：`--log1p_features`、`--drop_constant_features`
- 可视化：`--viz_mode`、`--viz_samples`、`--oracle_clip_dir`

## 输出文件命名
会按任务与预测模式自动加后缀：
- `report/metrics_<task>_<mode>.json`
- `report/confusion_matrix_<task>_<mode>.npy`
- `report/confusion_matrix_norm_<task>_<mode>.npy`
- `figures/confusion_matrix_<task>_<mode>.png`
- `figures/confusion_matrix_norm_<task>_<mode>.png`
- `figures/error_distance_hist_<task>_<mode>.png`

例如：`metrics_ordinal_indep05.json`、`metrics_reg_q_nearest.json`。

模型文件：
- `multiclass`: `models/lgbm_model_multiclass.txt`
- `reg`: `models/lgbm_model_reg.txt`
- `ordinal`: `models/lgbm_model_ordinal_tXX_*.txt`（8 个阈值模型）

## 指标说明
`metrics_*.json` 包含：
- `accuracy`
- `macro_f1`
- `mean_abs_class_error`（`|w_pred-w_true|` 的均值）
- `per_class` / `tail_recall`
- `low_support_classes`
- `mae_w`（`reg/ordinal` 会给出，表示连续空间误差）
- `ordinal_debug`（仅 `ordinal`：每个阈值的 acc/auc）

## 运行示例

### 1) multiclass（带 expected 后处理）
```powershell
python .\04_2_train_lgbm.py `
  --shard_dir .\train_oracle_dataset_info `
  --out_dir .\out_train_mc `
  --max_rows_per_shard 200000 `
  --split_mode by_shard --val_shards 2 `
  --task multiclass `
  --class_weight inv_sqrt `
  --use_expected_w true `
  --viz_mode auto --viz_samples 10
```

### 2) reg（推荐做对照）
```powershell
python .\04_2_train_lgbm.py `
  --shard_dir .\train_oracle_dataset_info `
  --out_dir .\out_train_reg `
  --max_rows_per_shard 200000 `
  --split_mode by_shard --val_shards 2 `
  --task reg --quantize_method nearest `
  --class_weight inv_sqrt `
  --viz_mode auto --viz_samples 10
```

### 3) ordinal（推荐主线）
```powershell
python .\04_2_train_lgbm.py `
  --shard_dir .\train_oracle_dataset_info `
  --out_dir .\out_train_ord `
  --max_rows_per_shard 200000 `
  --split_mode by_shard --val_shards 2 `
  --task ordinal --ordinal_strategy independent `
  --class_weight inv_sqrt `
  --viz_mode auto --viz_samples 10
```
