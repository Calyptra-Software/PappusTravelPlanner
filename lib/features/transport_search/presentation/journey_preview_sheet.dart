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

/// What [showConnectionOfferSheet] was answered with.
enum ConnectionOfferAnswer {
  /// Take the connection on offer.
  use,

  /// Leave the run as the plan has it. Also what swiping the sheet away means:
  /// the plan is already written, so not answering changes nothing.
  keep,

  /// Neither: open the search form on this run and ask again — another train,
  /// another hour, a via stop.
  adjust,
}

/// Offers [option] as the replacement for a run the trip already holds, with a
/// third way out besides taking it and keeping the plan: adjusting the search.
///
/// This is the preview a routine's lookup shows for each journey it stamped out.
/// There "keep the plan" and "use this" are rarely the only two answers worth
/// giving — the connection found may be the one before the train the traveler
/// actually wants, and the copied plan has no live times either way — and
/// without a third button the way to the right one led out of this flow and
/// back in through the trip's journey sheet.
Future<ConnectionOfferAnswer> showConnectionOfferSheet(
  BuildContext context, {
  required JourneyOption option,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final answer = await showAppSheet<ConnectionOfferAnswer>(
    context,
    builder: (sheetContext) {
      void reply(ConnectionOfferAnswer value) =>
          Navigator.of(sheetContext).pop(value);
      return JourneySheet(
        view: journeyViewFromOption(option),
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: () => reply(ConnectionOfferAnswer.use),
        onCancel: () => reply(ConnectionOfferAnswer.keep),
        onAdjustSearch: () => reply(ConnectionOfferAnswer.adjust),
      );
    },
  );
  return answer ?? ConnectionOfferAnswer.keep;
}
