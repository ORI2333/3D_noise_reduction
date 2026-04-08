# A0~A5 Pipeline Map (Protocol Review)

本文件只做现状梳理，不改已有结果定义。

## 1) Variant -> 脚本入口与依赖

| Variant | 当前主要评估入口 | 核心方法分支/依赖 |
|---|---|---|
| A0 Heuristic baseline | `script/09A_evaluate_groupA_full.py` / `script/09B_evaluate_ablation_full.py` | `build_baseline_wmap` + `3dnr.ThreeDNR.process` |
| A1 Multiclass LightGBM | `script/09A_evaluate_groupA_full.py` / `script/09B_evaluate_ablation_full.py` | `PredictorMulticlass` + `out_train_multiclass/models/lgbm_model_multiclass.txt` |
| A2 Regression-quantization LightGBM | `script/09A_evaluate_groupA_full.py` / `script/09B_evaluate_ablation_full.py` | `PredictorRegNearest` + `out_train_reg/models/lgbm_model_reg.txt` |
| A3 Ordinal raw | `script/09A_evaluate_groupA_full.py` / `script/09B_evaluate_ablation_full.py` | `PredictorOrdinal(tau=0.5)` + `out_train_ord_v2_full/models/lgbm_model_ordinal_t*.txt` |
| A4 Ordinal + threshold tuning | `script/09A_evaluate_groupA_full.py` / `script/09B_evaluate_ablation_full.py` | `PredictorOrdinal(tau=tuned)` + `out_ordinal_tune_v2_full/report/taus_monotone.json` |
| A5 Final deployable ordinal (当前 soft deploy) | `script/09B_evaluate_ablation_full.py` | `PredictorOrdinalDeploy`（`p_k>=tau_k` + monotonic comparator chain） |

补充：Verilog 导出入口为 `script/11_export_model_to_verilog.py`（及 lite 版本），用于硬件映射导出，不是现有评估入口。

## 2) 输入数据来源

- 评估图像：
  - DAVIS: `script/DAVIS-2017-trainval-480p/DAVIS/JPEGImages/480p/<clip>/*.jpg`
  - Set8: `script/Set8/**`
- 噪声：
  - 评估阶段由脚本内 RNG 现场注入（按 `seed + sigma + dataset_idx + seq_idx` 规则）。
- Oracle：
  - 统一由 `oracle_lib.oracle_label_w` 在评估时在线生成。
- 模型与阈值：
  - A1: `script/out_train_multiclass`
  - A2: `script/out_train_reg`
  - A3/A4/A5: `script/out_train_ord_v2_full`
  - tuned tau: `script/out_ordinal_tune_v2_full/report/taus_monotone.json`

## 3) 协议一致性检查（A0~A5）

| 检查项 | 现状 |
|---|---|
| 是否共享同一 train/val/test split | **部分是**。A1/A2/A3/A4/A5 使用相同训练集来源与 split 配置（`train_oracle_dataset_v2_info`, `split_mode=by_shard`, `val_shards=2`, `seed=123`）；A0 无训练。 |
| 是否共享同一 Oracle label | **是**（在 `09B_evaluate_ablation_full.py` 中，A0~A5 decision supervision 统一使用 `oracle_common`）。 |
| 是否共享同一 recursive evaluation path | **策略一致**：各分支都用“各自上一帧输出作为当前参考”（self-recursive）；但参考帧内容按方法分支不同，这是方法定义的一部分。 |
| 是否共享同一数据划分/噪声设置 | **在单次统一运行内是**；但不同历史脚本默认参数不完全一致。 |

## 4) 当前潜在不一致点

1. `09A_evaluate_groupA_full.py` 默认 `sigmas=10,20,30`、`max_frames_per_seq=85`，而已有 Paper-A/B 常用配置常来自 `out_eval_groupA_paperA_oraclefix/metrics_groupA_full.json`（`sigmas=10,30,50`、`max_frames_per_seq=12`）。
2. A5 仅在 `09B_evaluate_ablation_full.py` 出现；A0~A4 同时在 `09A/09B` 都有实现，若分别跑会因协议参数差异导致不可直接对比。
3. 旧评估脚本（如 `09_evaluate_davis_set8_full.py`）不是完整 A0~A5 全量对比协议。
4. 现有仓库没有现成的 `A5_hw_eq` 评估入口；已有 Verilog 导出脚本，但缺统一的 Python 端硬件等价推理入口用于 deploy gap。
5. 协议复用依赖 `protocol_json` 外部文件路径；若路径指向不同 run，会导致 clip/sigma/frame budget 不一致。

## 5) 结论

- 现有 A0~A5 方法定义本身可比较，但需要单一入口强制协议参数统一。
- 建议以后只通过统一入口（本次新增 `09B_run_unified_variants.py`）产出对比结果，避免“同名方法、不同协议”。

