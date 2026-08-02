import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/accent_picker.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/application/cost_providers.dart';
import '../../costs/application/currency_providers.dart';
import '../../costs/presentation/cost_chip.dart';
import '../../costs/presentation/cost_form_sheet.dart';
import '../../costs/presentation/person_picker.dart';
import '../application/trip_providers.dart';
import '../widgets/tag_editor.dart';

/// Create a trip or a routine, or edit an existing one when [tripId] is given.
///
/// One form serves both kinds — they are the same row underneath, so splitting
/// it would mean maintaining two copies of the title, destination, notes,
/// colour, tags and participants. The single difference is the dates: a trip
/// has them (one day or many, which is not a difference in kind and so not a
/// difference in the form), and a routine has none at all.
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.tripId, this.kind = TripKind.trip});

  final int? tripId;

  /// What is being created. Ignored when editing: an existing trip's kind comes
  /// from the row itself.
  final TripKind kind;

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
  late TripKind _kind = widget.kind;
  late int _colorValue = AppTheme.tripAccents.first.toARGB32();

  /// Participants chosen while creating a new trip, before it has an id. Once
  /// the trip exists (edit mode) participants are managed live via the repo.
  final List<String> _participants = [];

  /// The tags this trip is filed under. Held here for both create and edit —
  /// unlike participants, the whole set is written at once on save, so there is
  /// nothing to manage live.
  Set<int> _tagIds = {};

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
        _kind = trip.kind;
        _colorValue = trip.colorValue;
      }
      _loading = false;
    });
    final tags = await ref
        .read(repositoryProvider)
        .watchTagsForTrip(widget.tripId!)
        .first;
    if (mounted) setState(() => _tagIds = {for (final tag in tags) tag.id});
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
          startDate: _routine ? null : _startDate,
          endDate: _routine ? null : _endDate,
          notes: notes.isEmpty ? null : notes,
          kind: _kind,
          colorValue: _colorValue,
          createdAt: _editing!.createdAt,
        ),
      );
      await repo.setTagsForTrip(_editing!.id, _tagIds);
    } else {
      final tripId = await repo.createTrip(
        TripsCompanion.insert(
          title: title,
          destination: Value(destination),
          startDate: Value(_routine ? null : _startDate),
          endDate: Value(_routine ? null : _endDate),
          notes: Value(notes.isEmpty ? null : notes),
          kind: Value(_kind),
          colorValue: Value(_colorValue),
        ),
      );
      for (final name in _participants) {
        await repo.addParticipant(tripId, name);
      }
      await repo.setTagsForTrip(tripId, _tagIds);
    }
    if (mounted) context.pop();
  }

  /// Whether this form is editing a template rather than a trip.
  bool get _routine => _kind == TripKind.routine;

  String _screenTitle(AppLocalizations l10n) => switch (_kind) {
    TripKind.trip => widget.isEditing ? l10n.editTrip : l10n.newTrip,
    TripKind.routine => widget.isEditing ? l10n.editRoutine : l10n.newRoutine,
  };

  /// A trip's dates. A routine has none — that is what makes it reusable — so
  /// it gets no date control at all rather than a disabled one.
  Widget _whenField(AppLocalizations l10n, String localeName) {
    return _DateRangeField(
      label: l10n.fieldDates,
      valueText: formatDateRange(l10n, localeName, _startDate, _endDate),
      onTap: _pickDateRange,
      onClear: (_startDate == null && _endDate == null)
          ? null
          : () => setState(() {
              _startDate = null;
              _endDate = null;
            }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle(l10n))),
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
            if (!_routine) ...[
              const SizedBox(height: 16),
              _whenField(l10n, localeName),
            ],
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
            Text(
              l10n.accentColour,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            AccentPicker(
              selected: _colorValue,
              onSelected: (value) => setState(() => _colorValue = value),
            ),
            const SizedBox(height: 24),
            TagEditor(
              selected: _tagIds,
              onChanged: (ids) => setState(() => _tagIds = ids),
            ),
            const SizedBox(height: 24),
            if (widget.isEditing)
              _TripParticipantsEditor(tripId: widget.tripId!)
            else
              _NewTripParticipantsEditor(
                participants: _participants,
                onAdd: (name) => setState(() => _participants.add(name)),
                onRemove: (name) => setState(() => _participants.remove(name)),
              ),
            if (widget.isEditing) ...[
              const SizedBox(height: 24),
              _TripCostsEditor(tripId: widget.tripId!, localeName: localeName),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(
                widget.isEditing ? l10n.saveChanges : l10n.createTrip,
              ),
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
    final book = ref.watch(currencyBookProvider);

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
            // Settlements live beside the trip's general expenses: both hang off
            // the trip rather than a day, and this is where their chips appear.
            ActionChip(
              avatar: const Icon(Icons.swap_horiz, size: 16),
              label: Text(l10n.addTransfer),
              visualDensity: VisualDensity.compact,
              onPressed: () => showTransferFormSheet(context, tripId: tripId),
            ),
          ],
        ),
        // The total is the expenses' — a settlement moves money between people
        // without spending any, so it neither adds to the sum nor counts here.
        if (costs.where((c) => !c.isTransfer).length > 1)
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
                avatar: Icon(
                  person.isMe ? Icons.person : Icons.person_outline,
                  size: 16,
                ),
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

/// Trip participants while creating a new trip, before it has an id. Holds the
/// chosen names in the parent form's state (via [onAdd] / [onRemove]); they are
/// linked to the trip once it is saved. Mirrors [_TripParticipantsEditor], but
/// backed by a plain in-memory list rather than the live repository.
class _NewTripParticipantsEditor extends ConsumerWidget {
  const _NewTripParticipantsEditor({
    required this.participants,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> participants;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final meName = ref.watch(mePersonProvider).value?.name;

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
            for (final name in participants)
              InputChip(
                avatar: Icon(
                  name == meName ? Icons.person : Icons.person_outline,
                  size: 16,
                ),
                label: Text(name),
                visualDensity: VisualDensity.compact,
                onDeleted: () => onRemove(name),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.addParticipant),
              visualDensity: VisualDensity.compact,
              onPressed: () => _addParticipant(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addParticipant(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = await showPersonPicker(
      context,
      currentNames: participants.toSet(),
      title: l10n.addParticipant,
    );
    if (name == null || name.isEmpty) return;
    onAdd(name);
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
        child: Text(valueText, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
