# Paper-B Ablation Evaluation Report

## Run Command

```powershell
python -u .\script\09B_evaluate_ablation_full.py --protocol_json "F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_groupA_paperA_oraclefix\metrics_groupA_full.json" --out_dir "F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_ablation_paperB_run2"
```

## Experiment Config

```json
{
  "protocol_json": "F:\\EngineeringWarehouse\\NR\\3D_noise_reduction\\script\\out_eval_groupA_paperA_oraclefix\\metrics_groupA_full.json",
  "base_root": "F:\\EngineeringWarehouse\\NR\\3D_noise_reduction\\script",
  "davis_jpeg_dir": "F:\\EngineeringWarehouse\\NR\\3D_noise_reduction\\script\\DAVIS-2017-trainval-480p\\DAVIS\\JPEGImages\\480p",
  "set8_dir": "F:\\EngineeringWarehouse\\NR\\3D_noise_reduction\\script\\Set8",
  "davis_clips": [
    "surf",
    "bear",
    "bmx-trees"
  ],
  "sigmas": [
    10,
    30,
    50
  ],
  "max_frames_per_seq": 12,
  "seed": 123,
  "h_disp": 480,
  "v_disp": 320,
  "mb_size": 4,
  "baseline_temporal_weight": 16,
  "baseline_threshold": 4095,
  "w_set": [
    0,
    4,
    8,
    12,
    16,
    20,
    24,
    28,
    31
  ],
  "model_dir_multiclass": "F:\\EngineeringWarehouse\\NR\\3D_noise_reduction\\script\\out_train_multiclass",
  "model_dir_reg": "F:\\EngineeringWarehouse\\NR\\3D_noise_reduction\\script\\out_train_reg",
  "model_dir_ordinal": "F:\\EngineeringWarehouse\\NR\\3D_noise_reduction\\script\\out_train_ord_v2_full",
  "tau_tuned_json": "F:\\EngineeringWarehouse\\NR\\3D_noise_reduction\\script\\out_ordinal_tune_v2_full\\report\\taus_monotone.json",
  "methods": [
    "baseline",
    "multiclass",
    "reg_nearest",
    "ordinal_raw",
    "ordinal_tuned",
    "ordinal_deploy"
  ],
  "method_display": {
    "baseline": "A0 Heuristic baseline",
    "multiclass": "A1 Multiclass LightGBM",
    "reg_nearest": "A2 Regression-quantization LightGBM",
    "ordinal_raw": "A3 Ordinal raw",
    "ordinal_tuned": "A4 Ordinal + threshold tuning",
    "ordinal_deploy": "A5 Final deployable ordinal"
  },
  "ordinal_thresholds": [
    0,
    4,
    8,
    12,
    16,
    20,
    24,
    28
  ],
  "deploy_note": "A5 uses tuned thresholds plus monotonic projection on comparator decisions in inference stage."
}
```

## Table B1: Decision-level Ablation

| Variant | Accuracy | Macro-F1 | MeanAbsClassError | TailRecall@24 | TailRecall@28 | TailRecall@31 |
|---|---:|---:|---:|---:|---:|---:|
| A0 Heuristic baseline | 0.2630 | 0.0463 | 6.4699 | 0.0000 | 0.0000 | 0.0000 |
| A1 Multiclass LightGBM | 0.2878 | 0.1553 | 4.9832 | 0.0515 | 0.0027 | 0.0000 |
| A2 Regression-quantization LightGBM | 0.2870 | 0.1574 | 4.9989 | 0.0568 | 0.0014 | 0.0000 |
| A3 Ordinal raw | 0.2891 | 0.1885 | 5.3242 | 0.1788 | 0.1555 | 0.0640 |
| A4 Ordinal + threshold tuning | 0.2843 | 0.1827 | 5.3531 | 0.1970 | 0.1252 | 0.0507 |
| A5 Final deployable ordinal | 0.2849 | 0.1833 | 5.3363 | 0.1946 | 0.1225 | 0.0510 |

## Table B2: Image-level Ablation (PSNR/SSIM)

| Dataset & Variant | sigma=10 | sigma=30 | sigma=50 |
|---|---|---|---|
| DAVIS - A0 Heuristic baseline | 24.6836/0.693881 | 20.8784/0.386716 | 17.9592/0.245859 |
| DAVIS - A1 Multiclass LightGBM | 27.3380/0.730547 | 21.1251/0.389974 | 17.8820/0.247592 |
| DAVIS - A2 Regression-quantization LightGBM | 27.3400/0.730538 | 21.1278/0.390057 | 17.8845/0.247547 |
| DAVIS - A3 Ordinal raw | 27.2634/0.728272 | 21.1034/0.388859 | 17.9404/0.247210 |
| DAVIS - A4 Ordinal + threshold tuning | 27.1415/0.727972 | 21.1455/0.389960 | 17.9845/0.247750 |
| DAVIS - A5 Final deployable ordinal | 27.1496/0.728023 | 21.1470/0.389964 | 17.9845/0.247740 |
| Set8 - A0 Heuristic baseline | 24.5509/0.707589 | 20.8188/0.409305 | 18.0239/0.269415 |
| Set8 - A1 Multiclass LightGBM | 26.9945/0.739401 | 21.3369/0.417520 | 18.1721/0.275070 |
| Set8 - A2 Regression-quantization LightGBM | 26.9998/0.739395 | 21.3412/0.417897 | 18.1767/0.275201 |
| Set8 - A3 Ordinal raw | 26.8915/0.735674 | 21.3086/0.415930 | 18.2209/0.274675 |
| Set8 - A4 Ordinal + threshold tuning | 26.7889/0.736003 | 21.3303/0.416885 | 18.2570/0.275206 |
| Set8 - A5 Final deployable ordinal | 26.8070/0.736227 | 21.3315/0.416587 | 18.2560/0.275097 |

## Output Files

- `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_ablation_paperB_run2\metrics_ablation_full.json`
- `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_ablation_paperB_run2\figures` (confusion matrices and error histograms for A3/A4/A5)