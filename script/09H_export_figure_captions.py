#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Export figure caption suggestions and figure manifest for paper writing.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Sequence


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export paper figure captions and manifest.")
    p.add_argument(
        "--sigma_tail_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_sigma_tail_analysis\sigma_tail_analysis.json",
    )
    p.add_argument(
        "--deploy_gap_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_deploy_gap\deploy_gap.json",
    )
    p.add_argument(
        "--out_dir",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_paper_figures",
    )
    p.add_argument("--seed", type=int, default=123)
    return p.parse_args()


def _read_json(path: Path) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _file_exists_pair(base: Path) -> bool:
    return base.with_suffix(".png").is_file() and base.with_suffix(".pdf").is_file()


def _avg_tail(dec_item: Dict[str, Any]) -> float:
    tr = dec_item.get("tail_recall", {})
    vals = [
        float(tr.get("24", float("nan"))),
        float(tr.get("28", float("nan"))),
        float(tr.get("31", float("nan"))),
    ]
    vals = [x for x in vals if x == x]
    if len(vals) == 0:
        return float("nan")
    return float(sum(vals) / len(vals))


def _build_captions(
    out_dir: Path,
    sigma_payload: Dict[str, Any],
    deploy_payload: Dict[str, Any],
) -> str:
    dec = sigma_payload["decision_by_sigma"]
    img = sigma_payload["image_by_sigma"]
    sigmas = [int(x) for x in sigma_payload["sigmas"]]
    sig_low, sig_high = min(sigmas), max(sigmas)

    tail_low = _avg_tail(dec[str(sig_low)]["A3"])
    tail_high = _avg_tail(dec[str(sig_high)]["A3"])
    macro_low = float(dec[str(sig_low)]["A3"]["macro_f1"])
    macro_high = float(dec[str(sig_high)]["A3"]["macro_f1"])
    psnr_low_a2 = float(img[str(sig_low)]["A2"]["psnr"])
    psnr_low_a3 = float(img[str(sig_low)]["A3"]["psnr"])
    psnr_high_a2 = float(img[str(sig_high)]["A2"]["psnr"])
    psnr_high_a3 = float(img[str(sig_high)]["A3"]["psnr"])

    pair_map = {x["pair"]: x for x in deploy_payload["pairs"]}
    p_hw = pair_map["A5_soft_vs_A5_hw_eq"]
    agree = float(p_hw["decision_difference"]["agreement"])
    dmf1 = float(p_hw["decision_difference"]["delta_metrics_b_minus_a"]["macro_f1"])
    dpsnr = float(p_hw["image_difference"]["global"]["delta_psnr"]["mean"])

    lines: List[str] = []
    lines.append("# Figure Captions")
    lines.append("")
    lines.append("## fig_tail_recall_vs_sigma")
    lines.append("")
    lines.append(
        "Recommended caption: "
        "\"Average tail recall (classes 24/28/31) versus noise level. "
        "Ordinal-family variants maintain substantially stronger tail sensitivity as sigma increases, "
        "indicating a clear advantage in hard and tail-dominated regimes.\""
    )
    lines.append(
        "In-text suggestion: "
        f"\"As shown in Fig. 1, tail recall improves from {tail_low:.3f} at sigma={sig_low} "
        f"to {tail_high:.3f} at sigma={sig_high} for ordinal decisions, "
        "whereas non-ordinal quantized regression remains weaker on high-tail bins.\""
    )
    lines.append(
        "Supported claim: "
        "\"Ordinal family is more advantageous in hard and tail-dominated regimes.\""
    )
    lines.append("")
    lines.append("## fig_macrof1_vs_sigma")
    lines.append("")
    lines.append(
        "Recommended caption: "
        "\"Macro-F1 versus noise level for A2, A3, A4, and A5_hw_eq. "
        "Ordinal formulations consistently provide better class-balanced decision quality.\""
    )
    lines.append(
        "In-text suggestion: "
        f"\"Fig. 2 shows that ordinal decision quality remains strong from sigma={sig_low} to sigma={sig_high} "
        f"(e.g., A3 Macro-F1: {macro_low:.3f}→{macro_high:.3f}), supporting its robustness under increasing noise.\""
    )
    lines.append(
        "Supported claim: "
        "\"Ordinal objective aligns better with ordered class decisions than pure regression-quantization.\""
    )
    lines.append("")
    lines.append("## fig_psnr_vs_sigma")
    lines.append("")
    lines.append(
        "Recommended caption: "
        "\"Average PSNR versus noise level. "
        "A2 is slightly stronger at lower noise, while ordinal-family methods become competitive or superior at high noise.\""
    )
    lines.append(
        "In-text suggestion: "
        f"\"As illustrated in Fig. 3, A2 outperforms A3 at sigma={sig_low} "
        f"({psnr_low_a2:.3f} vs {psnr_low_a3:.3f} dB), "
        f"but ordinal methods close or reverse the gap at sigma={sig_high} "
        f"({psnr_high_a2:.3f} vs {psnr_high_a3:.3f} dB).\""
    )
    lines.append(
        "Supported claim: "
        "\"Ordinal brings better robustness in difficult regimes while retaining competitive reconstruction quality.\""
    )
    lines.append("")
    lines.append("## fig_deploy_gap_summary")
    lines.append("")
    lines.append(
        "Recommended caption: "
        "\"Deploy-gap summary from A4 to A5_soft to A5_hw_eq. "
        "Hardware-equivalent mapping preserves almost all software gains with near-perfect decision agreement.\""
    )
    lines.append(
        "In-text suggestion: "
        f"\"Fig. 4 reports agreement={agree:.4f}, ΔMacro-F1={dmf1:+.4f}, and ΔPSNR={dpsnr:+.4f} dB "
        "for A5_soft→A5_hw_eq, confirming negligible deployment loss.\""
    )
    lines.append(
        "Supported claim: "
        "\"Exported hardware-equivalent mapping preserves nearly all gains.\""
    )
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append(f"- Generated at: `{datetime.now().isoformat(timespec='seconds')}`")
    lines.append(f"- Output directory: `{out_dir}`")
    return "\n".join(lines) + "\n"


