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

    labels = ["A4→A5_soft", "A5_soft→A5_hw_eq"]
    x = np.arange(len(labels))
    w = 0.32
    y_f1 = [transition_data["A4_vs_A5_soft"]["delta_macro_f1"], transition_data["A5_soft_vs_A5_hw_eq"]["delta_macro_f1"]]
    y_ps = [transition_data["A4_vs_A5_soft"]["delta_psnr"], transition_data["A5_soft_vs_A5_hw_eq"]["delta_psnr"]]
    y_ag = [transition_data["A4_vs_A5_soft"]["decision_agreement"], transition_data["A5_soft_vs_A5_hw_eq"]["decision_agreement"]]

    fig = plt.figure(figsize=(5.6, 3.6), dpi=args.dpi)
    ax1 = fig.add_subplot(111)
    b1 = ax1.bar(x - w / 2, y_f1, width=w, color="#1f77b4", label="ΔMacro-F1")
    b2 = ax1.bar(x + w / 2, y_ps, width=w, color="#ff7f0e", label="ΔPSNR (dB)")
    ax1.axhline(0.0, color="black", linewidth=0.8)
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels)
    ax1.set_ylabel("Delta Value")
    ax1.grid(True, axis="y", linestyle="--", linewidth=0.6, alpha=0.35)

    ax2 = ax1.twinx()
    l1 = ax2.plot(x, y_ag, color="#2ca02c", marker="o", linewidth=1.8, markersize=5, label="Decision Agreement")
    ax2.set_ylabel("Agreement")
    ax2.set_ylim(0.95, 1.005)

    for rect in list(b1) + list(b2):
        h = rect.get_height()
        ax1.text(rect.get_x() + rect.get_width() / 2, h, f"{h:+.4f}", ha="center", va="bottom", fontsize=8)
    for xi, yi in zip(x, y_ag):
        ax2.text(xi, yi + 0.001, f"{yi:.4f}", ha="center", va="bottom", fontsize=8, color="#2ca02c")

    handles = [b1, b2, l1[0]]
    labels_legend = [h.get_label() for h in handles]
    ax1.legend(handles, labels_legend, frameon=False, loc="best")

    out_base = out_dir / "fig_deploy_gap_summary"
    fig.savefig(out_base.with_suffix(".png"))
    fig.savefig(out_base.with_suffix(".pdf"))
    plt.close(fig)

    _save_csv(out_dir / "data_deploy_gap_summary.csv", transition_data)
    notes_lines.extend(
        [
            "- Generated: `fig_deploy_gap_summary.(png|pdf)`",
            "- Includes transitions: A4→A5_soft and A5_soft→A5_hw_eq.",
        ]
    )
    _write_notes(notes_path, notes_lines)

    print(f"[OUT] {out_base.with_suffix('.png')}")
    print(f"[OUT] {out_base.with_suffix('.pdf')}")


if __name__ == "__main__":
    main()

