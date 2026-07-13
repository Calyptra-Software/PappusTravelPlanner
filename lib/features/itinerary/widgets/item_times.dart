import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../data/database/app_database.dart';

/// The colour a delay reads in: red when the entry ran late, green when it ran
/// early or to the minute. Green has no slot in a Material colour scheme (which
/// only names error), so it is spelled out here, one tone per brightness.
Color delayColor(ThemeData theme, int delta) {
  if (delta > 0) return theme.colorScheme.error;
  return theme.brightness == Brightness.dark
      ? const Color(0xFF7BC67E)
      : const Color(0xFF2E7D32);
}

/// The times of an itinerary entry: the planned range, each end carrying — once
/// the actual time is recorded — how far it missed its plan ("09:00 (+15) –
/// 10:30 (−5)").
///
/// The actual time itself is not spelled out: plan plus delta already says it,
/// and printing both only makes the line longer to read the same thing. What the
/// day is being judged against stays the anchor; the deltas are the news.
///
/// An actual time recorded against no planned one has nothing to be late for, so
/// it simply takes the plan's place in the range — it is then the only time the
/// entry knows.
class ItemTimes extends StatelessWidget {
  const ItemTimes({super.key, required this.item, this.style});

  final ItineraryItem item;

  /// The row's own time style; the deltas take their colour and weight on top.
  final TextStyle? style;

  /// Whether [item] carries any time at all — planned or actual. Callers use it
  /// to decide whether to give the times a slot in the row.
  static bool hasAny(ItineraryItem item) =>
      item.startMinutes != null ||
      item.endMinutes != null ||
      item.actualStartMinutes != null ||
      item.actualEndMinutes != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <InlineSpan>[];

    void addEnd(int? plannedMinutes, int? actualMinutes) {
      final shown = plannedMinutes ?? actualMinutes;
      if (shown == null) return;
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' – '));
      spans.add(TextSpan(text: formatMinutes(shown)));
      if (plannedMinutes == null || actualMinutes == null) return;
      final delta = actualMinutes - plannedMinutes;
      spans.add(
        TextSpan(
          text: ' (${formatSignedMinutes(delta)})',
          style: TextStyle(
            color: delayColor(theme, delta),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    addEnd(item.startMinutes, item.actualStartMinutes);
    addEnd(item.endMinutes, item.actualEndMinutes);

    if (spans.isEmpty) return const SizedBox.shrink();
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
