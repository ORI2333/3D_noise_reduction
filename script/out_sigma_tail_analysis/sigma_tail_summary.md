# Sigma Tail Summary

## Q1: 哪些 sigma 下 A2 更强

- 从 image-level（PSNR）看，A2 更强的 sigma: `[10, 30]`。
- 从 decision-level（Macro-F1）看，A2 更强的 sigma: `[]`。

## Q2: 哪些 sigma 下 ordinal family 更强

- 从 decision-level（Macro-F1）看，ordinal family 更强的 sigma: `[10, 30, 50]`。

## Q3: tail recall 优势是否主要集中在高噪声/困难场景

- best ordinal vs A2 的平均 tail recall 增益（@24/@28/@31 平均）: sigma=10: `+0.0430`, sigma=50: `+0.1254`。
- 高噪声均值增益（sigma>=30）=`+0.1199`，低噪声参考增益=`+0.0430`，结论：`是`。

## Q4: 是否支持该结论

- 结论 `ordinal family is more advantageous in hard and tail-dominated regimes` 判定：`支持`。

## 备注

- A2 更偏向 image-level PSNR 优势。
- Ordinal family 的价值主要体现在 decision 结构性与 tail-sensitive 指标。

