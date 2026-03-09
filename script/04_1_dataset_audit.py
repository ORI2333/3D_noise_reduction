#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script04-1: Dataset Audit（只做读取/体检/统计，不训练）

运行示例:
python 04_1_dataset_audit.py \
  --shard_dir /path/to/train_shards \
  --out_dir   ./out_audit \
  --max_shards 10 \
  --max_rows_per_shard 200000 \
  --w_set_expected "0,4,8,12,16,20,24,28,31"
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import matplotlib.pyplot as plt
import numpy as np

import oracle_lib as olib


def parse_args() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(
        description="读取 Script03 shard，做健康检查与统计审计（不训练）。"
    )
    parser.add_argument("--shard_dir", type=str, required=True, help="shard 目录（*.npz）")
    parser.add_argument("--out_dir", type=str, required=True, help="输出目录（report + figures）")
    parser.add_argument("--max_shards", type=int, default=None, help="仅扫描前 N 个 shard")
    parser.add_argument(
        "--max_rows_per_shard",
        type=int,
        default=None,
        help="每个 shard 最多读取多少行；注意是随机抽样，不是前 N 行截断",
    )
    parser.add_argument("--require_info", action="store_true", help="强制要求 info 字段")
    parser.add_argument(
        "--w_set_expected",
        type=str,
        default=None,
        help='可选，预期 w_set，例如 "0,4,8,12,16,20,24,28,31"',
    )
    parser.add_argument(
        "--save_plots",
        type=str,
        default="true",
        help="是否输出图像（true/false），默认 true",
    )
    parser.add_argument(
        "--sample_seed",
        type=int,
        default=123,
        help="随机抽样种子（用于 max_rows_per_shard 和近似分位数）",
    )
    return parser.parse_args()


def parse_bool(text: str) -> bool:
    """解析 true/false。"""
    return text.strip().lower() in {"1", "true", "yes", "y", "on"}


def fatal(shard_path: Path, reason: str) -> None:
    """致命错误并退出。"""
    print(f"[FATAL] {shard_path.name}: {reason}")
    raise SystemExit(1)


def validate_required_fields(data: np.lib.npyio.NpzFile, shard_path: Path) -> None:
    """校验必须字段存在。"""
    required = ["X", "y", "feature_names", "w_set", "files", "meta"]
    for key in required:
        if key not in data.files:
            fatal(shard_path, f"缺少必须字段 `{key}`")


def check_contract(
    shard_path: Path,
    X: np.ndarray,
    y: np.ndarray,
    feature_names: np.ndarray,
    w_set: np.ndarray,
    files: np.ndarray,
    meta: np.ndarray,
    info: Optional[np.ndarray],
    require_info: bool,
) -> None:
    """校验 dtype/shape/ndim 契约。"""
    if X.dtype != np.float32 or X.ndim != 2:
        fatal(shard_path, f"X 契约错误，期望 float32 2D，实际 dtype={X.dtype}, ndim={X.ndim}")
    if y.dtype != np.uint8 or y.ndim != 1:
        fatal(shard_path, f"y 契约错误，期望 uint8 1D，实际 dtype={y.dtype}, ndim={y.ndim}")
    if X.shape[0] != y.shape[0]:
        fatal(shard_path, f"X/y 行数不一致: X={X.shape[0]}, y={y.shape[0]}")

    if feature_names.dtype.kind != "U" or feature_names.ndim != 1:
        fatal(shard_path, "feature_names 契约错误，需 unicode 1D")
    if feature_names.shape[0] != X.shape[1]:
        fatal(shard_path, f"feature_names 长度不等于特征维度: {feature_names.shape[0]} vs {X.shape[1]}")

    if w_set.dtype != np.uint8 or w_set.ndim != 1:
        fatal(shard_path, "w_set 契约错误，需 uint8 1D")
    if files.dtype.kind != "U" or files.ndim != 1:
        fatal(shard_path, "files 契约错误，需 unicode 1D")
    if meta.dtype.kind != "U":
        fatal(shard_path, "meta 契约错误，需 unicode 字符串")

    if require_info and info is None:
        fatal(shard_path, "require_info=true 但 shard 中无 info")
    if info is not None:
        if info.ndim != 2 or info.shape[1] != 4:
            fatal(shard_path, f"info 契约错误，期望 (N,4)，实际 {info.shape}")
        if info.shape[0] != X.shape[0]:
            fatal(shard_path, f"info 行数与 X 不一致: info={info.shape[0]}, X={X.shape[0]}")


