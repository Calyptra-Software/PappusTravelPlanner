import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/application/currency_providers.dart';
import '../../sharing/presentation/trip_import.dart';
import '../application/trip_providers.dart';
import '../application/trip_query_provider.dart';
import 'create_trip_from_routine.dart';
import '../trip_filter.dart';
import '../widgets/trip_calendar.dart';
import '../widgets/tag_filter_bar.dart';
import '../widgets/trip_card.dart';

/// Actions folded into the overview app bar's overflow menu to keep the title
/// from being crowded out on narrow screens.
enum _OverflowAction { routines, stats, import, settings }

/// What the overview's "+" offers: a trip, a routine, or a trip made from one.
enum _NewAction { trip, routine, fromRoutine }

/// Width from which the overview app bar has room for every action as its own
/// icon. Below it the navigation actions collapse into an overflow menu; the
/// value is Material's compact/medium window breakpoint, i.e. phone vs. tablet.
const double _wideAppBarBreakpoint = 600;

/// Overview screen: the list of all planned trips.
class TripListScreen extends ConsumerStatefulWidget {
  const TripListScreen({super.key});

  @override
  ConsumerState<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends ConsumerState<TripListScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  bool _calendarView = false;

  /// The routines, kept from the last build so the "+" menu can offer to stamp
  /// one out without re-reading a provider that may have been disposed.
  List<Trip> _routines = const [];

  @override
  void initState() {
    super.initState();
    // The search text outlives this screen (it lives in the query, which is a
    // root provider) but the bar showing it does not, so a text left behind by
    // an earlier visit would filter the list with nothing on screen saying so.
    // Opening the bar on it is the honest reading: the search is still running.
    final text = ref.read(tripQueryProvider).text;
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
    ref.read(tripQueryProvider.notifier).setText('');
    _searchController.clear();
  }

