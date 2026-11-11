import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/routine_controller.dart';
import 'look_up_trip_connections.dart';

/// Stamps a real trip out of [routine], asking first when it starts and whether
/// to look its journeys up.
///
/// Returns the new trip's id, or null if the user backed out before it was
/// created. Once it *is* created nothing here can fail destructively: looking
/// the journeys up is an improvement on a trip that already exists and is
/// already correct as a plan.
Future<int?> createTripFromRoutine(
  BuildContext context,
  WidgetRef ref,
  Trip routine,
) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showAppSheet<_RoutineRunChoice>(
    context,
    builder: (_) => _RoutineRunSheet(routine: routine),
  );
  if (choice == null || !context.mounted) return null;

  // Recording the same routine twice on one day is easy to do when the point of
  // the feature is recording a commute morning and evening — so it is asked
  // about, never refused.
  final existing = await ref
      .read(repositoryProvider)
      .tripsFromRoutineOn(routine.id, choice.startDate);
  if (existing.isNotEmpty && context.mounted) {
    final localeName = Localizations.localeOf(context).languageCode;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.routineAlreadyRecordedTitle),
        content: Text(
          l10n.routineAlreadyRecordedBody(
            routine.title,
            formatFullDate(choice.startDate, localeName),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.routineCreateAnyway),
          ),
        ],
      ),
    );
    if (proceed != true) return null;
  }
  if (!context.mounted) return null;

  final tripId = await ref
      .read(routineControllerProvider)
      .createTrip(routine.id, startDate: choice.startDate);
  if (!context.mounted) return tripId;

  if (choice.lookUpConnections) {
    await lookUpTripConnections(context, ref, tripId);
  }
  return tripId;
}

/// What the run sheet answers: when the trip starts, and whether its journeys
/// should be looked up for those dates.
typedef _RoutineRunChoice = ({DateTime startDate, bool lookUpConnections});

class _RoutineRunSheet extends ConsumerStatefulWidget {
  const _RoutineRunSheet({required this.routine});

  final Trip routine;

  @override
  ConsumerState<_RoutineRunSheet> createState() => _RoutineRunSheetState();
}

class _RoutineRunSheetState extends ConsumerState<_RoutineRunSheet> {
  late DateTime _startDate = normalizeDay(DateTime.now());
  bool _lookUp = true;
  int _span = 1;

  @override
  void initState() {
    super.initState();
    _loadSpan();
  }

  /// How many days the routine covers, so the sheet can say what range the trip
  /// will occupy before it is created.
  Future<void> _loadSpan() async {
    final span = await ref
        .read(repositoryProvider)
        .routineDaySpan(widget.routine.id);
    if (mounted) setState(() => _span = span);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      // Backwards as far as forwards: a day that was travelled but never
      // recorded is exactly what this is for.
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _startDate = normalizeDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final end = addDays(_startDate, _span - 1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.routineCreateTripFor,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.routine.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.routineStartDate),
              subtitle: Text(
                // A one-day routine names its day; a longer one names the range
                // it will occupy, so the answer is visible before committing.
                _span == 1
                    ? formatFullDate(_startDate, localeName)
                    : formatDateRange(l10n, localeName, _startDate, end),
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _lookUp,
              onChanged: (value) => setState(() => _lookUp = value),
              title: Text(l10n.routineLookUpConnections),
              subtitle: Text(l10n.routineLookUpConnectionsBody),
              isThreeLine: true,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, (
                startDate: _startDate,
                lookUpConnections: _lookUp,
              )),
              icon: const Icon(Icons.check),
              label: Text(l10n.routineCreateTrip),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
