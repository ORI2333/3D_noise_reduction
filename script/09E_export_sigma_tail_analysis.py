#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Export sigma-sliced and tail-sensitive analysis from unified evaluation outputs.
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np

from unified_eval_core import (
    VARIANT_DISPLAY,
    evaluate_variants,
    load_py,
    prepare_predictor_bundle,
)


TARGET_VARIANTS = ["A2", "A3", "A4", "A5_soft", "A5_hw_eq"]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export sigma-tail analysis for ordinal-family argumentation.")
    p.add_argument(
        "--metrics_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_unified_variants\metrics.json",
    )
    p.add_argument(
        "--out_dir",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_sigma_tail_analysis",
    )
    p.add_argument(
        "--eval09a_script",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\09A_evaluate_groupA_full.py",
    )
    p.add_argument(
        "--force_recompute_decision_sigma",
        action="store_true",
        help="Force rerun to recompute sigma-level decision metrics even if available.",
    )
    return p.parse_args()


def _load_json(path: Path) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def _f4(x: float) -> str:
    return f"{float(x):.4f}"


def _f6(x: float) -> str:
    return f"{float(x):.6f}"


def _weighted_mean(items: Sequence[Tuple[float, int]]) -> float:
    if len(items) == 0:
        return float("nan")
    s = 0.0
    w = 0
    for v, n in items:
        s += float(v) * int(n)
        w += int(n)
    if w <= 0:
        return float("nan")
    return float(s / w)


def _extract_image_by_sigma(
    payload: Dict[str, Any],
    variants: Sequence[str],
) -> Tuple[Dict[str, Dict[str, Dict[str, float]]], bool]:
    cfg = payload["config"]
    results = payload["results"]
    datasets = [str(x) for x in cfg["datasets"]]
    sigmas = [int(x) for x in cfg["sigmas"]]

    has_strred = True
    for ds in datasets:
        for s in sigmas:
            for v in variants:
                item = results[ds][f"sigma_{s}"]["dataset_mean"][v]
                if "strred" not in item:
                    has_strred = False

    out: Dict[str, Dict[str, Dict[str, float]]] = {}
    for s in sigmas:
        sk = str(int(s))
        out[sk] = {}
        for v in variants:
            ps_items: List[Tuple[float, int]] = []
            ss_items: List[Tuple[float, int]] = []
            st_items: List[Tuple[float, int]] = []
            for ds in datasets:
                item = results[ds][f"sigma_{s}"]["dataset_mean"][v]
                n = int(item["num_frames"])
                ps_items.append((float(item["psnr"]["mean"]), n))
                ss_items.append((float(item["ssim"]["mean"]), n))
                if has_strred:
                    st_items.append((float(item["strred"]["mean"]), n))
            out[sk][v] = {
                "psnr": _weighted_mean(ps_items),
                "ssim": _weighted_mean(ss_items),
            }
            if has_strred:
                out[sk][v]["strred"] = _weighted_mean(st_items)
    return out, has_strred