  Future<void> _openFilters(List<Person> people, List<Tag> tags) async {
    final updated = await showModalBottomSheet<TripQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TripFilterSheet(
        query: ref.read(tripQueryProvider),
        people: people,
        tags: tags,
        routines: _routines,
      ),
    );
    if (updated != null) ref.read(tripQueryProvider.notifier).setQuery(updated);
  }

  /// Asks what is being made before opening anything.
  ///
  /// Three answers, not two: a trip, a routine, or a trip *out of* a routine —
  /// which is the one used most often, since a routine exists to be stamped
  /// out. It is offered here rather than only on the routine itself so that
  /// recording this morning's commute is one tap from the overview.
  Future<void> _pickNewTripKind() async {
    final l10n = AppLocalizations.of(context);
    final routines = _routines;
    final action = await showModalBottomSheet<_NewAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.luggage_outlined),
              title: Text(l10n.tripKindTrip),
              subtitle: Text(l10n.tripKindTripBody),
              onTap: () => Navigator.of(context).pop(_NewAction.trip),
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(l10n.tripKindRoutine),
              subtitle: Text(l10n.tripKindRoutineBody),
              onTap: () => Navigator.of(context).pop(_NewAction.routine),
            ),
            // Offered only when there is something to stamp out: an entry that
            // leads to an empty picker teaches nothing.
            if (routines.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.playlist_add_check),
                title: Text(l10n.routineFromRoutine),
                onTap: () => Navigator.of(context).pop(_NewAction.fromRoutine),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _NewAction.trip:
        context.push('/new');
      case _NewAction.routine:
        context.push('/new?kind=routine');
      case _NewAction.fromRoutine:
        await _runRoutine(routines);
    }
  }

  /// Picks a routine, then hands off to the run sheet (which asks for the date
  /// and whether to look the journeys up).
  Future<void> _runRoutine(List<Trip> routines) async {
    final routine = routines.length == 1
        ? routines.single
        : await showModalBottomSheet<Trip>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final routine in routines)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(routine.colorValue),
                      ),
                      title: Text(routine.title),
                      subtitle: routine.destination.isEmpty
                          ? null
                          : Text(routine.destination),
                      onTap: () => Navigator.of(context).pop(routine),
                    ),
                ],
              ),
            ),
          );
    if (routine == null || !mounted) return;
    final tripId = await createTripFromRoutine(context, ref, routine);
    if (tripId != null && mounted) context.push('/trip/$tripId');
  }

  /// The overview list proper — everything below the tag bar.
  Widget _buildList({
    required List<Trip> visible,
    required TripQuery query,
    required Map<int, Map<String, int>> totalsByTrip,
    required Map<int, List<Tag>> tagsByTrip,
    required CurrencyBook book,
  }) {
    if (visible.isEmpty) {
      // "Nothing matches your search" and "you have not made one of these yet"
      // are different messages: only the first is a dead end the user should
      // back out of.
      final searching = query.text.trim().isNotEmpty || query.hasActiveFilters;
      if (searching) return _NoResults(query: query.text.trim());
      return const _EmptyState();
    }
    if (_calendarView) {
      return TripCalendar(
        trips: visible,
        totals: totalsByTrip,
        book: book,
        onOpenTrip: (trip) => context.push('/trip/${trip.id}'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trip = visible[index];
        return TripCard(
          trip: trip,
          book: book,
          totals: totalsByTrip[trip.id] ?? const {},
          tags: tagsByTrip[trip.id] ?? const [],
          onTap: () => context.push('/trip/${trip.id}'),
        );
      },
    );
  }

  void _runOverflowAction(_OverflowAction action) {
    switch (action) {
      case _OverflowAction.routines:
        context.push('/routines');
      case _OverflowAction.stats:
        context.push('/stats');
      case _OverflowAction.import:
        pickAndImportTrip(context, ref);
      case _OverflowAction.settings:
        context.push('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(tripQueryProvider);
    final tripsAsync = ref.watch(tripListProvider);
    final participantsAsync = ref.watch(allParticipantsProvider);
    final totalsByTrip = ref.watch(tripTotalsProvider).value ?? const {};
    final tagsByTrip = ref.watch(tagsByTripProvider).value ?? const {};
    final tagList = ref.watch(tagListProvider).value ?? const <Tag>[];
    // Watched, not read inside the button's callback: the provider is
    // autoDispose, so nothing keeps it alive unless the screen holds it, and a
    // read of a provider with no listener has no value yet — which quietly hid
    // "from routine…" from the one menu it matters most in.
    _routines = ref.watch(routineListProvider).value ?? const <Trip>[];
    final book = ref.watch(currencyBookProvider);
    final l10n = AppLocalizations.of(context);

    final participantsByTrip = participantsAsync.value ?? const {};
    // People who take part in at least one trip — the participant filter's
    // candidates, de-duplicated by id and kept alphabetical.
    final people = <int, Person>{};
    for (final list in participantsByTrip.values) {
      for (final person in list) {
        people[person.id] = person;
      }
    }
    final peopleList = people.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final filterCount = query.activeFilterCount;

    // The three navigation actions, defined once so the wide and compact app
    // bars stay in sync: shown as icons when there is room, folded into an
    // overflow menu when there is not.
    final overflowActions = <(_OverflowAction, IconData, String)>[
      (_OverflowAction.routines, Icons.repeat, l10n.routinesTitle),
      (_OverflowAction.stats, Icons.bar_chart, l10n.statsAllTripsOpen),
      (_OverflowAction.import, Icons.file_download_outlined, l10n.importTrip),
      (_OverflowAction.settings, Icons.settings_outlined, l10n.settingsTitle),
    ];
    // Six icons crowd the title off a phone's app bar but fit comfortably on a
    // tablet or desktop window.
    final wide = MediaQuery.sizeOf(context).width >= _wideAppBarBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.searchTripsHint,
                ),
                onChanged: ref.read(tripQueryProvider.notifier).setText,
              )
            : Text(l10n.tripsTitle),
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
                  tooltip: _calendarView ? l10n.listView : l10n.calendarView,
                  icon: Icon(
                    _calendarView
                        ? Icons.view_list_outlined
                        : Icons.calendar_month_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _calendarView = !_calendarView),
                ),
                IconButton(
                  tooltip: l10n.searchTrips,
                  icon: const Icon(Icons.search),
                  onPressed: _startSearch,
                ),
                IconButton(
                  tooltip: l10n.filterTrips,
                  icon: Badge.count(
                    count: filterCount,
                    isLabelVisible: filterCount > 0,
                    child: const Icon(Icons.tune),
                  ),
                  onPressed: () => _openFilters(peopleList, tagList),
                ),
                if (wide)
                  for (final (action, icon, label) in overflowActions)
                    IconButton(
                      tooltip: label,
                      icon: Icon(icon),
                      onPressed: () => _runOverflowAction(action),
                    )
                else
                  PopupMenuButton<_OverflowAction>(
                    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                    onSelected: _runOverflowAction,
                    itemBuilder: (context) => [
                      for (final (action, icon, label) in overflowActions)
                        PopupMenuItem(
                          value: action,
                          child: ListTile(
                            leading: Icon(icon),
                            title: Text(label),
                          ),
                        ),
                    ],
                  ),
              ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickNewTripKind,
        icon: const Icon(Icons.add),
        label: Text(l10n.newTrip),
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.genericError('$error'))),
        data: (trips) {
          if (trips.isEmpty) return const _EmptyState();
          final idsByTrip = {
            for (final entry in participantsByTrip.entries)
              entry.key: {for (final p in entry.value) p.id},
          };
          final visible = applyTripQuery(
            trips,
            query: query,
            participantsByTrip: idsByTrip,
            tagsByTrip: {
              for (final entry in tagsByTrip.entries)
                entry.key: {for (final tag in entry.value) tag.id},
            },
            today: DateTime.now(),
            totalsByTrip: totalsByTrip,
          );
          return Column(
            children: [
              // The tags in the open, not buried in the filter sheet: filing is
              // only worth doing if reading it back is one tap, and this is the
              // control that keeps a hundred commutes off the holidays.
              TagFilterBar(
                selected: query.tagIds,
                onChanged: (ids) => ref
                    .read(tripQueryProvider.notifier)
                    .setQuery(query.copyWith(tagIds: ids)),
                onManage: () => context.push('/tags'),
              ),
              Expanded(
                child: _buildList(
                  visible: visible,
                  query: query,
                  totalsByTrip: totalsByTrip,
                  tagsByTrip: tagsByTrip,
                  book: book,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bottom sheet for filtering (status, dates, participants) and sorting the
/// overview list. Edits a local copy of the [TripQuery] and returns it on close;
/// the search [TripQuery.text] is preserved untouched.
class _TripFilterSheet extends StatefulWidget {
  const _TripFilterSheet({
    required this.query,
    required this.people,
    required this.tags,
    required this.routines,
  });

  final TripQuery query;
  final List<Person> people;
  final List<Tag> tags;
  final List<Trip> routines;

  @override
  State<_TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends State<_TripFilterSheet> {
  late TripQuery _draft = widget.query;

  String _statusLabel(AppLocalizations l10n, TripStatus status) {
    switch (status) {
      case TripStatus.upcoming:
        return l10n.tripStatusUpcoming;
      case TripStatus.ongoing:
        return l10n.tripStatusOngoing;
      case TripStatus.past:
        return l10n.tripStatusPast;
      case TripStatus.undated:
        return l10n.tripStatusUndated;
    }
  }

  String _sortLabel(AppLocalizations l10n, TripSort sort) {
    switch (sort) {
      case TripSort.dateAsc:
        return l10n.sortDateAsc;
      case TripSort.dateDesc:
        return l10n.sortDateDesc;
      case TripSort.nameAsc:
        return l10n.sortNameAsc;
      case TripSort.createdDesc:
        return l10n.sortCreatedDesc;
      case TripSort.expenseDesc:
        return l10n.sortExpenseDesc;
      case TripSort.expenseAsc:
        return l10n.sortExpenseAsc;
    }
  }

  void _toggleStatus(TripStatus status, bool selected) {
    final next = {..._draft.statuses};
    selected ? next.add(status) : next.remove(status);
    setState(() => _draft = _draft.copyWith(statuses: next));
  }

  void _toggleRoutine(int id, bool selected) {
    final next = {..._draft.routineIds};
    selected ? next.add(id) : next.remove(id);
    setState(() => _draft = _draft.copyWith(routineIds: next));
  }

  /// Selects every routine at once, or clears the facet.
  ///
  /// Selecting them all *is* the question "only trips I made from a routine":
  /// a trip points at its routine only while that routine exists, so there is
  /// no trip from a routine that is not from one of these.
  void _toggleAllRoutines(bool selected) {
    setState(() {
      _draft = _draft.copyWith(
        routineIds: selected
            ? {for (final routine in widget.routines) routine.id}
            : const {},
      );
    });
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _draft.from != null && _draft.to != null
        ? DateTimeRange(start: _draft.from!, end: _draft.to!)
        : null;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDateRange: initial,
    );
    if (range != null) {
      setState(
        () => _draft = _draft.copyWith(from: range.start, to: range.end),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final hasRange = _draft.from != null && _draft.to != null;

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
              _SectionLabel(l10n.statusLabel),
              Wrap(
                spacing: 8,
                children: [
                  for (final status in TripStatus.values)
                    FilterChip(
                      label: Text(_statusLabel(l10n, status)),
                      selected: _draft.statuses.contains(status),
                      onSelected: (v) => _toggleStatus(status, v),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(l10n.fieldDates),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range_outlined),
                      onPressed: _pickDateRange,
                      label: Text(
                        hasRange
                            ? formatDateRange(
                                l10n,
                                localeName,
                                _draft.from,
                                _draft.to,
                              )
                            : l10n.anyDate,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (hasRange)
                    IconButton(
                      tooltip: l10n.clearFilters,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(
                        () => _draft = _draft.copyWith(
                          clearFrom: true,
                          clearTo: true,
                        ),
                      ),
                    ),
                ],
              ),
              // Tags are also in the bar above the list, and on purpose: the
              // bar is for the one or two used daily, this for reaching the
              // rest alongside the other facets.
              if (widget.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
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
              ],
              if (widget.routines.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(l10n.filterRoutineLabel),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text(l10n.filterRoutineAny),
                      selected:
                          widget.routines.isNotEmpty &&
                          _draft.routineIds.length == widget.routines.length,
                      onSelected: _toggleAllRoutines,
                    ),
                    for (final routine in widget.routines)
                      FilterChip(
                        label: Text(routine.title),
                        selected: _draft.routineIds.contains(routine.id),
                        onSelected: (v) => _toggleRoutine(routine.id, v),
                      ),
                  ],
                ),
              ],
              if (widget.people.isNotEmpty) ...[
                const SizedBox(height: 16),
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
              ],
              const SizedBox(height: 16),
              _SectionLabel(l10n.sortLabel),
              Wrap(
                spacing: 8,
                children: [
                  for (final sort in TripSort.values)
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              Icons.luggage_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noTripsTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noTripsBody,
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
            Text(l10n.noTripsFoundTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              query.isEmpty ? l10n.noTripsBody : l10n.noTripsFoundBody(query),
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
