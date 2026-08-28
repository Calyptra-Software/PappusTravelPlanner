import 'package:flutter/material.dart';

import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../core/format/date_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/widgets/alternative_card.dart' show optionLabel;
import '../track_entry_path.dart';

/// Which entries a recording covers.
///
/// A **run**, not a set: the line is divided between them in order, and a gap in
/// the middle would be a stretch handed to nobody — or, worse, one entry given
/// ground it never covered. So tapping picks the two ends of the run and
/// everything between them comes along.
///
/// The list is **one path through the plan** ([buildTrackEntryPath]), not every
/// entry the trip holds. A decision is a fork, and a recording followed one of
/// its options — so showing all of them at once printed the same place two and
/// three times over with nothing to tell them apart, and let a run be picked
/// that ran through two options at once, which is a line divided between legs
/// that exclude each other.
///
/// Which option the path takes is therefore a switch on the decision's own row,
/// and it is a choice **about this import**: it never settles the decision, the
/// same rule that makes swiping an `AlternativeCard` browse rather than choose.
/// It defaults to the option the trip follows, and says so plainly when it does
/// not — importing into a road not taken is a legitimate thing to want (the
/// walk you scouted, so you can compare it), but not something to do without
/// noticing.
///
/// Days are shown as headers rather than as a filter, because a recording is
/// usually one outing but is not required to be: a night walk that crosses
/// midnight is one line over two days, and a picker that could not express it
/// would send the user back to splitting the file by hand.
Future<List<ItineraryItem>?> showTrackEntryPicker(
  BuildContext context, {
  required List<ItineraryItem> items,
  required Map<int, AlternativeSet> sets,
  required Map<int, List<Alternative>> branchesBySet,
  required List<int> preselected,
}) => showAppSheet<List<ItineraryItem>>(
  context,
  builder: (_) => _TrackEntryPicker(
    items: items,
    sets: sets,
    branchesBySet: branchesBySet,
    preselected: preselected,
  ),
);

class _TrackEntryPicker extends StatefulWidget {
  const _TrackEntryPicker({
    required this.items,
    required this.sets,
    required this.branchesBySet,
    required this.preselected,
  });

  final List<ItineraryItem> items;
  final Map<int, AlternativeSet> sets;
  final Map<int, List<Alternative>> branchesBySet;
  final List<int> preselected;

  @override
  State<_TrackEntryPicker> createState() => _TrackEntryPickerState();
}

class _TrackEntryPickerState extends State<_TrackEntryPicker> {
  /// The option each decision contributes to the path, keyed by set id.
  final Map<int, int> _branchBySet = {};

  int? _first;
  int? _last;

  @override
  void initState() {
    super.initState();
    // The path opens where the import was started from: a leg reached through
    // its own option's form must be on the list, chosen option or not.
    _branchBySet.addAll(
      pathThrough([
        for (final item in widget.items)
          if (widget.preselected.contains(item.id)) item,
      ], widget.branchesBySet),
    );
    final entries = _entries(_rows());
    final marked = [
      for (var i = 0; i < entries.length; i++)
        if (widget.preselected.contains(entries[i].id)) i,
    ];
    if (marked.isNotEmpty) {
      _first = marked.first;
      _last = marked.last;
    }
  }

  List<TrackPathRow> _rows() => buildTrackEntryPath(
    items: widget.items,
    sets: widget.sets,
    branchesBySet: widget.branchesBySet,
    branchBySet: _branchBySet,
  );

  List<ItineraryItem> _entries(List<TrackPathRow> rows) => pathEntries(rows);

  bool _inRun(int index) =>
      _first != null && index >= _first! && index <= _last!;

  /// Tapping outside the run extends it to reach; tapping an end pulls it back.
  /// Nothing here can produce a gap, which is the whole reason the selection is
  /// two indices rather than a set of ticks.
  void _toggle(int index) {
    setState(() {
      if (_first == null) {
        _first = _last = index;
      } else if (index < _first!) {
        _first = index;
      } else if (index > _last!) {
        _last = index;
      } else if (index == _first! && index == _last!) {
        _first = _last = null;
      } else if (index == _first!) {
        _first = index + 1;
      } else if (index == _last!) {
        _last = index - 1;
      } else {
        // Inside the run: the far side moves to here, so a tap always means
        // "this is now an end" rather than "punch a hole".
        if (index - _first! <= _last! - index) {
          _first = index;
        } else {
          _last = index;
        }
      }
    });
  }

