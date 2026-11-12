import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../l10n/app_localizations.dart';

/// By how many calendar days a trip's entries would move when its start date
/// changes from [oldStart] to [newStart], or null when there is nothing to ask.
///
/// Only a change of the **start** is a move: a new end alone lengthens or
/// shortens the trip, and the entries already sit where they belong. A trip
/// that had no dates has no old start to measure from, and one whose dates are
/// cleared has no new one.
int? entryShiftDays({
  required DateTime? oldStart,
  required DateTime? newStart,
}) {
  if (oldStart == null || newStart == null) return null;
  final days = daysBetween(oldStart, newStart);
  return days == 0 ? null : days;
}

/// What the question before moving answers: whether the entries come along,
/// and whether their journeys should then be looked up for the new dates.
typedef MoveEntriesChoice = ({bool move, bool lookUp});

/// Asks, when a trip's start date is saved as a different day, whether every
/// entry should move by the same [days].
///
/// Resolves to null when the user cancels, which keeps the form open. *Dates
/// only* is the answer for a correction: the entries were already on the right
/// days, and only the range was wrong.
///
/// [offerLookUp] shows the switch to look the journeys up afterwards, offered
/// only when the trip has any the timetable can be asked about.
/// [clearsActualTimes] says that moving removes the actual times recorded on
/// the old dates, since that is the one part of the move that loses something.
Future<MoveEntriesChoice?> showMoveEntriesDialog(
  BuildContext context, {
  required int days,
  required ({DateTime start, DateTime end}) from,
  required ({DateTime start, DateTime end}) to,
  required bool offerLookUp,
  required bool clearsActualTimes,
}) {
  return showDialog<MoveEntriesChoice>(
    context: context,
    builder: (_) => _MoveEntriesDialog(
      days: days,
      from: from,
      to: to,
      offerLookUp: offerLookUp,
      clearsActualTimes: clearsActualTimes,
    ),
  );
}

class _MoveEntriesDialog extends StatefulWidget {
  const _MoveEntriesDialog({
    required this.days,
    required this.from,
    required this.to,
    required this.offerLookUp,
    required this.clearsActualTimes,
  });

  final int days;
  final ({DateTime start, DateTime end}) from;
  final ({DateTime start, DateTime end}) to;
  final bool offerLookUp;
  final bool clearsActualTimes;

  @override
  State<_MoveEntriesDialog> createState() => _MoveEntriesDialogState();
}

class _MoveEntriesDialogState extends State<_MoveEntriesDialog> {
  bool _lookUp = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    String range(({DateTime start, DateTime end}) r) =>
        formatDateRange(l10n, localeName, r.start, r.end);

    return AlertDialog(
      title: Text(l10n.moveEntriesTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.days > 0
                  ? l10n.moveEntriesLater(widget.days)
                  : l10n.moveEntriesEarlier(-widget.days),
            ),
            const SizedBox(height: 8),
            Text(
              '${range(widget.from)} → ${range(widget.to)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.clearsActualTimes) ...[
              const SizedBox(height: 8),
              Text(l10n.moveEntriesClearsActualTimes),
            ],
            if (widget.offerLookUp) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _lookUp,
                onChanged: (value) => setState(() => _lookUp = value ?? false),
                title: Text(l10n.routineLookUpConnections),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (move: false, lookUp: false)),
          child: Text(l10n.moveEntriesDatesOnly),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            move: true,
            lookUp: widget.offerLookUp && _lookUp,
          )),
          child: Text(l10n.moveEntriesConfirm),
        ),
      ],
    );
  }
}
