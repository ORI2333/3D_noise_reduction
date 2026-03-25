#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Export Paper-B ablation tables and analysis draft from 09B metrics JSON.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List


METHODS = [
    "baseline",
    "multiclass",
    "reg_nearest",
    "ordinal_raw",
    "ordinal_tuned",
    "ordinal_deploy",
]

DISPLAY = {
    "baseline": "A0 Heuristic baseline",
    "multiclass": "A1 Multiclass LightGBM",
    "reg_nearest": "A2 Regression-quantization LightGBM",
    "ordinal_raw": "A3 Ordinal raw",
    "ordinal_tuned": "A4 Ordinal + threshold tuning",
    "ordinal_deploy": "A5 Final deployable ordinal",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export Paper-B ablation tables and analysis draft.")
    p.add_argument(
        "--metrics_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_ablation_paperB\metrics_ablation_full.json",
    )
    p.add_argument("--out_dir", type=str, default="")
    return p.parse_args()


def f4(x: float) -> str:
    return f"{float(x):.4f}"


def f6(x: float) -> str:
    return f"{float(x):.6f}"


def build_b1_tex(dec: Dict[str, Dict]) -> str:
    lines: List[str] = []
    lines.append(r"\begin{table}[t]")
    lines.append(r"\centering")
    lines.append(r"\caption{Table B1. Decision-level ablation under unified evaluation protocol.}")
    lines.append(r"\label{tab:b1_ablation_decision}")
    lines.append(r"\setlength{\tabcolsep}{4pt}")
    lines.append(r"\begin{tabular}{lcccccc}")
    lines.append(r"\toprule")
    lines.append(
        r"Variant & Accuracy & Macro-F1 & MeanAbsClassError & TailRecall@24 & TailRecall@28 & TailRecall@31 \\"
    )
    lines.append(r"\midrule")
    for m in METHODS:
        met = dec[m]
        tr = met.get("tail_recall", {})
        lines.append(
            " & ".join(
                [
                    DISPLAY[m],
                    f4(met["accuracy"]),
                    f4(met["macro_f1"]),
                    f4(met["mean_abs_class_error"]),
                    f4(tr.get("24", float("nan"))),
                    f4(tr.get("28", float("nan"))),
                    f4(tr.get("31", float("nan"))),
                ]
            )
            + r" \\"
        )
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")
    return "\n".join(lines) + "\n"


def build_b2_tex(results: Dict, sigmas: List[int]) -> str:
    lines: List[str] = []
    lines.append(r"\begin{table*}[t]")
    lines.append(r"\centering")
    lines.append(r"\caption{Table B2. Image-level ablation on DAVIS and Set8 (PSNR/SSIM).}")
    lines.append(r"\label{tab:b2_ablation_image}")
    lines.append(r"\setlength{\tabcolsep}{4pt}")
    lines.append(r"\begin{tabular}{llccc}")
    lines.append(r"\toprule")
    lines.append(r"Dataset & Variant & $\sigma=10$ & $\sigma=30$ & $\sigma=50$ \\")
    lines.append(r"\midrule")
    for ds in ["DAVIS", "Set8"]:
        first = True
        for m in METHODS:
            cells = []
            for s in sigmas:
                k = f"sigma_{s}"
                item = results[ds][k]["dataset_mean"][m]
                cells.append(f"{f4(item['psnr']['mean'])}/{f6(item['ssim']['mean'])}")
            if first:
                lines.append(
                    r"\multirow{"
                    + str(len(METHODS))
                    + r"}{*}{"
                    + ds
                    + r"} & "
                    + DISPLAY[m]
                    + " & "
                    + " & ".join(cells)
                    + r" \\"
                )
                first = False
            else:
                lines.append(" & " + DISPLAY[m] + " & " + " & ".join(cells) + r" \\")
        lines.append(r"\midrule")
    if lines[-1] == r"\midrule":
        lines.pop()
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table*}")
    return "\n".join(lines) + "\n"


