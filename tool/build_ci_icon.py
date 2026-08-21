#!/usr/bin/env python3
"""Derive the CI variant's launcher icon from the app's own icon.

The side-by-side build (see the `ci` signingConfig in android/app/build.gradle.kts)
installs beside a real one, so it needs an icon a human can tell apart at a glance
on the launcher. Rather than a second drawing to keep in sync, this composes the
existing mark with an amber "CI" chip, which is exactly what the release icon is
plus one mark of provenance.

The chip sits inside the adaptive icon's safe circle (66 of 108dp, centred), so
no launcher mask can crop it away -- the reason a corner badge or a bottom band
was not used. Its ring is the logo's green rather than white so it also reads on
the legacy icon, which has a transparent background.

Run from the repository root after changing the source icon:

    python3 tool/build_ci_icon.py

Requires Pillow. Regenerates every file it writes, so it is safe to re-run.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RES = Path("android/app/src/main/res")
SRC_FOREGROUND = RES / "drawable-xxxhdpi/ic_launcher_foreground.png"

GREEN = "#31513B"
AMBER = "#AC7824"

# Density buckets, as multiples of mdpi.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

BASE = 432  # 108dp at xxxhdpi: the adaptive icon's full canvas.
MARK_SCALE = 0.80  # Shrink the mark so the chip has room without overlapping it.
MARK_OFFSET = -24  # ...and lift it away from the chip's corner.

# The chip has to lie inside the adaptive icon's safe circle -- 66 of 108dp,
# i.e. radius 132 about (216, 216) at this scale -- or a round launcher mask
# slices a piece off it, which reads as a broken icon rather than a badge.
# Placed on the diagonal, that bounds it: hypot(56, 56) + 52 = 131 <= 132.
CHIP_CENTRE = (272, 272)
CHIP_RADIUS = 52
CHIP_RING = 7


def _font(size: int) -> ImageFont.FreeTypeFont:
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    raise SystemExit("DejaVu Sans Bold not found; install fonts-dejavu.")


def build_foreground() -> Image.Image:
    """The adaptive icon's foreground layer: the mark, plus the chip."""
    source = Image.open(SRC_FOREGROUND).convert("RGBA")
    size = int(BASE * MARK_SCALE)
    canvas = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    mark = source.resize((size, size), Image.LANCZOS)
    canvas.paste(
        mark,
        ((BASE - size) // 2 + MARK_OFFSET, (BASE - size) // 2 + MARK_OFFSET),
        mark,
    )

    draw = ImageDraw.Draw(canvas)
    cx, cy = CHIP_CENTRE
    draw.ellipse(
        [cx - CHIP_RADIUS, cy - CHIP_RADIUS, cx + CHIP_RADIUS, cy + CHIP_RADIUS],
        fill=AMBER,
        outline=GREEN,
        width=CHIP_RING,
    )
    draw.text((cx, cy + 2), "CI", font=_font(44), fill="#FFFFFF", anchor="mm")
    return canvas


def main() -> None:
    foreground = build_foreground()

    for bucket, scale in DENSITIES.items():
        # The adaptive foreground: 108dp.
        px = int(108 * scale)
        out = RES / f"drawable-{bucket}/ic_launcher_ci_foreground.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        foreground.resize((px, px), Image.LANCZOS).save(out)

        # The legacy launcher icon (API 24-25, below adaptive icons): 48dp.
        # Flattened the same way the existing one is -- transparent, no plate.
        px = int(48 * scale)
        out = RES / f"mipmap-{bucket}/ic_launcher_ci.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        foreground.resize((px, px), Image.LANCZOS).save(out)

    print(f"wrote {2 * len(DENSITIES)} files under {RES}")


if __name__ == "__main__":
    main()