def _recompute_decision_by_sigma(
    metrics_payload: Dict[str, Any],
    eval09a_script: Path,
    variants: Sequence[str],
) -> Dict[str, Dict[str, Dict[str, Any]]]:
    cfg = metrics_payload["config"]
    sources = metrics_payload.get("sources", {})
    datasets = [str(x) for x in cfg["datasets"]]
    sigmas = [int(x) for x in cfg["sigmas"]]
    w_set = np.asarray(cfg["w_set"], dtype=np.uint8)

    eval09a = load_py(eval09a_script, "eval09a_for_09E_sigma_tail")
    tdnr_mod = eval09a.load_module(Path(cfg["tdnr_py"]), "tdnr_mod_09E_sigma_tail")
    oracle_mod = eval09a.load_module(Path(cfg["oracle_lib_py"]), "oracle_mod_09E_sigma_tail")

    hw_prob_scale = int(sources.get("hw_prob_scale", 4096))
    bundle = prepare_predictor_bundle(
        eval09a=eval09a,
        cfg=cfg,
        variants=variants,
        hw_prob_scale=hw_prob_scale,
    )

    y_true: Dict[str, Dict[str, List[np.ndarray]]] = {str(s): {v: [] for v in variants} for s in sigmas}
    y_pred: Dict[str, Dict[str, List[np.ndarray]]] = {str(s): {v: [] for v in variants} for s in sigmas}

    def on_frame(ctx: Dict[str, Any]) -> None:
        s = str(int(ctx["sigma"]))
        yt = ctx["oracle_common"].reshape(-1).astype(np.uint8)
        for v in variants:
            yp = ctx["w_maps"][v].reshape(-1).astype(np.uint8)
            y_true[s][v].append(yt.copy())
            y_pred[s][v].append(yp)

    evaluate_variants(
        eval09a=eval09a,
        tdnr_mod=tdnr_mod,
        oracle_mod=oracle_mod,
        cfg=cfg,
        variants=list(variants),
        datasets=datasets,
        sigmas=sigmas,
        predictor_bundle=bundle,
        compute_strred=False,
        frame_callback=on_frame,
        progress_tag="SIGMA_DECISION",
    )

    out: Dict[str, Dict[str, Dict[str, Any]]] = {}
    for s in sigmas:
        sk = str(int(s))
        out[sk] = {}
        for v in variants:
            yt = np.concatenate(y_true[sk][v], axis=0).astype(np.uint8) if y_true[sk][v] else np.array([], dtype=np.uint8)
            yp = np.concatenate(y_pred[sk][v], axis=0).astype(np.uint8) if y_pred[sk][v] else np.array([], dtype=np.uint8)
            out[sk][v] = eval09a.compute_decision_metrics(yt, yp, w_set)
    return out


def _build_decision_rows(
    dec_by_sigma: Dict[str, Dict[str, Dict[str, Any]]],
    sigmas: Sequence[int],
    variants: Sequence[str],
) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for s in sigmas:
        sk = str(int(s))
        for v in variants:
            d = dec_by_sigma[sk][v]
            tr = d.get("tail_recall", {})
            rows.append(
                {
                    "sigma": sk,
                    "method": v,
                    "method_name": VARIANT_DISPLAY.get(v, v),
                    "accuracy": f"{float(d['accuracy']):.6f}",
                    "macro_f1": f"{float(d['macro_f1']):.6f}",
                    "mean_abs_class_error": f"{float(d['mean_abs_class_error']):.6f}",
                    "tail_recall_24": f"{float(tr.get('24', float('nan'))):.6f}",
                    "tail_recall_28": f"{float(tr.get('28', float('nan'))):.6f}",
                    "tail_recall_31": f"{float(tr.get('31', float('nan'))):.6f}",
                }
            )
    return rows


def _build_image_rows(
    img_by_sigma: Dict[str, Dict[str, Dict[str, float]]],
    sigmas: Sequence[int],
    variants: Sequence[str],
    has_strred: bool,
) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for s in sigmas:
        sk = str(int(s))
        for v in variants:
            it = img_by_sigma[sk][v]
            r = {
                "sigma": sk,
                "method": v,
                "method_name": VARIANT_DISPLAY.get(v, v),
                "psnr": f"{float(it['psnr']):.6f}",
                "ssim": f"{float(it['ssim']):.6f}",
            }
            if has_strred:
                r["strred"] = f"{float(it['strred']):.6f}"
            rows.append(r)
    return rows


def _write_csv(path: Path, rows: Sequence[Dict[str, str]], fields: Sequence[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(fields))
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})


def _md_decision_table(dec_rows: Sequence[Dict[str, str]]) -> str:
    lines: List[str] = []
    lines.append("| Sigma | Method | Accuracy | Macro-F1 | MeanAbsClassError | TailRecall@24 | TailRecall@28 | TailRecall@31 |")
    lines.append("|---:|---|---:|---:|---:|---:|---:|---:|")
    for r in dec_rows:
        lines.append(
            "| "
            + " | ".join(
                [
                    r["sigma"],
                    r["method_name"],
                    _f4(r["accuracy"]),
                    _f4(r["macro_f1"]),
                    _f4(r["mean_abs_class_error"]),
                    _f4(r["tail_recall_24"]),
                    _f4(r["tail_recall_28"]),
                    _f4(r["tail_recall_31"]),
                ]
            )
            + " |"
        )
    return "\n".join(lines) + "\n"


