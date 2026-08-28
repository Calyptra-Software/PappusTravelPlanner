import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../transport_search/domain/journey.dart';
import '../../transport_search/presentation/journey_preview_sheet.dart';
import '../application/routine_controller.dart';

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
    await _lookUpConnections(context, ref, tripId);
  }
  return tripId;
}

/// Offers each journey in the new trip a fresh connection for the day it now
/// sits on, one at a time, and puts in whichever the user accepts.
///
/// The plan is already written, so every exit from here leaves a usable trip:
/// declining an option, finding nothing, or losing the network all end with the
/// copied plan still in place. What the lookup adds is a real service — and so
/// live times that can be refreshed — for the dates this trip actually runs.
///
/// **Says nothing when it works.** A connection that was taken is in the trip
/// the user is one tap from opening, so announcing it only queues a second
/// message in front of the one carrying that tap. What does get said is what
/// the trip cannot show: that a journey is still the copied plan because
/// nothing runs, or because the service was out of reach.
Future<void> _lookUpConnections(
  BuildContext context,
  WidgetRef ref,
  int tripId,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(routineControllerProvider);
  final labels = (
    track: l10n.platformShort,
    fromTrack: l10n.platformFromShort,
    toTrack: l10n.platformToShort,
    direction: l10n.directionTo,
  );

  final candidates = await controller.lookUpCandidates(tripId);
  if (candidates.isEmpty || !context.mounted) return;

  var missing = 0;
  var failed = 0;
  for (final journey in candidates) {
    List<JourneyOption> options;
    try {
      options = await controller.lookUp(journey);
    } catch (_) {
      // A network failure is not "nothing runs", and must not be reported as
      // it. The plan stands, so nothing is lost — but the service being out of
      // reach for this journey says the same about the rest, so the round ends
      // here rather than asking again per journey.
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.connectionsOffline)),
        );
      }
      return;
    }
    if (options.isEmpty) {
      missing++;
      continue;
    }
    if (!context.mounted) return;

    // The same sheet that previews a search result anywhere else — a journey
    // reads the same way whoever asked for it.
    final accepted = await showJourneyPreviewSheet(
      context,
      option: options.first,
      confirmLabel: l10n.connectionsUseThis,
      cancelLabel: l10n.connectionsKeepPlan,
    );
    if (accepted && context.mounted) {
      try {
        await controller.useConnection(
          tripId,
          journey,
          options.first,
          labels: labels,
        );
      } catch (_) {
        // Writing this one connection failed. The journey keeps its copied
        // plan, and the *next* journey is still asked about: one failure is not
        // evidence about the others, and letting it out of the loop meant the
        // rest were silently never offered.
        failed++;
      }
    }
  }

  if (!context.mounted) return;
  if (missing > 0) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.connectionsNotFound)));
  }
  if (failed > 0) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.connectionsNotTaken)));
  }
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
