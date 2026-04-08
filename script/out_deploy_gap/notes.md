# Deploy Gap Notes

- Time: `2026-04-08T12:11:19`
- Output directory: `script\out_deploy_gap`
- Command: `python -u .\script\09C_eval_deploy_gap.py --dataset "all" --sigma "all" --output_dir "script\out_deploy_gap"`

## Compared Pairs

- `A4_vs_A5_soft` (A4 -> A5_soft)
- `A5_soft_vs_A5_hw_eq` (A5_soft -> A5_hw_eq)

## Protocol

- Datasets: `['DAVIS', 'Set8']`
- Sigmas: `[10, 30, 50]`
- Seed: `123`
- Max frames per sequence: `12`
- Oracle source: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\oracle_lib.py`
- TDNR source: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\3dnr.py`
- Inherited protocol json: `F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_groupA_paperA_oraclefix\metrics_groupA_full.json`

## Files

- `script\out_deploy_gap\deploy_gap.json`
- `script\out_deploy_gap\deploy_gap_summary.csv`
- `script\out_deploy_gap\config.json`
- `script\out_deploy_gap\notes.md`
