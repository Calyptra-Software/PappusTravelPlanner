import 'package:flutter/material.dart';

import '../domain/journey.dart';
import '../journey_view.dart';
import 'journey_sheet.dart';

/// Shows [option] leg by leg and offers to add it to the trip. Resolves to true
/// when the user confirmed, false/null when they backed out.
///
/// This is the step between finding a connection and owning it. A result row
/// can only say *07:34 – 14:41 · 2 changes · ICE 507 → ICE 71*; what a traveller
/// decides on is the rest — which platform, how long the change in Frankfurt
/// is, whether the 6 minutes in Basel are 6 minutes of walking. So tapping a
/// result **opens** it and the button here **commits** it, the same division
/// the itinerary draws between browsing an option and choosing it.
///
/// The reading itself is [JourneySheet]'s, shared with the journey the trip ends
/// up holding — so what was decided on is what is later read back.
Future<bool> showJourneyPreviewSheet(
  BuildContext context, {
  required JourneyOption option,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => JourneySheet(
      view: journeyViewFromOption(option),
      onConfirm: () => Navigator.of(sheetContext).pop(true),
    ),
  );
  return confirmed ?? false;
}
