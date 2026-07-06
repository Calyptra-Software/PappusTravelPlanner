import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/application/cost_providers.dart';
import '../../costs/presentation/cost_form_sheet.dart';
import '../widgets/transport_mode.dart';

/// Opens the add/edit sheet for an itinerary item and persists on save.
Future<void> showItemFormSheet(
  BuildContext context, {
  required int tripId,
  required ItemKind kind,
  DateTime? day,
  ItineraryItem? existing,
  String? defaultFromLocation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ItemFormSheet(
      tripId: tripId,
      kind: existing?.kind ?? kind,
      day: day,
      existing: existing,
      defaultFromLocation: defaultFromLocation,
    ),
  );
}

class ItemFormSheet extends ConsumerStatefulWidget {
  const ItemFormSheet({
    super.key,
    required this.tripId,
    required this.kind,
    this.day,
    this.existing,
    this.defaultFromLocation,
  });

  final int tripId;
  final ItemKind kind;
  final DateTime? day;
  final ItineraryItem? existing;

  /// Pre-fills the "from" field when adding a new transport leg, so the day's
  /// current location isn't typed again. Ignored when editing.
  final String? defaultFromLocation;

  @override
  ConsumerState<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends ConsumerState<ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _date;
  int? _startMinutes;
  int? _endMinutes;
  TransportMode _mode = TransportMode.train;

