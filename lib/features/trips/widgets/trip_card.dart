import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import 'tag_chip.dart';
import 'trip_when_line.dart';

/// How large the cover photograph is drawn on an overview card.
///
/// Big enough to be a picture rather than a bullet point, and bounded by what
/// the text beside it needs: on a 320dp phone this still leaves the title some
/// 170dp, which is a readable line.
const double kTripCoverSize = 104;

/// Overview card summarising a single trip: a colour accent stripe on one edge
/// and, when the trip has a cover photograph, its thumbnail on the other.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.book,
    this.totals = const {},
    this.tags = const [],
    this.cover,
  });

  final Trip trip;
  final VoidCallback onTap;

  /// The tags this trip is filed under, drawn as a quiet row under the title.
  final List<Tag> tags;

  /// The currencies, for labelling and ordering [totals] — passed in rather
  /// than watched, since the list screen already holds one for every card.
  final CurrencyBook book;

  /// Cost totals for this trip in minor units, keyed by currency code. Empty
  /// when the trip has no costs, in which case the total row is hidden.
  final Map<String, int> totals;

  /// The thumbnail of the trip's cover photograph, or null — which is the
  /// ordinary case, since most trips have no pictures and a trip may say it
  /// wants no cover at all. Passed in rather than watched, like [book] and
  /// [totals]: the list screen reads one map for every card.
  final Uint8List? cover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final accent = Color(trip.colorValue);
    final when = tripWhenLine(trip, l10n, localeName);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: accent),
              // `Flexible` and not `Expanded`, so the column is only as wide as
              // its longest line: that is what lets the picture sit against the
              // text instead of out at the card's edge. Every row inside it has
              // to shrink-wrap too (`MainAxisSize.min` and `Flexible` rather
              // than `Expanded`), or one of them would claim the full width and
              // push the picture back out again.
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    cover == null ? 16 : 12,
                    16,
                  ),
                  // Gives the column a width of its own — the widest line it
                  // holds — which is what lets a row inside it push something
                  // to the *column's* right edge. Without it a `Column` only
                  // knows the width it is allowed, so either every row fills
                  // the card (and the picture is back at the edge) or every row
                  // shrink-wraps (and the day count sits mid-line). The cost is
                  // a second intrinsic pass per card, on top of the
                  // `IntrinsicHeight` this row already needs.
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trip.destination.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  trip.destination,
                                  style: theme.textTheme.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        // Left to fill the column, unlike the rows around it, so
                        // the day-count chip stays at the right-hand end of the
                        // block the way it always has.
                        Row(
                          children: [
                            Icon(
                              when.icon,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                when.text,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (when.pill != null) _Pill(label: when.pill!),
                          ],
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final tag in tags) TagChip(tag: tag),
                            ],
                          ),
                        ],
                        if (totals.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  formatTotals(totals, book, localeName),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // After the text rather than at the card's edge: the picture
              // belongs to what is written beside it, and pushed out to the
              // right it read as a separate column of the list. Still on the
              // trailing side, not the leading one — leading would move the
              // title of every card that has a picture and leave the edge you
              // scan down ragged, or force a placeholder, which is something
              // invented to fill a space rather than something said.
              if (cover case final bytes?)
                // Centred rather than stretched: the row's children are laid
                // out with `stretch`, so without this the picture would take
                // the card's whole height — which varies with the tags and the
                // totals, giving each card a differently proportioned crop.
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        bytes,
                        width: kTripCoverSize,
                        height: kTripCoverSize,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
