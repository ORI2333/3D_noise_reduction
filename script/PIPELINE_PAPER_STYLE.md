# 基于 Oracle 监督与 Ordinal 决策的 3DNR 权重学习流程说明（论文式文档）

## 摘要
本文档总结了一个面向时域降噪权重选择（`w in {0,4,8,12,16,20,24,28,31}`）的完整工程流程。流程从 DAVIS 视频数据预处理开始，经过噪声合成、Oracle 标注、特征构建、LightGBM Student 训练，到 Ordinal 阈值后处理与硬件友好导出，形成了可复现、可审计、可部署的端到端方案。当前最稳版本为 **V2 特征 + Ordinal + 单调阈值调优**，在 macro-F1、跨档误差（MAE）与尾部类别召回之间达到较好平衡。

## 1. 问题定义与目标
我们将每个 4x4 宏块的时域融合权重离散为 9 档：

`w_set = [0,4,8,12,16,20,24,28,31]`

目标是学习一个 Student 预测器，在每个宏块输出合适的 `w`，使得：
1. 总体分类质量高（accuracy、macro-F1）。
2. 跨档误差小（`mean_abs_class_error` / `mae_w`）。
3. 尾部档位（24/28/31）不过度塌缩。
4. 可视化 `w_map` 结构与 Oracle 保持一致趋势。
5. 导出形式可直接映射到硬件规则（比较器 + 计数 + LUT）。

## 2. 总体流程
完整流水线如下：

1. `01_prepare_davis_clips.py`
2. `02_add_noise.py`
3. `03_oracle_label_one_clip.py`（单样本打通）
4. `03_oracle_label_dataset.py`（v1 扁平化训练集）
5. `03_oracle_label_batch.py`（v2 per-clip Oracle）
6. `03B_v2_oracle_smoke.py`（v2 smoke 生成）
7. `03C_v2_flatten_smoke.py`（v2 per-clip -> shard，含 info）
8. `04_1_dataset_audit.py`（仅体检，不训练）
9. `04_2_train_lgbm.py`（multiclass / reg / ordinal）
10. `04_2_5_ordinal_threshold_tune.py`（阈值搜索、单调投影、导出）

## 3. 数据与预处理
### 3.1 DAVIS 统一裁剪与切片
脚本：`01_prepare_davis_clips.py`

规则：
1. 输入帧来自 `JPEGImages/480p/<video>/*.jpg`。
2. clip 长度默认 16，每视频随机采样固定数量 clip。
3. 先等比缩放到覆盖 `320x480`，再中心裁剪到 `320x480`。
4. 每个 clip 输出一个 `.npz`，含 `frames` 及几何元信息。

### 3.2 噪声合成
脚本：`02_add_noise.py`

规则：
1. 每个 clip 采样一个 `sigma ~ Uniform(sigma_min, sigma_max)`。
2. 全 clip 同一 `sigma` 加高斯噪声。
3. 输出 `frames_gt`、`frames_noisy`、`sigma`、`seed` 等字段。

## 4. Oracle 标注与特征工程
### 4.1 单样本 Oracle（03A）
脚本：`03_oracle_label_one_clip.py`

作用：
1. 验证 MBDS + ME + Oracle 监督链路可跑通。
2. 输出宏块特征、`w_label` 与可视化图（`w_label/sad1/margin`）。

### 4.2 v1 与 v2 特征
公共库：`oracle_lib.py`

v1 特征（早期）：
1. `sad1, sad2, margin, mv_mag, sum, grad_energy, prev_w`

v2 特征（当前主线）：
1. `sad1_ds, sad2_ds, margin_ds, sad1_mb_best, mv_mag, sum, grad_energy, prev_w`

改进点：
1. 将 DS 置信度与 MB 复核分离，降低跨阶段混合语义。
2. `mv_mag` 固定由 DS 最优位置定义，避免 4pt 覆盖造成解释漂移。

### 4.3 Oracle 标签定义
对每个宏块枚举 `w_set`，计算：

`temporal_out(w) = temporal_iir_filter(cur_noisy_mb, ref_noisy_mb, w)`

损失：

`L(w) = mean(abs(temporal_out(w) - gt_mb))`

取 `argmin_w L(w)` 作为 `w_label`（并列取更小 `w`）。

## 5. 数据集构建（扁平化与分片）
### 5.1 v1 扁平化
脚本：`03_oracle_label_dataset.py`

输出 shard 字段：
1. `X, y, feature_names, w_set, files, meta`
2. 可选 `info(N,4)`，schema `[clip_id, br, bc, frame_idx]`

### 5.2 v2 smoke 扁平化
脚本：`03C_v2_flatten_smoke.py`

用于快速验证 v2 特征是否值得全量化，字段契约与 v1 训练接口对齐。

## 6. 数据健康审计（04-1）
脚本：`04_1_dataset_audit.py`

### 6.1 目标
仅做数据体检，不训练，不依赖 GPU。

### 6.2 关键检查
1. 契约检查：dtype/shape/字段完整性。
2. 一致性检查：`feature_names`、`w_set` 跨 shard 一致。
3. 数值检查：`X` 无 NaN/Inf，`y` 全在 `w_set`。
4. 分布统计：全局/分 shard 标签直方图。
5. 叙事统计：`mv_mag`、`margin`、`sad1` 分桶与 `E[w]`。

