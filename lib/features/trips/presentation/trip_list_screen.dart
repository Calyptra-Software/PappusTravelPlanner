import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_format.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../sharing/presentation/trip_import.dart';
import '../application/trip_providers.dart';
import '../trip_filter.dart';
import '../widgets/trip_calendar.dart';
import '../widgets/trip_card.dart';

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
  TripQuery _query = const TripQuery();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() => setState(() => _searching = true);

  void _stopSearch() {
    setState(() {
      _searching = false;
      _query = _query.copyWith(text: '');
      _searchController.clear();
    });
  }

  Future<void> _openFilters(List<Person> people) async {
    final updated = await showModalBottomSheet<TripQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TripFilterSheet(query: _query, people: people),
    );
    if (updated != null) setState(() => _query = updated);
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripListProvider);
    final participantsAsync = ref.watch(allParticipantsProvider);
    final totalsByTrip = ref.watch(tripTotalsProvider).value ?? const {};
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

    final filterCount = _query.activeFilterCount;

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
                onChanged: (value) =>
                    setState(() => _query = _query.copyWith(text: value)),
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
                  onPressed: () => _openFilters(peopleList),
                ),
                IconButton(
                  tooltip: l10n.statsAllTripsOpen,
                  icon: const Icon(Icons.bar_chart),
                  onPressed: () => context.push('/stats'),
                ),
                IconButton(
                  tooltip: l10n.importTrip,
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: () => pickAndImportTrip(context, ref),
                ),
                IconButton(
                  tooltip: l10n.settingsTitle,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
              ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new'),
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
            query: _query,
            participantsByTrip: idsByTrip,
            today: DateTime.now(),
            totalsByTrip: totalsByTrip,
          );
          if (visible.isEmpty) return _NoResults(query: _query.text.trim());
          if (_calendarView) {
            return TripCalendar(
              trips: visible,
              totals: totalsByTrip,
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
                totals: totalsByTrip[trip.id] ?? const {},
                onTap: () => context.push('/trip/${trip.id}'),
              );
            },
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
  const _TripFilterSheet({required this.query, required this.people});

  final TripQuery query;
  final List<Person> people;

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
            Text(l10n.noTripsTitle, style: theme.textTheme.titleLarge),
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
