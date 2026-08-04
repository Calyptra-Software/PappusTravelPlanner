import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart'
    show ItineraryItem, TransportModeRow;
import '../../../l10n/app_localizations.dart';
import '../../itinerary/widgets/live_refresh_button.dart';
import '../journey_preview.dart';
import '../journey_view.dart';
import 'journey_formats.dart';

/// A journey read leg by leg: board here, ride this, change there.
///
/// One sheet for both of the app's journeys — the connection just found, which
/// this lets a traveller judge before owning it, and the one the trip already
/// holds, which it lets them read again while travelling. Both arrive as a
/// [JourneyView], so the walking transfer the router puts between two trains is
/// folded into *the change* in either case: a leg list of five rows that is
/// really "board, change, board" reads as three either side of the import.
class JourneySheet extends StatelessWidget {
  const JourneySheet({
    super.key,
    required this.view,
    this.title,
    this.modesById = const {},
    this.itemsById = const {},
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onFindConnection,
    this.onFindLegConnection,
  });

  final JourneyView view;

  /// A line above the times naming this journey — the group's label, on one the
  /// trip holds. The connection preview has nothing to say here yet.
  final String? title;

  /// The user's transport modes, needed to draw a stored leg's icon and label.
  /// Empty for a routed journey, which names its own modes.
  final Map<int, TransportModeRow> modesById;

  /// The itinerary rows behind the legs, keyed by id — what lets each stored leg
  /// offer its own live-times refresh. Empty for a routed journey (there is
  /// nothing to refresh into yet).
  final Map<int, ItineraryItem> itemsById;

  final String? confirmLabel;

  /// Names the way *out* of the sheet when declining is a real choice rather
  /// than a dismissal — "keep the plan", when the alternative to taking this
  /// connection is the one already in the trip. Absent, the sheet is simply
  /// swiped away.
  final String? cancelLabel;

  final VoidCallback? onConfirm;

  /// Asks the timetable about **this** run again, offered only on a journey the
  /// trip already holds: what it finds replaces these legs, so a plan copied
  /// from a routine, or a service that has since been cancelled, can be brought
  /// up to date from the sheet that shows it is out of date. Null on a preview
  /// (there is nothing to replace yet), and on a run whose ends can no longer be
  /// addressed to the router.
  final VoidCallback? onFindConnection;

  /// Asks the timetable about **one leg** of the run, offered on the leg's own
  /// card. The whole-journey button above answers "is there a better way to make
  /// this trip"; this one answers the question a journey in progress actually
  /// raises — the train in was late and the connection is gone, or the change is
  /// twenty minutes when it needed to be forty. Only that leg is replaced; the
  /// rest of the run, its bundle and its ticket stay as they are.
  ///
  /// Null on a preview, on a routine, and on a run of one leg — where the
  /// journey's own button already is the leg's.
  final ValueChanged<ItineraryItem>? onFindLegConnection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final rows = journeyPreview(view);
    final legs = view.legs;
    final dep = legs.firstOrNull?.from;
    final arr = legs.lastOrNull?.to;
    final nextDay = dep != null && arr != null && arr.date.isAfter(dep.date);
    // The router plans around cancellations, so a cancelled result is all but
    // unreachable — which is why the sheet must show one plainly if it ever
    // is reached, rather than letting it in as an ordinary connection.
    final cancelled = legs.any((leg) => leg.cancelled);
    final duration = view.duration;
    final confirm = onConfirm;
    final find = onFindConnection;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(
                    title!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (dep != null && arr != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        ...pointTimeSpans(context, dep),
                        const TextSpan(text: ' – '),
                        ...pointTimeSpans(context, arr),
                        if (nextDay)
                          TextSpan(
                            text: ' +1',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    style: theme.textTheme.titleLarge,
                  ),
                Text(
                  [
                    if (duration != null) formatJourneyDuration(duration),
                    l10n.connectionChanges(view.transfers),
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (cancelled)
                  Text(
                    l10n.connectionCancelled,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                for (final row in rows)
                  switch (row) {
                    LegRow(:final leg) => _LegCard(
                      leg: leg,
                      modesById: modesById,
                      item: itemsById[leg.itemId],
                      onFindConnection: onFindLegConnection,
                    ),
                    ChangeRow() => _ChangeTile(
                      change: row,
                      modesById: modesById,
                    ),
                  },
              ],
            ),
          ),
          if (confirm != null || find != null) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + media.padding.bottom,
              ),
              child: Row(
                children: [
                  // Never beside the confirm pair: one sheet previews a
                  // connection, the other reads the one that was taken.
                  if (find != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.travel_explore),
                        label: Text(l10n.connectionsFindForLeg),
                        onPressed: find,
                      ),
                    ),
                  if (confirm != null) ...[
                    if (cancelLabel != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(cancelLabel!),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(confirmLabel ?? l10n.connectionAddToDay),
                        onPressed: confirm,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else
            SizedBox(height: media.padding.bottom),
        ],
      ),
    );
  }
}

