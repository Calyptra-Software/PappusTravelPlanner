import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../trip_filter.dart';

/// Bottom sheet for filtering (status, dates, tags, routines, participants) and,
/// where the reader has an order, sorting a set of trips. Edits a local copy of
/// the [TripQuery] and returns it on close; the search [TripQuery.text] is
/// preserved untouched.
///
/// Shared by the overview and the all-trips statistics. The statistics pass
/// `showSort: false`, since a sum has no order, and keep the [TripQuery.sort]
/// they were handed.
class TripFilterSheet extends StatefulWidget {
  const TripFilterSheet({
    super.key,
    required this.query,
    required this.people,
    required this.tags,
    required this.routines,
    this.showSort = true,
  });

  final TripQuery query;
  final List<Person> people;
  final List<Tag> tags;
  final List<Trip> routines;

  /// Whether the sort section is offered.
  final bool showSort;

  @override
  State<TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends State<TripFilterSheet> {
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
                      widget.showSort ? l10n.filterAndSort : l10n.filterTitle,
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
              if (widget.showSort) ...[
                const SizedBox(height: 16),
                _SectionLabel(l10n.sortLabel),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final sort in TripSort.values)
                      ChoiceChip(
                        label: Text(_sortLabel(l10n, sort)),
                        selected: _draft.sort == sort,
                        onSelected: (_) => setState(
                          () => _draft = _draft.copyWith(sort: sort),
                        ),
                      ),
                  ],
                ),
              ],
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
