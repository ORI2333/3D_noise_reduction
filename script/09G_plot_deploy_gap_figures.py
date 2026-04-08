#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Plot deploy-gap paper figure from deploy_gap.json.
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Sequence

import matplotlib.pyplot as plt
import numpy as np
from PIL import Image


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Plot deploy-gap summary figure for paper usage.")
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
    p.add_argument("--dpi", type=int, default=300)
    p.add_argument(
        "--export_split",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Also export split-view figures (delta-only and agreement-only).",
    )
    return p.parse_args()


def _read_json(path: Path) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _write_notes(path: Path, lines: Sequence[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def _set_style() -> None:
    plt.rcParams.update(
        {
            "font.family": "serif",
            "font.size": 11,
            "axes.labelsize": 12,
            "axes.titlesize": 12,
            "legend.fontsize": 10,
            "xtick.labelsize": 10,
            "ytick.labelsize": 10,
            "axes.linewidth": 1.0,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
            "savefig.bbox": "tight",
        }
    )


def _save_csv(path: Path, payload: Dict[str, Dict[str, float]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        fields = ["transition", "delta_macro_f1", "delta_psnr", "decision_agreement"]
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for k in payload:
            r = payload[k]
            w.writerow(
                {
                    "transition": k,
                    "delta_macro_f1": f"{float(r['delta_macro_f1']):.8f}",
                    "delta_psnr": f"{float(r['delta_psnr']):.8f}",
                    "decision_agreement": f"{float(r['decision_agreement']):.8f}",
                }
            )


def _save_png_then_pdf(fig: plt.Figure, out_base: Path) -> None:
    """
    Save PDF from PNG bytes to guarantee PDF visual consistency with PNG.
    """
    png_path = out_base.with_suffix(".png")
    pdf_path = out_base.with_suffix(".pdf")
    fig.savefig(png_path)
    with Image.open(png_path) as im:
        rgb = im.convert("RGB")
        rgb.save(pdf_path, "PDF", resolution=300.0)


def main() -> None:
    args = parse_args()
    np.random.seed(int(args.seed))
    _set_style()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    notes_path = out_dir / "notes.md"
    notes_lines = [
        "## 09G Plot Deploy Gap Figures",
        f"- Time: `{datetime.now().isoformat(timespec='seconds')}`",
        f"- Seed: `{int(args.seed)}`",
        f"- Input deploy-gap: `{Path(args.deploy_gap_json)}`",
    ]

    deploy_path = Path(args.deploy_gap_json)
    if not deploy_path.is_file():
        notes_lines.append("- ERROR: deploy_gap.json not found; skip figure generation.")
        _write_notes(notes_path, notes_lines)
        raise SystemExit(f"deploy gap json not found: {deploy_path}")
    payload = _read_json(deploy_path)

    pair_map = {x["pair"]: x for x in payload.get("pairs", [])}
    need_pairs = ["A4_vs_A5_soft", "A5_soft_vs_A5_hw_eq"]
    for p in need_pairs:
        if p not in pair_map:
            notes_lines.append(f"- ERROR: pair missing in deploy_gap.json: `{p}`.")
            _write_notes(notes_path, notes_lines)
            raise SystemExit(f"pair missing in deploy_gap.json: {p}")

    transition_data: Dict[str, Dict[str, float]] = {}
    for p in need_pairs:
        item = pair_map[p]
        dd = item["decision_difference"]
        dm = dd["delta_metrics_b_minus_a"]
        transition_data[p] = {
            "delta_macro_f1": float(dm["macro_f1"]),
            "delta_psnr": float(item["image_difference"]["global"]["delta_psnr"]["mean"]),
            "decision_agreement": float(dd["agreement"]),
        }

    labels = ["A4→A5_soft", "A5_soft→A5_hw"]
    x = np.arange(len(labels))
    w = 0.28
    y_f1 = [transition_data["A4_vs_A5_soft"]["delta_macro_f1"], transition_data["A5_soft_vs_A5_hw_eq"]["delta_macro_f1"]]
    y_ps = [transition_data["A4_vs_A5_soft"]["delta_psnr"], transition_data["A5_soft_vs_A5_hw_eq"]["delta_psnr"]]
    y_ag = [transition_data["A4_vs_A5_soft"]["decision_agreement"], transition_data["A5_soft_vs_A5_hw_eq"]["decision_agreement"]]

    fig = plt.figure(figsize=(5.8, 3.7), dpi=args.dpi)
    ax1 = fig.add_subplot(111)
    b1 = ax1.bar(x - w / 2, y_f1, width=w, color="#1f77b4", label="ΔMacro-F1", zorder=3)
    b2 = ax1.bar(x + w / 2, y_ps, width=w, color="#ff7f0e", label="ΔPSNR (dB)", zorder=3)
    ax1.axhline(0.0, color="black", linewidth=0.8)
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels)
    ax1.set_ylabel("Delta Value")
    ax1.grid(True, axis="y", linestyle="--", linewidth=0.5, alpha=0.20, zorder=0)

    ax2 = ax1.twinx()
    l1 = ax2.plot(
        x,
        y_ag,
        color="#2ca02c",
        marker="o",
        linewidth=1.2,
        markersize=4.2,
        label="Decision Agreement",
        zorder=4,
    )
    ax2.set_ylabel("Agreement")
    ax2.set_ylim(0.985, 1.001)

    # Keep bar labels only for A4->A5_soft group.
    for bars in (b1, b2):
        rect = bars[0]
        h = rect.get_height()
        ax1.text(
            rect.get_x() + rect.get_width() / 2,
            h,
            f"{h:+.4f}",
            ha="center",
            va="bottom",
            fontsize=8,
            color="#303030",
        )
    # For A5_soft->A5_hw group, suppress tiny labels to reduce clutter.
    tiny_eps = 1e-3
    for bars in (b1, b2):
        rect = bars[1]
        h = rect.get_height()
        if abs(h) > tiny_eps:
            ax1.text(
                rect.get_x() + rect.get_width() / 2,
                h,
                f"{h:+.4f}",
                ha="center",
                va="bottom",
                fontsize=8,
                color="#505050",
            )

    handles = [b1, b2, l1[0]]
    labels_legend = [h.get_label() for h in handles]
    ax1.legend(
        handles,
        labels_legend,
        frameon=False,
        ncol=3,
        loc="upper center",
        bbox_to_anchor=(0.5, 1.20),
        borderaxespad=0.0,
        handlelength=1.8,
        columnspacing=1.2,
    )

    fig.subplots_adjust(top=0.78, right=0.86)

    out_base = out_dir / "fig_deploy_gap_summary_v2"
    _save_png_then_pdf(fig, out_base)
    plt.close(fig)

    if args.export_split:
        # Delta-only bars (single-axis)
        fig_d = plt.figure(figsize=(5.4, 3.4), dpi=args.dpi)
        axd = fig_d.add_subplot(111)
        axd.bar(x - w / 2, y_f1, width=w, color="#1f77b4", label="ΔMacro-F1", zorder=3)
        axd.bar(x + w / 2, y_ps, width=w, color="#ff7f0e", label="ΔPSNR (dB)", zorder=3)
        axd.axhline(0.0, color="black", linewidth=0.8)
        axd.set_xticks(x)
        axd.set_xticklabels(labels)
        axd.set_ylabel("Delta Value")
        axd.grid(True, axis="y", linestyle="--", linewidth=0.5, alpha=0.20, zorder=0)
        axd.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, 1.16), ncol=2)
        fig_d.subplots_adjust(top=0.78)
        out_delta = out_dir / "fig_deploy_gap_delta_only"
        _save_png_then_pdf(fig_d, out_delta)
        plt.close(fig_d)

        # Agreement-only line (single-axis)
        fig_a = plt.figure(figsize=(5.4, 3.4), dpi=args.dpi)
        axa = fig_a.add_subplot(111)
        axa.plot(x, y_ag, color="#2ca02c", marker="o", linewidth=1.3, markersize=4.5)
        axa.set_xticks(x)
        axa.set_xticklabels(labels)
        axa.set_ylabel("Decision Agreement")
        axa.set_ylim(0.985, 1.001)
        axa.grid(True, axis="y", linestyle="--", linewidth=0.5, alpha=0.20)
        out_ag = out_dir / "fig_deploy_gap_agreement_only"
        _save_png_then_pdf(fig_a, out_ag)
        plt.close(fig_a)

    _save_csv(out_dir / "data_deploy_gap_summary.csv", transition_data)
    notes_lines.extend(
        [
            "- Generated: `fig_deploy_gap_summary_v2.(png|pdf)`",
            "- PDF is generated from PNG to ensure visual consistency.",
            "- Visual changes: external top legend, thinner agreement line, no agreement text labels, selective bar labels.",
            "- Includes transitions: A4→A5_soft and A5_soft→A5_hw_eq.",
        ]
    )
    if args.export_split:
        notes_lines.extend(
            [
                "- Generated: `fig_deploy_gap_delta_only.(png|pdf)`",
                "- Generated: `fig_deploy_gap_agreement_only.(png|pdf)`",
            ]
        )
    _write_notes(notes_path, notes_lines)

    print(f"[OUT] {out_base.with_suffix('.png')}")
    print(f"[OUT] {out_base.with_suffix('.pdf')}")
    if args.export_split:
        print(f"[OUT] {(out_dir / 'fig_deploy_gap_delta_only').with_suffix('.png')}")
        print(f"[OUT] {(out_dir / 'fig_deploy_gap_delta_only').with_suffix('.pdf')}")
        print(f"[OUT] {(out_dir / 'fig_deploy_gap_agreement_only').with_suffix('.png')}")
        print(f"[OUT] {(out_dir / 'fig_deploy_gap_agreement_only').with_suffix('.pdf')}")


if __name__ == "__main__":
    main()