/// One leg to be travelled: board here, ride this, get off there.
///
/// The two ends bracket the service rather than sitting beside it, so the card
/// reads top-to-bottom in the order the leg is lived — and a platform sits on
/// the line of the stop it belongs to, which is the only place it means
/// anything.
class _LegCard extends StatelessWidget {
  const _LegCard({
    required this.leg,
    required this.modesById,
    this.item,
    this.onFindConnection,
  });

  final ViewLeg leg;
  final Map<int, TransportModeRow> modesById;

  /// The itinerary row this leg is, when the trip holds it.
  final ItineraryItem? item;

  /// Searches the timetable for this leg alone — see
  /// [JourneySheet.onFindLegConnection].
  final ValueChanged<ItineraryItem>? onFindConnection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final headsign = leg.headsign;
    final notes = leg.notes;
    // A walking or cycling stretch has no line to name, so it is named by what
    // it is; a service falls back to its mode only when the feed gave no line.
    final modeLabel = viewModeLabel(leg.mode, l10n, modesById);
    final service = leg.line ?? modeLabel ?? '';
    final duration = leg.duration;
    final refreshable = item != null && item!.sourceTripId != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: leg.cancelled
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EndLine(end: leg.from),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    viewModeIcon(leg.mode, modesById),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (service.isNotEmpty) service,
                        if (headsign != null &&
                            headsign.isNotEmpty &&
                            headsign != leg.to.name)
                          l10n.directionTo(headsign),
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (duration != null)
                    Text(
                      formatJourneyDuration(duration),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  // The leg's own live times, asked for from the leg they belong
                  // to. Only a stored leg has anything to refresh into.
                  if (refreshable) LiveRefreshButton(item: item!),
                  // …and its own search, for when it is this leg that has to
                  // change rather than the whole journey.
                  if (item != null && onFindConnection != null)
                    IconButton(
                      icon: const Icon(Icons.travel_explore),
                      tooltip: l10n.connectionsFindForLeg,
                      onPressed: () => onFindConnection!(item!),
                    ),
                ],
              ),
            ),
            // What the import wrote into the leg (direction, platforms) and
            // whatever the user has added since — the only place a stored leg's
            // platform survives, since the trip keeps no column for one.
            if (notes != null && notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  notes,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (leg.cancelled)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l10n.connectionCancelled,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (leg.stops.isNotEmpty) _StopsSection(stops: leg.stops),
            _EndLine(
              end: leg.to,
              dayOffset: leg.to.date.difference(leg.from.date).inDays,
            ),
          ],
        ),
      ),
    );
  }
}

