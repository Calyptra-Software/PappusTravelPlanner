import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/trip_providers.dart';
import 'create_trip_from_routine.dart';

/// The routines, on their own screen.
///
/// Apart from the trips deliberately: a routine is a template, not something
/// that happened. It has no dates to sort or classify by, so it would sit
/// awkwardly in every date-ordered view — and putting a handful of templates
/// among a year of trips is the crowding the tags exist to prevent.
class RoutineListScreen extends ConsumerWidget {
  const RoutineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final routines = ref.watch(routineListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routinesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new?kind=routine'),
        icon: const Icon(Icons.add),
        label: Text(l10n.newRoutine),
      ),
      body: routines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.genericError('$error'))),
        data: (list) {
          if (list.isEmpty) return const _NoRoutines();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _RoutineTile(routine: list[index]),
          );
        },
      ),
    );
  }
}

class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({required this.routine});

  final Trip routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accent = Color(routine.colorValue);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent,
          child: const Icon(Icons.repeat, color: Colors.white, size: 20),
        ),
        title: Text(routine.title),
        subtitle: routine.destination.isEmpty
            ? null
            : Text(routine.destination),
        // The list's own purpose is stamping trips out, so that action is on
        // every row rather than one level down inside the routine.
        trailing: IconButton(
          tooltip: l10n.routineCreateTrip,
          icon: const Icon(Icons.playlist_add_check),
          onPressed: () async {
            final tripId = await createTripFromRoutine(context, ref, routine);
            if (tripId != null && context.mounted) {
              context.push('/trip/$tripId');
            }
          },
        ),
        onTap: () => context.push('/trip/${routine.id}'),
      ),
    );
  }
}

class _NoRoutines extends StatelessWidget {
  const _NoRoutines();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.noRoutinesTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noRoutinesBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
