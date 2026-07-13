import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../data/database/app_database.dart';
import '../time_marks.dart';

/// The colour a delay reads in: red when the entry ran late, green when it ran
/// early or to the minute. Green has no slot in a Material colour scheme (which
/// only names error), so it is spelled out here, one tone per brightness.
Color delayColor(ThemeData theme, int delta) {
  if (delta > 0) return theme.colorScheme.error;
  return theme.brightness == Brightness.dark
      ? const Color(0xFF7BC67E)
      : const Color(0xFF2E7D32);
}

/// The times of an itinerary entry as the timeline draws them: the planned
/// range, each end carrying — once the actual time is recorded — how far it
/// missed its plan, in colour ("09:00 (+15) – 10:30 (−5)"). What is printed is
/// decided by [timeMarks]; this only paints it.
class ItemTimes extends StatelessWidget {
  const ItemTimes({super.key, required this.item, this.style});

  final ItineraryItem item;

  /// The row's own time style; the deltas take their colour and weight on top.
  final TextStyle? style;

  /// Whether [item] carries any time at all — planned or actual. Callers use it
  /// to decide whether to give the times a slot in the row.
  static bool hasAny(ItineraryItem item) => timeMarks(item).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marks = timeMarks(item);
    if (marks.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    for (final mark in marks) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' – '));
      spans.add(TextSpan(text: formatMinutes(mark.minutes)));
      final delta = mark.delta;
      if (delta == null) continue;
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
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
