# Unified Variant Evaluation Notes

- Time: `2026-04-08T11:50:53`
- Output directory: `script\out_unified_variants`
- Command: `python -u .\script\09B_run_unified_variants.py --variant "all" --dataset "all" --sigma "all" --output_dir "script\out_unified_variants"`

## Protocol

- Variants: `['A0', 'A1', 'A2', 'A3', 'A4', 'A5_soft', 'A5_hw_eq']`
- Datasets: `['DAVIS', 'Set8']`
- Sigmas: `[10, 30, 50]`
- Seed: `123`
- Max frames per sequence: `12`
- Oracle source: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\oracle_lib.py`
- TDNR source: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\3dnr.py`
- Inherited protocol json: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_groupA_paperA_oraclefix\metrics_groupA_full.json`

## Key Inputs

- hw_prob_scale: `4096`
- model_dir_multiclass: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_train_multiclass`
- model_dir_ordinal: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_train_ord_v2_full`
- model_dir_reg: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_train_reg`
- multiclass_model_file: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_train_multiclass\models\lgbm_model_multiclass.txt`
- ordinal_model_dir: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_train_ord_v2_full`
- reg_model_file: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_train_reg\models\lgbm_model_reg.txt`
- tau_thresholds_T: `0,4,8,12,16,20,24,28`
- tau_tuned_json: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_ordinal_tune_v2_full\report\taus_monotone.json`

## Decision Summary

- A0 Heuristic baseline: acc=0.2633, macro_f1=0.0463, mae_cls=6.4652, tail24/28/31=0.0000/0.0000/0.0000
- A1 Multiclass LightGBM: acc=0.2879, macro_f1=0.1553, mae_cls=4.9815, tail24/28/31=0.0513/0.0027/0.0000
- A2 Regression-quantization LightGBM: acc=0.2871, macro_f1=0.1574, mae_cls=4.9973, tail24/28/31=0.0568/0.0014/0.0000
- A3 Ordinal raw: acc=0.2893, macro_f1=0.1886, mae_cls=5.3224, tail24/28/31=0.1787/0.1554/0.0644
- A4 Ordinal + threshold tuning: acc=0.2846, macro_f1=0.1828, mae_cls=5.3504, tail24/28/31=0.1967/0.1253/0.0503
- A5_soft Software deployable mapping: acc=0.2851, macro_f1=0.1835, mae_cls=5.3338, tail24/28/31=0.1943/0.1224/0.0522
- A5_hw_eq Exported hardware-equivalent mapping: acc=0.2851, macro_f1=0.1836, mae_cls=5.3345, tail24/28/31=0.1945/0.1231/0.0525

## Files

- `script\out_unified_variants\metrics.json`
- `script\out_unified_variants\config.json`
- `script\out_unified_variants\summary.csv`
- `script\out_unified_variants\notes.md`
