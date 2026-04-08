#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Unified evaluation entry for A0~A5 variants under one protocol.
"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

from unified_eval_core import (
    VARIANT_DISPLAY,
    apply_protocol_overrides,
    build_unified_summary_rows,
    evaluate_variants,
    load_protocol_config,
    load_py,
    parse_dataset_arg,
    parse_sigma_arg,
    parse_variant_arg,
    prepare_predictor_bundle,
    write_json,
    write_summary_csv,
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run unified evaluation for selected variant(s).")
    p.add_argument(
        "--variant",
        type=str,
        default="all",
        help="A0/A1/A2/A3/A4/A5_soft/A5_hw_eq/all, or comma-separated list.",
    )
    p.add_argument("--dataset", type=str, default="all", help="davis/set8/all")
    p.add_argument("--sigma", type=str, default="all", help="10/30/50/all or comma-separated integers")
    p.add_argument(
        "--output_dir",
        type=str,
        required=True,
        help="Output directory for unified result files.",
    )
    p.add_argument(
        "--base_root",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script",
        help="Script root containing 3dnr.py/oracle_lib.py/DAVIS/Set8.",
    )
    p.add_argument(
        "--protocol_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_groupA_paperA_oraclefix\metrics_groupA_full.json",
        help="Optional protocol source; when exists, config is inherited from this file.",
    )
    p.add_argument(
        "--eval09a_script",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\09A_evaluate_groupA_full.py",
        help="Path to 09A helper script used as function library.",
    )
    p.add_argument("--seed", type=int, default=None, help="Override seed in protocol config.")
    p.add_argument("--max_frames_per_seq", type=int, default=None, help="Override frame budget per sequence.")
    p.add_argument("--model_dir_multiclass", type=str, default="", help="Optional override.")
    p.add_argument("--model_dir_reg", type=str, default="", help="Optional override.")
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


def _build_notes(
    payload: Dict[str, Any],
    out_dir: Path,
    cmd: str,
) -> str:
    cfg = payload["config"]
    sources = payload.get("sources", {})
    dec = payload["decision_metrics"]
    lines: List[str] = []
    lines.append("# Unified Variant Evaluation Notes")
    lines.append("")
    lines.append(f"- Time: `{datetime.now().isoformat(timespec='seconds')}`")
    lines.append(f"- Output directory: `{out_dir}`")
    lines.append(f"- Command: `{cmd}`")
    lines.append("")
    lines.append("## Protocol")
    lines.append("")
    lines.append(f"- Variants: `{cfg['variants']}`")
    lines.append(f"- Datasets: `{cfg['datasets']}`")
    lines.append(f"- Sigmas: `{cfg['sigmas']}`")
    lines.append(f"- Seed: `{cfg['seed']}`")
    lines.append(f"- Max frames per sequence: `{cfg['max_frames_per_seq']}`")
    lines.append(f"- Oracle source: `{cfg['oracle_lib_py']}`")
    lines.append(f"- TDNR source: `{cfg['tdnr_py']}`")
    if "protocol_json" in cfg:
        lines.append(f"- Inherited protocol json: `{cfg['protocol_json']}`")
    lines.append("")
    lines.append("## Key Inputs")
    lines.append("")
    for k in sorted(sources.keys()):
        lines.append(f"- {k}: `{sources[k]}`")
    lines.append("")
    lines.append("## Decision Summary")
    lines.append("")
    for v in cfg["variants"]:
        d = dec[v]
        tr = d.get("tail_recall", {})
        lines.append(
            f"- {VARIANT_DISPLAY.get(v, v)}: "
            f"acc={float(d['accuracy']):.4f}, macro_f1={float(d['macro_f1']):.4f}, "
            f"mae_cls={float(d['mean_abs_class_error']):.4f}, "
            f"tail24/28/31={float(tr.get('24', float('nan'))):.4f}/"
            f"{float(tr.get('28', float('nan'))):.4f}/{float(tr.get('31', float('nan'))):.4f}"
        )
    lines.append("")
    lines.append("## Files")
    lines.append("")
    lines.append(f"- `{out_dir / 'metrics.json'}`")
    lines.append(f"- `{out_dir / 'config.json'}`")
    lines.append(f"- `{out_dir / 'summary.csv'}`")
    lines.append(f"- `{out_dir / 'notes.md'}`")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    variants = parse_variant_arg(args.variant)
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
        model_dir_multiclass=args.model_dir_multiclass,
        model_dir_reg=args.model_dir_reg,
        model_dir_ordinal=args.model_dir_ordinal,
        tau_tuned_json=args.tau_tuned_json,
    )
    sigmas = parse_sigma_arg(args.sigma, cfg["sigmas"])

    eval09a = load_py(Path(args.eval09a_script), "eval09a_for_09B_unified")
    tdnr_mod = eval09a.load_module(Path(cfg["tdnr_py"]), "tdnr_mod_09B_unified")
    oracle_mod = eval09a.load_module(Path(cfg["oracle_lib_py"]), "oracle_mod_09B_unified")

    bundle = prepare_predictor_bundle(
        eval09a=eval09a,
        cfg=cfg,
        variants=variants,
        hw_prob_scale=args.hw_prob_scale,
    )

    payload = evaluate_variants(
        eval09a=eval09a,
        tdnr_mod=tdnr_mod,
        oracle_mod=oracle_mod,
        cfg=cfg,
        variants=variants,
        datasets=datasets,
        sigmas=sigmas,
        predictor_bundle=bundle,
        compute_strred=bool(args.compute_strred),
        frame_callback=None,
        progress_tag="UNIFIED",
    )

    write_json(out_dir / "metrics.json", payload)
    write_json(out_dir / "config.json", payload["config"])
    rows = build_unified_summary_rows(payload)
    write_summary_csv(out_dir / "summary.csv", rows)

    cmd = (
        f"python -u .\\script\\09B_run_unified_variants.py "
        f"--variant \"{args.variant}\" --dataset \"{args.dataset}\" --sigma \"{args.sigma}\" "
        f"--output_dir \"{out_dir}\""
    )
    notes_text = _build_notes(payload=payload, out_dir=out_dir, cmd=cmd)
    (out_dir / "notes.md").write_text(notes_text, encoding="utf-8")

    print(f"[OUT] {out_dir / 'metrics.json'}")
    print(f"[OUT] {out_dir / 'config.json'}")
    print(f"[OUT] {out_dir / 'summary.csv'}")
    print(f"[OUT] {out_dir / 'notes.md'}")


if __name__ == "__main__":
    main()
