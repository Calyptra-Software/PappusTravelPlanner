import 'package:flutter/material.dart';

/// Codepoints in the bundled `TransportGlyphs` icon font (assets/fonts/
/// TransportGlyphs.ttf, built by `build_transport_glyphs.py`) — symbols Material
/// Icons has none for. Const `IconData`, so they tree-shake and render exactly
/// like a Material icon; the custom `fontFamily` is what points at the bundled
/// font. Shared by every curated icon set (transport modes, cost reasons).
const IconData kHorseGlyph = IconData(
  0xE800,
  fontFamily: kTransportGlyphsFamily,
);
const IconData kGondolaGlyph = IconData(
  0xE801,
  fontFamily: kTransportGlyphsFamily,
);
const IconData kChairliftGlyph = IconData(
  0xE802,
  fontFamily: kTransportGlyphsFamily,
);
const IconData kTbarGlyph = IconData(
  0xE803,
  fontFamily: kTransportGlyphsFamily,
);

/// The font family the glyphs above are declared under in `pubspec.yaml`. The
/// PDF export reads it to tell them from Material icons, which live in a font
/// of their own there.
const String kTransportGlyphsFamily = 'TransportGlyphs';
