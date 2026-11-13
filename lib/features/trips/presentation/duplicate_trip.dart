import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import 'look_up_trip_connections.dart';

/// Copies [trip] onto new dates as a trip of its own, asking first for its
/// title, when it starts, and whether to look its journeys up.
///
/// Returns the new trip's id, or null if the user backed out. As with a trip
/// stamped out of a routine, the copy is written first and is correct as a
/// plan on its own; the lookup that follows can only improve it.
Future<int?> duplicateTrip(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
) async {
  final choice = await showAppSheet<_DuplicateChoice>(
    context,
    builder: (_) => _DuplicateTripSheet(trip: trip),
  );
  if (choice == null || !context.mounted) return null;

  final tripId = await ref
      .read(repositoryProvider)
      .duplicateTrip(trip.id, title: choice.title, startDate: choice.startDate);
  if (!context.mounted) return tripId;

  if (choice.lookUpConnections) {
    await lookUpTripConnections(context, ref, tripId);
  }
  return tripId;
}

/// What the sheet answers: the copy's title, when it starts, and whether its
/// journeys should be looked up for those dates.
typedef _DuplicateChoice = ({
  String title,
  DateTime startDate,
  bool lookUpConnections,
});

class _DuplicateTripSheet extends ConsumerStatefulWidget {
  const _DuplicateTripSheet({required this.trip});

  final Trip trip;

  @override
  ConsumerState<_DuplicateTripSheet> createState() =>
      _DuplicateTripSheetState();
}

class _DuplicateTripSheetState extends ConsumerState<_DuplicateTripSheet> {
  late final _title = TextEditingController(text: widget.trip.title);
  late DateTime _startDate = normalizeDay(DateTime.now());
  bool _lookUp = true;

  /// How many days the plan covers, so the sheet can say which range the copy
  /// will occupy before it is written.
  int _span = 1;

  @override
  void initState() {
    super.initState();
    _loadSpan();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadSpan() async {
    final range = await ref.read(repositoryProvider).planRange(widget.trip.id);
    if (!mounted || range == null) return;
    setState(() => _span = daysBetween(range.start, range.end) + 1);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
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
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.duplicateTripHeading,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.fieldTitle,
                  prefixIcon: const Icon(Icons.title),
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(l10n.routineStartDate),
                subtitle: Text(
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
                onPressed: _title.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, (
                        // Read at the tap, not at the last build: what was
                        // typed is the title, frame or no frame.
                        title: _title.text.trim(),
                        startDate: _startDate,
                        lookUpConnections: _lookUp,
                      )),
                icon: const Icon(Icons.copy_outlined),
                label: Text(l10n.duplicateTripConfirm),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
