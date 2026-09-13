import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// "12 of 40 trips" above a searched and filtered list, with the way back out
/// beside it while a filter is active.
///
/// Always drawn, also when nothing is narrowed ("40 of 40"): the count is worth
/// having on its own, the two readings share one shape so a difference is read
/// at a glance, and a line that came and went with the first tapped tag chip
/// would push the whole list down and back up under the finger.
///
/// It counts what *matches*, never what is on screen — above the calendar a
/// month shows only some of them, and the map cannot draw a trip without
/// positions — which is why the label says "of" and not "shown".
///
/// Clearing is offered only for the filter facets, the same scope as the
/// filter sheet's own button: the search text is thrown away by the app bar's
/// close button, and a second control meaning something slightly different
/// would be one too many.
class QueryResultLine extends StatelessWidget {
  const QueryResultLine({super.key, required this.label, this.onClear});

  /// The already-localized count, e.g. `l10n.tripsMatching(12, 40)`.
  final String label;

  /// Clears the filters, or null when none is active.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      // Fixed, so the button appearing does not move the list either.
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (onClear != null)
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(l10n.clearFilters),
              ),
          ],
        ),
      ),
    );
  }
}