def parse_meta(meta: np.ndarray, shard_path: Path, warnings: List[str]) -> Optional[Dict[str, Any]]:
    """解析 meta JSON；失败只记 warning。"""
    try:
        text = str(meta.item()) if meta.ndim == 0 else str(meta.reshape(-1)[0])
        return json.loads(text)
    except Exception as exc:  # pylint: disable=broad-except
        warnings.append(f"{shard_path.name}: meta 解析失败 ({exc})")
        return None


def init_feature_stats(X: np.ndarray) -> Dict[str, np.ndarray]:
    """初始化特征统计。"""
    X64 = X.astype(np.float64)
    return {
        "min": X64.min(axis=0),
        "max": X64.max(axis=0),
        "sum": X64.sum(axis=0),
        "sumsq": (X64 * X64).sum(axis=0),
        "count": np.array([X64.shape[0]], dtype=np.int64),
    }


def update_feature_stats(stats: Dict[str, np.ndarray], X: np.ndarray) -> None:
    """流式更新特征统计。"""
    X64 = X.astype(np.float64)
    stats["min"] = np.minimum(stats["min"], X64.min(axis=0))
    stats["max"] = np.maximum(stats["max"], X64.max(axis=0))
    stats["sum"] += X64.sum(axis=0)
    stats["sumsq"] += (X64 * X64).sum(axis=0)
    stats["count"] += X64.shape[0]


def finalize_feature_stats(
    feature_names: np.ndarray,
    stats: Dict[str, np.ndarray],
    sample_X: Optional[np.ndarray],
) -> List[Dict[str, Any]]:
    """汇总特征统计并附带近似分位数。"""
    n = float(stats["count"][0])
    mean = stats["sum"] / n
    var = stats["sumsq"] / n - mean * mean
    var = np.maximum(var, 0.0)
    std = np.sqrt(var)

    quant = {}
    if sample_X is not None and sample_X.size > 0:
        quant["p1"] = np.percentile(sample_X, 1, axis=0)
        quant["p5"] = np.percentile(sample_X, 5, axis=0)
        quant["p50"] = np.percentile(sample_X, 50, axis=0)
        quant["p95"] = np.percentile(sample_X, 95, axis=0)
        quant["p99"] = np.percentile(sample_X, 99, axis=0)

    rows: List[Dict[str, Any]] = []
    for i, name in enumerate(feature_names.tolist()):
        row = {
            "name": name,
            "min": float(stats["min"][i]),
            "max": float(stats["max"][i]),
            "mean": float(mean[i]),
            "std": float(std[i]),
        }
        if quant:
            row["p1_approx"] = float(quant["p1"][i])
            row["p5_approx"] = float(quant["p5"][i])
            row["p50_approx"] = float(quant["p50"][i])
            row["p95_approx"] = float(quant["p95"][i])
            row["p99_approx"] = float(quant["p99"][i])
        rows.append(row)
    return rows


def bucketize_mv_mag(x: np.ndarray) -> np.ndarray:
    """mv_mag 分桶: 0,1,2,3,4,>=5 -> 0..5。"""
    return np.clip(x.astype(np.int64), 0, 5)


def bucketize_edges(x: np.ndarray, edges: np.ndarray) -> np.ndarray:
    """分位数边界分桶。"""
    idx = np.searchsorted(edges, x, side="right") - 1
    return np.clip(idx, 0, len(edges) - 2)


