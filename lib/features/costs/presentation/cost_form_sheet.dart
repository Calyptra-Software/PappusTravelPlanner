import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../core/widgets/search_picker.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../application/cost_providers.dart';
import '../cost_reason_icons.dart';
import 'person_picker.dart';

/// Opens the add/edit cost sheet. For a new cost, provide exactly one of
/// [itemId] (a single itinerary item), [groupId] (a group of items sharing one
/// expense), or [tripId] (a trip-level cost). When editing, [existing] carries
/// its own attachment, so none is required.
Future<void> showCostFormSheet(
  BuildContext context, {
  int? itemId,
  int? groupId,
  int? tripId,
  Cost? existing,
}) {
  assert(
    existing != null || itemId != null || groupId != null || tripId != null,
    'A new cost must be attached to an item, a group or a trip',
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => CostFormSheet(
      itemId: itemId,
      groupId: groupId,
      tripId: tripId,
      existing: existing,
    ),
  );
}

class CostFormSheet extends ConsumerStatefulWidget {
  const CostFormSheet({
    super.key,
    this.itemId,
    this.groupId,
    this.tripId,
    this.existing,
  });

  final int? itemId;
  final int? groupId;
  final int? tripId;
  final Cost? existing;

  @override
  ConsumerState<CostFormSheet> createState() => _CostFormSheetState();
}

