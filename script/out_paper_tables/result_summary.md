# Result Summary

## Unified Best

- Decision-level best (Macro-F1): `A3 Ordinal raw` (0.1886)
- Image-level best (average PSNR over selected datasets/sigmas): `A2 Regression-quantization LightGBM` (22.1502 dB)

## Deploy Gap

- A5_soft vs A5_hw_eq agreement: `0.9990`
- A5_hw_eq - A5_soft delta Macro-F1: `+0.0001`
- A5_hw_eq - A5_soft delta PSNR: `-0.0001` dB
- Deploy gap negligible: `yes`

## Claim Check

- Claim `exported hardware-equivalent mapping preserves nearly all gains`: `supported`