def build_interval_label(left: float, right: float, is_last: bool) -> str:
    """构造区间文案：前面 [a,b)，最后 [a,b]。"""
    if is_last:
        return f"[{left:.3f}, {right:.3f}]"
    return f"[{left:.3f}, {right:.3f})"


def resolve_feature_name(
    feature_idx_map: Dict[str, int],
    candidates: Tuple[str, ...],
) -> str:
    """按候选列表解析实际特征名（用于 v1/v2 兼容）。"""
    for name in candidates:
        if name in feature_idx_map:
            return name
    return ""


def accumulate_bucket(
    bucket_idx: np.ndarray,
    y: np.ndarray,
    w_set: np.ndarray,
    bucket_count: int,
) -> Dict[str, Any]:
    """统计分桶 count、E[w]、各类比例。"""
    counts = np.zeros(bucket_count, dtype=np.int64)
    sum_w = np.zeros(bucket_count, dtype=np.float64)
    cls = np.zeros((bucket_count, len(w_set)), dtype=np.int64)

    for b in range(bucket_count):
        m = bucket_idx == b
        if not np.any(m):
            continue
        yb = y[m].astype(np.int64)
        counts[b] = yb.size
        sum_w[b] = float(yb.mean()) * yb.size
        for wi, wv in enumerate(w_set.tolist()):
            cls[b, wi] = int((yb == wv).sum())

    e_w = np.divide(sum_w, np.maximum(counts, 1), dtype=np.float64)
    ratio = np.divide(cls, np.maximum(counts[:, None], 1), dtype=np.float64)
    return {"counts": counts, "e_w": e_w, "class_ratios": ratio}


def plot_label_hist(path: Path, w_set: np.ndarray, counts: np.ndarray) -> None:
    """全局标签直方图。"""
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.bar([str(int(w)) for w in w_set], counts, color="#4C78A8")
    ax.set_title("Global Label Histogram")
    ax.set_xlabel("w")
    ax.set_ylabel("count")
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_bucket(path: Path, title: str, labels: List[str], e_w: np.ndarray, counts: np.ndarray) -> None:
    """分桶 E[w] 与样本数双轴图。"""
    fig, ax1 = plt.subplots(figsize=(10, 4))
    x = np.arange(len(labels))
    ax1.bar(x, e_w, color="#F58518", alpha=0.85)
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels)
    ax1.set_ylabel("E[w]")
    ax1.set_title(title)

    ax2 = ax1.twinx()
    ax2.plot(x, counts, color="#54A24B", marker="o", linewidth=1.5)
    ax2.set_ylabel("count")

    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_feature_table(path: Path, rows: List[Dict[str, Any]]) -> None:
    """特征统计表（图）。"""
    show = rows[:12]
    cols = ["name", "min", "max", "mean", "std", "p1_approx", "p50_approx", "p99_approx"]
    data = []
    for r in show:
        data.append(
            [
                r["name"],
                f"{r['min']:.3f}",
                f"{r['max']:.3f}",
                f"{r['mean']:.3f}",
                f"{r['std']:.3f}",
                f"{r.get('p1_approx', float('nan')):.3f}",
                f"{r.get('p50_approx', float('nan')):.3f}",
                f"{r.get('p99_approx', float('nan')):.3f}",
            ]
        )

    fig, ax = plt.subplots(figsize=(12, 0.55 * (len(data) + 2)))
    ax.axis("off")
    tbl = ax.table(cellText=data, colLabels=cols, loc="center")
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(8)
    tbl.scale(1, 1.2)
    fig.tight_layout()
    fig.savefig(path, dpi=180)
    plt.close(fig)


