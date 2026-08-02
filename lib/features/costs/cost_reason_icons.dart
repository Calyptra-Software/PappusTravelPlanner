import 'package:flutter/material.dart';

import '../../core/icons/transport_glyphs.dart';

/// Curated set of icons a cost reason can be tagged with. Keyed by a stable
/// integer stored in `CostReasons.iconId`; values are `const IconData` so
/// Flutter's icon tree-shaking keeps working (a dynamically built `IconData`
/// would force `--no-tree-shake-icons`), a few of them from the bundled
/// `TransportGlyphs` font (`core/icons/`) where Material Icons has no symbol.
/// Only ever hand a new icon a fresh key — a key is persisted in the database,
/// so it must never be reused or point at a different icon. Where an entry sits
/// in the literal is only the order the picker lays it out in, so a later
/// addition may join the group it belongs to.
const Map<int, IconData> kCostReasonIcons = {
  // food & drink
  0: Icons.restaurant,
  1: Icons.local_cafe,
  2: Icons.local_bar,
  3: Icons.lunch_dining,
  4: Icons.apple, // fruit / groceries
  // lodging, sights & activities
  5: Icons.hotel,
  29: Icons.house, // house / holiday flat
  6: Icons.attractions,
  7: Icons.museum,
  8: Icons.beach_access,
  9: Icons.downhill_skiing, // ski
  28: kHorseGlyph, // riding
  // transport
  10: Icons.train,
  11: Icons.flight,
  12: Icons.directions_car,
  13: Icons.local_taxi,
  14: Icons.directions_bus,
  27: Icons.directions_bike,
  15: Icons.directions_boat,
  16: Icons.local_gas_station,
  // shopping & apparel
  17: Icons.shopping_cart,
  18: Icons.card_giftcard,
  19: Icons.checkroom, // clothing
  20: Icons.backpack,
  21: Icons.phone_iphone, // electronics
  22: Icons.power, // plug
  // utilities, health & other
  23: Icons.wifi,
  24: Icons.local_hospital,
  25: Icons.local_pharmacy,
  26: Icons.pets,
  30: Icons.handyman, // tools / repairs
};

/// The icon shown when a reason has no icon assigned (or an unknown id).
const IconData kDefaultCostReasonIcon = Icons.payments_outlined;

/// Resolves a reason's stored [iconId] to an icon, falling back to the default.
IconData iconForReason(int? iconId) =>
    kCostReasonIcons[iconId] ?? kDefaultCostReasonIcon;
