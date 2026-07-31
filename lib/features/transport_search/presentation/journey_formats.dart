import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart' show formatSignedMinutes;
import '../../../data/database/app_database.dart' show TransportModeRow;
import '../../../l10n/app_localizations.dart';
import '../../itinerary/widgets/item_times.dart' show delayColor;
import '../../itinerary/widgets/transport_mode.dart'
    show TransportModeRowUi, TransportModeUi, kDefaultTransportModeIcon;
import '../data/journey_mapper.dart' show builtinTransportModeFor, localParts;
import '../domain/journey.dart';
import '../domain/transit_mode.dart';
import '../journey_view.dart';

/// How the connection search writes a journey: shared by the results list, the
/// preview and a journey the trip already holds, so a time, a duration and an
/// icon read the same in all of them.

/// The local time of a leg end, plus — when the service reported real-time data
/// for it — a coloured signed delta ("(+5)", or green "(+0)" when it is running
/// to plan). Deliberately the same shape as the itinerary's delay marks: the
/// planned time is what is printed, the miss rides beside it.
List<InlineSpan> legTimeSpans(BuildContext context, LegPoint end) {
  final scheduled = localParts(end.scheduled, end.timeZone);
  final actual = end.actual;
  return timeSpans(
    context,
    minutes: scheduled.minutes,
    delay: actual == null
        ? null
        : localParts(actual, end.timeZone).minutes - scheduled.minutes,
  );
}

/// The same, for an end of a journey being *read* — routed or stored alike.
List<InlineSpan> pointTimeSpans(BuildContext context, ViewPoint point) =>
    point.minutes == null
    ? const []
    : timeSpans(context, minutes: point.minutes!, delay: point.delay);

/// A wall-clock time and, optionally, how far off it is running.
List<InlineSpan> timeSpans(
  BuildContext context, {
  required int minutes,
  int? delay,
}) {
  final theme = Theme.of(context);
  final spans = <InlineSpan>[
    TextSpan(
      text: MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60)),
    ),
  ];
  if (delay != null) {
    spans.add(
      TextSpan(
        text: ' (${formatSignedMinutes(delay)})',
        style: TextStyle(
          color: delayColor(theme, delay),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
  return spans;
}

/// The icon for a leg's mode, whichever of the two ways the view knows it: the
/// router's own vocabulary, or a row in the user's transport modes (which is
/// where a custom mode's chosen icon lives).
IconData viewModeIcon(ViewMode? mode, Map<int, TransportModeRow> modesById) =>
    switch (mode) {
      RoutedMode(mode: final transit) => transitIcon(transit),
      StoredMode(:final modeId) =>
        modesById[modeId]?.icon ?? kDefaultTransportModeIcon,
      null => transitIcon(null),
    };

/// What that mode is called, or null when nothing is known to call it — an
/// unmapped routing mode, or a leg whose mode row was deleted.
String? viewModeLabel(
  ViewMode? mode,
  AppLocalizations l10n,
  Map<int, TransportModeRow> modesById,
) => switch (mode) {
  RoutedMode(mode: final transit) => builtinTransportModeFor(
    transit,
  )?.label(l10n),
  StoredMode(:final modeId) => modesById[modeId]?.label(l10n),
  null => null,
};

/// How long a journey takes, as the results write it: "7h 7m", or bare minutes
/// under the hour — a walk across town is a matter of minutes, and "0h 12m"
/// reads like something went wrong.
String formatJourneyDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

/// A stay someone *chooses* — the minimum time at a via stop — written out in
/// words rather than the compact "1h 30m" a journey's duration uses.
///
/// A duration read off a result is scanned beside a dozen others, where terse
/// is a virtue; this one is picked from a menu, and "2 h" reads as an amount of
/// time to spend somewhere.
String formatStayDuration(AppLocalizations l10n, int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return l10n.connectionMinutesShort(rest);
  return rest == 0
      ? l10n.connectionHoursShort(hours)
      : l10n.connectionHoursMinutesShort(hours, rest);
}

IconData transitIcon(TransitMode? mode) {
  switch (mode) {
    case TransitMode.walk:
      return Icons.directions_walk;
    case TransitMode.bike:
      return Icons.directions_bike;
    case TransitMode.car:
      return Icons.directions_car;
    case TransitMode.bus:
    case TransitMode.coach:
      return Icons.directions_bus;
    case TransitMode.tram:
      return Icons.tram;
    case TransitMode.subway:
    case TransitMode.monorail:
      return Icons.subway;
    case TransitMode.ferry:
      return Icons.directions_boat;
    case null:
      return Icons.more_horiz;
    default:
      return Icons.train;
  }
}