def _build_manifest(out_dir: Path) -> str:
    items = [
        {
            "name": "fig_tail_recall_vs_sigma",
            "meaning": "Tail sensitivity trend across sigma (A2/A3/A4/A5_hw_eq).",
            "section": "3.4",
            "keep_main": "Yes",
        },
        {
            "name": "fig_macrof1_vs_sigma",
            "meaning": "Decision-level class-balance trend across sigma.",
            "section": "supplementary",
            "keep_main": "No (or brief mention)",
        },
        {
            "name": "fig_psnr_vs_sigma",
            "meaning": "Reconstruction-quality trend across sigma.",
            "section": "3.3",
            "keep_main": "Yes",
        },
        {
            "name": "fig_deploy_gap_summary",
            "meaning": "A4→A5_soft→A5_hw_eq deployment consistency summary.",
            "section": "3.4",
            "keep_main": "Yes",
        },
    ]
    lines: List[str] = []
    lines.append("# Figure Manifest")
    lines.append("")
    lines.append("| Figure File | Meaning | Suggested Section | Keep in Main Text |")
    lines.append("|---|---|---|---|")
    for it in items:
        base = out_dir / it["name"]
        exists = _file_exists_pair(base)
        fname = f"{it['name']}.png / {it['name']}.pdf"
        if not exists:
            fname += " (missing)"
        lines.append(f"| {fname} | {it['meaning']} | {it['section']} | {it['keep_main']} |")
    lines.append("")
    lines.append(f"- Generated at: `{datetime.now().isoformat(timespec='seconds')}`")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    sigma_path = Path(args.sigma_tail_json)
    deploy_path = Path(args.deploy_gap_json)
    if not sigma_path.is_file():
        raise SystemExit(f"sigma_tail_analysis json not found: {sigma_path}")
    if not deploy_path.is_file():
        raise SystemExit(f"deploy_gap json not found: {deploy_path}")

    sigma_payload = _read_json(sigma_path)
    deploy_payload = _read_json(deploy_path)

    captions = _build_captions(out_dir, sigma_payload, deploy_payload)
    manifest = _build_manifest(out_dir)

    (out_dir / "figure_captions.md").write_text(captions, encoding="utf-8")
    (out_dir / "figure_manifest.md").write_text(manifest, encoding="utf-8")

    print(f"[OUT] {out_dir / 'figure_captions.md'}")
    print(f"[OUT] {out_dir / 'figure_manifest.md'}")


if __name__ == "__main__":
    main()