  /// Points the path at another option of one decision.
  ///
  /// The run's ends are carried across **by identity**, so switching an option
  /// the run merely passes *through* keeps the run and swaps what lies inside
  /// it. An end that stood in the option being switched away from is gone, and
  /// with it the run: there is no honest place to put an end whose entry is no
  /// longer part of the path.
  void _selectBranch(int setId, int branchId) {
    final before = _entries(_rows());
    final firstId = _first == null ? null : before[_first!].id;
    final lastId = _last == null ? null : before[_last!].id;
    setState(() {
      _branchBySet[setId] = branchId;
      final after = _entries(_rows());
      final first = firstId == null
          ? -1
          : after.indexWhere((i) => i.id == firstId);
      final last = lastId == null
          ? -1
          : after.indexWhere((i) => i.id == lastId);
      if (first < 0 || last < 0) {
        _first = _last = null;
      } else {
        _first = first;
        _last = last;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = _rows();
    final entries = _entries(rows);
    final chosen = _first == null
        ? const <ItineraryItem>[]
        : entries.sublist(_first!, _last! + 1);
    final legs = chosen.where((i) => i.kind == ItemKind.transport).length;
    final forks = rows.whereType<TrackPathDecision>().isNotEmpty;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.trackPickEntries, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  forks
                      ? '${l10n.trackPickEntriesHint} ${l10n.trackPickOptionHint}'
                      : l10n.trackPickEntriesHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _buildRows(context, rows),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    legs == 0 ? l10n.trackNoLegsPicked : '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: legs == 0
                      ? null
                      : () => Navigator.of(context).pop(chosen),
                  child: Text(l10n.trackImportConfirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The path as widgets. A decision and the entries it contributes are drawn as
  /// one banded block, so what is inside an option cannot be mistaken for what
  /// stands loose on the day beside it.
  List<Widget> _buildRows(BuildContext context, List<TrackPathRow> rows) {
    final widgets = <Widget>[];
    var index = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      switch (row) {
        case TrackPathDay(:final day):
          widgets.add(_dayHeader(context, day));
        case TrackPathEntry():
          widgets.add(_entryTile(context, row.item, index++));
        case TrackPathDecision():
          final inOption = <Widget>[];
          while (i + 1 < rows.length &&
              rows[i + 1] is TrackPathEntry &&
              (rows[i + 1] as TrackPathEntry).inOption) {
            inOption.add(
              _entryTile(context, (rows[++i] as TrackPathEntry).item, index++),
            );
          }
          widgets.add(_decisionBlock(context, row, inOption));
      }
    }
    return widgets;
  }

  Widget _dayHeader(BuildContext context, DateTime day) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      formatDay(day, Localizations.localeOf(context).toString()),
      style: Theme.of(context).textTheme.labelLarge,
    ),
  );

  Widget _entryTile(BuildContext context, ItineraryItem item, int index) =>
      CheckboxListTile(
        value: _inRun(index),
        onChanged: (_) => _toggle(index),
        dense: true,
        secondary: Icon(
          item.kind == ItemKind.transport
              ? Icons.trip_origin
              : Icons.place_outlined,
          size: 18,
        ),
        title: Text(
          item.title?.trim().isNotEmpty == true
              ? item.title!
              : [
                  ?item.fromLocation,
                  ?item.toLocation,
                  ?item.location,
                ].join(' → '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _decisionBlock(
    BuildContext context,
    TrackPathDecision decision,
    List<Widget> inOption,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final set = decision.set;
    final label = (set.label != null && set.label!.isNotEmpty)
        ? set.label!
        : l10n.decisionDefaultLabel;
    final elsewhere = decision.selected.id != decision.chosen.id;

    // The tint sits on a Material rather than on the container: a
    // CheckboxListTile paints its ink on the nearest Material ancestor, and a
    // coloured box between the two hides the splash — which flutter asserts on.
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(width: 3, color: theme.colorScheme.primary),
        ),
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.alt_route,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _optionMenu(context, decision),
                ],
              ),
            ),
            if (elsewhere)
              Padding(
                padding: const EdgeInsets.fromLTRB(38, 0, 12, 4),
                child: Text(
                  l10n.trackOptionNotChosen,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (inOption.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(38, 4, 12, 12),
                child: Text(
                  l10n.optionEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...inOption,
          ],
        ),
      ),
    );
  }

  /// The switch itself. A menu rather than a pager: this list is read to find
  /// one entry, and a swipeable card in the middle of it would compete with the
  /// scroll — and browsing is not what is wanted here anyway, naming an option
  /// is.
  Widget _optionMenu(BuildContext context, TrackPathDecision decision) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      tooltip: l10n.trackPickOption,
      onSelected: (branchId) => _selectBranch(decision.set.id, branchId),
      itemBuilder: (_) => [
        for (var i = 0; i < decision.branches.length; i++)
          PopupMenuItem(
            value: decision.branches[i].id,
            child: Row(
              children: [
                Expanded(
                  child: Text(optionLabel(l10n, decision.branches[i], i)),
                ),
                if (decision.branches[i].id == decision.chosen.id)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      l10n.optionChosen,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              optionLabel(l10n, decision.selected, decision.selectedIndex),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
