import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/civil_date.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../trip_kind.dart';

/// Which day of a routine an entry belongs to, chosen as an **ordinal**.
///
/// A routine has no dates, so a calendar is the wrong instrument entirely: the
/// dates its entries carry are a sort origin, and asking someone to type
/// "2 January 1970" to mean "day two" is exposing the storage. The days on
/// offer are the days the plan already shows, plus the one after them — so a
/// routine grows a day by planning something on it, which is the same way its
/// first day came about.
class RoutineDayField extends ConsumerWidget {
  const RoutineDayField({
    super.key,
    required this.tripId,
    required this.value,
    required this.onChanged,
  });

  final int tripId;

  /// The day currently chosen, as stored — an absolute date whose only meaning
  /// is its position among the plan's days.
  final DateTime value;

  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(itineraryProvider(tripId)).value ?? const [];
    final sets =
        ref.watch(alternativeSetsProvider(tripId)).value ??
        const <int, AlternativeSet>{};

    final days = routineDaysOf(items, sets.values);
    final chosen = normalizeDay(value);
    // The plan's days, plus wherever the entry being edited sits (it may be on
    // a day nothing else is on yet), plus one more to grow into.
    final options = <DateTime>{...days, chosen}.toList()..sort();
    options.add(addDays(options.last, 1));

    return DropdownButtonFormField<DateTime>(
      initialValue: chosen,
      decoration: InputDecoration(
        labelText: l10n.fieldDay,
        prefixIcon: const Icon(Icons.event),
      ),
      items: [
        for (final (index, day) in options.indexed)
          DropdownMenuItem(
            value: day,
            child: Text(
              // The last entry is the day that does not exist yet, and says so
              // rather than pretending to be one of the plan's.
              index == options.length - 1
                  ? l10n.routineNewDay(index + 1)
                  : l10n.routineDayNumber(index + 1),
            ),
          ),
      ],
      onChanged: (day) {
        if (day != null) onChanged(day);
      },
    );
  }
}
