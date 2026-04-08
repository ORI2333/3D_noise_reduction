#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Plot sigma-tail paper figures from unified/sigma-tail analysis outputs.
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Sequence

import matplotlib.pyplot as plt
import numpy as np


METHODS = ["A2", "A3", "A4", "A5_hw_eq"]
DISPLAY = {
    "A2": "A2",
    "A3": "A3",
    "A4": "A4",
    "A5_hw_eq": "A5_hw_eq",
}
COLOR = {
    "A2": "#1f77b4",
    "A3": "#d62728",
    "A4": "#2ca02c",
    "A5_hw_eq": "#9467bd",
}
MARKER = {
    "A2": "o",
    "A3": "s",
    "A4": "^",
    "A5_hw_eq": "D",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Plot sigma-tail figures for paper usage.")
    p.add_argument(
        "--metrics_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_unified_variants\metrics.json",
    )
    p.add_argument(
        "--sigma_tail_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_sigma_tail_analysis\sigma_tail_analysis.json",
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
            "lines.linewidth": 2.0,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "savefig.facecolor": "white",
            "savefig.bbox": "tight",
        }
    )


def _extract_image_by_sigma(metrics_payload: Dict[str, Any], methods: Sequence[str]) -> Dict[str, Dict[str, float]]:
    cfg = metrics_payload["config"]
    results = metrics_payload["results"]
    datasets = [str(x) for x in cfg["datasets"]]
    sigmas = [int(x) for x in cfg["sigmas"]]
    out: Dict[str, Dict[str, float]] = {}
    for s in sigmas:
        sk = str(int(s))
        out[sk] = {}
        for m in methods:
            num = 0
            ps_sum = 0.0
            ss_sum = 0.0
            for ds in datasets:
                item = results[ds][f"sigma_{s}"]["dataset_mean"][m]
                n = int(item["num_frames"])
                ps_sum += float(item["psnr"]["mean"]) * n
                ss_sum += float(item["ssim"]["mean"]) * n
                num += n
            out[sk][m] = {
                "psnr": float(ps_sum / max(num, 1)),
                "ssim": float(ss_sum / max(num, 1)),
            }
    return out


def _plot_line(
    x: Sequence[int],
    y_map: Dict[str, Sequence[float]],
    y_label: str,
    out_base: Path,
    dpi: int,
) -> None:
    fig = plt.figure(figsize=(5.4, 3.6), dpi=dpi)
    ax = fig.add_subplot(111)
    for m in METHODS:
        y = y_map[m]
        ax.plot(
            x,
            y,
            marker=MARKER[m],
            color=COLOR[m],
            label=DISPLAY[m],
            linewidth=2.0,
            markersize=5,
        )
    ax.set_xlabel("Sigma")
    ax.set_ylabel(y_label)
    ax.set_xticks(list(x))
    ax.grid(True, linestyle="--", linewidth=0.6, alpha=0.35)
    ax.legend(frameon=False, ncol=2, loc="best")
    out_base.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_base.with_suffix(".png"))
    fig.savefig(out_base.with_suffix(".pdf"))
    plt.close(fig)