def build_analysis_draft(dec: Dict[str, Dict], results: Dict, sigmas: List[int]) -> str:
    a0 = dec["baseline"]
    a1 = dec["multiclass"]
    a2 = dec["reg_nearest"]
    a3 = dec["ordinal_raw"]
    a4 = dec["ordinal_tuned"]
    a5 = dec["ordinal_deploy"]

    def delta(x: float, y: float) -> str:
        return f"{(x - y):+.4f}"

    # PSNR deltas for A5 vs A4 by dataset/sigma
    deploy_deltas = []
    for ds in ["DAVIS", "Set8"]:
        for s in sigmas:
            k = f"sigma_{s}"
            p4 = float(results[ds][k]["dataset_mean"]["ordinal_tuned"]["psnr"]["mean"])
            p5 = float(results[ds][k]["dataset_mean"]["ordinal_deploy"]["psnr"]["mean"])
            deploy_deltas.append((ds, s, p5 - p4))

    max_abs_deploy = max(abs(x[2]) for x in deploy_deltas) if deploy_deltas else float("nan")

    lines: List[str] = []
    lines.append("### Ablation Result Analysis Draft")
    lines.append("")
    lines.append(
        "The heuristic-rule variant is inadequate under the unified protocol, while all learned decision variants consistently improve structured decision quality and image-level fidelity."
    )
    lines.append(
        f"Relative to A0, A1 and A2 improve Macro-F1 by {delta(a1['macro_f1'], a0['macro_f1'])} and {delta(a2['macro_f1'], a0['macro_f1'])}, confirming that learned decision replacing heuristic rules is effective."
    )
    lines.append(
        f"A3 further improves Macro-F1 to {f4(a3['macro_f1'])}, exceeding A1 and A2 by {delta(a3['macro_f1'], a1['macro_f1'])} and {delta(a3['macro_f1'], a2['macro_f1'])}, which supports that ordinal reformulation is better matched to the discrete ordered weight space."
    )
    lines.append(
        f"A4 mainly shifts decision boundaries toward difficult tail-sensitive categories; TailRecall@24/28/31 change from {f4(a3['tail_recall'].get('24', float('nan')))}/{f4(a3['tail_recall'].get('28', float('nan')))}/{f4(a3['tail_recall'].get('31', float('nan')))} to {f4(a4['tail_recall'].get('24', float('nan')))}/{f4(a4['tail_recall'].get('28', float('nan')))}/{f4(a4['tail_recall'].get('31', float('nan')))} while global accuracy changes from {f4(a3['accuracy'])} to {f4(a4['accuracy'])}."
    )
    lines.append(
        f"A5 introduces deployment-oriented monotonic projection at inference/export stage. Compared with A4, Macro-F1 changes from {f4(a4['macro_f1'])} to {f4(a5['macro_f1'])}, and the maximum absolute PSNR change across DAVIS and Set8 at sigma=10/30/50 is {max_abs_deploy:.4f} dB."
    )
    if max_abs_deploy <= 0.05:
        lines.append(
            "These results indicate that deployment-oriented mapping introduces negligible degradation while restoring hardware-consistent monotonicity."
        )
    else:
        lines.append(
            "These results indicate a limited but measurable deployment gap, which should be interpreted as the cost of enforcing hardware-consistent monotonicity."
        )
    lines.append("")

    lines.append("#### A5 vs A4 PSNR delta (dB)")
    lines.append("")
    for ds, s, d in deploy_deltas:
        lines.append(f"- {ds} sigma={s}: {d:+.4f} dB")
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    metrics_path = Path(args.metrics_json)
    if not metrics_path.is_file():
        raise SystemExit(f"metrics json not found: {metrics_path}")
    out_dir = Path(args.out_dir) if args.out_dir else metrics_path.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    payload = json.loads(metrics_path.read_text(encoding="utf-8"))
    sigmas = [10, 30, 50]

    b1_tex = build_b1_tex(payload["decision_metrics"])
    b2_tex = build_b2_tex(payload["results"], sigmas)
    draft = build_analysis_draft(payload["decision_metrics"], payload["results"], sigmas)

    (out_dir / "table_B1_ablation_decision.tex").write_text(b1_tex, encoding="utf-8")
    (out_dir / "table_B2_ablation_image.tex").write_text(b2_tex, encoding="utf-8")
    (out_dir / "ablation_result_analysis_draft.md").write_text(draft, encoding="utf-8")

    print(f"[OUT] {out_dir / 'table_B1_ablation_decision.tex'}")
    print(f"[OUT] {out_dir / 'table_B2_ablation_image.tex'}")
    print(f"[OUT] {out_dir / 'ablation_result_analysis_draft.md'}")


if __name__ == "__main__":
    main()

