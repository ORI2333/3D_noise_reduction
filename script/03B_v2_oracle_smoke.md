# 03B_v2_oracle_smoke 使用说明

## 目的
从 Script02 的 noisy clip 中抽样少量文件，生成 V2 per-clip oracle：
- 输出文件名：`<clip_stem>_oracle_v2.npz`
- 关键字段：`features`、`w_label`、`feature_names`

## 命令示例（PowerShell）
```powershell
python .\03B_v2_oracle_smoke.py `
  --noisy_dir .\davis_clips_noisy_npz `
  --out_dir .\oracle_v2_smoke_out `
  --max_files 20 `
  --seed 123 `
  --save_png false
```

## 输出契约
- `features`: `float32`, `(80,120,Fv2)`，当前 `Fv2=8`
- `w_label`: `uint8`, `(80,120)`
- `feature_names`: unicode, `(8,)`
- `w_set`: `uint8`, `(9,)`
- `clip_name` / `frame_idx` / `meta`