def _write_curve_csv(path: Path, x: Sequence[int], y_map: Dict[str, Sequence[float]], y_key: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        fields = ["sigma"] + [f"{m}_{y_key}" for m in METHODS]
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for i, s in enumerate(x):
            row = {"sigma": str(int(s))}
            for m in METHODS:
                row[f"{m}_{y_key}"] = f"{float(y_map[m][i]):.8f}"
            w.writerow(row)


def main() -> None:
    args = parse_args()
    np.random.seed(int(args.seed))
    _set_style()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    notes_path = out_dir / "notes.md"
    notes_lines = [
        "## 09F Plot Sigma Tail Figures",
        f"- Time: `{datetime.now().isoformat(timespec='seconds')}`",
        f"- Seed: `{int(args.seed)}`",
        f"- Input metrics: `{Path(args.metrics_json)}`",
        f"- Input sigma-tail: `{Path(args.sigma_tail_json)}`",
    ]

    metrics_path = Path(args.metrics_json)
    if not metrics_path.is_file():
        notes_lines.append("- ERROR: metrics.json not found; skip figure generation.")
        _write_notes(notes_path, notes_lines)
        raise SystemExit(f"metrics json not found: {metrics_path}")
    metrics_payload = _read_json(metrics_path)

    sigma_tail_path = Path(args.sigma_tail_json)
    if sigma_tail_path.is_file():
        sigma_payload = _read_json(sigma_tail_path)
        if "decision_by_sigma" not in sigma_payload or "image_by_sigma" not in sigma_payload:
            notes_lines.append("- ERROR: sigma_tail_analysis.json missing expected keys.")
            _write_notes(notes_path, notes_lines)
            raise SystemExit(f"invalid sigma-tail json: {sigma_tail_path}")
        decision_by_sigma = sigma_payload["decision_by_sigma"]
        image_by_sigma = sigma_payload["image_by_sigma"]
        notes_lines.append("- Decision/image by sigma loaded from sigma_tail_analysis.json.")
    else:
        notes_lines.append("- WARNING: sigma_tail_analysis.json missing; fallback to metrics.json.")
        if "decision_metrics_by_sigma" in metrics_payload:
            decision_by_sigma = metrics_payload["decision_metrics_by_sigma"]
        else:
            notes_lines.append("- ERROR: decision-by-sigma unavailable in inputs.")
            _write_notes(notes_path, notes_lines)
            raise SystemExit("decision-by-sigma unavailable; run 09E first.")
        image_by_sigma = _extract_image_by_sigma(metrics_payload, METHODS)

    sigmas = sorted(int(x) for x in decision_by_sigma.keys())

    y_tail: Dict[str, List[float]] = {m: [] for m in METHODS}
    y_f1: Dict[str, List[float]] = {m: [] for m in METHODS}
    y_psnr: Dict[str, List[float]] = {m: [] for m in METHODS}

    for s in sigmas:
        sk = str(int(s))
        for m in METHODS:
            d = decision_by_sigma[sk][m]
            tr = d.get("tail_recall", {})
            t24 = float(tr.get("24", np.nan))
            t28 = float(tr.get("28", np.nan))
            t31 = float(tr.get("31", np.nan))
            tail_avg = float(np.nanmean([t24, t28, t31]))
            y_tail[m].append(tail_avg)
            y_f1[m].append(float(d["macro_f1"]))
            y_psnr[m].append(float(image_by_sigma[sk][m]["psnr"]))

    _plot_line(sigmas, y_tail, "Average Tail Recall (24/28/31)", out_dir / "fig_tail_recall_vs_sigma", args.dpi)
    _plot_line(sigmas, y_f1, "Macro-F1", out_dir / "fig_macrof1_vs_sigma", args.dpi)
    _plot_line(sigmas, y_psnr, "Average PSNR (dB)", out_dir / "fig_psnr_vs_sigma", args.dpi)

    _write_curve_csv(out_dir / "data_tail_recall_vs_sigma.csv", sigmas, y_tail, "tail_avg")
    _write_curve_csv(out_dir / "data_macrof1_vs_sigma.csv", sigmas, y_f1, "macrof1")
    _write_curve_csv(out_dir / "data_psnr_vs_sigma.csv", sigmas, y_psnr, "psnr")

    notes_lines.extend(
        [
            "- Generated: `fig_tail_recall_vs_sigma.(png|pdf)`",
            "- Generated: `fig_macrof1_vs_sigma.(png|pdf)`",
            "- Generated: `fig_psnr_vs_sigma.(png|pdf)`",
        ]
    )
    _write_notes(notes_path, notes_lines)

    print(f"[OUT] {out_dir / 'fig_tail_recall_vs_sigma.png'}")
    print(f"[OUT] {out_dir / 'fig_tail_recall_vs_sigma.pdf'}")
    print(f"[OUT] {out_dir / 'fig_macrof1_vs_sigma.png'}")
    print(f"[OUT] {out_dir / 'fig_macrof1_vs_sigma.pdf'}")
    print(f"[OUT] {out_dir / 'fig_psnr_vs_sigma.png'}")
    print(f"[OUT] {out_dir / 'fig_psnr_vs_sigma.pdf'}")


if __name__ == "__main__":
    main()

