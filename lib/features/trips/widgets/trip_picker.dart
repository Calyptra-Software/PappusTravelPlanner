import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';

/// Asks which trip something should go to, and returns it (null if dismissed).
///
/// A picker, where an itinerary entry gets picked up and carried: the
/// destinations here are just *the trips*, a short flat list that names itself.
/// It is only when the destinations are many and structured — every day times
/// every option — that a picker stops working and the entry has to travel to a
/// place you can see.
///
/// The caller decides what [trips] holds, since what counts as a candidate is
/// the caller's question: a checklist leaves out the trip it is already in, and
/// a connection leaves out the routines (a real-dated journey laid onto a
/// dateless plan needs a plan day this list cannot ask for).
Future<Trip?> showTripPicker(BuildContext context, List<Trip> trips) {
  final l10n = AppLocalizations.of(context);
  final localeName = Localizations.localeOf(context).languageCode;
  return showDialog<Trip>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.tripPickerTitle),
      children: [
        for (final trip in trips)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, trip),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(trip.title),
              subtitle: Text(
                formatDateRange(l10n, localeName, trip.startDate, trip.endDate),
              ),
            ),
          ),
      ],
    ),
  );
}
