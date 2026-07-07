import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/application/cost_providers.dart';
import '../../costs/presentation/cost_chip.dart';
import '../../costs/presentation/cost_form_sheet.dart';
import '../../costs/presentation/person_picker_dialog.dart';
import '../application/trip_providers.dart';

/// Create a new trip, or edit an existing one when [tripId] is provided.
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.tripId});

  final int? tripId;

  bool get isEditing => tripId != null;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  late int _colorValue = AppTheme.tripAccents.first.toARGB32();

  Trip? _editing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loading = true;
      _loadTrip();
    }
  }

  Future<void> _loadTrip() async {
    final trip = await ref.read(repositoryProvider).findTrip(widget.tripId!);
    if (!mounted) return;
    setState(() {
      _editing = trip;
      if (trip != null) {
        _titleController.text = trip.title;
        _destinationController.text = trip.destination;
        _notesController.text = trip.notes ?? '';
        _startDate = trip.startDate;
        _endDate = trip.endDate;
        _colorValue = trip.colorValue;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      initialDateRange: initial,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(repositoryProvider);
    final title = _titleController.text.trim();
    final destination = _destinationController.text.trim();
    final notes = _notesController.text.trim();

    if (widget.isEditing && _editing != null) {
      await repo.updateTrip(
        Trip(
          id: _editing!.id,
          title: title,
          destination: destination,
          startDate: _startDate,
          endDate: _endDate,
          notes: notes.isEmpty ? null : notes,
          colorValue: _colorValue,
          createdAt: _editing!.createdAt,
        ),
      );
    } else {
      await repo.createTrip(
        TripsCompanion.insert(
          title: title,
          destination: Value(destination),
          startDate: Value(_startDate),
          endDate: Value(_endDate),
          notes: Value(notes.isEmpty ? null : notes),
          colorValue: Value(_colorValue),
        ),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l10n.editTrip : l10n.newTrip),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.fieldTitle,
                hintText: l10n.titleHint,
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.titleValidator
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _destinationController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.fieldDestination,
                hintText: l10n.destinationHint,
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 16),
            _DateRangeField(
              label: l10n.fieldDates,
              valueText:
                  formatDateRange(l10n, localeName, _startDate, _endDate),
              onTap: _pickDateRange,
              onClear: (_startDate == null && _endDate == null)
                  ? null
                  : () => setState(() {
                        _startDate = null;
                        _endDate = null;
                      }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.fieldNotes,
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.accentColour,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _ColorPicker(
              selected: _colorValue,
              onSelected: (value) => setState(() => _colorValue = value),
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 24),
              _TripParticipantsEditor(tripId: widget.tripId!),
              const SizedBox(height: 24),
              _TripCostsEditor(
                tripId: widget.tripId!,
                localeName: localeName,
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(widget.isEditing ? l10n.saveChanges : l10n.createTrip),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trip-level costs: costs that belong to the whole trip rather than a single
/// place or transport leg. Managing them lives here, on the trip's edit page,
/// mirroring how item costs are managed from the item's detail sheet.
class _TripCostsEditor extends ConsumerWidget {
  const _TripCostsEditor({required this.tripId, required this.localeName});

  final int tripId;
  final String localeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final costs =
        ref.watch(costsForTripProvider(tripId)).value?.tripLevel ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.generalCosts, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final cost in costs)
              CostChip(
                cost: cost,
                onTap: () =>
                    showCostFormSheet(context, tripId: tripId, existing: cost),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.addCost),
              visualDensity: VisualDensity.compact,
              onPressed: () => showCostFormSheet(context, tripId: tripId),
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

/// Trip participants: the people taking part in the trip. Managed here on the
/// trip's edit page, mirroring how general expenses are managed just below.
/// Adding a participant reuses the shared people roster (also used by the
/// expense payer), creating the person on the fly if they are new.
class _TripParticipantsEditor extends ConsumerWidget {
  const _TripParticipantsEditor({required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final participants =
        ref.watch(tripParticipantsProvider(tripId)).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.participants, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final person in participants)
              InputChip(
                avatar: const Icon(Icons.person_outline, size: 16),
                label: Text(person.name),
                visualDensity: VisualDensity.compact,
                onDeleted: () => ref
                    .read(repositoryProvider)
                    .removeParticipant(tripId, person.id),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.addParticipant),
              visualDensity: VisualDensity.compact,
              onPressed: () => _addParticipant(context, ref, participants),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addParticipant(
    BuildContext context,
    WidgetRef ref,
    List<Person> current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = await showPersonPicker(
      context,
      currentNames: current.map((p) => p.name).toSet(),
      title: l10n.addParticipant,
    );
    if (name == null || name.isEmpty) return;
    await ref.read(repositoryProvider).addParticipant(tripId, name);
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.label,
    required this.valueText,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.date_range),
        suffixIcon: onClear != null
            ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        child: Text(
          valueText,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in AppTheme.tripAccents)
          _ColorDot(
            color: color,
            selected: color.toARGB32() == selected,
            onTap: () => onSelected(color.toARGB32()),
          ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