/// The stops between a leg's ends, folded away behind their count.
///
/// Collapsed by default and on purpose: a regional train calls at thirty places
/// and the two that matter are the ones already on the card. Opened, it answers
/// the question a stop list is actually for — *does it stop at mine, and when
/// am I there?*
class _StopsSection extends StatefulWidget {
  const _StopsSection({required this.stops});

  final List<ViewStop> stops;

  @override
  State<_StopsSection> createState() => _StopsSectionState();
}

class _StopsSectionState extends State<_StopsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final cancelled = widget.stops.where((stop) => stop.cancelled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: muted,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.connectionStops(widget.stops.length),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                // The list is folded away by default, so the one thing that
                // cannot wait to be opened is said on the fold itself.
                if (cancelled > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    l10n.connectionStopsCancelled(cancelled),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              children: [
                for (final stop in widget.stops) _StopLine(stop: stop),
              ],
            ),
          ),
      ],
    );
  }
}

/// One stop passed through: when the service leaves it, how late that is, and
/// where it is.
///
/// A stop the service **skips** is struck through and named as cancelled rather
/// than removed from the list — the timetable still says the train comes past at
/// this minute, and a stop that quietly vanished would leave someone standing on
/// its platform. It shows no time-keeping either: a partially cancelled service
/// goes on reporting the planned departure for the stops it is dropping, and
/// printing that as a punctual "(+0)" is the one thing a stop list must not say.
class _StopLine extends StatelessWidget {
  const _StopLine({required this.stop});

  final ViewStop stop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colour = stop.cancelled
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final struck = stop.cancelled ? TextDecoration.lineThrough : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: timeSpans(
                context,
                minutes: stop.minutes,
                delay: stop.delay,
              ),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colour,
              decoration: struck,
              decorationColor: colour,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (stop.dayOffset > 0)
            Text(
              ' +${stop.dayOffset}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stop.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colour,
                decoration: struck,
                decorationColor: colour,
              ),
            ),
          ),
          if (stop.cancelled)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                l10n.connectionCancelled,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An end of a leg as one line: when, where, and from which platform.
class _EndLine extends StatelessWidget {
  const _EndLine({required this.end, this.dayOffset = 0});

  final ViewPoint end;

  /// How many days after the leg's departure this end falls — an overnight leg's
  /// arrival, marked "+1".
  final int dayOffset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final track = end.track;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: pointTimeSpans(context, end)),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (dayOffset > 0)
          Text(
            ' +$dayOffset',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        const SizedBox(width: 12),
        Expanded(child: Text(end.name, style: theme.textTheme.bodyMedium)),
        if (track != null && track.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              l10n.platformShort(track),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// A change between two services: how long there is, where, and how much of it
/// is spent walking to the next platform.
class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change, required this.modesById});

  final ChangeRow change;
  final Map<int, TransportModeRow> modesById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final toPlace = change.toPlace;
    final minutes = change.minutes;
    final actual = change.actualMinutes;
    final ownSteam = change.ownSteamMinutes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.swap_vert,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // A change between two legs nobody timed still happens; it
                  // just cannot be measured, so it is named without a figure
                  // rather than given one.
                  switch ((minutes, toPlace)) {
                    (final int m, null) => l10n.connectionChangeIn(
                      m,
                      change.place,
                    ),
                    (final int m, final String to) =>
                      l10n.connectionChangeBetween(m, change.place, to),
                    (null, null) => l10n.connectionChangePlace(change.place),
                    (null, final String to) => l10n.connectionChangePlaces(
                      change.place,
                      to,
                    ),
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                // What a delay actually threatens. Shown only when it differs
                // from the plan, and coloured as a warning only when the change
                // has grown *shorter* — a change that got longer is a wait, not
                // a risk, so the red the delay marks use would misread here.
                if (actual != null)
                  Text(
                    l10n.connectionChangeNow(actual),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: (minutes != null && actual < minutes)
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (ownSteam != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(
                          viewModeIcon(change.ownSteamMode, modesById),
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.connectionMinutesShort(ownSteam),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