def _md_image_table(img_rows: Sequence[Dict[str, str]], has_strred: bool) -> str:
    lines: List[str] = []
    if has_strred:
        lines.append("| Sigma | Method | PSNR | SSIM | STRRED |")
        lines.append("|---:|---|---:|---:|---:|")
    else:
        lines.append("| Sigma | Method | PSNR | SSIM |")
        lines.append("|---:|---|---:|---:|")
    for r in img_rows:
        if has_strred:
            row = [r["sigma"], r["method_name"], _f4(r["psnr"]), _f6(r["ssim"]), _f4(r["strred"])]
        else:
            row = [r["sigma"], r["method_name"], _f4(r["psnr"]), _f6(r["ssim"])]
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines) + "\n"


def _tex_escape(s: str) -> str:
    return s.replace("_", "\\_")


def _tex_decision_table(dec_rows: Sequence[Dict[str, str]]) -> str:
    lines: List[str] = []
    lines.append(r"\begin{table*}[t]")
    lines.append(r"\centering")
    lines.append(r"\caption{Sigma-wise decision-level comparison (A2/A3/A4/A5\_soft/A5\_hw\_eq).}")
    lines.append(r"\label{tab:sigma_decision}")
    lines.append(r"\setlength{\tabcolsep}{4pt}")
    lines.append(r"\begin{tabular}{llcccccc}")
    lines.append(r"\toprule")
    lines.append(r"$\sigma$ & Method & Accuracy & Macro-F1 & MeanAbsClassError & TailRecall@24 & TailRecall@28 & TailRecall@31 \\")
    lines.append(r"\midrule")
    for r in dec_rows:
        lines.append(
            " & ".join(
                [
                    r["sigma"],
                    _tex_escape(r["method"]),
                    _f4(r["accuracy"]),
                    _f4(r["macro_f1"]),
                    _f4(r["mean_abs_class_error"]),
                    _f4(r["tail_recall_24"]),
                    _f4(r["tail_recall_28"]),
                    _f4(r["tail_recall_31"]),
                ]
            )
            + r" \\"
        )
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table*}")
    return "\n".join(lines) + "\n"


def _tex_image_table(img_rows: Sequence[Dict[str, str]], has_strred: bool) -> str:
    lines: List[str] = []
    lines.append(r"\begin{table*}[t]")
    lines.append(r"\centering")
    lines.append(r"\caption{Sigma-wise image-level comparison (A2/A3/A4/A5\_soft/A5\_hw\_eq).}")
    lines.append(r"\label{tab:sigma_image}")
    lines.append(r"\setlength{\tabcolsep}{4pt}")
    if has_strred:
        lines.append(r"\begin{tabular}{llccc}")
        lines.append(r"\toprule")
        lines.append(r"$\sigma$ & Method & PSNR & SSIM & STRRED \\")
    else:
        lines.append(r"\begin{tabular}{llcc}")
        lines.append(r"\toprule")
        lines.append(r"$\sigma$ & Method & PSNR & SSIM \\")
    lines.append(r"\midrule")
    for r in img_rows:
        if has_strred:
            cols = [r["sigma"], _tex_escape(r["method"]), _f4(r["psnr"]), _f6(r["ssim"]), _f4(r["strred"])]
        else:
            cols = [r["sigma"], _tex_escape(r["method"]), _f4(r["psnr"]), _f6(r["ssim"])]
        lines.append(" & ".join(cols) + r" \\")
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table*}")
    return "\n".join(lines) + "\n"


def _avg_tail(d: Dict[str, Any]) -> float:
    tr = d.get("tail_recall", {})
    vals = [float(tr.get("24", np.nan)), float(tr.get("28", np.nan)), float(tr.get("31", np.nan))]
    vals = [x for x in vals if np.isfinite(x)]
    if len(vals) == 0:
        return float("nan")
    return float(np.mean(vals))


