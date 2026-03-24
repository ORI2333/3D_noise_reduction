#!/usr/bin/env python3
"""
Export a LightGBM dump_model() JSON into synthesizable SystemVerilog.

Pipeline mapping:
  Stage 1: tree compare logic -> fixed-point leaf output -> register
  Stage 2: adder tree reduction -> total_score register
  Stage 3: compare total_score with taus -> w_out
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Sequence, Set, Tuple

import numpy as np


DEFAULT_FEATURE_ORDER = [
    "sad1_ds",
    "sad2_ds",
    "margin_ds",
    "sad1_mb_best",
    "mv_mag",
    "sum",
    "grad_energy",
]

DEFAULT_LOG1P_KEYS = [
    "sad1_ds",
    "sad2_ds",
    "margin_ds",
    "sad1_mb_best",
    "grad_energy",
    "sum",
]

DEFAULT_W_SET = [0, 4, 8, 12, 16, 20, 24, 28, 31]

FEATURE_PORT_MAP = {
    "sum": "sum_feat",
    "sum_feat": "sum_feat",
}

VALID_MODULE_PORTS = {
    "sad1_ds",
    "sad2_ds",
    "margin_ds",
    "sad1_mb_best",
    "mv_mag",
    "sum_feat",
    "grad_energy",
}

UINT32_MAX = (1 << 32) - 1
UINT16_MAX = (1 << 16) - 1


def parse_csv_str_list(text: str) -> List[str]:
    items = [x.strip() for x in text.split(",")]
    return [x for x in items if x]


def parse_csv_int_list(text: str) -> List[int]:
    out: List[int] = []
    for item in parse_csv_str_list(text):
        out.append(int(item))
    return out


def to_fixed(value: float, scale: int) -> int:
    return int(np.round(float(value) * scale))


def sv_int(value: int) -> str:
    return str(int(value))


def sv_signed_lit(width: int, value: int) -> str:
    v = int(value)
    if v < 0:
        return f"-{width}'sd{abs(v)}"
    return f"{width}'sd{v}"


def feature_to_port(feature_name: str) -> str:
    return FEATURE_PORT_MAP.get(feature_name, feature_name)


def extract_taus(tau_json: Dict[str, Any]) -> List[float]:
    for key in ("tau", "taus", "taus_monotone", "tau_monotone"):
        v = tau_json.get(key)
        if isinstance(v, list):
            return [float(x) for x in v]

    report = tau_json.get("report")
    if isinstance(report, dict):
        for key in ("tau", "taus", "taus_monotone", "tau_monotone"):
            v = report.get(key)
            if isinstance(v, list):
                return [float(x) for x in v]

    raise KeyError(
        "Cannot find tau list. Expected one of keys: "
        "tau/taus/taus_monotone/tau_monotone"
    )


def threshold_to_hardware(threshold: float, feature_name: str, log1p_keys: Set[str]) -> int:
    if feature_name in log1p_keys:
        value = np.expm1(float(threshold))
    else:
        value = float(threshold)

    if not np.isfinite(value):
        raise ValueError(f"Non-finite threshold after transform: feature={feature_name}, threshold={threshold}")

    hw_threshold = int(np.round(value))
    if hw_threshold > UINT16_MAX:
        hw_threshold = UINT16_MAX
    if hw_threshold < -1:
        hw_threshold = -1
    return hw_threshold


def signed_width(min_v: int, max_v: int) -> int:
    max_abs = max(abs(int(min_v)), abs(int(max_v)))
    return max(2, max_abs.bit_length() + 1)


def tree_leaf_bounds(node: Dict[str, Any], scale: int) -> Tuple[int, int]:
    if "leaf_value" in node:
        v = to_fixed(float(node["leaf_value"]), scale)
        return v, v

    left = node.get("left_child")
    right = node.get("right_child")
    if left is None or right is None:
        raise ValueError("Invalid tree node: missing left_child/right_child")

    lmin, lmax = tree_leaf_bounds(left, scale)
    rmin, rmax = tree_leaf_bounds(right, scale)
    return min(lmin, rmin), max(lmax, rmax)


def decision_op(decision_type: str) -> str:
    if decision_type in {"<=", "<", ">", ">=", "=="}:
        return decision_type
    raise ValueError(f"Unsupported decision_type={decision_type!r}")


def emit_tree_node(
    node: Dict[str, Any],
    tree_idx: int,
    feature_order: Sequence[str],
    log1p_keys: Set[str],
    scale: int,
    base_indent: str,
    depth: int = 0,
) -> List[str]:
    lines: List[str] = []
    pad = base_indent + ("  " * depth)

    if "leaf_value" in node:
        leaf_fp = to_fixed(float(node["leaf_value"]), scale)
        lines.append(f"{pad}tree_comb[{tree_idx}] = {sv_int(leaf_fp)};")
        return lines

    missing_type = node.get("missing_type", "None")
    if missing_type not in (None, "None"):
        raise ValueError(f"Unsupported missing_type={missing_type!r}; only missing_type=None is supported")

    feat_idx = int(node["split_feature"])
    if feat_idx < 0 or feat_idx >= len(feature_order):
        raise IndexError(
            f"split_feature index out of range: {feat_idx}, feature_order_len={len(feature_order)}"
        )

    feature_name = feature_order[feat_idx]
    port_name = feature_to_port(feature_name)
    if port_name not in VALID_MODULE_PORTS:
        raise ValueError(
            f"Feature {feature_name!r} maps to port {port_name!r}, "
            f"which is not in module interface"
        )

    op = decision_op(str(node.get("decision_type", "<=")))
    hw_threshold = threshold_to_hardware(float(node["threshold"]), feature_name, log1p_keys)

    condition = f"$signed({{1'b0, {port_name}}}) {op} {sv_signed_lit(17, hw_threshold)}"

    lines.append(f"{pad}if ({condition}) begin")
    lines.extend(
        emit_tree_node(
            node=node["left_child"],
            tree_idx=tree_idx,
            feature_order=feature_order,
            log1p_keys=log1p_keys,
            scale=scale,
            base_indent=base_indent,
            depth=depth + 1,
        )
    )
    lines.append(f"{pad}end else begin")
    lines.extend(
        emit_tree_node(
            node=node["right_child"],
            tree_idx=tree_idx,
            feature_order=feature_order,
            log1p_keys=log1p_keys,
            scale=scale,
            base_indent=base_indent,
            depth=depth + 1,
        )
    )
    lines.append(f"{pad}end")
    return lines


def generate_adder_tree_sv(num_trees: int) -> Tuple[List[str], str]:
    if num_trees <= 0:
        raise ValueError("num_trees must be positive")

    lines: List[str] = []
    lines.append(f"  logic signed [SCORE_W-1:0] add_l0 [0:{num_trees - 1}];")
    for i in range(num_trees):
        lines.append(f"  assign add_l0[{i}] = $signed(tree_stage1[{i}]);")

    level = 0
    level_size = num_trees
    while level_size > 1:
        next_size = (level_size + 1) // 2
        lines.append(f"  logic signed [SCORE_W-1:0] add_l{level + 1} [0:{next_size - 1}];")
        lines.append(f"  always_ff @(posedge clk) begin")
        for j in range(next_size):
            a = 2 * j
            b = a + 1
            if b < level_size:
                lines.append(f"    add_l{level + 1}[{j}] <= add_l{level}[{a}] + add_l{level}[{b}];")
            else:
                lines.append(f"    add_l{level + 1}[{j}] <= add_l{level}[{a}];")
        lines.append(f"  end")
        level += 1
        level_size = next_size

    final_node = f"add_l{level}[0]"
    return lines, final_node


def build_sv_module(
    model_json: Dict[str, Any],
    taus_fp: Sequence[int],
    w_set: Sequence[int],
    feature_order: Sequence[str],
    log1p_keys: Set[str],
    scale: int,
    model_path: Path,
    tau_path: Path,
) -> str:
    tree_info = model_json.get("tree_info")
    if not isinstance(tree_info, list) or len(tree_info) == 0:
        raise ValueError("Invalid model JSON: missing non-empty tree_info list")

    max_feature_idx = int(model_json.get("max_feature_idx", len(feature_order) - 1))
    if max_feature_idx >= len(feature_order):
        raise ValueError(
            f"feature_order is too short for model max_feature_idx={max_feature_idx}; "
            f"feature_order_len={len(feature_order)}"
        )

    for wv in w_set:
        if wv < 0 or wv > 31:
            raise ValueError(f"w_set value out of 5-bit range: {wv}")

    if len(taus_fp) != len(w_set) - 1:
        raise ValueError(
            f"taus length mismatch: len(taus)={len(taus_fp)} vs len(w_set)-1={len(w_set) - 1}"
        )

    tree_structures: List[Dict[str, Any]] = []
    tree_bounds: List[Tuple[int, int]] = []
    for idx, t in enumerate(tree_info):
        ts = t.get("tree_structure")
        if not isinstance(ts, dict):
            raise ValueError(f"tree_info[{idx}] missing tree_structure")
        tree_structures.append(ts)
        tree_bounds.append(tree_leaf_bounds(ts, scale))

    num_trees = len(tree_structures)
    leaf_min = min(v[0] for v in tree_bounds)
    leaf_max = max(v[1] for v in tree_bounds)
    total_min = sum(v[0] for v in tree_bounds)
    total_max = sum(v[1] for v in tree_bounds)

    tau_min = min(taus_fp) if taus_fp else 0
    tau_max = max(taus_fp) if taus_fp else 0

    leaf_w = signed_width(leaf_min, leaf_max)
    score_w = signed_width(min(total_min, tau_min), max(total_max, tau_max))

    lines: List[str] = []
    lines.append("// -----------------------------------------------------------------------------")
    lines.append("// Auto-generated by 11_export_model_to_verilog.py")
    lines.append(f"// model_json : {model_path}")
    lines.append(f"// tau_json   : {tau_path}")
    lines.append(f"// num_trees  : {num_trees}")
    lines.append(f"// scale      : {scale}")
    lines.append("// -----------------------------------------------------------------------------")
    lines.append("module OOTW_Tree_Inference (")
    lines.append("    input  logic        clk,")
    lines.append("    input  logic        rst_n,")
    lines.append("    // Raw integer features")
    lines.append("    input  logic [15:0] sad1_ds,")
    lines.append("    input  logic [15:0] sad2_ds,")
    lines.append("    input  logic [15:0] margin_ds,")
    lines.append("    input  logic [15:0] sad1_mb_best,")
    lines.append("    input  logic [15:0] mv_mag,")
    lines.append("    input  logic [15:0] sum_feat,")
    lines.append("    input  logic [15:0] grad_energy,")
    lines.append("    // Weight output")
    lines.append("    output logic [4:0]  w_out")
    lines.append(");")
    lines.append("")
    lines.append(f"  localparam int SCALE     = {scale};")
    lines.append(f"  localparam int NUM_TREES = {num_trees};")
    lines.append(f"  localparam int NUM_TAUS  = {len(taus_fp)};")
    lines.append(f"  localparam int LEAF_W    = {leaf_w};")
    lines.append(f"  localparam int SCORE_W   = {score_w};")
    lines.append("")

    for i, tau in enumerate(taus_fp):
        lines.append(f"  localparam logic signed [SCORE_W-1:0] TAU_FP_{i} = {sv_int(tau)};")
    lines.append("")
    for i, wv in enumerate(w_set):
        lines.append(f"  localparam logic [4:0] W_SET_{i} = 5'd{int(wv)};")
    lines.append("")

    lines.append("  logic signed [LEAF_W-1:0] tree_comb   [0:NUM_TREES-1];")
    lines.append("  logic signed [LEAF_W-1:0] tree_stage1 [0:NUM_TREES-1];")
    lines.append("  logic signed [SCORE_W-1:0] total_score_comb;")
    lines.append("  logic signed [SCORE_W-1:0] total_score;")
    lines.append("")

    for ti, tree in enumerate(tree_structures):
        lines.append(f"  // Tree {ti}")
        lines.append(f"  always_comb begin : TREE_{ti}")
        lines.append(f"    tree_comb[{ti}] = '0;")
        lines.extend(
            emit_tree_node(
                node=tree,
                tree_idx=ti,
                feature_order=feature_order,
                log1p_keys=log1p_keys,
                scale=scale,
                base_indent="    ",
                depth=0,
            )
        )
        lines.append("  end")
        lines.append("")

    lines.append("  // Stage 1 register")
    lines.append("  always_ff @(posedge clk or negedge rst_n) begin")
    lines.append("    if (!rst_n) begin")
    lines.append("      for (int i = 0; i < NUM_TREES; i++) begin")
    lines.append("        tree_stage1[i] <= '0;")
    lines.append("      end")
    lines.append("    end else begin")
    lines.append("      for (int i = 0; i < NUM_TREES; i++) begin")
    lines.append("        tree_stage1[i] <= tree_comb[i];")
    lines.append("      end")
    lines.append("    end")
    lines.append("  end")
    lines.append("")

    adder_lines, adder_final = generate_adder_tree_sv(num_trees)
    lines.append("  // Stage 2 adder tree")
    lines.extend(adder_lines)
    lines.append(f"  assign total_score_comb = {adder_final};")
    lines.append("")

    lines.append("  // Stage 2 register")
    lines.append("  always_ff @(posedge clk or negedge rst_n) begin")
    lines.append("    if (!rst_n) begin")
    lines.append("      total_score <= '0;")
    lines.append("    end else begin")
    lines.append("      total_score <= total_score_comb;")
    lines.append("    end")
    lines.append("  end")
    lines.append("")

    lines.append("  // Stage 3: score to weight mapping")
    lines.append("  always_comb begin")
    if len(taus_fp) == 0:
        lines.append("    w_out = W_SET_0;")
    else:
        lines.append("    if (total_score < TAU_FP_0) begin")
        lines.append("      w_out = W_SET_0;")
        for i in range(1, len(taus_fp)):
            lines.append(f"    end else if (total_score < TAU_FP_{i}) begin")
            lines.append(f"      w_out = W_SET_{i};")
        lines.append("    end else begin")
        lines.append(f"      w_out = W_SET_{len(w_set) - 1};")
        lines.append("    end")
    lines.append("  end")
    lines.append("")

    lines.append("endmodule")
    return "\n".join(lines) + "\n"


def build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Export LightGBM dump_model JSON + taus to OOTW_Tree_Inference.sv"
    )
    p.add_argument("--model_json", type=Path, required=True, help="Path to booster.dump_model() JSON")
    p.add_argument("--tau_json", type=Path, required=True, help="Path to taus_monotone.json")
    p.add_argument(
        "--out_sv",
        type=Path,
        default=Path("OOTW_Tree_Inference.sv"),
        help="Output SystemVerilog file path",
    )
    p.add_argument(
        "--feature_order",
        type=str,
        default=",".join(DEFAULT_FEATURE_ORDER),
        help="Comma-separated feature order used by model split_feature index",
    )
    p.add_argument(
        "--log1p_keys",
        type=str,
        default=",".join(DEFAULT_LOG1P_KEYS),
        help="Comma-separated features that used log1p during training",
    )
    p.add_argument(
        "--w_set",
        type=str,
        default=",".join(str(x) for x in DEFAULT_W_SET),
        help="Comma-separated candidate weights",
    )
    p.add_argument("--scale", type=int, default=4096, help="Fixed-point scale factor")
    return p


def main() -> None:
    args = build_argparser().parse_args()

    feature_order = parse_csv_str_list(args.feature_order)
    log1p_keys = set(parse_csv_str_list(args.log1p_keys))
    w_set = parse_csv_int_list(args.w_set)

    if not feature_order:
        raise ValueError("feature_order cannot be empty")
    if len(w_set) < 2:
        raise ValueError("w_set must contain at least 2 entries")

    with args.model_json.open("r", encoding="utf-8") as f:
        model_json = json.load(f)
    with args.tau_json.open("r", encoding="utf-8") as f:
        tau_json = json.load(f)

    taus = extract_taus(tau_json)
    taus_fp = [to_fixed(x, args.scale) for x in taus]

    sv_text = build_sv_module(
        model_json=model_json,
        taus_fp=taus_fp,
        w_set=w_set,
        feature_order=feature_order,
        log1p_keys=log1p_keys,
        scale=args.scale,
        model_path=args.model_json,
        tau_path=args.tau_json,
    )

    args.out_sv.parent.mkdir(parents=True, exist_ok=True)
    args.out_sv.write_text(sv_text, encoding="utf-8")

    print(f"[OK] Generated: {args.out_sv.resolve()}")
    print(f"[INFO] Trees={len(model_json['tree_info'])}, Taus={len(taus_fp)}, SCALE={args.scale}")


if __name__ == "__main__":
    main()
