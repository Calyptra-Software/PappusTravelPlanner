import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../core/widgets/text_prompt_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/application/cost_providers.dart';
import '../../costs/application/currency_providers.dart';
import '../../costs/presentation/cost_chip.dart';
import '../../costs/presentation/cost_form_sheet.dart';
import '../../transport_search/presentation/connection_search_sheet.dart';
import '../application/item_clipboard.dart';
import '../application/itinerary_providers.dart';
import '../application/transport_mode_providers.dart';
import '../widgets/transport_mode.dart';

/// Opens the add/edit sheet for an itinerary item and persists on save.
Future<void> showItemFormSheet(
  BuildContext context, {
  required int tripId,
  required ItemKind kind,
  DateTime? day,
  ItineraryItem? existing,
  String? defaultFromLocation,
  int? alternativeId,
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
      alternativeId: alternativeId,
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
    this.alternativeId,
  });

  final int tripId;
  final ItemKind kind;
  final DateTime? day;
  final ItineraryItem? existing;

  /// When set, a new entry is planned inside this option of a decision rather
  /// than directly on the day. Ignored when editing (an item's option is changed
  /// from the decision's card, not here).
  final int? alternativeId;

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
  final _times = <_TimeSlot, int?>{};

  /// The selected transport mode's row id, or null before the modes have loaded
  /// (a default is filled in once they do) or when there are somehow none.
  int? _mode;

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
      _times[_TimeSlot.plannedStart] = existing.startMinutes;
      _times[_TimeSlot.plannedEnd] = existing.endMinutes;
      _times[_TimeSlot.actualStart] = existing.actualStartMinutes;
      _times[_TimeSlot.actualEnd] = existing.actualEndMinutes;
      _mode = existing.mode;
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

  Future<void> _pickTime(_TimeSlot slot) async {
    // An actual time starts from its planned counterpart, which is the time it
    // is being corrected against — usually only minutes away from it.
    final current = _times[slot] ?? _times[slot.planned];
    final initial = current != null
        ? TimeOfDay(hour: current ~/ 60, minute: current % 60)
        : TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => _times[slot] = picked.hour * 60 + picked.minute);
    }
  }

  /// The two time fields of one row — planned or actual. Both rows carry the
  /// same pair of labels (a leg departs and arrives, a place starts and ends);
  /// the heading above them says whether they are the plan or what happened.
  Widget _timeRow(AppLocalizations l10n, _TimeSlot start, _TimeSlot end) {
    Widget field(_TimeSlot slot, String label) => Expanded(
      child: _TimeField(
        label: label,
        emptyLabel: l10n.setTime,
        minutes: _times[slot],
        onTap: () => _pickTime(slot),
        onClear: _times[slot] == null
            ? null
            : () => setState(() => _times[slot] = null),
      ),
    );

    return Row(
      children: [
        field(start, _isTransport ? l10n.timeDeparts : l10n.timeStart),
        const SizedBox(width: 12),
        field(end, _isTransport ? l10n.timeArrives : l10n.timeEnd),
      ],
    );
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
      // Preserve the item's current group and option membership. `widget.existing`
      // is a snapshot from when the sheet opened, so if the item was grouped, or
      // turned into a decision, while the sheet was open, that membership lives
      // only in live data — reading it back here keeps this full-row update from
      // clobbering it.
      final live = ref.read(itineraryProvider(widget.tripId)).value;
      var currentGroupId = existing.groupId;
      var currentAlternativeId = existing.alternativeId;
      if (live != null) {
        for (final it in live) {
          if (it.id == existing.id) {
            currentGroupId = it.groupId;
            currentAlternativeId = it.alternativeId;
            break;
          }
        }
      }
      await repo.updateItem(
        ItineraryItem(
          id: existing.id,
          tripId: existing.tripId,
          groupId: currentGroupId,
          alternativeId: currentAlternativeId,
          date: _date,
          sortOrder: existing.sortOrder,
          kind: widget.kind,
          title: nullIfEmpty(title),
          startMinutes: _times[_TimeSlot.plannedStart],
          endMinutes: _times[_TimeSlot.plannedEnd],
          actualStartMinutes: _times[_TimeSlot.actualStart],
          actualEndMinutes: _times[_TimeSlot.actualEnd],
          // The form doesn't expose these yet; carry them through unchanged so
          // editing a leg doesn't wipe an imported connection's overnight flag,
          // endpoint coordinates or its source trip id (which the live-times
          // refresh needs). Direction/platform ride along in notes, which the
          // form does edit.
          spansNextDay: existing.spansNextDay,
          notes: nullIfEmpty(notes),
          location: _isTransport ? null : nullIfEmpty(location),
          mode: _isTransport ? _mode : null,
          fromLocation: _isTransport ? nullIfEmpty(from) : null,
          toLocation: _isTransport ? nullIfEmpty(to) : null,
          fromLat: _isTransport ? existing.fromLat : null,
          fromLon: _isTransport ? existing.fromLon : null,
          toLat: _isTransport ? existing.toLat : null,
          toLon: _isTransport ? existing.toLon : null,
          sourceTripId: _isTransport ? existing.sourceTripId : null,
        ),
      );
    } else {
      // An entry planned inside an option is ordered within that option; one on
      // the day is ordered among the day's blocks.
      final alternativeId = widget.alternativeId;
      final sortOrder = alternativeId != null
          ? await repo.nextSortOrderInAlternative(alternativeId)
          : await repo.nextSortOrder(widget.tripId, _date);
      await repo.addItem(
        ItineraryItemsCompanion.insert(
          tripId: widget.tripId,
          date: _date,
          kind: widget.kind,
          sortOrder: Value(sortOrder),
          alternativeId: Value(alternativeId),
          title: Value(nullIfEmpty(title)),
          startMinutes: Value(_times[_TimeSlot.plannedStart]),
          endMinutes: Value(_times[_TimeSlot.plannedEnd]),
          actualStartMinutes: Value(_times[_TimeSlot.actualStart]),
          actualEndMinutes: Value(_times[_TimeSlot.actualEnd]),
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

  /// The mode dropdown, populated from the user-managed modes.
  ///
  /// A **new** leg opens on the "train" built-in (or the first mode there is),
  /// so it starts on something valid. An **existing** leg keeps whatever it has
  /// stored — including *no* mode, which is what a leg is left with when the
  /// mode it used was deleted (`ItineraryItems.mode` is set null). That state
  /// shows here exactly as the timeline shows it — the three-dots icon and
  /// "Other" — instead of silently pre-selecting a real mode that saving would
  /// then assign.
  Widget _buildModeDropdown(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final modes = ref.watch(transportModesProvider).value ?? const [];
    // A selection whose mode no longer exists (deleted while the sheet was open)
    // falls back to "no mode" rather than to some other row's id.
    if (_mode != null && modes.isNotEmpty && !modes.any((m) => m.id == _mode)) {
      _mode = null;
    }
    if (!_isEditing && _mode == null && modes.isNotEmpty) {
      _mode = modes
          .firstWhere(
            (m) => m.builtinKey == TransportMode.train.name,
            orElse: () => modes.first,
          )
          .id;
    }
    return DropdownButtonFormField<int?>(
      initialValue: _mode,
      decoration: InputDecoration(labelText: l10n.fieldMode),
      // Shown while nothing is selected — a leg whose mode was deleted.
      hint: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            kDefaultTransportModeIcon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(l10n.modeOther),
        ],
      ),
      items: [
        for (final mode in modes)
          DropdownMenuItem<int?>(
            value: mode.id,
            child: Row(
              children: [
                Icon(mode.icon, size: 18),
                const SizedBox(width: 8),
                Text(mode.label(l10n)),
              ],
            ),
          ),
      ],
      onChanged: (value) => setState(() => _mode = value),
    );
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
                if (_isTransport && !_isEditing) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.travel_explore),
                    label: Text(l10n.connectionSearchOnline),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final imported = await showConnectionSearchSheet(
                        context,
                        tripId: widget.tripId,
                        day: _date,
                      );
                      // The search imported and closed itself; close the manual
                      // form too so we don't leave an empty leg behind it.
                      if (imported && mounted) navigator.pop();
                    },
                  ),
                ],
                const SizedBox(height: 16),
                if (_isTransport) ...[
                  _buildModeDropdown(l10n),
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
                const SizedBox(height: 16),
                Text(l10n.plannedTimes, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _timeRow(l10n, _TimeSlot.plannedStart, _TimeSlot.plannedEnd),
                const SizedBox(height: 16),
                Text(l10n.actualTimes, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  l10n.actualTimesHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _timeRow(l10n, _TimeSlot.actualStart, _TimeSlot.actualEnd),
                const SizedBox(height: 16),
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
                  _GroupingAndCosts(
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

/// Grouping controls plus the cost list for the item being edited. Grouping
/// bundles adjacent items so a single expense (e.g. a train ticket) covers them
/// all; when the item belongs to a group, the cost list manages that shared
/// group expense instead of a per-item one.
class _GroupingAndCosts extends ConsumerWidget {
  const _GroupingAndCosts({
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
    final repo = ref.read(repositoryProvider);
    final items = ref.watch(itineraryProvider(tripId)).value ?? const [];
    final groups = ref.watch(groupsProvider(tripId)).value ?? const {};

    // Resolve the item from live data so its group membership stays current
    // after grouping without closing the sheet.
    ItineraryItem? current;
    for (final it in items) {
      if (it.id == itemId) {
        current = it;
        break;
      }
    }
    final groupId = current?.groupId;
    final alternativeId = current?.alternativeId;

    // The next item in the same list — the "group with next" target. That list is
    // the day for a loose item, and the option itself for an item inside one, so
    // a group can never straddle two options.
    ItineraryItem? next;
    if (current != null) {
      final siblings = alternativeId != null
          ? items.where((it) => it.alternativeId == alternativeId).toList()
          : items
                .where(
                  (it) =>
                      it.alternativeId == null &&
                      normalizeDay(it.date) == normalizeDay(current!.date),
                )
                .toList();
      final index = siblings.indexWhere((it) => it.id == itemId);
      if (index >= 0 && index + 1 < siblings.length) next = siblings[index + 1];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.moveOrCopy, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          l10n.moveOrCopyHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // Picking up closes the sheet: the second half of the act happens out
            // in the timeline, and a sheet covering it would hide the very thing
            // being chosen.
            OutlinedButton.icon(
              icon: const Icon(Icons.drive_file_move_outline, size: 18),
              label: Text(l10n.moveToDots),
              onPressed: () => _hold(context, ref, itemId, HoldMode.move),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.content_copy, size: 18),
              label: Text(l10n.copyToDots),
              onPressed: () => _hold(context, ref, itemId, HoldMode.copy),
            ),
            // The common copy needs no journey: right here, just below.
            TextButton.icon(
              icon: const Icon(Icons.control_point_duplicate, size: 18),
              label: Text(l10n.duplicateEntry),
              onPressed: current == null
                  ? null
                  : () => _duplicateInPlace(context, repo, current!),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.alternatives, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (alternativeId != null)
          Text(
            l10n.itemInOptionHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          Text(
            l10n.planAlternativesHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.alt_route, size: 18),
              label: Text(l10n.planAlternatives),
              onPressed: () => repo.createAlternativeSetFromItem(itemId),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(l10n.grouping, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (groupId == null) ...[
          if (next != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link, size: 18),
                label: Text(l10n.groupWithNext),
                onPressed: () => repo.groupItems(itemId, next!.id),
              ),
            ),
        ] else ...[
          Text(
            l10n.groupMemberHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (next != null && next.groupId != groupId)
                OutlinedButton.icon(
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(l10n.groupWithNext),
                  onPressed: () => repo.groupItems(itemId, next!.id),
                ),
              // Carry the whole run, not just this entry: picking up a single
              // grouped item *leaves* the group (see [_hold] / moveItem), which
              // is the opposite of what you want for a shared ticket.
              OutlinedButton.icon(
                icon: const Icon(Icons.drive_file_move_outline, size: 18),
                label: Text(l10n.groupMoveTo),
                onPressed: () =>
                    _holdGroup(context, ref, groupId, HoldMode.move),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.content_copy, size: 18),
                label: Text(l10n.groupCopyTo),
                onPressed: () =>
                    _holdGroup(context, ref, groupId, HoldMode.copy),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.groupNameLabel),
                onPressed: () => _renameGroup(
                  context,
                  repo,
                  groupId,
                  groups[groupId]?.label,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.link_off, size: 18),
                label: Text(l10n.groupRemoveItem),
                onPressed: () => repo.removeFromGroup(itemId),
              ),
              TextButton.icon(
                icon: const Icon(Icons.layers_clear_outlined, size: 18),
                label: Text(l10n.groupUngroup),
                onPressed: () => repo.dissolveGroup(groupId),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        // The item always has its own expenses; a grouped item additionally has
        // the group's shared expenses. Both are managed here, independently.
        _CostsEditor(
          tripId: tripId,
          itemId: itemId,
          groupId: null,
          localeName: localeName,
        ),
        if (groupId != null) ...[
          const SizedBox(height: 20),
          _CostsEditor(
            tripId: tripId,
            itemId: null,
            groupId: groupId,
            localeName: localeName,
          ),
        ],
      ],
    );
  }

  /// Picks the entry up and gets out of the way, so the destination — a day, or
  /// one option of a decision — can be chosen where it is visible.
  void _hold(BuildContext context, WidgetRef ref, int itemId, HoldMode mode) {
    ref
        .read(itemClipboardProvider.notifier)
        .hold(HeldItem(tripId: tripId, itemId: itemId, mode: mode));
    Navigator.of(context).pop();
  }

  /// Picks the whole group up instead of the single entry, so a shared-ticket
  /// run relocates as one — its members travel together and stay grouped.
  void _holdGroup(
    BuildContext context,
    WidgetRef ref,
    int groupId,
    HoldMode mode,
  ) {
    ref
        .read(itemClipboardProvider.notifier)
        .hold(HeldGroup(tripId: tripId, groupId: groupId, mode: mode));
    Navigator.of(context).pop();
  }

  /// Copies the entry to the end of the list it is already in — the same day, or
  /// the same option. No journey, because the destination is where we are.
  Future<void> _duplicateInPlace(
    BuildContext context,
    TripRepository repo,
    ItineraryItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await repo.duplicateItem(
      item.id,
      day: item.date,
      alternativeId: item.alternativeId,
    );
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.copiedWithoutCosts)));
  }

  Future<void> _renameGroup(
    BuildContext context,
    TripRepository repo,
    int groupId,
    String? current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await showTextPromptDialog(
      context,
      title: l10n.groupNameLabel,
      hint: l10n.groupNameHint,
      initial: current ?? '',
      confirmLabel: l10n.save,
    );
    if (result != null) await repo.setGroupLabel(groupId, result);
  }
}

/// Cost list for the item or group being edited: existing costs as tappable
/// chips plus an "add cost" action. Managing costs lives here, in the detail
/// sheet, rather than on the trip overview. Attaches to a single item ([itemId])
/// or, when the item is grouped, to the shared group expense ([groupId]).
class _CostsEditor extends ConsumerWidget {
  const _CostsEditor({
    required this.tripId,
    required this.itemId,
    required this.groupId,
    required this.localeName,
  });

  final int tripId;
  final int? itemId;
  final int? groupId;
  final String localeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tripCosts = ref.watch(costsForTripProvider(tripId)).value;
    final costs =
        (groupId != null
            ? tripCosts?.byGroup[groupId]
            : tripCosts?.byItem[itemId]) ??
        const [];
    final book = ref.watch(currencyBookProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          groupId != null ? l10n.groupSharedExpenses : l10n.costs,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final cost in costs)
              CostChip(
                cost: cost,
                onTap: () => showCostFormSheet(context, existing: cost),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.addCost),
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  showCostFormSheet(context, itemId: itemId, groupId: groupId),
            ),
          ],
        ),
        if (costs.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${l10n.costsTotal}: '
              '${formatTotals(sumByCurrency(costs, book), book, localeName)}',
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

/// The four times an entry can carry: the plan, and what actually happened.
enum _TimeSlot {
  plannedStart,
  plannedEnd,
  actualStart,
  actualEnd;

  /// The planned time this slot is measured against — itself, for a planned one.
  _TimeSlot get planned => switch (this) {
    _TimeSlot.actualStart => _TimeSlot.plannedStart,
    _TimeSlot.actualEnd => _TimeSlot.plannedEnd,
    _ => this,
  };
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
