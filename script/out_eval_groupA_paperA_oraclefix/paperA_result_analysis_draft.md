### Draft Analysis for Paper A Group

Under a unified protocol on DAVIS and Set8 with identical noise settings and frame budget, all learned methods significantly outperform the heuristic baseline in both decision-level and image-level metrics.
Compared with the baseline, multiclass and regression-quantization already improve macro-level discrimination, with Macro-F1 increasing from 0.0463 to 0.1553 and 0.1574, respectively.
The ordinal formulation further improves class-structure awareness, lifting Macro-F1 to 0.1885 while substantially improving tail-category recalls, especially for high-weight tail bins.
Threshold tuning mainly benefits tail-sensitive categories rather than global accuracy, as reflected by the shift from ordinal raw to ordinal tuned in TailRecall@24/28/31 while overall accuracy changes from 0.2891 to 0.2843.
The oracle branch should be interpreted separately according to the verified diagnostic result.
Its perfect decision-level score indicates consistency with its own supervision target, whereas image-level metrics reflect the gap between local macroblock MAE optimization and global frame-level perceptual or distortion criteria.