  bool get _isTransport => widget.kind == ItemKind.transport;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = normalizeDay(existing?.date ?? widget.day ?? DateTime.now());
    if (existing != null) {
      _titleController.text = existing.title ?? '';
      _locationController.text = existing.location ?? '';
      _fromController.text = existing.fromLocation ?? '';
      _toController.text = existing.toLocation ?? '';
      _notesController.text = existing.notes ?? '';
      _startMinutes = existing.startMinutes;
      _endMinutes = existing.endMinutes;
      _mode = existing.mode ?? TransportMode.train;
    } else if (_isTransport) {
      _fromController.text = widget.defaultFromLocation ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 10),
    );
    if (picked != null) setState(() => _date = normalizeDay(picked));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startMinutes : _endMinutes;
    final initial = current != null
        ? TimeOfDay(hour: current ~/ 60, minute: current % 60)
        : TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        final minutes = picked.hour * 60 + picked.minute;
        if (isStart) {
          _startMinutes = minutes;
        } else {
          _endMinutes = minutes;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(repositoryProvider);
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    final notes = _notesController.text.trim();

    String? nullIfEmpty(String v) => v.isEmpty ? null : v;

    if (_isEditing) {
      final existing = widget.existing!;
      await repo.updateItem(
        ItineraryItem(
          id: existing.id,
          tripId: existing.tripId,
          date: _date,
          sortOrder: existing.sortOrder,
          kind: widget.kind,
          title: nullIfEmpty(title),
          startMinutes: _startMinutes,
          endMinutes: _endMinutes,
          notes: nullIfEmpty(notes),
          location: _isTransport ? null : nullIfEmpty(location),
          mode: _isTransport ? _mode : null,
          fromLocation: _isTransport ? nullIfEmpty(from) : null,
          toLocation: _isTransport ? nullIfEmpty(to) : null,
        ),
      );
    } else {
      final sortOrder = await repo.nextSortOrder(widget.tripId, _date);
      await repo.addItem(
        ItineraryItemsCompanion.insert(
          tripId: widget.tripId,
          date: _date,
          kind: widget.kind,
          sortOrder: Value(sortOrder),
          title: Value(nullIfEmpty(title)),
          startMinutes: Value(_startMinutes),
          endMinutes: Value(_endMinutes),
          notes: Value(nullIfEmpty(notes)),
          location: Value(_isTransport ? null : nullIfEmpty(location)),
          mode: Value(_isTransport ? _mode : null),
          fromLocation: Value(_isTransport ? nullIfEmpty(from) : null),
          toLocation: Value(_isTransport ? nullIfEmpty(to) : null),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(repositoryProvider).deleteItem(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final String heading;
    if (_isTransport) {
      heading = _isEditing ? l10n.editTransport : l10n.addTransport;
    } else {
      heading = _isEditing ? l10n.editPlace : l10n.addPlace;
    }

    final media = MediaQuery.of(context);
    return Padding(
      // Keyboard inset (viewInsets) plus the Android system navigation-bar
      // inset (padding.bottom), so the save button clears the nav buttons.
      // With the keyboard up, padding.bottom collapses to 0, so no double count.
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom + media.padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_isTransport) ...[
                  DropdownButtonFormField<TransportMode>(
                    initialValue: _mode,
                    decoration: InputDecoration(labelText: l10n.fieldMode),
                    items: [
                      for (final mode in kTransportModeOrder)
                        DropdownMenuItem(
                          value: mode,
                          child: Row(
                            children: [
                              Icon(mode.icon, size: 18),
                              const SizedBox(width: 8),
                              Text(mode.label(l10n)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _mode = value ?? _mode),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fromController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.fieldFrom,
                      prefixIcon: const Icon(Icons.trip_origin, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _toController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.fieldTo,
                      prefixIcon: const Icon(Icons.place, size: 18),
                    ),
                    validator: (_) {
                      if (_fromController.text.trim().isEmpty &&
                          _toController.text.trim().isEmpty) {
                        return l10n.fromToValidator;
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.fieldPlace,
                      hintText: l10n.placeHint,
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? l10n.placeValidator
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _isTransport
                        ? l10n.transportLabelOptional
                        : l10n.noteTitleOptional,
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.fieldDay,
                      prefixIcon: const Icon(Icons.event),
                    ),
                    child: Text(formatDay(_date, localeName)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: _isTransport ? l10n.timeDeparts : l10n.timeStart,
                        emptyLabel: l10n.setTime,
                        minutes: _startMinutes,
                        onTap: () => _pickTime(isStart: true),
                        onClear: _startMinutes == null
                            ? null
                            : () => setState(() => _startMinutes = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeField(
                        label: _isTransport ? l10n.timeArrives : l10n.timeEnd,
                        emptyLabel: l10n.setTime,
                        minutes: _endMinutes,
                        onTap: () => _pickTime(isStart: false),
                        onClear: _endMinutes == null
                            ? null
                            : () => setState(() => _endMinutes = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.notesOptional,
                    prefixIcon: const Icon(Icons.notes),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 20),
                  _CostsEditor(
                    tripId: widget.tripId,
                    itemId: widget.existing!.id,
                    localeName: localeName,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_isEditing) ...[
                      IconButton(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        tooltip: l10n.delete,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check),
                        label: Text(_isEditing ? l10n.save : l10n.add),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cost list for the item being edited: existing costs as tappable chips plus
/// an "add cost" action. Managing costs lives here, in the item's detail sheet,
/// rather than on the trip overview.
class _CostsEditor extends ConsumerWidget {
  const _CostsEditor({
    required this.tripId,
    required this.itemId,
    required this.localeName,
  });

  final int tripId;
  final int itemId;
  final String localeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final costs =
        ref.watch(costsForTripProvider(tripId)).value?.byItem[itemId] ??
            const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.costs, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final cost in costs)
              ActionChip(
                avatar: const Icon(Icons.payments_outlined, size: 16),
                label: Text(
                  '${cost.reason}  '
                  '${formatMoney(cost.amountMinor, cost.currency, localeName)}',
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    showCostFormSheet(context, itemId: itemId, existing: cost),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.addCost),
              visualDensity: VisualDensity.compact,
              onPressed: () => showCostFormSheet(context, itemId: itemId),
            ),
          ],
        ),
        if (costs.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${l10n.costsTotal}: '
              '${formatTotals(sumByCurrency(costs), localeName)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.emptyLabel,
    required this.minutes,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String emptyLabel;
  final int? minutes;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule, size: 18),
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(minutes == null ? emptyLabel : formatMinutes(minutes)),
      ),
    );
  }
}
