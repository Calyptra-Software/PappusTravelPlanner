import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/routine_query_provider.dart';
import '../application/trip_providers.dart';
import '../routine_filter.dart';
import '../widgets/tag_chip.dart';
import '../widgets/tag_filter_bar.dart';
import 'create_trip_from_routine.dart';

/// The routines, on their own screen.
///
/// Apart from the trips deliberately: a routine is a template, not something
/// that happened. It has no dates to sort or classify by, so it would sit
/// awkwardly in every date-ordered view — and putting a handful of templates
/// among a year of trips is the crowding the tags exist to prevent.
///
/// It is read the same way the overview is, though, and for the same reason: a
/// commute morning and evening, a bike route each way and a shopping run are
/// four routines before anyone has tried to be thorough, and a list nobody can
/// narrow is one the "from routine…" picker is faster than. So the search, the
/// tag bar and the filter sheet are the overview's, minus the facets a template
/// cannot answer — see [RoutineQuery].
class RoutineListScreen extends ConsumerStatefulWidget {
  const RoutineListScreen({super.key});

  @override
  ConsumerState<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends ConsumerState<RoutineListScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // The search text outlives this screen (the query is a root provider) but
    // the bar showing it does not, so a text left behind by an earlier visit
    // would filter the list with nothing on screen saying so. Opening the bar
    // on it is the honest reading: the search is still running.
    final text = ref.read(routineQueryProvider).text;
    _searchController.text = text;
    _searching = text.isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() => setState(() => _searching = true);

  void _stopSearch() {
    setState(() => _searching = false);
    ref.read(routineQueryProvider.notifier).setText('');
    _searchController.clear();
  }

