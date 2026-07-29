import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../itinerary/widgets/transport_mode.dart' show TransportModeUi;
import '../data/journey_mapper.dart' show builtinTransportModeFor, localParts;
import '../domain/journey.dart';
import '../journey_preview.dart';
import 'journey_formats.dart';

/// Shows [option] leg by leg and offers to add it to the trip. Resolves to true
/// when the user confirmed, false/null when they backed out.
///
/// This is the step between finding a connection and owning it. A result row
/// can only say *07:34 – 14:41 · 2 changes · ICE 507 → ICE 71*; what a traveller
/// decides on is the rest — which platform, how long the change in Frankfurt
/// is, whether the 6 minutes in Basel are 6 minutes of walking. So tapping a
/// result **opens** it and the button here **commits** it, the same division
/// the itinerary draws between browsing an option and choosing it.
Future<bool> showJourneyPreviewSheet(
  BuildContext context, {
  required JourneyOption option,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => JourneyPreviewSheet(option: option),
  );
  return confirmed ?? false;
}

class JourneyPreviewSheet extends StatelessWidget {
  const JourneyPreviewSheet({super.key, required this.option});

  final JourneyOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final rows = journeyPreview(option);

    final dep = option.legs.first.from;
    final arr = option.legs.last.to;
    final nextDay = localParts(
      arr.scheduled,
      arr.timeZone,
    ).date.isAfter(localParts(dep.scheduled, dep.timeZone).date);
    // The router plans around cancellations, so a cancelled result is all but
    // unreachable — which is why the preview must show one plainly if it ever
    // is reached, rather than letting it in as an ordinary connection.
    final cancelled = option.legs.any((leg) => leg.cancelled);

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
                Text.rich(
                  TextSpan(
                    children: [
                      ...legTimeSpans(context, dep),
                      const TextSpan(text: ' – '),
                      ...legTimeSpans(context, arr),
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
                  '${formatJourneyDuration(option.duration)} · '
                  '${l10n.connectionChanges(option.transfers)}',
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
                    LegRow(:final leg) => _LegCard(leg: leg),
                    ChangeRow() => _ChangeTile(change: row),
                  },
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + media.padding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.connectionAddToDay),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ),
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
  const _LegCard({required this.leg});

  final JourneyLeg leg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final headsign = leg.headsign;
    // A walking or cycling stretch has no line to name, so it is named by what
    // it is; a service falls back to its mode only when the feed gave no line.
    final modeLabel = builtinTransportModeFor(leg.mode)?.label(l10n);
    final service = leg.line ?? modeLabel ?? '';
    final duration = leg.to.scheduled.difference(leg.from.scheduled);

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
            _StopLine(end: leg.from),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    transitIcon(leg.mode),
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
                  Text(
                    formatJourneyDuration(duration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
            _StopLine(end: leg.to),
          ],
        ),
      ),
    );
  }
}

/// A stop as one line: when, where, and from which platform.
class _StopLine extends StatelessWidget {
  const _StopLine({required this.end});

  final LegPoint end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final track = end.track;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: legTimeSpans(context, end)),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
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
  const _ChangeTile({required this.change});

  final ChangeRow change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final toPlace = change.toPlace;
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
                  toPlace == null
                      ? l10n.connectionChangeIn(change.minutes, change.place)
                      : l10n.connectionChangeBetween(
                          change.minutes,
                          change.place,
                          toPlace,
                        ),
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
                      color: actual < change.minutes
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
                          transitIcon(change.ownSteamMode),
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