def main() -> None:
    """主流程。"""
    args = parse_args()
    save_plots = parse_bool(args.save_plots)
    rng = np.random.default_rng(args.sample_seed)

    shard_dir = Path(args.shard_dir)
    out_dir = Path(args.out_dir)
    report_dir = out_dir / "report"
    fig_dir = out_dir / "figures"
    report_dir.mkdir(parents=True, exist_ok=True)
    if save_plots:
        fig_dir.mkdir(parents=True, exist_ok=True)

    if not shard_dir.is_dir():
        print(f"[FATAL] shard_dir 不存在: {shard_dir}")
        raise SystemExit(1)

    shard_files = sorted(shard_dir.glob("*.npz"))
    total_shards = len(shard_files)
    if args.max_shards is not None:
        shard_files = shard_files[: max(0, args.max_shards)]
    scanned_shards = len(shard_files)

    print(f"[信息] shard 总数: {total_shards}")
    print(f"[信息] 扫描 shard 数: {scanned_shards}")

    if scanned_shards == 0:
        print("[FATAL] 没有可扫描的 shard")
        raise SystemExit(1)

    expected_w_set = None
    if args.w_set_expected is not None:
        expected_w_set = olib.parse_w_set(args.w_set_expected)

    warnings: List[str] = []
    ref_feature_names: Optional[np.ndarray] = None
    ref_w_set: Optional[np.ndarray] = None
    feature_idx: Optional[Dict[str, int]] = None
    feature_key_mv_mag: Optional[str] = None
    feature_key_margin: Optional[str] = None
    feature_key_sad1: Optional[str] = None

    global_rows = 0
    global_label_counts: Optional[np.ndarray] = None
    shard_summaries: List[Dict[str, Any]] = []
    feat_stats: Optional[Dict[str, np.ndarray]] = None

    # 近似分位数缓存
    sample_X_list: List[np.ndarray] = []
    sample_cap_total = 200_000
    sample_per_shard = 2000

    # 分桶统计
    mv_counts = np.zeros(6, dtype=np.int64)
    mv_sumw = np.zeros(6, dtype=np.float64)
    mv_cls = None

    margin_vals_sample: List[np.ndarray] = []
    margin_y_sample: List[np.ndarray] = []
    sad1_vals_sample: List[np.ndarray] = []
    sad1_y_sample: List[np.ndarray] = []
    story_cap = 300_000

    for shard_path in shard_files:
        with np.load(shard_path, allow_pickle=False) as data:
            validate_required_fields(data, shard_path)

            X_full = data["X"]
            y_full = data["y"]
            feature_names = data["feature_names"]
            w_set = data["w_set"]
            files = data["files"]
            meta = data["meta"]
            info = data["info"] if "info" in data.files else None

            check_contract(shard_path, X_full, y_full, feature_names, w_set, files, meta, info, args.require_info)

            if ref_feature_names is None:
                ref_feature_names = feature_names.copy()
            elif not np.array_equal(ref_feature_names, feature_names):
                fatal(shard_path, "feature_names 与其他 shard 不一致（内容/顺序）")

            if ref_w_set is None:
                ref_w_set = w_set.copy()
                if expected_w_set is not None and not np.array_equal(ref_w_set, expected_w_set):
                    fatal(shard_path, f"w_set 与 w_set_expected 不一致: actual={ref_w_set}, expected={expected_w_set}")
                global_label_counts = np.zeros(len(ref_w_set), dtype=np.int64)
                mv_cls = np.zeros((6, len(ref_w_set)), dtype=np.int64)
            elif not np.array_equal(ref_w_set, w_set):
                fatal(shard_path, "w_set 与其他 shard 不一致（内容/顺序）")

            assert ref_w_set is not None
            assert global_label_counts is not None
            assert mv_cls is not None

            # 随机抽样读取，不是前 N 行截断
            n_total = X_full.shape[0]
            if args.max_rows_per_shard is None or args.max_rows_per_shard >= n_total:
                row_idx = np.arange(n_total, dtype=np.int64)
            else:
                row_idx = rng.choice(n_total, size=args.max_rows_per_shard, replace=False)
                row_idx.sort()

            if row_idx.size == 0:
                warnings.append(f"{shard_path.name}: 抽样后行数为 0，跳过")
                continue

            X = X_full[row_idx]
            y = y_full[row_idx]
            n_read = X.shape[0]

            # y 必须在 w_set 内
            invalid_y = np.setdiff1d(np.unique(y), ref_w_set)
            if invalid_y.size > 0:
                fatal(shard_path, f"y 存在非法类别（不在 w_set）: {invalid_y.tolist()}")

            # NaN/Inf
            if not np.isfinite(X).all():
                fatal(shard_path, "X 含 NaN/Inf")

            _ = parse_meta(meta, shard_path, warnings)

            # 特征索引（叙事统计）
            if feature_idx is None:
                feature_idx = {name: i for i, name in enumerate(ref_feature_names.tolist())}
                feature_key_mv_mag = resolve_feature_name(feature_idx, ("mv_mag",))
                feature_key_margin = resolve_feature_name(feature_idx, ("margin", "margin_ds"))
                feature_key_sad1 = resolve_feature_name(feature_idx, ("sad1", "sad1_ds"))
                if feature_key_mv_mag == "":
                    fatal(shard_path, "缺少关键特征 `mv_mag`")
                if feature_key_margin == "":
                    fatal(shard_path, "缺少关键特征 `margin` 或 `margin_ds`")
                if feature_key_sad1 == "":
                    fatal(shard_path, "缺少关键特征 `sad1` 或 `sad1_ds`")
                if feature_key_margin != "margin":
                    warnings.append(f"检测到 V2 特征，使用 `{feature_key_margin}` 进行 margin 分桶统计")
                if feature_key_sad1 != "sad1":
                    warnings.append(f"检测到 V2 特征，使用 `{feature_key_sad1}` 进行 sad1 分桶统计")

            # 全局样本
            global_rows += n_read

            # per-shard 标签分布
            shard_counts = np.zeros(len(ref_w_set), dtype=np.int64)
            for wi, wv in enumerate(ref_w_set.tolist()):
                c = int((y == wv).sum())
                shard_counts[wi] = c
                global_label_counts[wi] += c

            dominant_idx = int(np.argmax(shard_counts))
            dominant_ratio = float(shard_counts[dominant_idx] / max(n_read, 1))
            if dominant_ratio >= 0.90:
                warnings.append(
                    f"{shard_path.name}: 标签分布高度偏置，w={int(ref_w_set[dominant_idx])}, ratio={dominant_ratio:.3f}"
                )

            shard_summaries.append(
                {
                    "shard": shard_path.name,
                    "N_total": int(n_total),
                    "N_read": int(n_read),
                    "sample_mode": "random" if n_read < n_total else "all",
                    "F": int(X.shape[1]),
                    "label_hist": {str(int(w)): int(shard_counts[i]) for i, w in enumerate(ref_w_set.tolist())},
                    "dominant_w": int(ref_w_set[dominant_idx]),
                    "dominant_ratio": dominant_ratio,
                }
            )

            # 流式特征统计
            if feat_stats is None:
                feat_stats = init_feature_stats(X)
            else:
                update_feature_stats(feat_stats, X)

            # 近似分位数样本池
            take_n = min(sample_per_shard, n_read)
            sel = rng.choice(n_read, size=take_n, replace=False)
            sample_X_list.append(X[sel].copy())
            cur_n = sum(a.shape[0] for a in sample_X_list)
            if cur_n > sample_cap_total:
                merged = np.concatenate(sample_X_list, axis=0)
                keep = rng.choice(merged.shape[0], size=sample_cap_total, replace=False)
                sample_X_list = [merged[keep]]

            # mv_mag 分桶（基于当前抽样）
            assert feature_key_mv_mag is not None
            mv = X[:, feature_idx[feature_key_mv_mag]]
            mv_bin = bucketize_mv_mag(mv)
            for b in range(6):
                m = mv_bin == b
                if not np.any(m):
                    continue
                yb = y[m]
                mv_counts[b] += yb.size
                mv_sumw[b] += float(yb.mean()) * yb.size
                for wi, wv in enumerate(ref_w_set.tolist()):
                    mv_cls[b, wi] += int((yb == wv).sum())

            # margin/sad1 采样叙事
            story_take = min(2000, n_read)
            sidx = rng.choice(n_read, size=story_take, replace=False)
            assert feature_key_margin is not None
            assert feature_key_sad1 is not None
            margin_vals_sample.append(X[sidx, feature_idx[feature_key_margin]].astype(np.float64))
            margin_y_sample.append(y[sidx].astype(np.uint8))
            sad1_vals_sample.append(X[sidx, feature_idx[feature_key_sad1]].astype(np.float64))
            sad1_y_sample.append(y[sidx].astype(np.uint8))
            story_n = sum(v.shape[0] for v in margin_vals_sample)
            if story_n > story_cap:
                m_all = np.concatenate(margin_vals_sample, axis=0)
                s_all = np.concatenate(sad1_vals_sample, axis=0)
                y_all = np.concatenate(margin_y_sample, axis=0)
                keep = rng.choice(m_all.shape[0], size=story_cap, replace=False)
                margin_vals_sample = [m_all[keep]]
                sad1_vals_sample = [s_all[keep]]
                margin_y_sample = [y_all[keep]]
                sad1_y_sample = [y_all[keep]]

    assert ref_feature_names is not None
    assert ref_w_set is not None
    assert global_label_counts is not None
    assert feat_stats is not None
    assert feature_idx is not None
    assert mv_cls is not None

    # 全局标签
    label_ratios = global_label_counts / max(global_rows, 1)
    label_hist_global = {
        str(int(w)): {"count": int(global_label_counts[i]), "ratio": float(label_ratios[i])}
        for i, w in enumerate(ref_w_set.tolist())
    }

    # 偏置 top10
    top10_biased = sorted(shard_summaries, key=lambda r: r["dominant_ratio"], reverse=True)[:10]

    # 特征统计
    sample_X = np.concatenate(sample_X_list, axis=0) if sample_X_list else None
    feature_stats_rows = finalize_feature_stats(ref_feature_names, feat_stats, sample_X)

    # 常数列/异常大值告警
    for row in feature_stats_rows:
        if row["std"] < 1e-6:
            warnings.append(f"feature `{row['name']}` 近似常数列（std={row['std']:.3e}）")
        n = row["name"]
        mx = row["max"]
        if n in ("sad1", "sad1_ds", "margin", "margin_ds") and mx > 65535:
            warnings.append(f"feature `{n}` 最大值异常偏大（max={mx:.1f} > 65535）")
        if n == "mv_mag" and mx > 50:
            warnings.append(f"feature `mv_mag` 最大值偏大（max={mx:.1f} > 50）")

    # 叙事统计
    mv_e_w = np.divide(mv_sumw, np.maximum(mv_counts, 1), dtype=np.float64)
    mv_ratio = np.divide(mv_cls, np.maximum(mv_counts[:, None], 1), dtype=np.float64)
    mv_labels = ["0", "1", "2", "3", "4", ">=5"]
    bucket_mv = []
    for bi, label in enumerate(mv_labels):
        bucket_mv.append(
            {
                "bucket": label,
                "count": int(mv_counts[bi]),
                "E_w": float(mv_e_w[bi]),
                "class_ratio": {
                    str(int(w)): float(mv_ratio[bi, wi]) for wi, w in enumerate(ref_w_set.tolist())
                },
            }
        )

    margin_vals = np.concatenate(margin_vals_sample, axis=0) if margin_vals_sample else np.array([], dtype=np.float64)
    margin_y = np.concatenate(margin_y_sample, axis=0) if margin_y_sample else np.array([], dtype=np.uint8)
    sad1_vals = np.concatenate(sad1_vals_sample, axis=0) if sad1_vals_sample else np.array([], dtype=np.float64)
    sad1_y = np.concatenate(sad1_y_sample, axis=0) if sad1_y_sample else np.array([], dtype=np.uint8)
    if margin_vals.size == 0 or sad1_vals.size == 0:
        print("[FATAL] 无法生成 margin/sad1 分桶统计（样本为空）")
        raise SystemExit(1)

    margin_edges = np.percentile(margin_vals, [0, 20, 40, 60, 80, 100])
    sad1_edges = np.percentile(sad1_vals, [0, 20, 40, 60, 80, 100])
    margin_bin = bucketize_edges(margin_vals, margin_edges)
    sad1_bin = bucketize_edges(sad1_vals, sad1_edges)
    margin_stat = accumulate_bucket(margin_bin, margin_y, ref_w_set, 5)
    sad1_stat = accumulate_bucket(sad1_bin, sad1_y, ref_w_set, 5)

    def build_bucket_rows(edges: np.ndarray, stat: Dict[str, Any], approx: bool) -> List[Dict[str, Any]]:
        rows = []
        for bi in range(len(edges) - 1):
            rows.append(
                {
                    "bucket": build_interval_label(edges[bi], edges[bi + 1], is_last=(bi == len(edges) - 2)),
                    "count": int(stat["counts"][bi]),
                    "E_w": float(stat["e_w"][bi]),
                    "class_ratio": {
                        str(int(w)): float(stat["class_ratios"][bi, wi]) for wi, w in enumerate(ref_w_set.tolist())
                    },
                    "approx": approx,
                }
            )
        return rows

    bucket_margin = build_bucket_rows(margin_edges, margin_stat, approx=True)
    bucket_sad1 = build_bucket_rows(sad1_edges, sad1_stat, approx=True)

    # JSON 报告
    audit = {
        "purpose": "dataset_audit_only_no_training",
        "input": {
            "shard_dir": str(shard_dir),
            "max_shards": args.max_shards,
            "max_rows_per_shard": args.max_rows_per_shard,
            "row_sampling_mode": "random" if args.max_rows_per_shard is not None else "all",
            "require_info": bool(args.require_info),
            "w_set_expected": args.w_set_expected,
            "sample_seed": args.sample_seed,
        },
        "scale": {
            "total_shards": total_shards,
            "scanned_shards": scanned_shards,
            "N_total": int(global_rows),
            "feature_dim": int(ref_feature_names.shape[0]),
        },
        "feature_names": ref_feature_names.tolist(),
        "w_set": [int(v) for v in ref_w_set.tolist()],
        "label_hist_global": label_hist_global,
        "per_shard": shard_summaries,
        "top10_biased_shards": top10_biased,
        "feature_stats": feature_stats_rows,
        "bucket_mv_mag_vs_w": bucket_mv,
        "bucket_margin_vs_w": bucket_margin,
        "bucket_sad1_vs_w": bucket_sad1,
        "warnings": warnings,
    }

    json_path = report_dir / "dataset_audit.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(audit, f, ensure_ascii=False, indent=2)

    # Markdown 报告
    md: List[str] = []
    md.append("# Dataset Audit Report")
    md.append("")
    md.append("## 结论")
    md.append("- 本脚本仅做数据体检与统计，不涉及训练。")
    md.append(f"- shard 扫描: {scanned_shards}/{total_shards}")
    md.append(f"- 全局样本数 N_total: {global_rows}")
    md.append(f"- 特征维度 F: {ref_feature_names.shape[0]}")
    if args.max_rows_per_shard is not None:
        md.append(f"- 统计口径: 每 shard 随机抽样 {args.max_rows_per_shard} 行（不是前缀截断）")
    else:
        md.append("- 统计口径: 全量读取每 shard")
    md.append("")

    md.append("## 全局标签分布")
    for w in ref_w_set.tolist():
        rec = label_hist_global[str(int(w))]
        md.append(f"- w={int(w):2d}: count={rec['count']}, ratio={rec['ratio']:.4f}")
    md.append("")

    md.append("## 最偏置 Top10 Shard")
    for r in top10_biased:
        md.append(f"- {r['shard']}: dominant_w={r['dominant_w']}, dominant_ratio={r['dominant_ratio']:.4f}, N_read={r['N_read']}")
    md.append("")

    md.append("## 特征统计")
    md.append("| feature | min | max | mean | std | p1_approx | p50_approx | p99_approx |")
    md.append("|---|---:|---:|---:|---:|---:|---:|---:|")
    for r in feature_stats_rows:
        md.append(
            f"| {r['name']} | {r['min']:.4f} | {r['max']:.4f} | {r['mean']:.4f} | {r['std']:.4f} | "
            f"{r.get('p1_approx', float('nan')):.4f} | {r.get('p50_approx', float('nan')):.4f} | {r.get('p99_approx', float('nan')):.4f} |"
        )
    md.append("")

    md.append("## 叙事分桶")
    md.append("- 说明：E[w] 是离散档位 `w_set` 的数学期望（不是连续权重）。")
    md.append("- mv_mag 分桶（精确）")
    for r in bucket_mv:
        md.append(f"  - {r['bucket']}: count={r['count']}, E[w]={r['E_w']:.4f}")
    md.append("- margin 分桶（按分位数，approx）")
    for r in bucket_margin:
        md.append(f"  - {r['bucket']}: count={r['count']}, E[w]={r['E_w']:.4f}")
    md.append("- sad1 分桶（按分位数，approx）")
    for r in bucket_sad1:
        md.append(f"  - {r['bucket']}: count={r['count']}, E[w]={r['E_w']:.4f}")
    md.append("")

    md.append("## Warnings")
    if warnings:
        for w in warnings:
            md.append(f"- WARNING: {w}")
    else:
        md.append("- 无")
    md.append("")

    md.append("## 建议")
    md.append("- 若全局标签分布偏置严重，训练阶段建议 class weight 或重采样。")
    md.append("- 若关键特征近似常数或出现异常大值，先回查 Script03 数据生成逻辑。")
    md.append("- 建议至少跑一次全 shard（可继续随机抽样每 shard）以稳定结论。")

    md_path = report_dir / "dataset_audit.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(md))

    # 图输出
    if save_plots:
        plot_label_hist(fig_dir / "label_hist_global.png", ref_w_set, global_label_counts)
        plot_feature_table(fig_dir / "feature_stats_table.png", feature_stats_rows)
        plot_bucket(
            fig_dir / "bucket_mv_mag_vs_w.png",
            "mv_mag bucket vs E[w]",
            ["0", "1", "2", "3", "4", ">=5"],
            mv_e_w,
            mv_counts,
        )
        plot_bucket(
            fig_dir / "bucket_margin_vs_w.png",
            "margin bucket vs E[w] (approx)",
            [f"B{i}" for i in range(5)],
            margin_stat["e_w"],
            margin_stat["counts"],
        )
        plot_bucket(
            fig_dir / "bucket_sad1_vs_w.png",
            "sad1 bucket vs E[w] (approx)",
            [f"B{i}" for i in range(5)],
            sad1_stat["e_w"],
            sad1_stat["counts"],
        )

    # 终端摘要（不再只说“跑通”）
    print("[摘要] 全局标签分布（count, ratio）:")
    for w in ref_w_set.tolist():
        rec = label_hist_global[str(int(w))]
        print(f"  - w={int(w):2d}: {rec['count']}, {rec['ratio']:.4f}")
    print("[摘要] 最偏置 shard Top3:")
    for r in top10_biased[:3]:
        print(f"  - {r['shard']}: dominant_w={r['dominant_w']}, dominant_ratio={r['dominant_ratio']:.4f}")
    print("[摘要] mv_mag 分桶 E[w]:")
    for r in bucket_mv:
        print(f"  - {r['bucket']}: E[w]={r['E_w']:.4f}, count={r['count']}")

    print(f"[输出] JSON 报告: {json_path}")
    print(f"[输出] Markdown 报告: {md_path}")
    if save_plots:
        print(f"[输出] 图目录: {fig_dir}")
    print(f"[WARNING] 数量: {len(warnings)}")
    print("[完成] Dataset Audit 完成（未进行训练）")


if __name__ == "__main__":
    main()