### 6.3 v1/v2 兼容
当前审计已支持：
1. `sad1` 或 `sad1_ds`
2. `margin` 或 `margin_ds`

## 7. Student 训练（04-2）
脚本：`04_2_train_lgbm.py`

支持任务：
1. `multiclass`
2. `reg`
3. `ordinal`（当前主线）

关键训练增强：
1. `class_weight`（`inv_sqrt` 推荐）
2. `log1p_features`（对长尾特征稳定分裂）
3. `drop_constant_features`（自动剔除 `prev_w` 常数列）
4. `from_info` 的 `w_map` 可视化链路

## 8. Ordinal 阈值调优（04-2.5）
脚本：`04_2_5_ordinal_threshold_tune.py`

### 8.1 基本规则
阈值模型输出 `p_k = P(y > T[k])`，`T=[0,4,8,12,16,20,24,28]`。

预测重构：
1. `b_k = 1[p_k >= tau_k]`
2. `rank = sum_k b_k`
3. `w_pred = w_set[rank]`

### 8.2 目标函数
支持：
1. `macro_f1`
2. `mean_abs_class_error`
3. `hybrid`
4. `hybrid_tail24`（当前使用）

`hybrid_tail24 = alpha*macro_f1 - (1-alpha)*mae_norm + beta*recall_24`

### 8.3 单调约束
支持 `project` 模式，将 `tau` 投影为非降：

`tau[0] <= tau[1] <= ... <= tau[7]`

并输出 `unconstrained` 与 `monotone` 对比报告。

### 8.4 导出物
`export/` 目录输出：
1. `ordinal_thresholds.json`
2. `ordinal_thresholds.csv`
3. `rtl_snippet.sv`
4. `ordinal_rules.md`

## 9. 当前结果总结（截至当前迭代）
### 9.1 V2 全量基线（ordinal）
来自 `out_train_ord_v2_full/report/metrics_ordinal_indep05.json`：
1. `accuracy = 0.35979`
2. `macro_f1 = 0.25850`
3. `mean_abs_class_error = 3.95469`

### 9.2 V2 全量 + τ 调优（monotone）
来自 `out_ordinal_tune_v2_full/report/metrics_after.json`：
1. `accuracy = 0.36144`
2. `macro_f1 = 0.26412`
3. `mean_abs_class_error = 3.88674`
4. `tail recall`: `w24=0.0700, w28=0.1011, w31=0.3773`

解释：
1. 相比基线，macro-F1 提升且跨档误差下降。
2. 尾部召回整体改善，`w_map` 可视化与结构趋势一致。
3. 该版本可作为当前“整体最稳”候选。

## 10. 复现命令（推荐主线）
### 10.1 V2 per-clip 全量生成
```powershell
python .\03_oracle_label_batch.py `
  --in_dir .\davis_clips_noisy_npz `
  --out_dir .\oracle_batch_out_v2 `
  --frame_idx 1 `
  --w_set "0,4,8,12,16,20,24,28,31" `
  --save_png false `
  --overwrite
```

### 10.2 扁平化成训练 shards（含 info）
```powershell
python .\03C_v2_flatten_smoke.py `
  --oracle_dir .\oracle_batch_out_v2 `
  --out_dir .\train_oracle_dataset_v2_info `
  --pattern "*_oracle.npz" `
  --shard_size 2000000 `
  --mb_h 80 --mb_w 120 `
  --frame_idx_mode zero
```

### 10.3 训练（ordinal）
```powershell
python .\04_2_train_lgbm.py `
  --shard_dir .\train_oracle_dataset_v2_info `
  --out_dir .\out_train_ord_v2_full `
  --split_mode by_shard --val_shards 2 `
  --max_rows_per_shard 200000 `
  --task ordinal `
  --class_weight inv_sqrt `
  --viz_mode from_info --viz_samples 10 `
  --log1p_features true `
  --log1p_keys "sad1_ds,sad2_ds,margin_ds,sad1_mb_best,grad_energy,sum" `
  --drop_constant_features true
```

### 10.4 阈值调优（tail-aware + monotone）
```powershell
python .\04_2_5_ordinal_threshold_tune.py `
  --shard_dir .\train_oracle_dataset_v2_info `
  --model_dir .\out_train_ord_v2_full\models `
  --out_dir .\out_ordinal_tune_v2_full `
  --split_mode by_shard --val_shards 2 `
  --max_rows_per_shard 200000 `
  --objective hybrid_tail24 --hybrid_alpha 0.5 `
  --tail24_beta 0.03 --tail24_floor 0.04 `
  --enforce_tau_monotonic project `
  --log1p_features true `
  --log1p_keys "sad1_ds,sad2_ds,margin_ds,sad1_mb_best,grad_energy,sum" `
  --drop_constant_features true `
  --save_wmap true --viz_samples 10
```

