#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import annotations

import csv
import importlib.util
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Sequence, Tuple

import numpy as np


VARIANT_ORDER: List[str] = ["A0", "A1", "A2", "A3", "A4", "A5_soft", "A5_hw_eq"]
VARIANT_DISPLAY: Dict[str, str] = {
    "A0": "A0 Heuristic baseline",
    "A1": "A1 Multiclass LightGBM",
    "A2": "A2 Regression-quantization LightGBM",
    "A3": "A3 Ordinal raw",
    "A4": "A4 Ordinal + threshold tuning",
    "A5_soft": "A5_soft Software deployable mapping",
    "A5_hw_eq": "A5_hw_eq Exported hardware-equivalent mapping",
}
DATASET_NAME_MAP: Dict[str, str] = {"davis": "DAVIS", "set8": "Set8"}


def parse_variant_arg(text: str) -> List[str]:
    t = text.strip()
    if t.lower() == "all":
        return list(VARIANT_ORDER)
    items = [x.strip() for x in t.split(",") if x.strip()]
    if len(items) == 0:
        raise ValueError("variant cannot be empty")
    bad = [x for x in items if x not in VARIANT_ORDER]
    if bad:
        raise ValueError(f"unknown variants: {bad}, valid={VARIANT_ORDER}")
    out: List[str] = []
    for x in items:
        if x not in out:
            out.append(x)
    return out


def parse_dataset_arg(text: str) -> List[str]:
    t = text.strip().lower()
    if t == "all":
        return ["DAVIS", "Set8"]
    if t not in DATASET_NAME_MAP:
        raise ValueError(f"unknown dataset={text!r}, valid=['davis','set8','all']")
    return [DATASET_NAME_MAP[t]]


def parse_sigma_arg(text: str, protocol_sigmas: Sequence[int]) -> List[int]:
    t = text.strip().lower()
    if t == "all":
        vals = [int(x) for x in protocol_sigmas]
        if len(vals) == 0:
            raise ValueError("protocol sigmas are empty; cannot use sigma=all")
        return vals
    parts = [x.strip() for x in text.split(",") if x.strip()]
    if len(parts) == 0:
        raise ValueError("sigma cannot be empty")
    vals = [int(x) for x in parts]
    out: List[int] = []
    for x in vals:
        if x not in out:
            out.append(x)
    return out


