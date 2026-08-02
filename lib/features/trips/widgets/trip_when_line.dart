import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';

/// How a trip answers "when": one icon, one line, one optional trailing pill.
///
/// A trip answers it with its dates, however many days they span — one day is
/// not a different kind of answer, only a shorter one, so a walk reads as its
/// single date with no day-count pill beside it (a count of one says nothing).
/// A routine has no dates at all and answers with the shape of its plan.
///
/// Defined once because the overview card and the trip header must not be able
/// to disagree about it.
typedef TripWhenLine = ({IconData icon, String text, String? pill});

TripWhenLine tripWhenLine(
  Trip trip,
  AppLocalizations l10n,
  String localeName, {
  int routineDays = 1,
}) {
  if (trip.kind == TripKind.routine) {
    return (
      icon: Icons.repeat,
      text: l10n.routineNoDates,
      pill: l10n.days(routineDays),
    );
  }
  final days = tripDayCount(trip.startDate, trip.endDate);
  // One day is the ordinary case for an everyday trip, and "1 day" beside a
  // single date is noise; from two days up the count earns its place.
  return (
    icon: days == 1 ? Icons.event_outlined : Icons.calendar_today_outlined,
    text: days == 1
        ? formatFullDate(trip.startDate!, localeName)
        : formatDateRange(l10n, localeName, trip.startDate, trip.endDate),
    pill: days == null || days == 1 ? null : l10n.days(days),
  );
}