## 11. 局限与下一步
当前局限：
1. `w20` 仍是难点类别，召回可继续提升。
2. `mv_mag` 单变量与 `E[w]` 不严格单调，需联合可靠性特征解释。
3. 尾部类比例低，对指标波动仍敏感。

下一步建议：
1. 在 `04_2_5` 中继续启用后段联合搜索，重点优化 `tau20/tau24/tau28`。
2. 固化 “数据审计 Gate + 指标 Gate + 可视化 Gate” 三重验收。
3. 最终冻结一组 `ordinal_thresholds.json` 作为部署版本，并在新数据上回归验证。

## 12. 原理与数学过程（补充）
### 12.1 观测模型与噪声假设
给定干净序列 \(x_t\) 与观测序列 \(y_t\)，假设加性高斯噪声：

\[
y_t = x_t + n_t,\quad n_t \sim \mathcal{N}(0,\sigma^2)
\]

其中 \(\sigma\) 在 clip 级别采样并固定（Script02 设定）。

### 12.2 时域滤波与离散权重
在宏块级，时域 IIR 融合写作：

\[
\hat{x}_t(w) = \alpha(w)\, y_t + \left(1-\alpha(w)\right)\, r_t
\]

其中：
1. \(y_t\) 为当前 noisy 宏块。
2. \(r_t\) 为参考宏块（由上一帧 noisy 经过时域参考路径得到）。
3. \(w \in \{0,4,8,12,16,20,24,28,31\}\)。
4. \(\alpha(w)\) 为由实现定义的单调映射（`temporal_iir_filter` 内部规则）。

该问题本质是学习宏块条件下的最优离散动作 \(w\)。

### 12.3 Oracle 标注的监督目标
对每个宏块 \(b\)、每个候选 \(w\) 枚举：

\[
L_b(w)=\frac{1}{|\Omega_b|}\sum_{p\in\Omega_b}\left|\hat{x}_{t,b,p}(w)-x_{t,b,p}^{gt}\right|
\]

其中 \(\Omega_b\) 为宏块内像素集合（含 RGB 通道平均）。Oracle 标签：

\[
w_b^\* = \arg\min_{w\in\mathcal{W}} L_b(w)
\]

并列时选择较小 \(w\)（保证确定性）。

### 12.4 运动匹配特征（V2）的统计语义
对每个宏块提取：
1. \(sad1\_{ds}\): DS 搜索最小 SAD
2. \(sad2\_{ds}\): DS 搜索次小 SAD
3. \(margin\_{ds}=sad2\_{ds}-sad1\_{ds}\)
4. \(sad1\_{mb\_best}\): MB 4pt 复核最小 SAD
5. \(mv\_mag=|dx|+|dy|\)（DS 网格）
6. `sum`, `grad_energy`, `prev_w`

解释：
1. `margin_ds` 越大，匹配置信度通常越高。
2. `mv_mag` 仅反映搜索落点偏移，不等价于真实光流。
3. `sad1_mb_best` 给出 MB 空间下的最终匹配代价补充。

### 12.5 Student 学习形式
我们最终采用 Ordinal 分解，而非直接 9 类 softmax。

给定阈值集合：

\[
T=\{0,4,8,12,16,20,24,28\}
\]

构造 8 个二分类任务：

\[
z_k = \mathbf{1}[y>T_k],\quad k=0,\dots,7
\]

每个模型输出：

\[
p_k = P(y>T_k\mid f)
\]

其中 \(f\) 为宏块特征向量。

### 12.6 Ordinal 重构规则
给定阈值 \(\tau_k\)：

\[
b_k = \mathbf{1}[p_k \ge \tau_k]
\]
\[
rank = \sum_{k=0}^{7} b_k
\]
\[
\hat{w}=w\_{set}[rank]
\]

该形式可直接硬件实现：8 比较器 + popcount + LUT。

### 12.7 阈值调优目标函数
我们使用 tail-aware 混合目标：

\[
J(\tau)=\alpha\cdot \text{MacroF1}-(1-\alpha)\cdot \widetilde{MAE}+\beta\cdot Recall_{24}
\]

其中：
1. \(\widetilde{MAE}\) 为归一化跨档误差。
2. \(\beta\) 控制对 `w=24` 的偏好。
3. 若 \(Recall_{24} < \text{floor}\) 施加惩罚项（实现中为常数扣分）。

### 12.8 单调阈值约束
为满足有序决策一致性，要求：

\[
\tau_0 \le \tau_1 \le \cdots \le \tau_7
\]

先做 unconstrained 搜索，再做单调投影（PAV/等价非降投影），得到 \(\tau^{mono}\)。

工程意义：
1. 避免“高阈值比低阈值更容易通过”的逻辑冲突。
2. 提升导出规则的可解释性和可部署性。

### 12.9 评价指标与解释
我们联合报告：
1. `accuracy`
2. `macro_f1`
3. `mean_abs_class_error` / `mae_w`
4. per-class precision/recall/f1
5. tail recall（24/28/31）

解释原则：
1. `macro_f1` 反映类别均衡表现。
2. `MAE` 反映跨档错误距离，和画质代价更相关。
3. `w_map` 三联图用于验证空间结构一致性（Oracle vs Student vs Diff）。
