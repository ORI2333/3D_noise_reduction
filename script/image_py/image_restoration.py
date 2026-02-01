from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def _parse_hex_lines(path: Path) -> list[int]:
    values: list[int] = []
    for line_no, raw in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1):
        s = raw.strip()
        if not s:
            continue
        if s.startswith(("0x", "0X")):
            s = s[2:]
        try:
            v = int(s, 16)
        except ValueError as e:
            raise ValueError(f"{path}:{line_no}: invalid hex: {raw!r}") from e
        values.append(v)
    return values


def rgb565_words_to_rgb888_bytes(words: list[int]) -> bytes:
    out = bytearray()
    for w in words:
        if not (0 <= w <= 0xFFFF):
            raise ValueError(f"RGB565 word out of range: {w}")
        r5 = (w >> 11) & 0x1F
        g6 = (w >> 5) & 0x3F
        b5 = w & 0x1F
        r8 = (r5 << 3) | (r5 >> 2)
        g8 = (g6 << 2) | (g6 >> 4)
        b8 = (b5 << 3) | (b5 >> 2)
        out.extend((r8, g8, b8))
    return bytes(out)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Restore an image from Verilog output text (RGB888 bytes or RGB565 words)."
    )
    parser.add_argument(
        "-i",
        "--input",
        default=None,
        help="Input txt path (default: script/image_py/out/rgb888_output.txt).",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Output image path (default: script/image_py/out/rgb888_output.png).",
    )
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument(
        "--format",
        choices=["rgb888_bytes", "rgb565_words"],
        default="rgb888_bytes",
        help="Input txt format: 1 byte/line (rgb888_bytes) or 1 word/line (rgb565_words).",
    )

    args = parser.parse_args()

    repo_dir = Path(__file__).resolve().parents[2]
    out_dir = repo_dir / "script" / "image_py" / "out"
    out_dir.mkdir(parents=True, exist_ok=True)

    in_path = Path(args.input) if args.input else (out_dir / "rgb888_output.txt")
    out_path = Path(args.output) if args.output else (out_dir / "rgb888_output.png")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    values = _parse_hex_lines(in_path)

    if args.format == "rgb888_bytes":
        for v in values:
            if not (0 <= v <= 0xFF):
                raise ValueError(f"{in_path}: byte out of range: {v}")
        raw = bytes(values)
        expected = args.width * args.height * 3
        if len(raw) < expected:
            raise ValueError(f"{in_path}: not enough bytes: got {len(raw)}, expected {expected}")
        if len(raw) > expected:
            raw = raw[:expected]
        img = Image.frombytes("RGB", (args.width, args.height), raw)
        img.save(out_path)
        print(f"Wrote image: {out_path}")
        return 0

    if args.format == "rgb565_words":
        for v in values:
            if not (0 <= v <= 0xFFFF):
                raise ValueError(f"{in_path}: word out of range: {v}")
        expected = args.width * args.height
        if len(values) < expected:
            raise ValueError(f"{in_path}: not enough words: got {len(values)}, expected {expected}")
        if len(values) > expected:
            values = values[:expected]
        raw = rgb565_words_to_rgb888_bytes(values)
        img = Image.frombytes("RGB", (args.width, args.height), raw)
        img.save(out_path)
        print(f"Wrote image: {out_path}")
        return 0

    raise AssertionError("unreachable")


if __name__ == "__main__":
    raise SystemExit(main())