class _CostFormSheetState extends ConsumerState<CostFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  /// The chosen category and payer. Both fields are read-only — they are filled
  /// from the search picker, which yields either a saved entry or a new name
  /// typed into its search box, so no separate "new one" mode is needed. An
  /// empty payer means the expense is unassigned.
  final _reasonController = TextEditingController();
  final _payerController = TextEditingController();

  late Currency _currency;

  /// Names the expense was paid for (its split), edited locally and persisted
  /// on save. Seeded once from the DB when editing.
  List<String> _paidFor = const [];
  bool _seededPaidFor = false;

  /// Whether the expense has already been paid/settled.
  bool _paid = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _currency = existing?.currency ?? Currency.eur;
    if (existing != null) {
      _amountController.text = (existing.amountMinor / 100).toStringAsFixed(2);
      _reasonController.text = existing.reason;
      _payerController.text = existing.paidBy ?? '';
      _paid = existing.paid;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _payerController.dispose();
    super.dispose();
  }

  /// Seeds the "paid for" list from an existing cost once its beneficiaries load.
  void _seedPaidFor(List<Person> beneficiaries) {
    if (_seededPaidFor) return;
    _seededPaidFor = true;
    _paidFor = beneficiaries.map((p) => p.name).toList();
  }

  /// Opens the category picker: every saved category with its icon, plus
  /// whatever the user types into the search box.
  Future<void> _pickReason(
    List<String> reasons,
    Map<String, int?> icons,
  ) async {
    final l10n = AppLocalizations.of(context);
    final current = _reasonController.text.trim();
    final result = await showSearchPicker(
      context,
      title: l10n.costReason,
      options: [
        for (final reason in reasons)
          SearchPickerOption(reason, icon: iconForReason(icons[reason])),
      ],
      selected: current.isEmpty ? null : current,
    );
    // No "none" row here — a category is required — so a null value can only
    // mean the sheet was dismissed.
    final reason = result?.value;
    if (reason == null) return;
    setState(() => _reasonController.text = reason);
  }

  /// Opens the payer picker: the saved people, whatever the user types, and
  /// "unassigned" (which clears the payer).
  Future<void> _pickPayer(List<String> people, String? meName) async {
    final l10n = AppLocalizations.of(context);
    final current = _payerController.text.trim();
    final result = await showSearchPicker(
      context,
      title: l10n.costPaidBy,
      options: [
        for (final person in people)
          SearchPickerOption(
            person,
            icon: person == meName ? Icons.person : Icons.person_outline,
          ),
      ],
      selected: current.isEmpty ? null : current,
      noneLabel: l10n.costPaidByNone,
      textCapitalization: TextCapitalization.words,
    );
    if (result == null) return;
    setState(() {
      _payerController.text = result.value ?? '';
      _seedPaidForFromPayer(result.value);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amountMinor = parseAmountToMinor(_amountController.text)!;
    final reason = _reasonController.text.trim();

    // Payer is optional: a picked or newly typed person, or null (nobody).
    final payer = _payerController.text.trim();
    final paidBy = payer.isEmpty ? null : payer;

    final controller = ref.read(costControllerProvider);
    if (_isEditing) {
      await controller.updateCost(
        widget.existing!,
        amountMinor: amountMinor,
        currency: _currency,
        reason: reason,
        paidBy: paidBy,
        paidFor: _paidFor,
        paid: _paid,
      );
    } else {
      await controller.addCost(
        itemId: widget.itemId,
        groupId: widget.groupId,
        tripId: widget.tripId,
        amountMinor: amountMinor,
        currency: _currency,
        reason: reason,
        paidBy: paidBy,
        paidFor: _paidFor,
        paid: _paid,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(costControllerProvider).deleteCost(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// When adding a new expense with an empty split, default "paid for" to the
  /// payer — one normally pays at least for oneself. One-shot: it won't re-add a
  /// name the user has since removed, and does nothing when editing.
  void _seedPaidForFromPayer(String? name) {
    if (_isEditing || name == null || name.isEmpty || _paidFor.isNotEmpty) {
      return;
    }
    _paidFor = [name];
  }

  /// Picks a person (dropdown excluding those already listed) and adds them to
  /// the "paid for" split.
  Future<void> _addPaidFor() async {
    final l10n = AppLocalizations.of(context);
    final name = await showPersonPicker(
      context,
      currentNames: _paidFor.toSet(),
      title: l10n.costPaidFor,
    );
    if (name == null || name.isEmpty || _paidFor.contains(name)) return;
    setState(() => _paidFor = [..._paidFor, name]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Watched, not read at tap time: the picker's options must be loaded (and
    // stay live) by the time the user opens it.
    final reasons = ref.watch(reasonsProvider).value ?? const [];
    final reasonIcons = ref.watch(reasonIconsProvider);
    final people = ref.watch(peopleProvider).value ?? const [];
    final meName = ref.watch(mePersonProvider).value?.name;

    if (_isEditing) {
      // Seed the split once its beneficiaries have actually loaded, so an
      // existing list isn't briefly overwritten with an empty one.
      final beneficiaries = ref
          .watch(costBeneficiariesProvider(widget.existing!.id))
          .value;
      if (beneficiaries != null) _seedPaidFor(beneficiaries);
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
                Text(
                  _isEditing ? l10n.editCost : l10n.addCost,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  autofocus: !_isEditing,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.costAmount,
                    prefixText: '${_currency.symbol} ',
                  ),
                  validator: (value) => parseAmountToMinor(value ?? '') == null
                      ? l10n.costAmountInvalid
                      : null,
                ),
                const SizedBox(height: 16),
                Text(l10n.costCurrency, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<Currency>(
                  segments: [
                    for (final c in Currency.values)
                      ButtonSegment(value: c, label: Text(c.symbol)),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (selection) =>
                      setState(() => _currency = selection.first),
                ),
                const SizedBox(height: 16),
                // Category and payer are picked, never typed into directly: the
                // field opens a searchable list of what is saved, and a name it
                // doesn't hold can be added from that list's search box.
                TextFormField(
                  controller: _reasonController,
                  readOnly: true,
                  canRequestFocus: false,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: l10n.costReason,
                    hintText: l10n.costReasonHint,
                    prefixIcon: Icon(
                      iconForReason(reasonIcons[_reasonController.text]),
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  onTap: () => _pickReason(reasons, reasonIcons),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.costReasonRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _payerController,
                  readOnly: true,
                  canRequestFocus: false,
                  decoration: InputDecoration(
                    labelText: l10n.costPaidBy,
                    hintText: l10n.costPaidByNone,
                    prefixIcon: Icon(
                      _payerController.text.isEmpty
                          ? Icons.person_off_outlined
                          : (_payerController.text == meName
                                ? Icons.person
                                : Icons.person_outline),
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  onTap: () => _pickPayer(people, meName),
                ),
                const SizedBox(height: 16),
                // "Paid for": the people this expense was split among. Chips are
                // added via the shared person picker (dropdown excluding those
                // already listed) and persisted on save.
                Text(l10n.costPaidFor, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final name in _paidFor)
                      InputChip(
                        avatar: Icon(
                          name == meName ? Icons.person : Icons.person_outline,
                          size: 16,
                        ),
                        label: Text(name),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => setState(() {
                          _paidFor = _paidFor.where((n) => n != name).toList();
                        }),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(l10n.personAdd),
                      visualDensity: VisualDensity.compact,
                      onPressed: _addPaidFor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _paid,
                  onChanged: (value) => setState(() => _paid = value ?? false),
                  title: Text(l10n.costPaid),
                ),
                const SizedBox(height: 12),
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
