#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Paper-B ablation evaluation under Group-A unified protocol.

A0: Heuristic baseline
A1: Multiclass LightGBM
A2: Regression-quantization LightGBM
A3: Ordinal raw
A4: Ordinal + threshold tuning
A5: Final deployable ordinal (Ordinal + tuning + monotonic projection)
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np
from PIL import Image


IMG_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"}
METHODS = [
    "baseline",
    "multiclass",
    "reg_nearest",
    "ordinal_raw",
    "ordinal_tuned",
    "ordinal_deploy",
]

METHOD_DISPLAY = {
    "baseline": "A0 Heuristic baseline",
    "multiclass": "A1 Multiclass LightGBM",
    "reg_nearest": "A2 Regression-quantization LightGBM",
    "ordinal_raw": "A3 Ordinal raw",
    "ordinal_tuned": "A4 Ordinal + threshold tuning",
    "ordinal_deploy": "A5 Final deployable ordinal",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Evaluate Paper-B ablation variants under Group-A protocol.")
    p.add_argument(
        "--protocol_json",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_groupA_paperA_oraclefix\metrics_groupA_full.json",
        help="Use config from Group-A result JSON to keep protocol identical.",
    )
    p.add_argument(
        "--eval09a_script",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\09A_evaluate_groupA_full.py",
    )
    p.add_argument(
        "--out_dir",
        type=str,
        default=r"F:\EngineeringWarehouse\NR\3D_noise_reduction\script\out_eval_ablation_paperB",
    )
    return p.parse_args()


def load_py(path: Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import: {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def load_rgb(path: Path) -> np.ndarray:
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8)


def list_image_frames(seq_dir: Path, max_frames: int) -> List[Path]:
    frames = [p for p in seq_dir.iterdir() if p.is_file() and p.suffix.lower() in IMG_EXTS]
    frames = sorted(frames)
    if max_frames > 0:
        frames = frames[:max_frames]
    return frames


def discover_set8_sequences(set8_root: Path, max_frames: int) -> Dict[str, List[Path]]:
    seqs: Dict[str, List[Path]] = {}
    if not set8_root.is_dir():
        return seqs
    for d in set8_root.rglob("*"):
        if not d.is_dir():
            continue
        frames = list_image_frames(d, max_frames=0)
        if not frames:
            continue
        seq_name = d.name
        if seq_name in seqs:
            seq_name = str(d.relative_to(set8_root)).replace("\\", "/")
        seqs[seq_name] = frames[:max_frames] if max_frames > 0 else frames
    return dict(sorted(seqs.items(), key=lambda kv: kv[0]))


def summarize(values: Sequence[float]) -> Dict[str, float]:
    arr = np.asarray(values, dtype=np.float64)
    if arr.size == 0:
        return {"mean": float("nan"), "std": float("nan")}
    return {"mean": float(arr.mean()), "std": float(arr.std(ddof=0))}


class PredictorOrdinalDeploy:
    """
    Deployment-oriented ordinal inference:
    1) use tuned tau thresholds
    2) apply monotonic projection on binary comparator chain
    """

    def __init__(
        self,
        models: Sequence[Any],
        tau: np.ndarray,
        feature_names: Sequence[str],
        log1p_keys: Sequence[str],
        w_set: np.ndarray,
        eval09a_mod: Any,
    ):
        self.models = list(models)
        self.tau = np.asarray(tau, dtype=np.float32)
        self.feature_names = list(feature_names)
        self.log1p_keys = list(log1p_keys)
        self.w_set = np.asarray(w_set, dtype=np.uint8)
        self.eval09a = eval09a_mod

    def predict(self, feat_3d: np.ndarray, feat_names: np.ndarray) -> np.ndarray:
        h, w, _ = feat_3d.shape
        x = self.eval09a.align_and_preprocess_features(
            feat_3d=feat_3d,
            feat_names=feat_names,
            model_feature_names=self.feature_names,
            log1p_keys=self.log1p_keys,
        )
        p_cols: List[np.ndarray] = []
        for m in self.models:
            p = np.asarray(m.predict(x), dtype=np.float32)
            if p.ndim == 2 and p.shape[1] == 2:
                p = p[:, 1]
            p_cols.append(p.reshape(-1))
        p_mat = np.stack(p_cols, axis=1)
        if p_mat.shape[1] != self.tau.shape[0]:
            raise RuntimeError(f"tau dim mismatch: p={p_mat.shape}, tau={self.tau.shape}")

        # Comparator decisions
        b = (p_mat >= self.tau[None, :]).astype(np.uint8)
        # Monotonic projection for deployable comparator chain:
        # once a threshold fails, all higher thresholds are forced to fail.
        b_mono = np.minimum.accumulate(b, axis=1)
        rank = b_mono.sum(axis=1)
        rank = np.clip(rank, 0, len(self.w_set) - 1)
        pred = self.w_set[rank].astype(np.uint8)
        return pred.reshape(h, w)


def build_a1_markdown(decision_metrics: Dict[str, Dict[str, Any]]) -> str:
    lines = [
        "| Variant | Accuracy | Macro-F1 | MeanAbsClassError | TailRecall@24 | TailRecall@28 | TailRecall@31 |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for m in METHODS:
        met = decision_metrics[m]
        tr = met.get("tail_recall", {})
        lines.append(
            "| "
            + " | ".join(
                [
                    METHOD_DISPLAY[m],
                    f"{met['accuracy']:.4f}",
                    f"{met['macro_f1']:.4f}",
                    f"{met['mean_abs_class_error']:.4f}",
                    f"{float(tr.get('24', float('nan'))):.4f}",
                    f"{float(tr.get('28', float('nan'))):.4f}",
                    f"{float(tr.get('31', float('nan'))):.4f}",
                ]
            )
            + " |"
        )
    return "\n".join(lines)


def build_a2_markdown(results: Dict[str, Any], sigmas: Sequence[int]) -> str:
    lines = [
        "| Dataset & Variant | " + " | ".join([f"sigma={s}" for s in sigmas]) + " |",
        "|" + "---|" * (len(sigmas) + 1),
    ]
    for ds in ["DAVIS", "Set8"]:
        for m in METHODS:
            cells = []
            for s in sigmas:
                k = f"sigma_{s}"
                item = results[ds][k]["dataset_mean"][m]
                cells.append(f"{item['psnr']['mean']:.4f}/{item['ssim']['mean']:.6f}")
            lines.append("| " + " | ".join([f"{ds} - {METHOD_DISPLAY[m]}"] + cells) + " |")
    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    protocol_path = Path(args.protocol_json)
    if not protocol_path.is_file():
        raise SystemExit(f"protocol json not found: {protocol_path}")
    proto = json.loads(protocol_path.read_text(encoding="utf-8"))
    cfg = proto["config"]

    eval09a_path = Path(args.eval09a_script)
    eval09a = load_py(eval09a_path, "eval09a_for_09B")

    base_root = Path(cfg["base_root"])
    davis_jpeg_dir = Path(cfg["davis_jpeg_dir"])
    set8_dir = Path(cfg["set8_dir"])
    davis_clips = list(cfg["davis_clips"])
    sigmas = [int(x) for x in cfg["sigmas"]]
    max_frames = int(cfg["max_frames_per_seq"])
    seed = int(cfg["seed"])
    h_disp = int(cfg["h_disp"])
    v_disp = int(cfg["v_disp"])
    mb_size = int(cfg["mb_size"])
    baseline_temporal_weight = int(cfg["baseline_temporal_weight"])
    baseline_threshold = int(cfg["baseline_threshold"])
    w_set = np.asarray(cfg["w_set"], dtype=np.uint8)

    model_dir_mc = Path(cfg["model_dir_multiclass"])
    model_dir_reg = Path(cfg["model_dir_reg"])
    model_dir_ord = Path(cfg["model_dir_ordinal"])
    tau_tuned_json = Path(cfg["tau_tuned_json"])
    tdnr_py = base_root / "3dnr.py"
    oracle_lib_py = base_root / "oracle_lib.py"

    tdnr_mod = eval09a.load_module(tdnr_py, "tdnr_mod_09B")
    oracle_mod = eval09a.load_module(oracle_lib_py, "oracle_mod_09B")

    # Load predictors
    mc_cfg_feat, mc_cfg_log1p, mc_pred_mode = eval09a.load_train_config_feature_recipe(
        model_dir_mc,
        fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
        fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
    )
    mc_model_file = model_dir_mc / "models" / "lgbm_model_multiclass.txt"
    if not mc_model_file.is_file():
        mc_model_file = model_dir_mc / "lgbm_model_multiclass.txt"
    predictor_mc = eval09a.PredictorMulticlass(
        model_file=mc_model_file,
        feature_names=mc_cfg_feat,
        log1p_keys=mc_cfg_log1p,
        w_set=w_set,
        prediction_mode_metric=mc_pred_mode,
    )

    reg_cfg_feat, reg_cfg_log1p, _ = eval09a.load_train_config_feature_recipe(
        model_dir_reg,
        fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
        fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
    )
    reg_model_file = model_dir_reg / "models" / "lgbm_model_reg.txt"
    if not reg_model_file.is_file():
        reg_model_file = model_dir_reg / "lgbm_model_reg.txt"
    predictor_reg = eval09a.PredictorRegNearest(
        model_file=reg_model_file,
        feature_names=reg_cfg_feat,
        log1p_keys=reg_cfg_log1p,
        w_set=w_set,
    )

    ord_cfg_feat, ord_cfg_log1p, _ = eval09a.load_train_config_feature_recipe(
        model_dir_ord,
        fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
        fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
    )
    ord_models, ord_thresholds = eval09a.load_ordinal_models(model_dir_ord)
    tau_t_list, tau_tuned = eval09a.load_tau_json(tau_tuned_json)
    if not np.array_equal(ord_thresholds.astype(np.int32), tau_t_list.astype(np.int32)):
        raise RuntimeError(
            f"ordinal threshold mismatch: model={ord_thresholds.tolist()} vs tuned={tau_t_list.tolist()}"
        )
    tau_raw = np.full_like(tau_tuned, 0.5, dtype=np.float32)
    predictor_ord_raw = eval09a.PredictorOrdinal(
        models=ord_models,
        tau=tau_raw,
        feature_names=ord_cfg_feat,
        log1p_keys=ord_cfg_log1p,
        w_set=w_set,
    )
    predictor_ord_tuned = eval09a.PredictorOrdinal(
        models=ord_models,
        tau=tau_tuned,
        feature_names=ord_cfg_feat,
        log1p_keys=ord_cfg_log1p,
        w_set=w_set,
    )
    predictor_ord_deploy = PredictorOrdinalDeploy(
        models=ord_models,
        tau=tau_tuned,
        feature_names=ord_cfg_feat,
        log1p_keys=ord_cfg_log1p,
        w_set=w_set,
        eval09a_mod=eval09a,
    )

    # Discover sequences
    davis_sequences: Dict[str, List[Path]] = {}
    for clip in davis_clips:
        cdir = davis_jpeg_dir / clip
        if not cdir.is_dir():
            print(f"[WARN] DAVIS clip not found: {clip}")
            continue
        frames = list_image_frames(cdir, max_frames=max_frames)
        if frames:
            davis_sequences[clip] = frames
    set8_sequences = discover_set8_sequences(set8_dir, max_frames=max_frames)
    datasets = {"DAVIS": davis_sequences, "Set8": set8_sequences}

    shape_helper = tdnr_mod.ThreeDNR(
        h_disp=h_disp,
        v_disp=v_disp,
        temporal_weight=baseline_temporal_weight,
        mb_threshold=baseline_threshold,
    )

    results: Dict[str, Any] = {"DAVIS": {}, "Set8": {}}
    frame_values: Dict[str, Dict[str, Dict[str, Dict[str, List[float]]]]] = {
        "DAVIS": {},
        "Set8": {},
    }
    decision_true: Dict[str, List[np.ndarray]] = {m: [] for m in METHODS}
    decision_pred: Dict[str, List[np.ndarray]] = {m: [] for m in METHODS}

    print(f"[INFO] Protocol from: {protocol_path}")
    print(f"[INFO] DAVIS clips: {list(davis_sequences.keys())}")
    print(f"[INFO] Set8 sequence count: {len(set8_sequences)}")
    print(f"[INFO] Sigmas: {sigmas}")
    print(f"[INFO] max_frames_per_seq: {max_frames}")
    print(f"[INFO] Output dir: {out_dir}")

    for dsi, (dataset_name, seq_map) in enumerate(datasets.items()):
        for sigma in sigmas:
            sigma_key = f"sigma_{sigma}"
            results[dataset_name][sigma_key] = {"clips": {}, "dataset_mean": {}}
            frame_values[dataset_name][sigma_key] = {}

            for seqi, (seq_name, frames) in enumerate(seq_map.items()):
                seq_seed = int(seed) + int(sigma) * 10007 + int(dsi) * 1000003 + int(seqi) * 1009
                rng = np.random.default_rng(seq_seed)

                baseline_nr = tdnr_mod.ThreeDNR(
                    h_disp=h_disp,
                    v_disp=v_disp,
                    temporal_weight=baseline_temporal_weight,
                    mb_threshold=baseline_threshold,
                )
                me_holder = tdnr_mod.ThreeDNR(
                    h_disp=h_disp,
                    v_disp=v_disp,
                    temporal_weight=baseline_temporal_weight,
                    mb_threshold=baseline_threshold,
                )
                prev_out: Dict[str, np.ndarray | None] = {m: None for m in METHODS}
                prev_noisy_common: np.ndarray | None = None

                frame_values[dataset_name][sigma_key][seq_name] = {
                    m: {"psnr": [], "ssim": []} for m in METHODS
                }

                n = len(frames)
                for fi, fp in enumerate(frames, start=1):
                    clean_raw = load_rgb(fp)
                    clean = shape_helper._ensure_resolution(clean_raw)
                    noisy = np.clip(
                        clean.astype(np.float32) + rng.normal(0.0, float(sigma), clean.shape),
                        0.0,
                        255.0,
                    ).astype(np.uint8)
                    ref_common = prev_noisy_common if prev_noisy_common is not None else noisy
                    oracle_common = oracle_mod.oracle_label_w(
                        cur_noisy=noisy,
                        ref_noisy=ref_common,
                        gt=clean,
                        w_set=w_set,
                        temporal_iir_filter_fn=tdnr_mod.temporal_iir_filter,
                        mb_size=mb_size,
                    ).astype(np.uint8)
                    prev_noisy_common = noisy

                    outputs: Dict[str, np.ndarray] = {}

                    # A0 baseline
                    ref_base = prev_out["baseline"] if prev_out["baseline"] is not None else noisy
                    w_base = eval09a.build_baseline_wmap(
                        cur_noisy=noisy,
                        ref_img=ref_base,
                        baseline_nr=baseline_nr,
                        tdnr_mod=tdnr_mod,
                        temporal_weight=baseline_temporal_weight,
                    )
                    out_base = baseline_nr.process(noisy, ref_base)
                    prev_out["baseline"] = out_base
                    outputs["baseline"] = out_base
                    decision_true["baseline"].append(oracle_common.reshape(-1))
                    decision_pred["baseline"].append(w_base.reshape(-1))

                    # Common feature extraction helper
                    def get_feat(ref_img: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
                        return eval09a.build_feature_v2_for_infer(
                            cur_noisy=noisy,
                            ref_img=ref_img,
                            tdnr_mod=tdnr_mod,
                            oracle_mod=oracle_mod,
                            me_obj=me_holder.me_td,
                            mb_size=mb_size,
                        )

                    # A1 multiclass
                    ref_mc = prev_out["multiclass"] if prev_out["multiclass"] is not None else noisy
                    feat_mc, feat_names_mc = get_feat(ref_mc)
                    w_mc = predictor_mc.predict(feat_mc, feat_names_mc)
                    out_mc = eval09a.temporal_blend_with_wmap(noisy, ref_mc, w_mc, mb_size=mb_size)
                    prev_out["multiclass"] = out_mc
                    outputs["multiclass"] = out_mc
                    decision_true["multiclass"].append(oracle_common.reshape(-1))
                    decision_pred["multiclass"].append(w_mc.reshape(-1))

                    # A2 regression-quantization
                    ref_reg = prev_out["reg_nearest"] if prev_out["reg_nearest"] is not None else noisy
                    feat_reg, feat_names_reg = get_feat(ref_reg)
                    w_reg = predictor_reg.predict(feat_reg, feat_names_reg)
                    out_reg = eval09a.temporal_blend_with_wmap(noisy, ref_reg, w_reg, mb_size=mb_size)
                    prev_out["reg_nearest"] = out_reg
                    outputs["reg_nearest"] = out_reg
                    decision_true["reg_nearest"].append(oracle_common.reshape(-1))
                    decision_pred["reg_nearest"].append(w_reg.reshape(-1))

                    # A3 ordinal raw
                    ref_or = prev_out["ordinal_raw"] if prev_out["ordinal_raw"] is not None else noisy
                    feat_or, feat_names_or = get_feat(ref_or)
                    w_or = predictor_ord_raw.predict(feat_or, feat_names_or)
                    out_or = eval09a.temporal_blend_with_wmap(noisy, ref_or, w_or, mb_size=mb_size)
                    prev_out["ordinal_raw"] = out_or
                    outputs["ordinal_raw"] = out_or
                    decision_true["ordinal_raw"].append(oracle_common.reshape(-1))
                    decision_pred["ordinal_raw"].append(w_or.reshape(-1))

                    # A4 ordinal tuned
                    ref_ot = prev_out["ordinal_tuned"] if prev_out["ordinal_tuned"] is not None else noisy
                    feat_ot, feat_names_ot = get_feat(ref_ot)
                    w_ot = predictor_ord_tuned.predict(feat_ot, feat_names_ot)
                    out_ot = eval09a.temporal_blend_with_wmap(noisy, ref_ot, w_ot, mb_size=mb_size)
                    prev_out["ordinal_tuned"] = out_ot
                    outputs["ordinal_tuned"] = out_ot
                    decision_true["ordinal_tuned"].append(oracle_common.reshape(-1))
                    decision_pred["ordinal_tuned"].append(w_ot.reshape(-1))

                    # A5 deployable ordinal
                    ref_od = prev_out["ordinal_deploy"] if prev_out["ordinal_deploy"] is not None else noisy
                    feat_od, feat_names_od = get_feat(ref_od)
                    w_od = predictor_ord_deploy.predict(feat_od, feat_names_od)
                    out_od = eval09a.temporal_blend_with_wmap(noisy, ref_od, w_od, mb_size=mb_size)
                    prev_out["ordinal_deploy"] = out_od
                    outputs["ordinal_deploy"] = out_od
                    decision_true["ordinal_deploy"].append(oracle_common.reshape(-1))
                    decision_pred["ordinal_deploy"].append(w_od.reshape(-1))

                    for m in METHODS:
                        p, s = eval09a.compute_psnr_ssim(clean, outputs[m])
                        frame_values[dataset_name][sigma_key][seq_name][m]["psnr"].append(p)
                        frame_values[dataset_name][sigma_key][seq_name][m]["ssim"].append(s)

                    if fi == 1 or fi == n or (fi % 10 == 0):
                        print(
                            f"[ABLATION] [{dataset_name}] '{seq_name}' sigma={sigma} frame {fi}/{n} done"
                        )

                clip_store: Dict[str, Any] = {}
                for m in METHODS:
                    ps = frame_values[dataset_name][sigma_key][seq_name][m]["psnr"]
                    ss = frame_values[dataset_name][sigma_key][seq_name][m]["ssim"]
                    clip_store[m] = {
                        "psnr": summarize(ps),
                        "ssim": summarize(ss),
                        "num_frames": int(len(ps)),
                    }
                results[dataset_name][sigma_key]["clips"][seq_name] = clip_store

            for m in METHODS:
                all_ps: List[float] = []
                all_ss: List[float] = []
                for seq_name in frame_values[dataset_name][sigma_key]:
                    all_ps.extend(frame_values[dataset_name][sigma_key][seq_name][m]["psnr"])
                    all_ss.extend(frame_values[dataset_name][sigma_key][seq_name][m]["ssim"])
                results[dataset_name][sigma_key]["dataset_mean"][m] = {
                    "psnr": summarize(all_ps),
                    "ssim": summarize(all_ss),
                    "num_frames": int(len(all_ps)),
                }

    decision_metrics: Dict[str, Dict[str, Any]] = {}
    for m in METHODS:
        yt = np.concatenate(decision_true[m], axis=0).astype(np.uint8) if decision_true[m] else np.array([], dtype=np.uint8)
        yp = np.concatenate(decision_pred[m], axis=0).astype(np.uint8) if decision_pred[m] else np.array([], dtype=np.uint8)
        decision_metrics[m] = eval09a.compute_decision_metrics(yt, yp, w_set)

    # Required extra export: confusion/hist for A3/A4/A5
    for m in ["ordinal_raw", "ordinal_tuned", "ordinal_deploy"]:
        yt = np.concatenate(decision_true[m], axis=0).astype(np.uint8) if decision_true[m] else np.array([], dtype=np.uint8)
        yp = np.concatenate(decision_pred[m], axis=0).astype(np.uint8) if decision_pred[m] else np.array([], dtype=np.uint8)
        eval09a.save_confusion_and_hist(out_dir / "figures", m, yt, yp, w_set)

    table_b1_md = build_a1_markdown(decision_metrics)
    table_b2_md = build_a2_markdown(results, sigmas)

    payload = {
        "config": {
            "protocol_json": str(protocol_path),
            "base_root": str(base_root),
            "davis_jpeg_dir": str(davis_jpeg_dir),
            "set8_dir": str(set8_dir),
            "davis_clips": davis_clips,
            "sigmas": sigmas,
            "max_frames_per_seq": max_frames,
            "seed": seed,
            "h_disp": h_disp,
            "v_disp": v_disp,
            "mb_size": mb_size,
            "baseline_temporal_weight": baseline_temporal_weight,
            "baseline_threshold": baseline_threshold,
            "w_set": [int(x) for x in w_set.tolist()],
            "model_dir_multiclass": str(model_dir_mc),
            "model_dir_reg": str(model_dir_reg),
            "model_dir_ordinal": str(model_dir_ord),
            "tau_tuned_json": str(tau_tuned_json),
            "methods": METHODS,
            "method_display": METHOD_DISPLAY,
            "ordinal_thresholds": [int(x) for x in ord_thresholds.tolist()],
            "deploy_note": "A5 uses tuned thresholds plus monotonic projection on comparator decisions in inference stage.",
        },
        "results": results,
        "decision_metrics": decision_metrics,
        "table_B1_decision_markdown": table_b1_md,
        "table_B2_image_markdown": table_b2_md,
    }

    out_json = out_dir / "metrics_ablation_full.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    report_lines = [
        "# Paper-B Ablation Evaluation Report",
        "",
        "## Run Command",
        "",
        "```powershell",
        f"python -u .\\script\\09B_evaluate_ablation_full.py --protocol_json \"{protocol_path}\" --out_dir \"{out_dir}\"",
        "```",
        "",
        "## Experiment Config",
        "",
        "```json",
        json.dumps(payload["config"], ensure_ascii=False, indent=2),
        "```",
        "",
        "## Table B1: Decision-level Ablation",
        "",
        table_b1_md,
        "",
        "## Table B2: Image-level Ablation (PSNR/SSIM)",
        "",
        table_b2_md,
        "",
        "## Output Files",
        "",
        f"- `{out_json}`",
        f"- `{out_dir / 'figures'}` (confusion matrices and error histograms for A3/A4/A5)",
    ]
    (out_dir / "ablation_report.md").write_text("\n".join(report_lines), encoding="utf-8")

    print("\n=== Table B1: Decision-level Ablation ===")
    print(table_b1_md)
    print("\n=== Table B2: Image-level Ablation ===")
    print(table_b2_md)
    print(f"\n[OUT] {out_json}")
    print(f"[OUT] {out_dir / 'ablation_report.md'}")


if __name__ == "__main__":
    main()
