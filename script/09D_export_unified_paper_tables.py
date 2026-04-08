#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Export paper-ready tables from unified metrics + deploy gap outputs.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Tuple

from unified_eval_core import VARIANT_DISPLAY, VARIANT_ORDER


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export unified paper tables.")
    p.add_argument(
        "--unified_metrics",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_unified_variants\metrics.json",
    )
    p.add_argument(
        "--deploy_gap_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_deploy_gap\deploy_gap.json",
    )
    p.add_argument(
        "--out_dir",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_paper_tables",
    )
    return p.parse_args()


def _f4(x: float) -> str:
    return f"{float(x):.4f}"


def _f6(x: float) -> str:
    return f"{float(x):.6f}"


def _load_json(path: Path) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _table_unified_decision_tex(payload: Dict[str, Any], variants: List[str]) -> str:
    dec = payload["decision_metrics"]
    lines: List[str] = []
    lines.append(r"\begin{table}[t]")
    lines.append(r"\centering")
    lines.append(r"\caption{Unified decision-level comparison for A0--A5 variants.}")
    lines.append(r"\label{tab:unified_decision}")
    lines.append(r"\setlength{\tabcolsep}{4pt}")
    lines.append(r"\begin{tabular}{lcccccc}")
    lines.append(r"\toprule")
    lines.append(r"Variant & Accuracy & Macro-F1 & MeanAbsClassError & TailRecall@24 & TailRecall@28 & TailRecall@31 \\")
    lines.append(r"\midrule")
    for v in variants:
        d = dec[v]
        tr = d.get("tail_recall", {})
        lines.append(
            " & ".join(
                [
                    VARIANT_DISPLAY.get(v, v),
                    _f4(d["accuracy"]),
                    _f4(d["macro_f1"]),
                    _f4(d["mean_abs_class_error"]),
                    _f4(tr.get("24", float("nan"))),
                    _f4(tr.get("28", float("nan"))),
                    _f4(tr.get("31", float("nan"))),
                ]
            )
            + r" \\"
        )
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")
    return "\n".join(lines) + "\n"


def _table_unified_image_tex(payload: Dict[str, Any], variants: List[str], sigmas: List[int], datasets: List[str]) -> str:
    results = payload["results"]
    lines: List[str] = []
    lines.append(r"\begin{table*}[t]")
    lines.append(r"\centering")
    lines.append(r"\caption{Unified image-level comparison (PSNR/SSIM).}")
    lines.append(r"\label{tab:unified_image}")
    lines.append(r"\setlength{\tabcolsep}{4pt}")
    col_spec = "ll" + ("c" * len(sigmas))
    lines.append(r"\begin{tabular}{" + col_spec + "}")
    lines.append(r"\toprule")
    sigma_head = " & ".join([rf"$\sigma={int(s)}$" for s in sigmas])
    lines.append(rf"Dataset & Variant & {sigma_head} \\")
    lines.append(r"\midrule")
    for ds in datasets:
        first = True
        for v in variants:
            cells = []
            for s in sigmas:
                item = results[ds][f"sigma_{int(s)}"]["dataset_mean"][v]
                cells.append(f"{_f4(item['psnr']['mean'])}/{_f6(item['ssim']['mean'])}")
            if first:
                lines.append(
                    rf"\multirow{{{len(variants)}}}{{*}}{{{ds}}} & "
                    + VARIANT_DISPLAY.get(v, v)
                    + " & "
                    + " & ".join(cells)
                    + r" \\"
                )
                first = False
            else:
                lines.append(" & " + VARIANT_DISPLAY.get(v, v) + " & " + " & ".join(cells) + r" \\")
        lines.append(r"\midrule")
    if lines[-1] == r"\midrule":
        lines.pop()
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table*}")
    return "\n".join(lines) + "\n"


def _table_deploy_gap_tex(deploy_payload: Dict[str, Any]) -> str:
    lines: List[str] = []
    lines.append(r"\begin{table}[t]")
    lines.append(r"\centering")
    lines.append(r"\caption{Deploy gap analysis between adjacent deploy stages.}")
    lines.append(r"\label{tab:deploy_gap}")
    lines.append(r"\setlength{\tabcolsep}{4pt}")
    lines.append(r"\begin{tabular}{lccccc}")
    lines.append(r"\toprule")
    lines.append(r"Pair & Agreement & Pair-MAE & $\Delta$Macro-F1 & $\Delta$Tail@24 & $\Delta$PSNR \\")
    lines.append(r"\midrule")
    for p in deploy_payload["pairs"]:
        dd = p["decision_difference"]
        dm = dd["delta_metrics_b_minus_a"]
        tail24 = dm["tail_recall"]["24"]
        dpsnr = p["image_difference"]["global"]["delta_psnr"]["mean"]
        lines.append(
            " & ".join(
                [
                    p["pair"],
                    _f4(dd["agreement"]),
                    _f4(dd["mean_abs_class_error_pair"]),
                    _f4(dm["macro_f1"]),
                    _f4(tail24),
                    _f4(dpsnr),
                ]
            )
            + r" \\"
        )
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")
    return "\n".join(lines) + "\n"


def _best_decision_variant(payload: Dict[str, Any], variants: List[str]) -> Tuple[str, float]:
    dec = payload["decision_metrics"]
    best = max(variants, key=lambda v: float(dec[v]["macro_f1"]))
    return best, float(dec[best]["macro_f1"])