def load_py(path: Path, module_name: str) -> Any:
    if not path.is_file():
        raise FileNotFoundError(f"python module not found: {path}")
    spec = importlib.util.spec_from_file_location(module_name, str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import module from {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = mod
    spec.loader.exec_module(mod)
    return mod


def read_json(path: Path) -> Any:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def default_protocol_config(base_root: Path) -> Dict[str, Any]:
    return {
        "base_root": str(base_root),
        "davis_jpeg_dir": str(base_root / "DAVIS-2017-trainval-480p" / "DAVIS" / "JPEGImages" / "480p"),
        "set8_dir": str(base_root / "Set8"),
        "davis_clips": ["surf", "bear", "bmx-trees"],
        "sigmas": [10, 30, 50],
        "max_frames_per_seq": 12,
        "seed": 123,
        "h_disp": 480,
        "v_disp": 320,
        "mb_size": 4,
        "baseline_temporal_weight": 16,
        "baseline_threshold": 4095,
        "w_set": [0, 4, 8, 12, 16, 20, 24, 28, 31],
        "model_dir_multiclass": str(base_root / "out_train_multiclass"),
        "model_dir_reg": str(base_root / "out_train_reg"),
        "model_dir_ordinal": str(base_root / "out_train_ord_v2_full"),
        "tau_tuned_json": str(base_root / "out_ordinal_tune_v2_full" / "report" / "taus_monotone.json"),
        "tdnr_py": str(base_root / "3dnr.py"),
        "oracle_lib_py": str(base_root / "oracle_lib.py"),
    }


def load_protocol_config(base_root: Path, protocol_json: Optional[Path]) -> Dict[str, Any]:
    cfg = default_protocol_config(base_root)
    if protocol_json is None:
        return cfg
    if not protocol_json.is_file():
        raise FileNotFoundError(f"protocol_json not found: {protocol_json}")
    payload = read_json(protocol_json)
    if not isinstance(payload, dict) or "config" not in payload:
        raise ValueError(f"invalid protocol json (missing `config`): {protocol_json}")
    in_cfg = payload["config"]
    if not isinstance(in_cfg, dict):
        raise ValueError(f"invalid protocol json `config` type: {type(in_cfg)}")
    for k in cfg.keys():
        if k in in_cfg:
            cfg[k] = in_cfg[k]
    cfg["protocol_json"] = str(protocol_json)
    return cfg


def apply_protocol_overrides(
    cfg: Dict[str, Any],
    seed: Optional[int],
    max_frames_per_seq: Optional[int],
    model_dir_multiclass: Optional[str],
    model_dir_reg: Optional[str],
    model_dir_ordinal: Optional[str],
    tau_tuned_json: Optional[str],
) -> Dict[str, Any]:
    out = dict(cfg)
    if seed is not None:
        out["seed"] = int(seed)
    if max_frames_per_seq is not None:
        out["max_frames_per_seq"] = int(max_frames_per_seq)
    if model_dir_multiclass:
        out["model_dir_multiclass"] = model_dir_multiclass
    if model_dir_reg:
        out["model_dir_reg"] = model_dir_reg
    if model_dir_ordinal:
        out["model_dir_ordinal"] = model_dir_ordinal
    if tau_tuned_json:
        out["tau_tuned_json"] = tau_tuned_json
    return out


@dataclass
class PredictorBundle:
    predictors: Dict[str, Any]
    w_set: np.ndarray
    tau_tuned: np.ndarray
    tau_thresholds: np.ndarray
    source_paths: Dict[str, str]


class PredictorOrdinalDeploySoft:
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
        b = (p_mat >= self.tau[None, :]).astype(np.uint8)
        b_mono = np.minimum.accumulate(b, axis=1)
        rank = b_mono.sum(axis=1)
        rank = np.clip(rank, 0, len(self.w_set) - 1)
        pred = self.w_set[rank].astype(np.uint8)
        return pred.reshape(h, w)


class PredictorOrdinalHwEq:
    """
    Minimal hardware-equivalent simulation in Python:
    - fixed-point comparator on p_k and tau_k
    - monotonic comparator chain projection
    - LUT rank->w_set mapping
    """

    def __init__(
        self,
        models: Sequence[Any],
        tau: np.ndarray,
        feature_names: Sequence[str],
        log1p_keys: Sequence[str],
        w_set: np.ndarray,
        eval09a_mod: Any,
        prob_scale: int = 4096,
    ):
        self.models = list(models)
        self.tau = np.asarray(tau, dtype=np.float32)
        self.feature_names = list(feature_names)
        self.log1p_keys = list(log1p_keys)
        self.w_set = np.asarray(w_set, dtype=np.uint8)
        self.eval09a = eval09a_mod
        self.prob_scale = int(prob_scale)
        if self.prob_scale <= 0:
            raise ValueError("prob_scale must be positive")
        self.tau_fp = np.rint(np.clip(self.tau, 0.0, 1.0) * self.prob_scale).astype(np.int32)

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
        p_fp = np.rint(np.clip(p_mat, 0.0, 1.0) * self.prob_scale).astype(np.int32)
        b = (p_fp >= self.tau_fp[None, :]).astype(np.uint8)
        b_mono = np.minimum.accumulate(b, axis=1)
        rank = b_mono.sum(axis=1)
        rank = np.clip(rank, 0, len(self.w_set) - 1)
        pred = self.w_set[rank].astype(np.uint8)
        return pred.reshape(h, w)


def _require_file(path: Path, name: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"required file not found for {name}: {path}")


def _resolve_model_file(path_a: Path, path_b: Path, name: str) -> Path:
    if path_a.is_file():
        return path_a
    if path_b.is_file():
        return path_b
    raise FileNotFoundError(f"{name} not found: tried {path_a} and {path_b}")


def prepare_predictor_bundle(
    eval09a: Any,
    cfg: Dict[str, Any],
    variants: Sequence[str],
    hw_prob_scale: int = 4096,
) -> PredictorBundle:
    w_set = np.asarray(cfg["w_set"], dtype=np.uint8)
    model_dir_mc = Path(cfg["model_dir_multiclass"])
    model_dir_reg = Path(cfg["model_dir_reg"])
    model_dir_ord = Path(cfg["model_dir_ordinal"])
    tau_tuned_json = Path(cfg["tau_tuned_json"])

    predictors: Dict[str, Any] = {}
    source_paths: Dict[str, str] = {
        "model_dir_multiclass": str(model_dir_mc),
        "model_dir_reg": str(model_dir_reg),
        "model_dir_ordinal": str(model_dir_ord),
        "tau_tuned_json": str(tau_tuned_json),
    }

    tau_thresholds = np.array([], dtype=np.int32)
    tau_tuned = np.array([], dtype=np.float32)

    need_mc = "A1" in variants
    need_reg = "A2" in variants
    need_ord = any(x in variants for x in ["A3", "A4", "A5_soft", "A5_hw_eq"])

    if need_mc:
        mc_cfg_feat, mc_cfg_log1p, mc_pred_mode = eval09a.load_train_config_feature_recipe(
            model_dir_mc,
            fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
            fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
        )
        mc_model_file = _resolve_model_file(
            model_dir_mc / "models" / "lgbm_model_multiclass.txt",
            model_dir_mc / "lgbm_model_multiclass.txt",
            "multiclass model",
        )
        predictors["A1"] = eval09a.PredictorMulticlass(
            model_file=mc_model_file,
            feature_names=mc_cfg_feat,
            log1p_keys=mc_cfg_log1p,
            w_set=w_set,
            prediction_mode_metric=mc_pred_mode,
        )
        source_paths["multiclass_model_file"] = str(mc_model_file)

    if need_reg:
        reg_cfg_feat, reg_cfg_log1p, _ = eval09a.load_train_config_feature_recipe(
            model_dir_reg,
            fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
            fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
        )
        reg_model_file = _resolve_model_file(
            model_dir_reg / "models" / "lgbm_model_reg.txt",
            model_dir_reg / "lgbm_model_reg.txt",
            "regression model",
        )
        predictors["A2"] = eval09a.PredictorRegNearest(
            model_file=reg_model_file,
            feature_names=reg_cfg_feat,
            log1p_keys=reg_cfg_log1p,
            w_set=w_set,
        )
        source_paths["reg_model_file"] = str(reg_model_file)

    if need_ord:
        ord_cfg_feat, ord_cfg_log1p, _ = eval09a.load_train_config_feature_recipe(
            model_dir_ord,
            fallback_feature_names=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "mv_mag", "sum", "grad_energy"],
            fallback_log1p_keys=["sad1_ds", "sad2_ds", "margin_ds", "sad1_mb_best", "grad_energy", "sum"],
        )
        ord_models, ord_thresholds = eval09a.load_ordinal_models(model_dir_ord)
        tau_t_list, tau = eval09a.load_tau_json(tau_tuned_json)
        if not np.array_equal(ord_thresholds.astype(np.int32), tau_t_list.astype(np.int32)):
            raise RuntimeError(
                f"ordinal threshold mismatch: model={ord_thresholds.tolist()} vs tuned={tau_t_list.tolist()}"
            )
        tau_thresholds = tau_t_list.astype(np.int32)
        tau_tuned = tau.astype(np.float32)

        tau_raw = np.full_like(tau_tuned, 0.5, dtype=np.float32)
        if "A3" in variants:
            predictors["A3"] = eval09a.PredictorOrdinal(
                models=ord_models,
                tau=tau_raw,
                feature_names=ord_cfg_feat,
                log1p_keys=ord_cfg_log1p,
                w_set=w_set,
            )
        if "A4" in variants:
            predictors["A4"] = eval09a.PredictorOrdinal(
                models=ord_models,
                tau=tau_tuned,
                feature_names=ord_cfg_feat,
                log1p_keys=ord_cfg_log1p,
                w_set=w_set,
            )
        if "A5_soft" in variants:
            predictors["A5_soft"] = PredictorOrdinalDeploySoft(
                models=ord_models,
                tau=tau_tuned,
                feature_names=ord_cfg_feat,
                log1p_keys=ord_cfg_log1p,
                w_set=w_set,
                eval09a_mod=eval09a,
            )
        if "A5_hw_eq" in variants:
            predictors["A5_hw_eq"] = PredictorOrdinalHwEq(
                models=ord_models,
                tau=tau_tuned,
                feature_names=ord_cfg_feat,
                log1p_keys=ord_cfg_log1p,
                w_set=w_set,
                eval09a_mod=eval09a,
                prob_scale=hw_prob_scale,
            )

        source_paths["ordinal_model_dir"] = str(model_dir_ord)
        source_paths["tau_thresholds_T"] = ",".join(str(int(x)) for x in tau_thresholds.tolist())
        source_paths["hw_prob_scale"] = str(int(hw_prob_scale))

    return PredictorBundle(
        predictors=predictors,
        w_set=w_set,
        tau_tuned=tau_tuned,
        tau_thresholds=tau_thresholds,
        source_paths=source_paths,
    )


def build_sequence_map(
    eval09a: Any,
    cfg: Dict[str, Any],
    datasets: Sequence[str],
) -> Dict[str, Dict[str, List[Path]]]:
    max_frames = int(cfg["max_frames_per_seq"])
    out: Dict[str, Dict[str, List[Path]]] = {}
    if "DAVIS" in datasets:
        davis_dir = Path(cfg["davis_jpeg_dir"])
        if not davis_dir.is_dir():
            raise FileNotFoundError(f"DAVIS directory not found: {davis_dir}")
        davis_clips = [str(x) for x in cfg["davis_clips"]]
        seqs: Dict[str, List[Path]] = {}
        for clip in davis_clips:
            cdir = davis_dir / clip
            if not cdir.is_dir():
                print(f"[WARN] DAVIS clip not found: {clip}")
                continue
            frames = eval09a.list_image_frames(cdir, max_frames=max_frames)
            if len(frames) > 0:
                seqs[clip] = frames
        out["DAVIS"] = seqs
    if "Set8" in datasets:
        set8_dir = Path(cfg["set8_dir"])
        if not set8_dir.is_dir():
            raise FileNotFoundError(f"Set8 directory not found: {set8_dir}")
        out["Set8"] = eval09a.discover_set8_sequences(set8_dir, max_frames=max_frames)
    return out


def _summarize(arr: Sequence[float]) -> Dict[str, float]:
    x = np.asarray(arr, dtype=np.float64)
    if x.size == 0:
        return {"mean": float("nan"), "std": float("nan")}
    return {"mean": float(x.mean()), "std": float(x.std(ddof=0))}


FrameCallback = Callable[[Dict[str, Any]], None]


def evaluate_variants(
    eval09a: Any,
    tdnr_mod: Any,
    oracle_mod: Any,
    cfg: Dict[str, Any],
    variants: Sequence[str],
    datasets: Sequence[str],
    sigmas: Sequence[int],
    predictor_bundle: PredictorBundle,
    compute_strred: bool = False,
    frame_callback: Optional[FrameCallback] = None,
    progress_tag: str = "UNIFIED",
) -> Dict[str, Any]:
    if len(variants) == 0:
        raise ValueError("variants is empty")
    if len(datasets) == 0:
        raise ValueError("datasets is empty")
    if len(sigmas) == 0:
        raise ValueError("sigmas is empty")

    sequence_map = build_sequence_map(eval09a, cfg, datasets)
    results: Dict[str, Any] = {k: {} for k in datasets}
    frame_values: Dict[str, Dict[str, Dict[str, Dict[str, Dict[str, List[float]]]]]] = {
        k: {} for k in datasets
    }
    strred_values: Dict[str, Dict[str, Dict[str, List[float]]]] = {k: {} for k in datasets}
    decision_true: Dict[str, List[np.ndarray]] = {v: [] for v in variants}
    decision_pred: Dict[str, List[np.ndarray]] = {v: [] for v in variants}

    h_disp = int(cfg["h_disp"])
    v_disp = int(cfg["v_disp"])
    mb_size = int(cfg["mb_size"])
    baseline_temporal_weight = int(cfg["baseline_temporal_weight"])
    baseline_threshold = int(cfg["baseline_threshold"])
    seed = int(cfg["seed"])
    w_set = predictor_bundle.w_set

    shape_helper = tdnr_mod.ThreeDNR(
        h_disp=h_disp,
        v_disp=v_disp,
        temporal_weight=baseline_temporal_weight,
        mb_threshold=baseline_threshold,
    )

    print(f"[INFO] [{progress_tag}] datasets={datasets} sigmas={list(sigmas)} variants={list(variants)}")

    for dsi, dataset_name in enumerate(datasets):
        seq_map = sequence_map.get(dataset_name, {})
        for sigma in sigmas:
            sigma_key = f"sigma_{int(sigma)}"
            results[dataset_name][sigma_key] = {"clips": {}, "dataset_mean": {}}
            frame_values[dataset_name][sigma_key] = {}
            if compute_strred:
                strred_values[dataset_name][sigma_key] = {v: [] for v in variants}

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
                prev_out: Dict[str, Optional[np.ndarray]] = {v: None for v in variants}
                prev_noisy_common: Optional[np.ndarray] = None

                frame_values[dataset_name][sigma_key][seq_name] = {
                    v: {"psnr": [], "ssim": []} for v in variants
                }
                if compute_strred:
                    seq_clean_gray: List[np.ndarray] = []
                    seq_pred_gray: Dict[str, List[np.ndarray]] = {v: [] for v in variants}

                n = len(frames)
                for fi, fp in enumerate(frames, start=1):
                    clean_raw = eval09a.load_rgb(fp)
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
                    w_maps: Dict[str, np.ndarray] = {}
                    frame_metric_this: Dict[str, Dict[str, float]] = {}

                    def get_feat(ref_img: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
                        return eval09a.build_feature_v2_for_infer(
                            cur_noisy=noisy,
                            ref_img=ref_img,
                            tdnr_mod=tdnr_mod,
                            oracle_mod=oracle_mod,
                            me_obj=me_holder.me_td,
                            mb_size=mb_size,
                        )

                    for v in variants:
                        ref_v = prev_out[v] if prev_out[v] is not None else noisy
                        if v == "A0":
                            w_v = eval09a.build_baseline_wmap(
                                cur_noisy=noisy,
                                ref_img=ref_v,
                                baseline_nr=baseline_nr,
                                tdnr_mod=tdnr_mod,
                                temporal_weight=baseline_temporal_weight,
                            )
                            out_v = baseline_nr.process(noisy, ref_v)
                        else:
                            feat_v, feat_names_v = get_feat(ref_v)
                            pred_obj = predictor_bundle.predictors.get(v, None)
                            if pred_obj is None:
                                raise RuntimeError(f"predictor not prepared for variant={v}")
                            w_v = pred_obj.predict(feat_v, feat_names_v)
                            out_v = eval09a.temporal_blend_with_wmap(noisy, ref_v, w_v, mb_size=mb_size)

                        prev_out[v] = out_v
                        outputs[v] = out_v
                        w_maps[v] = w_v
                        decision_true[v].append(oracle_common.reshape(-1))
                        decision_pred[v].append(w_v.reshape(-1))

                        p, s = eval09a.compute_psnr_ssim(clean, out_v)
                        frame_values[dataset_name][sigma_key][seq_name][v]["psnr"].append(p)
                        frame_values[dataset_name][sigma_key][seq_name][v]["ssim"].append(s)
                        frame_metric_this[v] = {"psnr": float(p), "ssim": float(s)}

                    if compute_strred:
                        clean_gray = oracle_mod.rgb_to_luma_u8(clean)
                        seq_clean_gray.append(clean_gray)
                        for v in variants:
                            seq_pred_gray[v].append(oracle_mod.rgb_to_luma_u8(outputs[v]))

                    if frame_callback is not None:
                        frame_callback(
                            {
                                "dataset": dataset_name,
                                "sigma": int(sigma),
                                "seq_name": seq_name,
                                "frame_idx": int(fi),
                                "clean": clean,
                                "noisy": noisy,
                                "oracle_common": oracle_common,
                                "outputs": outputs,
                                "w_maps": w_maps,
                                "frame_metrics": frame_metric_this,
                            }
                        )

                    if fi == 1 or fi == n or (fi % 10 == 0):
                        print(f"[{progress_tag}] [{dataset_name}] '{seq_name}' sigma={sigma} frame {fi}/{n} done")

                clip_store: Dict[str, Any] = {}
                for v in variants:
                    ps = frame_values[dataset_name][sigma_key][seq_name][v]["psnr"]
                    ss = frame_values[dataset_name][sigma_key][seq_name][v]["ssim"]
                    clip_store[v] = {"psnr": _summarize(ps), "ssim": _summarize(ss), "num_frames": int(len(ps))}
                results[dataset_name][sigma_key]["clips"][seq_name] = clip_store

                if compute_strred:
                    clean_vid = np.stack(seq_clean_gray, axis=0).astype(np.uint8)
                    for v in variants:
                        pred_vid = np.stack(seq_pred_gray[v], axis=0).astype(np.uint8)
                        val = eval09a.safe_strred_scalar(clean_vid, pred_vid)
                        strred_values[dataset_name][sigma_key][v].append(val)

            for v in variants:
                all_ps: List[float] = []
                all_ss: List[float] = []
                for seq_name in frame_values[dataset_name][sigma_key]:
                    all_ps.extend(frame_values[dataset_name][sigma_key][seq_name][v]["psnr"])
                    all_ss.extend(frame_values[dataset_name][sigma_key][seq_name][v]["ssim"])
                results[dataset_name][sigma_key]["dataset_mean"][v] = {
                    "psnr": _summarize(all_ps),
                    "ssim": _summarize(all_ss),
                    "num_frames": int(len(all_ps)),
                }
                if compute_strred:
                    vals = strred_values[dataset_name][sigma_key][v]
                    results[dataset_name][sigma_key]["dataset_mean"][v]["strred"] = _summarize(vals)

    decision_metrics: Dict[str, Dict[str, Any]] = {}
    for v in variants:
        yt = np.concatenate(decision_true[v], axis=0).astype(np.uint8) if decision_true[v] else np.array([], dtype=np.uint8)
        yp = np.concatenate(decision_pred[v], axis=0).astype(np.uint8) if decision_pred[v] else np.array([], dtype=np.uint8)
        decision_metrics[v] = eval09a.compute_decision_metrics(yt, yp, w_set)

    return {
        "config": {
            **cfg,
            "sigmas": [int(x) for x in sigmas],
            "datasets": list(datasets),
            "variants": list(variants),
            "w_set": [int(x) for x in w_set.tolist()],
        },
        "sources": predictor_bundle.source_paths,
        "results": results,
        "decision_metrics": decision_metrics,
    }


def build_unified_summary_rows(payload: Dict[str, Any]) -> List[Dict[str, str]]:
    cfg = payload["config"]
    variants = [str(x) for x in cfg["variants"]]
    datasets = [str(x) for x in cfg["datasets"]]
    sigmas = [int(x) for x in cfg["sigmas"]]
    rows: List[Dict[str, str]] = []

    dec = payload["decision_metrics"]
    for v in variants:
        tr = dec[v].get("tail_recall", {})
        rows.append(
            {
                "type": "decision",
                "variant": v,
                "variant_name": VARIANT_DISPLAY.get(v, v),
                "dataset": "ALL",
                "sigma": "ALL",
                "accuracy": f"{float(dec[v]['accuracy']):.6f}",
                "macro_f1": f"{float(dec[v]['macro_f1']):.6f}",
                "mean_abs_class_error": f"{float(dec[v]['mean_abs_class_error']):.6f}",
                "tail_recall_24": f"{float(tr.get('24', float('nan'))):.6f}",
                "tail_recall_28": f"{float(tr.get('28', float('nan'))):.6f}",
                "tail_recall_31": f"{float(tr.get('31', float('nan'))):.6f}",
                "psnr_mean": "",
                "ssim_mean": "",
                "strred_mean": "",
            }
        )

    results = payload["results"]
    for ds in datasets:
        for s in sigmas:
            key = f"sigma_{int(s)}"
            for v in variants:
                it = results[ds][key]["dataset_mean"][v]
                strred_mean = ""
                if "strred" in it:
                    strred_mean = f"{float(it['strred']['mean']):.6f}"
                rows.append(
                    {
                        "type": "image",
                        "variant": v,
                        "variant_name": VARIANT_DISPLAY.get(v, v),
                        "dataset": ds,
                        "sigma": str(int(s)),
                        "accuracy": "",
                        "macro_f1": "",
                        "mean_abs_class_error": "",
                        "tail_recall_24": "",
                        "tail_recall_28": "",
                        "tail_recall_31": "",
                        "psnr_mean": f"{float(it['psnr']['mean']):.6f}",
                        "ssim_mean": f"{float(it['ssim']['mean']):.6f}",
                        "strred_mean": strred_mean,
                    }
                )
    return rows


def write_summary_csv(path: Path, rows: Sequence[Dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "type",
        "variant",
        "variant_name",
        "dataset",
        "sigma",
        "accuracy",
        "macro_f1",
        "mean_abs_class_error",
        "tail_recall_24",
        "tail_recall_28",
        "tail_recall_31",
        "psnr_mean",
        "ssim_mean",
        "strred_mean",
    ]
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})

