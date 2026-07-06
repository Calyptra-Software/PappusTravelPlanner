import 'package:flutter/material.dart';

import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';

/// Display order for the transport-mode picker. Decoupled from the enum's
/// declaration order (which is fixed because it is the stored `intEnum` index),
/// so modes can be reordered in the UI without remapping saved data.
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

/// UI mapping for [TransportMode] — icon and human label in one place.
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