def _best_image_variant(payload: Dict[str, Any], variants: List[str], datasets: List[str], sigmas: List[int]) -> Tuple[str, float]:
    results = payload["results"]
    score: Dict[str, List[float]] = {v: [] for v in variants}
    for ds in datasets:
        for s in sigmas:
            item = results[ds][f"sigma_{int(s)}"]["dataset_mean"]
            for v in variants:
                score[v].append(float(item[v]["psnr"]["mean"]))
    avg_psnr = {v: (sum(vals) / max(len(vals), 1)) for v, vals in score.items()}
    best = max(variants, key=lambda v: avg_psnr[v])
    return best, float(avg_psnr[best])


def _assess_deploy_gap(deploy_payload: Dict[str, Any]) -> Tuple[bool, Dict[str, float]]:
    target = None
    for p in deploy_payload["pairs"]:
        if p["pair"] == "A5_soft_vs_A5_hw_eq":
            target = p
            break
    if target is None:
        return False, {"agreement": float("nan"), "delta_macro_f1": float("nan"), "delta_psnr": float("nan")}
    dd = target["decision_difference"]
    dm = dd["delta_metrics_b_minus_a"]
    dpsnr = float(target["image_difference"]["global"]["delta_psnr"]["mean"])
    info = {
        "agreement": float(dd["agreement"]),
        "delta_macro_f1": float(dm["macro_f1"]),
        "delta_psnr": dpsnr,
    }
    ok = (
        info["agreement"] >= 0.99
        and abs(info["delta_macro_f1"]) <= 0.005
        and abs(info["delta_psnr"]) <= 0.05
    )
    return ok, info


def _build_result_summary_md(
    unified_payload: Dict[str, Any],
    deploy_payload: Dict[str, Any],
    variants: List[str],
    datasets: List[str],
    sigmas: List[int],
) -> str:
    best_dec_v, best_dec_val = _best_decision_variant(unified_payload, variants)
    best_img_v, best_img_val = _best_image_variant(unified_payload, variants, datasets, sigmas)
    deploy_ok, deploy_info = _assess_deploy_gap(deploy_payload)

    lines: List[str] = []
    lines.append("# Result Summary")
    lines.append("")
    lines.append("## Unified Best")
    lines.append("")
    lines.append(
        f"- Decision-level best (Macro-F1): `{VARIANT_DISPLAY.get(best_dec_v, best_dec_v)}` ({best_dec_val:.4f})"
    )
    lines.append(
        f"- Image-level best (average PSNR over selected datasets/sigmas): "
        f"`{VARIANT_DISPLAY.get(best_img_v, best_img_v)}` ({best_img_val:.4f} dB)"
    )
    lines.append("")
    lines.append("## Deploy Gap")
    lines.append("")
    lines.append(
        f"- A5_soft vs A5_hw_eq agreement: `{deploy_info['agreement']:.4f}`"
    )
    lines.append(
        f"- A5_hw_eq - A5_soft delta Macro-F1: `{deploy_info['delta_macro_f1']:+.4f}`"
    )
    lines.append(
        f"- A5_hw_eq - A5_soft delta PSNR: `{deploy_info['delta_psnr']:+.4f}` dB"
    )
    lines.append(
        f"- Deploy gap negligible: `{'yes' if deploy_ok else 'no'}`"
    )
    lines.append("")
    lines.append("## Claim Check")
    lines.append("")
    claim = "supported" if deploy_ok else "not fully supported"
    lines.append(
        f"- Claim `exported hardware-equivalent mapping preserves nearly all gains`: `{claim}`"
    )
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    unified_path = Path(args.unified_metrics)
    deploy_path = Path(args.deploy_gap_json)
    if not unified_path.is_file():
        raise SystemExit(f"unified metrics not found: {unified_path}")
    if not deploy_path.is_file():
        raise SystemExit(f"deploy gap json not found: {deploy_path}")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    unified_payload = _load_json(unified_path)
    deploy_payload = _load_json(deploy_path)

    cfg = unified_payload["config"]
    variants = [v for v in VARIANT_ORDER if v in cfg["variants"]]
    datasets = [str(x) for x in cfg["datasets"]]
    sigmas = [int(x) for x in cfg["sigmas"]]

    tex_dec = _table_unified_decision_tex(unified_payload, variants)
    tex_img = _table_unified_image_tex(unified_payload, variants, sigmas, datasets)
    tex_gap = _table_deploy_gap_tex(deploy_payload)
    md_sum = _build_result_summary_md(unified_payload, deploy_payload, variants, datasets, sigmas)

    (out_dir / "table_unified_decision.tex").write_text(tex_dec, encoding="utf-8")
    (out_dir / "table_unified_image.tex").write_text(tex_img, encoding="utf-8")
    (out_dir / "table_deploy_gap.tex").write_text(tex_gap, encoding="utf-8")
    (out_dir / "result_summary.md").write_text(md_sum, encoding="utf-8")

    print(f"[OUT] {out_dir / 'table_unified_decision.tex'}")
    print(f"[OUT] {out_dir / 'table_unified_image.tex'}")
    print(f"[OUT] {out_dir / 'table_deploy_gap.tex'}")
    print(f"[OUT] {out_dir / 'result_summary.md'}")


if __name__ == "__main__":
    main()

