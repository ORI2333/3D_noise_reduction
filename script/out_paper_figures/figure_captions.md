# Figure Captions

## fig_tail_recall_vs_sigma

Recommended caption: "Average tail recall (classes 24/28/31) versus noise level. Ordinal-family variants maintain substantially stronger tail sensitivity as sigma increases, indicating a clear advantage in hard and tail-dominated regimes."
In-text suggestion: "As shown in Fig. 1, tail recall improves from 0.045 at sigma=10 to 0.144 at sigma=50 for ordinal decisions, whereas non-ordinal quantized regression remains weaker on high-tail bins."
Supported claim: "Ordinal family is more advantageous in hard and tail-dominated regimes."

## fig_macrof1_vs_sigma

Recommended caption: "Macro-F1 versus noise level for A2, A3, A4, and A5_hw_eq. Ordinal formulations consistently provide better class-balanced decision quality."
In-text suggestion: "Fig. 2 shows that ordinal decision quality remains strong from sigma=10 to sigma=50 (e.g., A3 Macro-F1: 0.144→0.192), supporting its robustness under increasing noise."
Supported claim: "Ordinal objective aligns better with ordered class decisions than pure regression-quantization."

## fig_psnr_vs_sigma

Recommended caption: "Average PSNR versus noise level. A2 is slightly stronger at lower noise, while ordinal-family methods become competitive or superior at high noise."
In-text suggestion: "As illustrated in Fig. 3, A2 outperforms A3 at sigma=10 (27.098 vs 26.999 dB), but ordinal methods close or reverse the gap at sigma=50 (18.098 vs 18.145 dB)."
Supported claim: "Ordinal brings better robustness in difficult regimes while retaining competitive reconstruction quality."

## fig_deploy_gap_summary

Recommended caption: "Deploy-gap summary from A4 to A5_soft to A5_hw_eq. Hardware-equivalent mapping preserves almost all software gains with near-perfect decision agreement."
In-text suggestion: "Fig. 4 reports agreement=0.9990, ΔMacro-F1=+0.0001, and ΔPSNR=-0.0001 dB for A5_soft→A5_hw_eq, confirming negligible deployment loss."
Supported claim: "Exported hardware-equivalent mapping preserves nearly all gains."

## Notes

- Generated at: `2026-04-08T17:26:54`
- Output directory: `script\out_paper_figures`
