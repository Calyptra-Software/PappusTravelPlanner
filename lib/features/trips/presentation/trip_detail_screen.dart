import 'package:drift/drift.dart' show Value;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/clock.dart';
import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../checklist/presentation/trip_checklists_section.dart';
import '../../costs/application/cost_display_provider.dart';
import '../../costs/application/cost_providers.dart';
import '../../costs/presentation/cost_chip.dart';
import '../../costs/presentation/cost_form_sheet.dart';
import '../../itinerary/application/item_clipboard.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/day_blocks.dart';
import '../../itinerary/presentation/item_form_sheet.dart';
import '../../itinerary/widgets/alternative_card.dart';
import '../../itinerary/widgets/itinerary_timeline.dart';
import '../../sharing/trip_bundle.dart';
import '../../sharing/trip_pdf.dart';
import '../application/trip_providers.dart';

/// The two ways to export a trip from the detail screen's share menu: the app's
/// own portable `.tpt` bundle (re-importable) or a printable PDF.
enum _ShareAction { tripFile, pdf }

/// Trip detail: header summary plus the day-by-day itinerary.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId, this.initialItemId});

  final int tripId;

  /// When set (from a widget row deep-link), opens this item's editor once the
  /// itinerary has loaded.
  final int? initialItemId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  /// Today's section in the timeline, when the trip is under way — scrolled into
  /// view once, so an ongoing trip opens where we actually are rather than at
  /// day 1.
  final _todayKey = GlobalKey();
  bool _scrolledToToday = false;

  int get tripId => widget.tripId;
  int? get initialItemId => widget.initialItemId;

  /// Brings today's section into view, once, as soon as it is in the tree. Stays
  /// armed until it lands: on the first frames the itinerary is still loading and
  /// the key has no context yet.
  void _scrollToTodayOnce() {
    if (_scrolledToToday) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrolledToToday) return;
      final context = _todayKey.currentContext;
      if (context == null) return;
      _scrolledToToday = true;
      Scrollable.ensureVisible(
        context,
        alignment: 0.05,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTripQuestion),
        content: Text(l10n.deleteTripBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(repositoryProvider).deleteTrip(tripId);
      if (context.mounted) context.go('/');
    }
  }

  /// Whether this is a desktop platform, which has no OS share sheet (and where
  /// `share_plus` can't share files on Linux). Desktop saves the bundle to a
  /// file instead, mirroring the database export in settings.
  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// A filesystem-safe base name derived from the trip [title], for the exported
  /// file. Falls back to `trip` when the title is empty or all-punctuation.
  String _fileBase(String title) {
    final base = title.replaceAll(RegExp(r'[^\w\- ]'), '_').trim();
    return base.isEmpty ? 'trip' : base;
  }

  /// Delivers [bytes] as a file: saved to a chosen location on desktop (which
  /// has no OS share sheet), handed to the share sheet everywhere else.
  /// [savedMessage] is shown after a desktop save.
  Future<void> _shareBytes(
    ScaffoldMessengerState messenger, {
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String subject,
    required String savedMessage,
  }) async {
    if (_isDesktop) {
      // Use file_selector (not file_picker) on desktop, matching the database
      // export in settings: its native chooser parents to the app window on
      // Linux instead of opening behind it.
      final location = await getSaveLocation(suggestedName: fileName);
      if (location != null) {
        await XFile.fromData(bytes).saveTo(location.path);
        messenger.showSnackBar(SnackBar(content: Text(savedMessage)));
      }
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
          fileNameOverrides: [fileName],
          subject: subject,
        ),
      );
    }
  }

  /// Exports the trip to a portable `.tpt` bundle: on mobile/web via the OS
  /// share sheet, on desktop by saving it to a file. [title] names the file.
  Future<void> _shareTrip(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(repositoryProvider).exportTrip(tripId);
      if (bytes == null) return;
      await _shareBytes(
        messenger,
        bytes: bytes,
        fileName: '${_fileBase(title)}.tpt',
        mimeType: tripBundleMimeType,
        subject: title,
        savedMessage: l10n.shareTripSaved,
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareTripFailed)));
    }
  }

  /// Exports the trip as a printable PDF: shared via the OS share sheet on
  /// mobile/web, saved to a file on desktop. [title] names the file.
  Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bundle = await ref.read(repositoryProvider).tripBundle(tripId);
      if (bundle == null) return;
      final fonts = await TripPdfFonts.load();
      final bytes = await buildTripPdf(
        bundle: bundle,
        l10n: l10n,
        localeName: localeName,
        fonts: fonts,
      );
      await _shareBytes(
        messenger,
        bytes: bytes,
        fileName: '${_fileBase(title)}.pdf',
        mimeType: 'application/pdf',
        subject: title,
        savedMessage: l10n.shareTripSaved,
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportPdfFailed)));
    }
  }

  /// Reorders a day's blocks. A day's ordering space is shared by its loose items
  /// and its decisions, so the renumbering writes to both tables — the items
  /// inside a decision's options are untouched, they are ordered within their
  /// option (see [_onReorderItems]).
  Future<void> _onReorder(
    WidgetRef ref,
    List<DayBlock> dayBlocks,
    int oldIndex,
    int newIndex,
  ) async {
    // newIndex is already adjusted for the removal (onReorderItem semantics).
    final reordered = List<DayBlock>.of(dayBlocks);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final repo = ref.read(repositoryProvider);
    for (var i = 0; i < reordered.length; i++) {
      final block = reordered[i];
      if (block.sortOrder == i) continue;
      switch (block) {
        case ItemBlock(:final item):
          await repo.updateItem(item.copyWith(sortOrder: i));
        case DecisionBlock(:final set):
          await repo.setAlternativeSetSortOrder(set.id, i);
      }
    }
  }

  /// Puts the held entry down at the end of [day], or of [alternativeId]'s
  /// option — the other half of picking it up in the item sheet.
  ///
  /// Both halves are explicit and named, which is the point: landing in an
  /// option that is not the chosen one takes the entry's money out of the trip's
  /// totals, so that is said out loud, here, at the moment it happens.
  Future<void> _putDown(
    BuildContext context,
    WidgetRef ref,
    Held held,
    DateTime day, {
    int? alternativeId,
  }) async {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final target = _findBranch(ref, alternativeId);
    final normalized = normalizeDay(day);
    final move = held.mode == HoldMode.move;

    // An item and a group land the same way — at the end of the destination —
    // through their own DAO op; a move relocates, a copy leaves the plan behind
    // and takes only a fresh, unpriced version.
    switch (held) {
      case HeldItem(:final itemId):
        move
            ? await repo.moveItem(
                itemId,
                day: normalized,
                alternativeId: alternativeId,
              )
            : await repo.duplicateItem(
                itemId,
                day: normalized,
                alternativeId: alternativeId,
              );
      case HeldGroup(:final groupId):
        move
            ? await repo.moveGroup(
                groupId,
                day: normalized,
                alternativeId: alternativeId,
              )
            : await repo.copyGroup(
                groupId,
                day: normalized,
                alternativeId: alternativeId,
              );
    }
    ref.read(itemClipboardProvider.notifier).clear();

    final notes = [
      if (held.mode == HoldMode.copy) l10n.copiedWithoutCosts,
      if (target case (final branch, final index) when !branch.chosen)
        l10n.putIntoUnchosenOption(optionLabel(l10n, branch, index)),
    ];
    if (notes.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(notes.join('\n'))));
    }
  }

  /// The option [alternativeId] names together with its position among its
  /// siblings (which is what gives an unlabelled one its letter), or null when
  /// the entry is landing on a day rather than in an option.
  (Alternative, int)? _findBranch(WidgetRef ref, int? alternativeId) {
    if (alternativeId == null) return null;
    final branchesBySet =
        ref.read(alternativeBranchesProvider(tripId)).value ?? const {};
    for (final branches in branchesBySet.values) {
      final index = branches.indexWhere((b) => b.id == alternativeId);
      if (index >= 0) return (branches[index], index);
    }
    return null;
  }

  /// Renumbers a plain list of items — one option's contents.
  Future<void> _onReorderItems(
    WidgetRef ref,
    List<ItineraryItem> items,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = List<ItineraryItem>.of(items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final repo = ref.read(repositoryProvider);
    for (var i = 0; i < reordered.length; i++) {
      if (reordered[i].sortOrder != i) {
        await repo.updateItem(reordered[i].copyWith(sortOrder: i));
      }
    }
  }

  /// Adds a place to [day] — or to one option of a decision on it — named
  /// [location] with no form step. Used by the "you just arrived here" quick-add
  /// chip, which reuses the previous leg's destination so the name isn't typed
  /// twice. An entry inside an option is ordered within that option.
  Future<void> _quickAddPlace(
    WidgetRef ref,
    DateTime day,
    String location, {
    int? alternativeId,
  }) async {
    final repo = ref.read(repositoryProvider);
    final normalized = normalizeDay(day);
    final sortOrder = alternativeId != null
        ? await repo.nextSortOrderInAlternative(alternativeId)
        : await repo.nextSortOrder(tripId, normalized);
    await repo.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: normalized,
        kind: ItemKind.place,
        sortOrder: Value(sortOrder),
        location: Value(location),
        alternativeId: Value(alternativeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(tripId));
    final itemsAsync = ref.watch(itineraryProvider(tripId));
    final collapsedDays =
        ref.watch(collapsedDaysProvider(tripId)).value ?? const <DateTime>{};
    final tripCosts = ref.watch(costsForTripProvider(tripId)).value;
    final costsByItem = tripCosts?.byItem ?? const {};
    final costsByGroup = tripCosts?.byGroup ?? const {};
    final tripLevelCosts = tripCosts?.tripLevel ?? const <Cost>[];
    // The header's total is the plan's, so it leaves out the costs of branches
    // that were not chosen — unlike the chips above, which price every branch.
    final countedCosts =
        ref.watch(countedCostsProvider(tripId)).value ?? const <Cost>[];
    final sets =
        ref.watch(alternativeSetsProvider(tripId)).value ??
        const <int, AlternativeSet>{};
    final branches =
        ref.watch(alternativeBranchesProvider(tripId)).value ??
        const <int, List<Alternative>>{};
    final groups =
        ref.watch(groupsProvider(tripId)).value ?? const <int, ItemGroup>{};
    final participants =
        ref.watch(tripParticipantsProvider(tripId)).value ?? const <Person>[];
    final localeName = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    // Ticks on the minute, so the timeline's "you are here" mark keeps up with
    // the clock. The first frame comes before the stream's first value.
    final now = ref.watch(nowProvider).value ?? DateTime.now();
    // Watched (not read) for two reasons: it drives the put-down chips, and the
    // watch is what keeps the hold alive — leaving this screen disposes it.
    // Another trip's entry is not offered here; an entry carries costs and
    // participants that belong to its own trip.
    final rawHeld = ref.watch(itemClipboardProvider);
    final held = rawHeld?.tripId == tripId ? rawHeld : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.itineraryTitle),
        actions: [
          IconButton(
            tooltip: l10n.statsOpen,
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/trip/$tripId/stats'),
          ),
          PopupMenuButton<_ShareAction>(
            tooltip: l10n.shareTrip,
            icon: const Icon(Icons.ios_share),
            onSelected: (action) {
              final title = tripAsync.value?.title ?? '';
              switch (action) {
                case _ShareAction.tripFile:
                  _shareTrip(context, ref, title);
                case _ShareAction.pdf:
                  _exportPdf(context, ref, title);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ShareAction.tripFile,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.ios_share),
                  title: Text(l10n.shareTrip),
                ),
              ),
              PopupMenuItem(
                value: _ShareAction.pdf,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l10n.exportPdf),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: l10n.editTrip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/trip/$tripId/edit'),
          ),
          IconButton(
            tooltip: l10n.deleteTrip,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      bottomNavigationBar: held == null
          ? null
          : _HoldingBar(
              held: held,
              items: itemsAsync.value ?? const [],
              groups: groups,
              onCancel: () => ref.read(itemClipboardProvider.notifier).clear(),
            ),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (trip) {
          final accent = Color(trip.colorValue);
          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (items) {
              _scrollToTodayOnce();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (initialItemId != null)
                    _OpenItemOnce(
                      key: ValueKey('open-item-$initialItemId'),
                      tripId: tripId,
                      itemId: initialItemId!,
                      items: items,
                    ),
                  _TripHeader(
                    trip: trip,
                    accent: accent,
                    allCosts: countedCosts,
                    tripLevelCosts: tripLevelCosts,
                    participants: participants,
                    localeName: localeName,
                    onEdit: () => context.push('/trip/$tripId/edit'),
                    onTapCost: (cost) => showCostFormSheet(
                      context,
                      tripId: tripId,
                      existing: cost,
                    ),
                  ),
                  TripChecklistsSection(tripId: tripId, accent: accent),
                  ItineraryTimeline(
                    items: items,
                    accent: accent,
                    tripStart: trip.startDate,
                    tripEnd: trip.endDate,
                    now: now,
                    todayKey: _todayKey,
                    costsByItem: costsByItem,
                    groups: groups,
                    costsByGroup: costsByGroup,
                    sets: sets,
                    branches: branches,
                    localeName: localeName,
                    collapsedDays: collapsedDays,
                    onToggleDayCollapsed: (day, collapsed) => ref
                        .read(repositoryProvider)
                        .setDayCollapsed(tripId, day, collapsed),
                    onTapItem: (item) => showItemFormSheet(
                      context,
                      tripId: tripId,
                      kind: item.kind,
                      existing: item,
                    ),
                    onAddPlace: (day, {alternativeId}) => showItemFormSheet(
                      context,
                      tripId: tripId,
                      kind: ItemKind.place,
                      day: day,
                      alternativeId: alternativeId,
                    ),
                    onQuickAddPlace: (day, location, {alternativeId}) =>
                        _quickAddPlace(
                          ref,
                          day,
                          location,
                          alternativeId: alternativeId,
                        ),
                    onAddTransport: (day, fromDefault, {alternativeId}) =>
                        showItemFormSheet(
                          context,
                          tripId: tripId,
                          kind: ItemKind.transport,
                          day: day,
                          defaultFromLocation: fromDefault,
                          alternativeId: alternativeId,
                        ),
                    onTapCost: (cost) => showCostFormSheet(
                      context,
                      itemId: cost.itemId,
                      groupId: cost.groupId,
                      existing: cost,
                    ),
                    onReorder: (dayBlocks, oldIndex, newIndex) =>
                        _onReorder(ref, dayBlocks, oldIndex, newIndex),
                    onReorderBranch: (branchItems, oldIndex, newIndex) =>
                        _onReorderItems(ref, branchItems, oldIndex, newIndex),
                    held: held,
                    onPutDown: (day, {alternativeId}) {
                      if (held == null) return;
                      _putDown(
                        context,
                        ref,
                        held,
                        day,
                        alternativeId: alternativeId,
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TripHeader extends ConsumerWidget {
  const _TripHeader({
    required this.trip,
    required this.accent,
    required this.allCosts,
    required this.tripLevelCosts,
    required this.participants,
    required this.localeName,
    required this.onEdit,
    required this.onTapCost,
  });

  final Trip trip;
  final Color accent;
  final List<Cost> allCosts;
  final List<Cost> tripLevelCosts;
  final List<Person> participants;
  final String localeName;
  final VoidCallback onEdit;
  final ValueChanged<Cost> onTapCost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final days = tripDayCount(trip.startDate, trip.endDate);

    // "My expenses" filter: only offered when a person is marked as "me"; the
    // toggle otherwise collapses to the plain all-expenses total.
    final meName = ref.watch(mePersonProvider).value?.name;
    final scope = meName == null
        ? ExpenseScope.all
        : ref.watch(expenseScopeProvider);
    final scopedCosts = scope == ExpenseScope.mine
        ? allCosts.where((c) => c.paidBy == meName)
        : allCosts;
    final totals = sumByCurrency(scopedCosts);

    return Card(
      color: accent.withValues(alpha: 0.10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trip.destination.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 18, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trip.destination,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatDateRange(
                      l10n,
                      localeName,
                      trip.startDate,
                      trip.endDate,
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (days != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· ${l10n.days(days)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(trip.notes!, style: theme.textTheme.bodyMedium),
              ],
              if (participants.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.participants, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final person in participants)
                      Chip(
                        avatar: Icon(
                          person.isMe ? Icons.person : Icons.person_outline,
                          size: 16,
                        ),
                        label: Text(person.name),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              if (tripLevelCosts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.generalCosts, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final cost in tripLevelCosts)
                      CostChip(cost: cost, onTap: () => onTapCost(cost)),
                  ],
                ),
              ],
              if (allCosts.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (meName != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<ExpenseScope>(
                      segments: [
                        ButtonSegment(
                          value: ExpenseScope.all,
                          label: Text(l10n.expenseScopeAll),
                        ),
                        ButtonSegment(
                          value: ExpenseScope.mine,
                          label: Text(l10n.expenseScopeMine),
                        ),
                      ],
                      selected: {scope},
                      onSelectionChanged: (selection) => ref
                          .read(expenseScopeProvider.notifier)
                          .setScope(selection.first),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                InkWell(
                  onTap: () => context.push('/trip/${trip.id}/stats'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${scope == ExpenseScope.mine ? l10n.myCostsTotal : l10n.costsTotal}: ',
                          style: theme.textTheme.titleSmall,
                        ),
                        Expanded(
                          child: Text(
                            totals.isEmpty
                                ? '—'
                                : formatTotals(totals, localeName),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Invisible list child that opens [itemId]'s editor once, after the itinerary
/// has loaded — honoring a widget row deep-link into a specific item. Keyed by
/// the item id in the parent, so a fresh deep-link to a different item builds a
/// new instance and re-triggers.
class _OpenItemOnce extends StatefulWidget {
  const _OpenItemOnce({
    super.key,
    required this.tripId,
    required this.itemId,
    required this.items,
  });

  final int tripId;
  final int itemId;
  final List<ItineraryItem> items;

  @override
  State<_OpenItemOnce> createState() => _OpenItemOnceState();
}

class _OpenItemOnceState extends State<_OpenItemOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ItineraryItem? item;
      for (final i in widget.items) {
        if (i.id == widget.itemId) {
          item = i;
          break;
        }
      }
      if (item != null) {
        showItemFormSheet(
          context,
          tripId: widget.tripId,
          kind: item.kind,
          existing: item,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The bar shown while an itinerary entry is picked up: what is being carried,
/// and the way out.
///
/// It exists because the hold is otherwise invisible state — the entry stays in
/// place (dimmed), and the only other sign is a chip in each add-row. A carried
/// thing you cannot see, and cannot put back down, is the failure mode of every
/// two-step move; this is the answer to both.
class _HoldingBar extends StatelessWidget {
  const _HoldingBar({
    required this.held,
    required this.items,
    required this.groups,
    required this.onCancel,
  });

  final Held held;
  final List<ItineraryItem> items;
  final Map<int, ItemGroup> groups;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = _heldName(l10n);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                held.mode == HoldMode.move
                    ? Icons.drive_file_move_outline
                    : Icons.content_copy,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Scaffold hands its bottom bar *loose* height constraints, so
                  // a Column left at MainAxisSize.max grows to the whole screen
                  // and takes the bar (which paints over the app bar) with it.
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      held.mode == HoldMode.move
                          ? l10n.holdingMove(name)
                          : l10n.holdingCopy(name),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.holdingHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
            ],
          ),
        ),
      ),
    );
  }

  /// Names what is being carried: a group by its label, an entry by its own
  /// name — a nameless thing still has to be referred to while it is in the air.
  String _heldName(AppLocalizations l10n) {
    switch (held) {
      case HeldGroup(:final groupId):
        final label = groups[groupId]?.label?.trim() ?? '';
        return label.isEmpty ? l10n.groupDefaultLabel : label;
      case HeldItem(:final itemId):
        for (final item in items) {
          if (item.id == itemId) return _entryLabel(item, l10n);
        }
        return l10n.untitledEntry;
    }
  }

  /// Names an entry the way its tile does: its title, else where it is (or the
  /// route it runs), else a placeholder.
  String _entryLabel(ItineraryItem item, AppLocalizations l10n) {
    final title = item.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final fallback = switch (item.kind) {
      ItemKind.place => item.location?.trim() ?? '',
      ItemKind.transport => [
        item.fromLocation?.trim() ?? '',
        item.toLocation?.trim() ?? '',
      ].where((s) => s.isNotEmpty).join(' → '),
    };
    return fallback.isEmpty ? l10n.untitledEntry : fallback;
  }
}
