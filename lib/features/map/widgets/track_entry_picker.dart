import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../core/format/date_format.dart';
import '../../../l10n/app_localizations.dart';

/// Which entries a recording covers.
///
/// A **run**, not a set: the line is divided between them in order, and a gap in
/// the middle would be a stretch handed to nobody — or, worse, one entry given
/// ground it never covered. So tapping picks the two ends of the run and
/// everything between them comes along.
///
/// Days are shown as headers rather than as a filter, because a recording is
/// usually one outing but is not required to be: a night walk that crosses
/// midnight is one line over two days, and a picker that could not express it
/// would send the user back to splitting the file by hand.
Future<List<ItineraryItem>?> showTrackEntryPicker(
  BuildContext context, {
  required List<ItineraryItem> items,
  required List<int> preselected,
}) => showModalBottomSheet<List<ItineraryItem>>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _TrackEntryPicker(items: items, preselected: preselected),
);

class _TrackEntryPicker extends StatefulWidget {
  const _TrackEntryPicker({required this.items, required this.preselected});

  final List<ItineraryItem> items;
  final List<int> preselected;

  @override
  State<_TrackEntryPicker> createState() => _TrackEntryPickerState();
}

class _TrackEntryPickerState extends State<_TrackEntryPicker> {
  int? _first;
  int? _last;

  @override
  void initState() {
    super.initState();
    final marked = [
      for (var i = 0; i < widget.items.length; i++)
        if (widget.preselected.contains(widget.items[i].id)) i,
    ];
    if (marked.isNotEmpty) {
      _first = marked.first;
      _last = marked.last;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chosen = _first == null
        ? const <ItineraryItem>[]
        : widget.items.sublist(_first!, _last! + 1);
    final legs = chosen.where((i) => i.kind == ItemKind.transport).length;

    DateTime? lastDay;
    final rows = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (lastDay != item.date) {
        lastDay = item.date;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              formatDay(item.date, Localizations.localeOf(context).toString()),
              style: theme.textTheme.labelLarge,
            ),
          ),
        );
      }
      rows.add(
        CheckboxListTile(
          value: _inRun(i),
          onChanged: (_) => _toggle(i),
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
        ),
      );
    }

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
                  l10n.trackPickEntriesHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: ListView(shrinkWrap: true, children: rows)),
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
}
