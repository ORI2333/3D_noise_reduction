from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

from PIL import Image


def _parse_res(s: str) -> tuple[int, int]:
    s = s.strip().lower().replace(" ", "")
    if "x" not in s:
        raise ValueError(f"Invalid --res {s!r}, expected like 640x480")
    w_str, h_str = s.split("x", 1)
    w = int(w_str, 10)
    h = int(h_str, 10)
    if w <= 0 or h <= 0:
        raise ValueError(f"Invalid --res {s!r}, width/height must be positive")
    return w, h


def _iter_hex_lines(values: Iterable[int], width: int) -> Iterable[str]:
    fmt = f"{{:0{width}X}}"
    for v in values:
        yield fmt.format(v)


def rgb888_to_rgb565_words(rgb_bytes: bytes) -> list[int]:
    if len(rgb_bytes) % 3 != 0:
        raise ValueError(f"RGB888 byte length must be multiple of 3, got {len(rgb_bytes)}")
    out: list[int] = []
    for i in range(0, len(rgb_bytes), 3):
        r = rgb_bytes[i + 0]
        g = rgb_bytes[i + 1]
        b = rgb_bytes[i + 2]
        word = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
        out.append(word)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate Verilog $readmemh input from an image (RGB888 bytes, 1 byte per line)."
    )
    parser.add_argument(
        "-i",
        "--input",
        required=True,
        help="Input image path (bmp/png/jpg...).",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Output txt path (default: script/image_py/out/Bmp_2_rgb888.txt).",
    )
    parser.add_argument(
        "--res",
        default=None,
        help="Resolution like 640x480 (overrides --width/--height).",
    )
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument(
        "--no-resize",
        action="store_true",
        help="Fail if input image size != width/height (default: resize).",
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Also write a preview PNG beside the txt.",
    )
    parser.add_argument(
        "--rgb565-output",
        default=None,
        help="Optional: also write RGB565 words (1 word per line, hex) for other testbenches.",
    )

    args = parser.parse_args()
    if args.res:
        args.width, args.height = _parse_res(args.res)

    repo_dir = Path(__file__).resolve().parents[2]
    out_dir = repo_dir / "script" / "image_py" / "out"
    out_dir.mkdir(parents=True, exist_ok=True)

    in_path = Path(args.input)
    out_path = Path(args.output) if args.output else (out_dir / "Bmp_2_rgb888.txt")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with Image.open(in_path) as img:
        img = img.convert("RGB")
        if (img.width, img.height) != (args.width, args.height):
            if args.no_resize:
                raise SystemExit(
                    f"Input image size is {img.width}x{img.height}, expected {args.width}x{args.height}."
                )
            img = img.resize((args.width, args.height), resample=Image.BILINEAR)

        rgb_bytes = img.tobytes()  # row-major RGBRGB...

    out_path.write_text("\n".join(_iter_hex_lines(rgb_bytes, width=2)) + "\n", encoding="utf-8")

    if args.preview:
        preview_path = out_path.with_suffix(".preview.png")
        Image.frombytes("RGB", (args.width, args.height), rgb_bytes).save(preview_path)

    if args.rgb565_output:
        rgb565_path = Path(args.rgb565_output)
        rgb565_path.parent.mkdir(parents=True, exist_ok=True)
        rgb565_words = rgb888_to_rgb565_words(rgb_bytes)
        rgb565_path.write_text("\n".join(_iter_hex_lines(rgb565_words, width=4)) + "\n", encoding="utf-8")

    print(f"Wrote RGB888 memh bytes: {out_path}")
    if args.rgb565_output:
        print(f"Wrote RGB565 memh words: {Path(args.rgb565_output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