def _build_summary(
    sigmas: Sequence[int],
    dec_by_sigma: Dict[str, Dict[str, Dict[str, Any]]],
    img_by_sigma: Dict[str, Dict[str, Dict[str, float]]],
) -> str:
    ordinal_family = ["A3", "A4", "A5_soft", "A5_hw_eq"]
    a2_psnr_strong: List[int] = []
    a2_decision_strong: List[int] = []
    ordinal_decision_strong: List[int] = []
    tail_gain_by_sigma: Dict[int, float] = {}

    for s in sigmas:
        sk = str(int(s))
        a2_psnr = float(img_by_sigma[sk]["A2"]["psnr"])
        ord_psnr_best = max(float(img_by_sigma[sk][v]["psnr"]) for v in ordinal_family)
        if a2_psnr >= ord_psnr_best:
            a2_psnr_strong.append(int(s))

        a2_macro = float(dec_by_sigma[sk]["A2"]["macro_f1"])
        ord_macro_best = max(float(dec_by_sigma[sk][v]["macro_f1"]) for v in ordinal_family)
        if a2_macro >= ord_macro_best:
            a2_decision_strong.append(int(s))
        else:
            ordinal_decision_strong.append(int(s))

        a2_tail = _avg_tail(dec_by_sigma[sk]["A2"])
        ord_tail_best = max(_avg_tail(dec_by_sigma[sk][v]) for v in ordinal_family)
        tail_gain_by_sigma[int(s)] = float(ord_tail_best - a2_tail)

    sig_sorted = sorted(int(x) for x in sigmas)
    low_sigma = sig_sorted[0]
    high_sigma = sig_sorted[-1]
    low_gain = tail_gain_by_sigma[low_sigma]
    high_gain = tail_gain_by_sigma[high_sigma]
    high_two = [tail_gain_by_sigma[s] for s in sig_sorted if s >= 30]
    low_two = [tail_gain_by_sigma[s] for s in sig_sorted if s <= 30][:1] if len(sig_sorted) > 1 else [tail_gain_by_sigma[sig_sorted[0]]]
    high_mean = float(np.mean(high_two)) if len(high_two) > 0 else float("nan")
    low_mean = float(np.mean(low_two)) if len(low_two) > 0 else float("nan")
    tail_adv_hard = bool(high_mean >= low_mean)

    claim_support = bool((len(ordinal_decision_strong) > 0) and (high_gain >= low_gain))

    lines: List[str] = []
    lines.append("# Sigma Tail Summary")
    lines.append("")
    lines.append("## Q1: 哪些 sigma 下 A2 更强")
    lines.append("")
    lines.append(
        f"- 从 image-level（PSNR）看，A2 更强的 sigma: `{a2_psnr_strong}`。"
    )
    lines.append(
        f"- 从 decision-level（Macro-F1）看，A2 更强的 sigma: `{a2_decision_strong}`。"
    )
    lines.append("")
    lines.append("## Q2: 哪些 sigma 下 ordinal family 更强")
    lines.append("")
    lines.append(
        f"- 从 decision-level（Macro-F1）看，ordinal family 更强的 sigma: `{ordinal_decision_strong}`。"
    )
    lines.append("")
    lines.append("## Q3: tail recall 优势是否主要集中在高噪声/困难场景")
    lines.append("")
    lines.append(
        f"- best ordinal vs A2 的平均 tail recall 增益（@24/@28/@31 平均）: "
        f"sigma={low_sigma}: `{low_gain:+.4f}`, sigma={high_sigma}: `{high_gain:+.4f}`。"
    )
    lines.append(
        f"- 高噪声均值增益（sigma>=30）=`{high_mean:+.4f}`，低噪声参考增益=`{low_mean:+.4f}`，"
        f"结论：`{'是' if tail_adv_hard else '否'}`。"
    )
    lines.append("")
    lines.append("## Q4: 是否支持该结论")
    lines.append("")
    lines.append(
        "- 结论 `ordinal family is more advantageous in hard and tail-dominated regimes` "
        f"判定：`{'支持' if claim_support else '部分支持/证据不足'}`。"
    )
    lines.append("")
    lines.append("## 备注")
    lines.append("")
    lines.append("- A2 更偏向 image-level PSNR 优势。")
    lines.append("- Ordinal family 的价值主要体现在 decision 结构性与 tail-sensitive 指标。")
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = parse_args()
    metrics_path = Path(args.metrics_json)
    if not metrics_path.is_file():
        raise SystemExit(f"metrics json not found: {metrics_path}")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    metrics_payload = _load_json(metrics_path)
    cfg = metrics_payload["config"]
    sigmas = [int(x) for x in cfg["sigmas"]]

    missing = [v for v in TARGET_VARIANTS if v not in cfg["variants"]]
    if missing:
        raise SystemExit(f"target variants missing in metrics: {missing}")

    img_by_sigma, has_strred = _extract_image_by_sigma(metrics_payload, TARGET_VARIANTS)

    need_recompute = True
    if not args.force_recompute_decision_sigma and "decision_metrics_by_sigma" in metrics_payload:
        dms = metrics_payload["decision_metrics_by_sigma"]
        ok = True
        for s in sigmas:
            sk = str(int(s))
            if sk not in dms:
                ok = False
                break
            for v in TARGET_VARIANTS:
                if v not in dms[sk]:
                    ok = False
                    break
        if ok:
            need_recompute = False

    if need_recompute:
        print("[INFO] sigma-level decision metrics not found in metrics.json; recomputing under same protocol.")
        dec_by_sigma = _recompute_decision_by_sigma(
            metrics_payload=metrics_payload,
            eval09a_script=Path(args.eval09a_script),
            variants=TARGET_VARIANTS,
        )
    else:
        dec_by_sigma = metrics_payload["decision_metrics_by_sigma"]

    dec_rows = _build_decision_rows(dec_by_sigma, sigmas, TARGET_VARIANTS)
    img_rows = _build_image_rows(img_by_sigma, sigmas, TARGET_VARIANTS, has_strred)

    dec_md = _md_decision_table(dec_rows)
    img_md = _md_image_table(img_rows, has_strred=has_strred)
    dec_tex = _tex_decision_table(dec_rows)
    img_tex = _tex_image_table(img_rows, has_strred=has_strred)
    summary_md = _build_summary(sigmas, dec_by_sigma, img_by_sigma)

    fields_dec = [
        "sigma",
        "method",
        "method_name",
        "accuracy",
        "macro_f1",
        "mean_abs_class_error",
        "tail_recall_24",
        "tail_recall_28",
        "tail_recall_31",
    ]
    fields_img = ["sigma", "method", "method_name", "psnr", "ssim"] + (["strred"] if has_strred else [])

    _write_csv(out_dir / "sigma_decision_table.csv", dec_rows, fields_dec)
    _write_csv(out_dir / "sigma_image_table.csv", img_rows, fields_img)
    (out_dir / "sigma_decision_table.md").write_text(dec_md, encoding="utf-8")
    (out_dir / "sigma_image_table.md").write_text(img_md, encoding="utf-8")
    (out_dir / "table_sigma_decision.tex").write_text(dec_tex, encoding="utf-8")
    (out_dir / "table_sigma_image.tex").write_text(img_tex, encoding="utf-8")
    (out_dir / "sigma_tail_summary.md").write_text(summary_md, encoding="utf-8")

    export_payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "input_metrics_json": str(metrics_path),
        "target_variants": TARGET_VARIANTS,
        "sigmas": sigmas,
        "has_strred": bool(has_strred),
        "decision_by_sigma": dec_by_sigma,
        "image_by_sigma": img_by_sigma,
    }
    _write_json(out_dir / "sigma_tail_analysis.json", export_payload)

    print(f"[OUT] {out_dir / 'sigma_decision_table.md'}")
    print(f"[OUT] {out_dir / 'sigma_image_table.md'}")
    print(f"[OUT] {out_dir / 'sigma_tail_summary.md'}")
    print(f"[OUT] {out_dir / 'table_sigma_decision.tex'}")
    print(f"[OUT] {out_dir / 'table_sigma_image.tex'}")
    print(f"[OUT] {out_dir / 'sigma_tail_analysis.json'}")


if __name__ == "__main__":
    main()

