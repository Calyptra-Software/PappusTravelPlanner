import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../l10n/app_localizations.dart';

/// The colour "now" is drawn in. Deliberately *not* the trip's accent — the
/// timeline already spends that colour on days, groups and decisions, and the
/// mark must not read as one more part of the plan. Every trip accent is a
/// choosable colour, so nothing derived from it could be told apart from it.
Color nowColor(ThemeData theme) => theme.colorScheme.error;

/// The line between what is behind us and what is still ahead of us today, with
/// the current time on it. Sits between two entries — never inside one; the
/// entry that is under way is marked by [NowBadge] instead.
class NowLine extends StatelessWidget {
  const NowLine({super.key, required this.minutes});

  /// The current time, as minutes since midnight.
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = nowColor(theme);
    return Semantics(
      label: l10n.now,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Centred on the timeline's rail: the gutter is 40 wide (see
            // `_Gutter`), so the dot lands on the line the day is strung along.
            SizedBox(
              width: 40,
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
            Expanded(child: Container(height: 2, color: color)),
            const SizedBox(width: 8),
            Text(
              formatMinutes(minutes),
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks the entry that is under way right now.
class NowBadge extends StatelessWidget {
  const NowBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = nowColor(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        l10n.now,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
