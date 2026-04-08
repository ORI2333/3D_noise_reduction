#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Deploy gap analysis:
- A4 vs A5_soft
- A5_soft vs A5_hw_eq
"""

from __future__ import annotations

import argparse
import csv
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np

from unified_eval_core import (
    VARIANT_DISPLAY,
    apply_protocol_overrides,
    evaluate_variants,
    load_protocol_config,
    load_py,
    parse_dataset_arg,
    parse_sigma_arg,
    prepare_predictor_bundle,
    write_json,
)


PAIR_SPECS: List[Tuple[str, str]] = [("A4", "A5_soft"), ("A5_soft", "A5_hw_eq")]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Evaluate deploy gap between A4/A5_soft/A5_hw_eq.")
    p.add_argument("--dataset", type=str, default="all", help="davis/set8/all")
    p.add_argument("--sigma", type=str, default="all", help="10/30/50/all or comma-separated integers")
    p.add_argument(
        "--output_dir",
        type=str,
        required=True,
        help="Output directory for deploy-gap files.",
    )
    p.add_argument(
        "--base_root",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script",
    )
    p.add_argument(
        "--protocol_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_groupA_paperA_oraclefix\metrics_groupA_full.json",
    )
    p.add_argument(
        "--eval09a_script",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\09A_evaluate_groupA_full.py",
    )
    p.add_argument("--seed", type=int, default=None, help="Override seed in protocol config.")
    p.add_argument("--max_frames_per_seq", type=int, default=None, help="Override frame budget per sequence.")
    p.add_argument("--model_dir_ordinal", type=str, default="", help="Optional override.")
    p.add_argument("--tau_tuned_json", type=str, default="", help="Optional override.")
    p.add_argument(
        "--hw_prob_scale",
        type=int,
        default=4096,
        help="Fixed-point scale used by A5_hw_eq comparator simulation.",
    )
    p.add_argument("--compute_strred", action="store_true", help="Compute STRRED (slow).")
    return p.parse_args()


def _summarize(vals: Sequence[float]) -> Dict[str, float]:
    arr = np.asarray(vals, dtype=np.float64)
    if arr.size == 0:
        return {"mean": float("nan"), "std": float("nan")}
    return {"mean": float(arr.mean()), "std": float(arr.std(ddof=0))}


def _pair_key(a: str, b: str) -> str:
    return f"{a}_vs_{b}"


def _init_accumulators(
    pairs: Sequence[Tuple[str, str]],
    datasets: Sequence[str],
    sigmas: Sequence[int],
) -> Tuple[Dict[str, Dict[str, float]], Dict[str, Dict[str, List[float]]], Dict[str, Dict[str, Dict[str, List[float]]]]]:
    decision_acc: Dict[str, Dict[str, float]] = {}
    image_global: Dict[str, Dict[str, List[float]]] = {}
    image_by_group: Dict[str, Dict[str, Dict[str, List[float]]]] = {}
    for a, b in pairs:
        k = _pair_key(a, b)
        decision_acc[k] = {"n": 0.0, "agree": 0.0, "abs_err_sum": 0.0}
        image_global[k] = {"delta_psnr": [], "delta_ssim": []}
        image_by_group[k] = {}
        for ds in datasets:
            for s in sigmas:
                g = f"{ds}|sigma_{int(s)}"
                image_by_group[k][g] = {"delta_psnr": [], "delta_ssim": []}
    return decision_acc, image_global, image_by_group


def _write_summary_csv(path: Path, rows: Sequence[Dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "pair",
        "scope",
        "dataset",
        "sigma",
        "agreement",
        "mean_abs_class_error_pair",
        "delta_accuracy",
        "delta_macro_f1",
        "delta_mae_vs_oracle",
        "delta_tail_recall_24",
        "delta_tail_recall_28",
        "delta_tail_recall_31",
        "delta_psnr_mean",
        "delta_psnr_std",
        "delta_ssim_mean",
        "delta_ssim_std",
        "delta_strred_mean",
    ]
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})


def _build_notes(payload: Dict[str, Any], out_dir: Path, cmd: str) -> str:
    cfg = payload["config"]
    lines: List[str] = []
    lines.append("# Deploy Gap Notes")
    lines.append("")
    lines.append(f"- Time: `{datetime.now().isoformat(timespec='seconds')}`")
    lines.append(f"- Output directory: `{out_dir}`")
    lines.append(f"- Command: `{cmd}`")
    lines.append("")
    lines.append("## Compared Pairs")
    lines.append("")
    for p in payload["pairs"]:
        lines.append(f"- `{p['pair']}` ({p['variant_a']} -> {p['variant_b']})")
    lines.append("")
    lines.append("## Protocol")
    lines.append("")
    lines.append(f"- Datasets: `{cfg['datasets']}`")
    lines.append(f"- Sigmas: `{cfg['sigmas']}`")
    lines.append(f"- Seed: `{cfg['seed']}`")
    lines.append(f"- Max frames per sequence: `{cfg['max_frames_per_seq']}`")
    lines.append(f"- Oracle source: `{cfg['oracle_lib_py']}`")
    lines.append(f"- TDNR source: `{cfg['tdnr_py']}`")
    if "protocol_json" in cfg:
        lines.append(f"- Inherited protocol json: `{cfg['protocol_json']}`")
    lines.append("")
    lines.append("## Files")
    lines.append("")
    lines.append(f"- `{out_dir / 'deploy_gap.json'}`")
    lines.append(f"- `{out_dir / 'deploy_gap_summary.csv'}`")
    lines.append(f"- `{out_dir / 'config.json'}`")
    lines.append(f"- `{out_dir / 'notes.md'}`")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    variants = ["A4", "A5_soft", "A5_hw_eq"]
    datasets = parse_dataset_arg(args.dataset)

    base_root = Path(args.base_root)
    protocol_path = Path(args.protocol_json) if args.protocol_json else None
    if protocol_path is not None and not protocol_path.is_file():
        raise SystemExit(f"protocol_json not found: {protocol_path}")
    cfg0 = load_protocol_config(base_root=base_root, protocol_json=protocol_path)
    cfg = apply_protocol_overrides(
        cfg0,
        seed=args.seed,
        max_frames_per_seq=args.max_frames_per_seq,
        model_dir_multiclass=None,
        model_dir_reg=None,
        model_dir_ordinal=args.model_dir_ordinal,
        tau_tuned_json=args.tau_tuned_json,
    )
    sigmas = parse_sigma_arg(args.sigma, cfg["sigmas"])

    eval09a = load_py(Path(args.eval09a_script), "eval09a_for_09C_deploy_gap")
    tdnr_mod = eval09a.load_module(Path(cfg["tdnr_py"]), "tdnr_mod_09C_deploy_gap")
    oracle_mod = eval09a.load_module(Path(cfg["oracle_lib_py"]), "oracle_mod_09C_deploy_gap")

    bundle = prepare_predictor_bundle(
        eval09a=eval09a,
        cfg=cfg,
        variants=variants,
        hw_prob_scale=args.hw_prob_scale,
    )

    decision_acc, image_global, image_by_group = _init_accumulators(PAIR_SPECS, datasets, sigmas)

    def on_frame(ctx: Dict[str, Any]) -> None:
        dataset = str(ctx["dataset"])
        sigma = int(ctx["sigma"])
        w_maps = ctx["w_maps"]
        fm = ctx["frame_metrics"]
        for a, b in PAIR_SPECS:
            k = _pair_key(a, b)
            wa = w_maps[a].reshape(-1).astype(np.int16)
            wb = w_maps[b].reshape(-1).astype(np.int16)
            n = wa.size
            if n <= 0:
                continue
            decision_acc[k]["n"] += float(n)
            decision_acc[k]["agree"] += float(np.sum(wa == wb))
            decision_acc[k]["abs_err_sum"] += float(np.sum(np.abs(wb - wa)))

            dpsnr = float(fm[b]["psnr"] - fm[a]["psnr"])
            dssim = float(fm[b]["ssim"] - fm[a]["ssim"])
            image_global[k]["delta_psnr"].append(dpsnr)
            image_global[k]["delta_ssim"].append(dssim)
            g = f"{dataset}|sigma_{sigma}"
            if g in image_by_group[k]:
                image_by_group[k][g]["delta_psnr"].append(dpsnr)
                image_by_group[k][g]["delta_ssim"].append(dssim)

    payload_eval = evaluate_variants(
        eval09a=eval09a,
        tdnr_mod=tdnr_mod,
        oracle_mod=oracle_mod,
        cfg=cfg,
        variants=variants,
        datasets=datasets,
        sigmas=sigmas,
        predictor_bundle=bundle,
        compute_strred=bool(args.compute_strred),
        frame_callback=on_frame,
        progress_tag="DEPLOY_GAP",
    )

    decision_metrics = payload_eval["decision_metrics"]
    results = payload_eval["results"]

    pair_payload: List[Dict[str, Any]] = []
    summary_rows: List[Dict[str, str]] = []

    for a, b in PAIR_SPECS:
        k = _pair_key(a, b)
        acc = decision_acc[k]
        n = max(acc["n"], 1.0)
        agreement = acc["agree"] / n
        pair_mae = acc["abs_err_sum"] / n

        da = decision_metrics[a]
        db = decision_metrics[b]
        delta_tail = {}
        for t in ["24", "28", "31"]:
            delta_tail[t] = float(db.get("tail_recall", {}).get(t, float("nan")) - da.get("tail_recall", {}).get(t, float("nan")))

        delta_dec = {
            "accuracy": float(db["accuracy"] - da["accuracy"]),
            "macro_f1": float(db["macro_f1"] - da["macro_f1"]),
            "mean_abs_class_error_vs_oracle": float(db["mean_abs_class_error"] - da["mean_abs_class_error"]),
            "tail_recall": delta_tail,
        }

        image_global_summary = {
            "delta_psnr": _summarize(image_global[k]["delta_psnr"]),
            "delta_ssim": _summarize(image_global[k]["delta_ssim"]),
        }

        image_group_summary: Dict[str, Any] = {}
        for ds in datasets:
            image_group_summary.setdefault(ds, {})
            for s in sigmas:
                g = f"{ds}|sigma_{int(s)}"
                g_psnr = _summarize(image_by_group[k][g]["delta_psnr"])
                g_ssim = _summarize(image_by_group[k][g]["delta_ssim"])
                rec = {
                    "delta_psnr": g_psnr,
                    "delta_ssim": g_ssim,
                }
                if args.compute_strred:
                    key = f"sigma_{int(s)}"
                    va = results[ds][key]["dataset_mean"][a]
                    vb = results[ds][key]["dataset_mean"][b]
                    if "strred" in va and "strred" in vb:
                        rec["delta_strred_mean"] = float(vb["strred"]["mean"] - va["strred"]["mean"])
                image_group_summary[ds][f"sigma_{int(s)}"] = rec

                summary_rows.append(
                    {
                        "pair": k,
                        "scope": "dataset_sigma",
                        "dataset": ds,
                        "sigma": str(int(s)),
                        "agreement": f"{agreement:.6f}",
                        "mean_abs_class_error_pair": f"{pair_mae:.6f}",
                        "delta_accuracy": f"{delta_dec['accuracy']:.6f}",
                        "delta_macro_f1": f"{delta_dec['macro_f1']:.6f}",
                        "delta_mae_vs_oracle": f"{delta_dec['mean_abs_class_error_vs_oracle']:.6f}",
                        "delta_tail_recall_24": f"{float(delta_tail['24']):.6f}",
                        "delta_tail_recall_28": f"{float(delta_tail['28']):.6f}",
                        "delta_tail_recall_31": f"{float(delta_tail['31']):.6f}",
                        "delta_psnr_mean": f"{float(g_psnr['mean']):.6f}",
                        "delta_psnr_std": f"{float(g_psnr['std']):.6f}",
                        "delta_ssim_mean": f"{float(g_ssim['mean']):.6f}",
                        "delta_ssim_std": f"{float(g_ssim['std']):.6f}",
                        "delta_strred_mean": (
                            f"{float(image_group_summary[ds][f'sigma_{int(s)}'].get('delta_strred_mean', float('nan'))):.6f}"
                            if args.compute_strred
                            else ""
                        ),
                    }
                )

        pair_payload.append(
            {
                "pair": k,
                "variant_a": a,
                "variant_b": b,
                "variant_a_display": VARIANT_DISPLAY[a],
                "variant_b_display": VARIANT_DISPLAY[b],
                "decision_difference": {
                    "agreement": float(agreement),
                    "mean_abs_class_error_pair": float(pair_mae),
                    "variant_a_metrics": da,
                    "variant_b_metrics": db,
                    "delta_metrics_b_minus_a": delta_dec,
                },
                "image_difference": {
                    "global": image_global_summary,
                    "by_dataset_sigma": image_group_summary,
                },
            }
        )

        summary_rows.append(
            {
                "pair": k,
                "scope": "global",
                "dataset": "ALL",
                "sigma": "ALL",
                "agreement": f"{agreement:.6f}",
                "mean_abs_class_error_pair": f"{pair_mae:.6f}",
                "delta_accuracy": f"{delta_dec['accuracy']:.6f}",
                "delta_macro_f1": f"{delta_dec['macro_f1']:.6f}",
                "delta_mae_vs_oracle": f"{delta_dec['mean_abs_class_error_vs_oracle']:.6f}",
                "delta_tail_recall_24": f"{float(delta_tail['24']):.6f}",
                "delta_tail_recall_28": f"{float(delta_tail['28']):.6f}",
                "delta_tail_recall_31": f"{float(delta_tail['31']):.6f}",
                "delta_psnr_mean": f"{float(image_global_summary['delta_psnr']['mean']):.6f}",
                "delta_psnr_std": f"{float(image_global_summary['delta_psnr']['std']):.6f}",
                "delta_ssim_mean": f"{float(image_global_summary['delta_ssim']['mean']):.6f}",
                "delta_ssim_std": f"{float(image_global_summary['delta_ssim']['std']):.6f}",
                "delta_strred_mean": "",
            }
        )

    final_payload: Dict[str, Any] = {
        "config": payload_eval["config"],
        "sources": payload_eval.get("sources", {}),
        "pairs": pair_payload,
        "raw_metrics_subset": {
            "decision_metrics": decision_metrics,
            "results": results,
        },
    }

    write_json(out_dir / "deploy_gap.json", final_payload)
    write_json(out_dir / "config.json", final_payload["config"])
    _write_summary_csv(out_dir / "deploy_gap_summary.csv", summary_rows)

    cmd = (
        f"python -u .\\script\\09C_eval_deploy_gap.py "
        f"--dataset \"{args.dataset}\" --sigma \"{args.sigma}\" --output_dir \"{out_dir}\""
    )
    notes = _build_notes(final_payload, out_dir=out_dir, cmd=cmd)
    (out_dir / "notes.md").write_text(notes, encoding="utf-8")

    print(f"[OUT] {out_dir / 'deploy_gap.json'}")
    print(f"[OUT] {out_dir / 'config.json'}")
    print(f"[OUT] {out_dir / 'deploy_gap_summary.csv'}")
    print(f"[OUT] {out_dir / 'notes.md'}")


if __name__ == "__main__":
    main()
