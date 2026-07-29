import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart' show formatSignedMinutes;
import '../../itinerary/widgets/item_times.dart' show delayColor;
import '../data/journey_mapper.dart' show localParts;
import '../domain/journey.dart';
import '../domain/transit_mode.dart';

/// How the connection search writes a routed journey: shared by the results
/// list and the preview, so a time, a duration and an icon read the same in
/// both.

/// The local time of a leg end, plus — when the service reported real-time data
/// for it — a coloured signed delta ("(+5)", or green "(+0)" when it is running
/// to plan). Deliberately the same shape as the itinerary's delay marks: the
/// planned time is what is printed, the miss rides beside it.
List<InlineSpan> legTimeSpans(BuildContext context, LegPoint end) {
  final theme = Theme.of(context);
  final materialL10n = MaterialLocalizations.of(context);
  final scheduled = localParts(end.scheduled, end.timeZone);
  final spans = <InlineSpan>[
    TextSpan(
      text: materialL10n.formatTimeOfDay(
        TimeOfDay(
          hour: scheduled.minutes ~/ 60,
          minute: scheduled.minutes % 60,
        ),
      ),
    ),
  ];
  final actual = end.actual;
  if (actual != null) {
    final delta = localParts(actual, end.timeZone).minutes - scheduled.minutes;
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
  return spans;
}

/// How long a journey takes, as the results write it: "7h 7m", or bare minutes
/// under the hour — a walk across town is a matter of minutes, and "0h 12m"
/// reads like something went wrong.
String formatJourneyDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
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
