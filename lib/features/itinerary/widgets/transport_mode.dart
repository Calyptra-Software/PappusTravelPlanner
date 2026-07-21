import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';

/// Seed order for the transport modes: the order the built-ins are laid out in
/// the picker and settings list (their `sortOrder`). Decoupled from the enum's
/// declaration order (which is fixed as the stable `builtinKey`), so built-ins
/// can be presented in a friendlier order without touching their identity.
const List<TransportMode> kTransportModeOrder = [
  TransportMode.walk,
  TransportMode.bike,
  TransportMode.ski,
  TransportMode.car,
  TransportMode.taxi,
  TransportMode.bus,
  TransportMode.train,
  TransportMode.tram,
  TransportMode.subway,
  TransportMode.ferry,
  TransportMode.flight,
  TransportMode.other,
];

/// Codepoints in the bundled `TransportGlyphs` icon font (assets/fonts/
/// TransportGlyphs.ttf, built by `build_transport_glyphs.py`) — transport modes
/// Material Icons has no symbol for. Const `IconData`, so they tree-shake and
/// render exactly like a Material icon; the custom `fontFamily` is what points
/// at the bundled font.
const IconData _horse = IconData(0xE800, fontFamily: 'TransportGlyphs');
const IconData _gondola = IconData(0xE801, fontFamily: 'TransportGlyphs');
const IconData _chairlift = IconData(0xE802, fontFamily: 'TransportGlyphs');
const IconData _tbar = IconData(0xE803, fontFamily: 'TransportGlyphs');

/// Curated set of icons a transport mode can be tagged with — everything that
/// plausibly moves a traveller from A to B. Keyed by a stable integer stored in
/// `TransportModes.iconId`; values are `const IconData` so Flutter's icon
/// tree-shaking keeps working (a dynamically built `IconData` would force
/// `--no-tree-shake-icons`). A few come from the bundled `TransportGlyphs` font
/// (above) rather than Material Icons. Only append new entries — never reuse or
/// reorder a key, since it is persisted in the database.
const Map<int, IconData> kTransportModeIcons = {
  // on foot
  0: Icons.directions_walk,
  1: Icons.hiking,
  // cycles & small motors
  2: Icons.directions_bike,
  3: Icons.pedal_bike,
  4: Icons.electric_bike,
  5: Icons.electric_scooter,
  6: Icons.two_wheeler,
  // road
  7: Icons.directions_car,
  8: Icons.directions_car_filled,
  9: Icons.local_taxi,
  10: Icons.directions_bus,
  11: Icons.airport_shuttle,
  12: Icons.local_shipping,
  13: Icons.agriculture,
  // rail
  14: Icons.train,
  15: Icons.directions_railway,
  16: Icons.tram,
  17: Icons.directions_subway,
  18: Icons.directions_transit,
  // water
  19: Icons.directions_boat,
  20: Icons.sailing,
  21: Icons.kayaking,
  22: Icons.rowing,
  // air
  23: Icons.flight,
  24: Icons.flight_takeoff,
  25: Icons.flight_land,
  26: Icons.paragliding,
  // snow & ski lifts (the last three from the bundled TransportGlyphs font)
  27: Icons.downhill_skiing,
  28: Icons.snowshoeing,
  29: Icons.snowmobile,
  30: _gondola,
  31: _chairlift,
  32: _tbar,
  // animal (bundled TransportGlyphs font)
  33: _horse,
  // catch-alls — the generic "three dots" stays last
  34: Icons.commute,
  35: Icons.emoji_transportation,
  36: Icons.more_horiz,
};

/// The icon shown when a mode has no icon assigned and no built-in default (an
/// unknown id, or a custom mode the user never gave an icon).
const IconData kDefaultTransportModeIcon = Icons.more_horiz;

/// Resolves a stored [iconId] to an icon, falling back to the default. Used for
/// the icon grid and any place holding a raw id rather than a mode row.
IconData iconForTransportMode(int? iconId) =>
    kTransportModeIcons[iconId] ?? kDefaultTransportModeIcon;

/// The built-in a `builtinKey` names, or null if the key isn't a known built-in
/// (e.g. a bundle from a newer app, or a custom mode's key — there is none).
TransportMode? builtinTransportModeFor(String key) {
  for (final mode in TransportMode.values) {
    if (mode.name == key) return mode;
  }
  return null;
}

/// The label for a bare mode key (the form the sharing bundle and PDF carry):
/// the localized built-in label when [key] names one, otherwise the key itself,
/// which for a custom mode is exactly the user's typed name.
String labelForTransportModeKey(String key, AppLocalizations l10n) =>
    builtinTransportModeFor(key)?.label(l10n) ?? key;

/// UI mapping for a built-in [TransportMode] — its default icon, its localized
/// label, and the icon-set id that default corresponds to (used when seeding a
/// built-in's row so its chosen icon starts on the matching curated entry).
extension TransportModeUi on TransportMode {
  IconData get icon {
    switch (this) {
      case TransportMode.walk:
        return Icons.directions_walk;
      case TransportMode.bike:
        return Icons.directions_bike;
      case TransportMode.car:
        return Icons.directions_car;
      case TransportMode.taxi:
        return Icons.local_taxi;
      case TransportMode.bus:
        return Icons.directions_bus;
      case TransportMode.train:
        return Icons.train;
      case TransportMode.tram:
        return Icons.tram;
      case TransportMode.subway:
        return Icons.directions_subway;
      case TransportMode.ferry:
        return Icons.directions_boat;
      case TransportMode.flight:
        return Icons.flight;
      case TransportMode.other:
        return Icons.more_horiz;
      case TransportMode.ski:
        return Icons.downhill_skiing;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case TransportMode.walk:
        return l10n.modeWalk;
      case TransportMode.bike:
        return l10n.modeBike;
      case TransportMode.car:
        return l10n.modeCar;
      case TransportMode.taxi:
        return l10n.modeTaxi;
      case TransportMode.bus:
        return l10n.modeBus;
      case TransportMode.train:
        return l10n.modeTrain;
      case TransportMode.tram:
        return l10n.modeTram;
      case TransportMode.subway:
        return l10n.modeSubway;
      case TransportMode.ferry:
        return l10n.modeFerry;
      case TransportMode.flight:
        return l10n.modeFlight;
      case TransportMode.other:
        return l10n.modeOther;
      case TransportMode.ski:
        return l10n.modeSki;
    }
  }
}

/// UI mapping for a persisted [TransportModeRow] — the icon and label to draw
/// for it. A pristine built-in (no [name], no chosen [iconId]) falls back to its
/// [builtinKey]'s localized label and default icon; a custom mode or a renamed /
/// re-iconed built-in uses what the user set.
extension TransportModeRowUi on TransportModeRow {
  IconData get icon => kTransportModeIcons[iconId] ?? defaultIcon;

  /// The icon this mode falls back to when it has no [iconId] of its own: a
  /// built-in's own icon, or the generic default for a custom mode (which has
  /// no icon of its own to fall back to).
  IconData get defaultIcon {
    final key = builtinKey;
    if (key != null) {
      return builtinTransportModeFor(key)?.icon ?? kDefaultTransportModeIcon;
    }
    return kDefaultTransportModeIcon;
  }

  String label(AppLocalizations l10n) {
    final custom = name;
    if (custom != null && custom.isNotEmpty) return custom;
    final key = builtinKey;
    if (key != null) return builtinTransportModeFor(key)?.label(l10n) ?? key;
    return '';
  }
}