  Future<void> _openFilters(List<Person> people, List<Tag> tags) async {
    final updated = await showAppSheet<RoutineQuery>(
      context,
      builder: (_) => _RoutineFilterSheet(
        query: ref.read(routineQueryProvider),
        people: people,
        tags: tags,
      ),
    );
    if (updated != null) {
      ref.read(routineQueryProvider.notifier).setQuery(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(routineQueryProvider);
    final routines = ref.watch(routineListProvider);
    final tagsByTrip = ref.watch(tagsByTripProvider).value ?? const {};
    final participantsByTrip =
        ref.watch(allParticipantsProvider).value ?? const {};
    final tagList = ref.watch(tagListProvider).value ?? const <Tag>[];

    final filterCount = query.activeFilterCount;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.searchRoutinesHint,
                ),
                onChanged: ref.read(routineQueryProvider.notifier).setText,
              )
            : Text(l10n.routinesTitle),
        actions: _searching
            ? [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: _stopSearch,
                ),
              ]
            : [
                IconButton(
                  tooltip: l10n.searchRoutines,
                  icon: const Icon(Icons.search),
                  onPressed: _startSearch,
                ),
                IconButton(
                  tooltip: l10n.filterRoutines,
                  icon: Badge.count(
                    count: filterCount,
                    isLabelVisible: filterCount > 0,
                    child: const Icon(Icons.tune),
                  ),
                  onPressed: () => _openFilters(
                    _peopleOf(participantsByTrip, routines.value),
                    tagList,
                  ),
                ),
              ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new?kind=routine'),
        icon: const Icon(Icons.add),
        label: Text(l10n.newRoutine),
      ),
      body: routines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.genericError('$error'))),
        data: (list) {
          // "You have not made one of these yet" is a different message from
          // "nothing matches", and only the second is a dead end to back out
          // of — so the roster is asked before the query is applied.
          if (list.isEmpty) return const _NoRoutines();
          final visible = applyRoutineQuery(
            list,
            query: query,
            tagsByTrip: {
              for (final entry in tagsByTrip.entries)
                entry.key: {for (final tag in entry.value) tag.id},
            },
            participantsByTrip: {
              for (final entry in participantsByTrip.entries)
                entry.key: {for (final person in entry.value) person.id},
            },
          );
          return Column(
            children: [
              // The same bar the overview carries, for the same reason: filing
              // is only worth doing if reading it back is one tap, and a
              // routine's tags are what its trips are stamped out wearing.
              TagFilterBar(
                selected: query.tagIds,
                onChanged: (ids) => ref
                    .read(routineQueryProvider.notifier)
                    .setQuery(query.copyWith(tagIds: ids)),
                onManage: () => context.push('/tags'),
              ),
              Expanded(
                child: visible.isEmpty
                    ? _NoResults(query: query.text.trim())
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final routine = visible[index];
                          return _RoutineTile(
                            routine: routine,
                            tags: tagsByTrip[routine.id] ?? const [],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The people taking part in at least one routine — the participant filter's
/// candidates, de-duplicated by id and kept alphabetical.
///
/// Drawn from the routines rather than from every trip: offering somebody who
/// has only ever been on a holiday is offering a filter that can only empty the
/// list.
List<Person> _peopleOf(
  Map<int, List<Person>> participantsByTrip,
  List<Trip>? routines,
) {
  final people = <int, Person>{};
  for (final routine in routines ?? const <Trip>[]) {
    for (final person in participantsByTrip[routine.id] ?? const <Person>[]) {
      people[person.id] = person;
    }
  }
  return people.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({required this.routine, this.tags = const []});

  final Trip routine;

  /// The tags this routine is filed under, drawn as a quiet row under the
  /// title exactly as a trip card draws them — a filter you cannot see the
  /// effect of is one nobody trusts.
  final List<Tag> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accent = Color(routine.colorValue);
    final subtitle = <Widget>[
      if (routine.destination.isNotEmpty) Text(routine.destination),
      if (tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [for (final tag in tags) TagChip(tag: tag)],
          ),
        ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent,
          child: const Icon(Icons.repeat, color: Colors.white, size: 20),
        ),
        title: Text(routine.title),
        subtitle: subtitle.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: subtitle,
              ),
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

/// Bottom sheet for filtering (tags, participants) and sorting the routine
/// list. Edits a local copy of the [RoutineQuery] and returns it on close; the
/// search [RoutineQuery.text] is preserved untouched.
class _RoutineFilterSheet extends StatefulWidget {
  const _RoutineFilterSheet({
    required this.query,
    required this.people,
    required this.tags,
  });

  final RoutineQuery query;
  final List<Person> people;
  final List<Tag> tags;

  @override
  State<_RoutineFilterSheet> createState() => _RoutineFilterSheetState();
}

class _RoutineFilterSheetState extends State<_RoutineFilterSheet> {
  late RoutineQuery _draft = widget.query;

  String _sortLabel(AppLocalizations l10n, RoutineSort sort) {
    switch (sort) {
      case RoutineSort.nameAsc:
        return l10n.sortNameAsc;
      case RoutineSort.createdDesc:
        return l10n.sortCreatedDesc;
    }
  }

  void _toggleTag(int id, bool selected) {
    final next = {..._draft.tagIds};
    selected ? next.add(id) : next.remove(id);
    setState(() => _draft = _draft.copyWith(tagIds: next));
  }

  void _toggleParticipant(int id, bool selected) {
    final next = {..._draft.participantIds};
    selected ? next.add(id) : next.remove(id);
    setState(() => _draft = _draft.copyWith(participantIds: next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.filterAndSort,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: _draft.hasActiveFilters
                        ? () => setState(() => _draft = _draft.clearedFilters())
                        : null,
                    child: Text(l10n.clearFilters),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Tags are also in the bar above the list, and on purpose: the
              // bar is for the one or two used daily, this for reaching the
              // rest alongside the other facets.
              if (widget.tags.isNotEmpty) ...[
                _SectionLabel(l10n.tagsFilterLabel),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in widget.tags)
                      FilterChip(
                        label: Text(tag.name),
                        selected: _draft.tagIds.contains(tag.id),
                        onSelected: (v) => _toggleTag(tag.id, v),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (widget.people.isNotEmpty) ...[
                _SectionLabel(l10n.participants),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final person in widget.people)
                      FilterChip(
                        label: Text(person.name),
                        selected: _draft.participantIds.contains(person.id),
                        onSelected: (v) => _toggleParticipant(person.id, v),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _SectionLabel(l10n.sortLabel),
              Wrap(
                spacing: 8,
                children: [
                  for (final sort in RoutineSort.values)
                    ChoiceChip(
                      label: Text(_sortLabel(l10n, sort)),
                      selected: _draft.sort == sort,
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(sort: sort)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: Text(MaterialLocalizations.of(context).okButtonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

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
            Icon(
              Icons.search_off_outlined,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.noRoutinesFoundTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? l10n.noRoutinesBody
                  : l10n.noRoutinesFoundBody(query),
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
