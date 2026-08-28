import 'package:flutter/material.dart';

import '../../../core/widgets/app_sheet.dart';
import '../domain/journey.dart';
import '../journey_view.dart';
import 'journey_sheet.dart';

/// Shows [option] leg by leg and offers to add it to the trip. Resolves to true
/// when the user confirmed, false/null when they backed out.
///
/// [confirmable] false drops the button: the search was made with no plan behind
/// it, so there is nowhere for this journey to go and the sheet is the whole
/// answer. A button that wrote nothing would be worse than none.
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
  bool confirmable = true,
  String? title,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final confirmed = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => JourneySheet(
      view: journeyViewFromOption(option),
      title: title,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: confirmable
          ? () => Navigator.of(sheetContext).pop(true)
          : null,
    ),
  );
  return confirmed ?? false;
}
