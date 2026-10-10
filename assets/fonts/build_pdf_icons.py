#!/usr/bin/env python3
"""Builds MaterialIconsPdf.ttf: the transport-mode icons, for the PDF export.

Run: python3 assets/fonts/build_pdf_icons.py "$(dirname "$(dirname "$(which flutter)")")" \
         assets/fonts/MaterialIconsPdf.ttf

The PDF draws a leg's mode icon on its timeline rail, as the app does. The app
draws it from the Material Icons font Flutter ships, but that font is CFF-based
(its file starts with "OTTO"), and package:pdf parses TrueType outlines only — it
falls back to its Latin-1 standard font and throws on the icon's code point. So
this takes exactly the Material icons transport_mode.dart names out of Flutter's
own font, converts their cubic outlines to quadratic ones, and writes a TrueType
font. Same glyphs as the app, at the same code points, a few kilobytes in size.

The code points are not listed here: every `Icons.<name>` in transport_mode.dart
is looked up in the Flutter SDK's icons.dart, so an icon added to the curated set
only needs this script run again. test/trip_pdf_test.dart fails until it is.
The TransportGlyphs icons are TrueType already and are embedded as they are.
"""
import os
import re
import sys

from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont, newTable

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODES = os.path.join(REPO, "lib/features/itinerary/widgets/transport_mode.dart")


def code_points(flutter_root):
    with open(MODES, encoding="utf-8") as f:
        names = sorted(set(re.findall(r"\bIcons\.(\w+)", f.read())))
    icons_dart = os.path.join(flutter_root, "packages/flutter/lib/src/material/icons.dart")
    with open(icons_dart, encoding="utf-8") as f:
        source = f.read()
    points = {}
    for name in names:
        m = re.search(
            r"static const IconData " + name + r" = IconData\(\s*0x([0-9a-fA-F]+)", source
        )
        if m is None:
            sys.exit(f"Icons.{name} not found in {icons_dart}")
        points[name] = int(m.group(1), 16)
    return points


def main(flutter_root, out_path):
    points = code_points(flutter_root)
    font = TTFont(
        os.path.join(flutter_root, "bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf")
    )

    options = Options()
    options.layout_features = []
    options.notdef_outline = True
    options.drop_tables += ["GSUB", "GPOS", "GDEF"]
    subsetter = Subsetter(options)
    subsetter.populate(unicodes=points.values())
    subsetter.subset(font)

    # CFF (cubic) -> glyf (quadratic). CFF contours run counter-clockwise and
    # TrueType ones clockwise, hence reverse_direction.
    glyph_set = font.getGlyphSet()
    order = font.getGlyphOrder()
    glyf = newTable("glyf")
    glyf.glyphOrder = order
    glyf.glyphs = {}
    for name in order:
        pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(pen, max_err=1.0, reverse_direction=True))
        glyf.glyphs[name] = pen.glyph()
    del font["CFF "]
    font["glyf"] = glyf
    font["loca"] = newTable("loca")

    # A TrueType renderer places a glyph's origin at xMin - lsb, so the left
    # side bearing has to be the outline's xMin. The CFF font's hmtx says 0, and
    # left like that every icon is drawn shifted left by its own xMin.
    hmtx = font["hmtx"]
    for name in order:
        glyph = glyf[name]
        glyph.recalcBounds(glyf)
        advance, _ = hmtx[name]
        hmtx[name] = (advance, getattr(glyph, "xMin", 0))

    maxp = newTable("maxp")
    maxp.tableVersion = 0x00010000
    for field in (
        "maxTwilightPoints",
        "maxStorage",
        "maxFunctionDefs",
        "maxInstructionDefs",
        "maxStackElements",
        "maxSizeOfInstructions",
        "maxComponentElements",
    ):
        setattr(maxp, field, 0)
    maxp.maxZones = 1
    maxp.numGlyphs = len(order)
    font["maxp"] = maxp  # the remaining counts are recalculated on save

    font["head"].indexToLocFormat = 0
    font["head"].glyphDataFormat = 0
    font["post"].formatType = 3.0  # no glyph names: nothing reads them
    font.sfntVersion = "\x00\x01\x00\x00"
    for record in font["name"].names:
        if record.nameID in (1, 4):
            record.string = "MaterialIconsPdf"
        elif record.nameID == 6:
            record.string = "MaterialIconsPdf-Regular"

    font.save(out_path)
    print(f"wrote {out_path}: {len(points)} icons")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
