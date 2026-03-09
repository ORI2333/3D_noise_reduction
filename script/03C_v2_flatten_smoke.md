# 03C_v2_flatten_smoke 使用说明

## 目的
将 `oracle_v2_smoke_out/*.npz` 扁平化为训练 shard（带 `info`），便于直接复用 `04_1/04_2/04_2.5`。

## 命令示例（PowerShell）
```powershell
python .\03C_v2_flatten_smoke.py `
  --oracle_dir .\oracle_v2_smoke_out `
  --out_dir .\train_oracle_dataset_v2_smoke_info `
  --shard_size 2000000 `
  --mb_h 80 --mb_w 120 `
  --frame_idx_mode zero
```

## 输出 shard 字段
- `X`: `float32`, `(N,F)`
- `y`: `uint8`, `(N,)`
- `feature_names`: unicode, `(F,)`
- `w_set`: `uint8`, `(9,)`
- `files`: unicode, `(num_clips,)`
- `meta`: unicode json
- `info`: `int32`, `(N,4)`，schema `[clip_id, br, bc, frame_idx]`

