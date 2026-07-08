import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/presentation/item_form_sheet.dart';
import '../../itinerary/widgets/itinerary_timeline.dart';
import '../application/trip_providers.dart';

/// Trip detail: header summary plus the day-by-day itinerary.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

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

  Future<void> _onReorder(
    WidgetRef ref,
    List<ItineraryItem> dayItems,
    int oldIndex,
    int newIndex,
  ) async {
    // newIndex is already adjusted for the removal (onReorderItem semantics).
    final reordered = List<ItineraryItem>.of(dayItems);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final repo = ref.read(repositoryProvider);
    for (var i = 0; i < reordered.length; i++) {
      if (reordered[i].sortOrder != i) {
        await repo.updateItem(reordered[i].copyWith(sortOrder: i));
      }
    }
  }

  /// Adds a place to [day] named [location] with no form step — used by the
  /// "you just arrived here" quick-add chip, which reuses the previous leg's
  /// destination so the name isn't typed twice.
  Future<void> _quickAddPlace(
    WidgetRef ref,
    DateTime day,
    String location,
  ) async {
    final repo = ref.read(repositoryProvider);
    final normalized = normalizeDay(day);
    final sortOrder = await repo.nextSortOrder(tripId, normalized);
    await repo.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: normalized,
        kind: ItemKind.place,
        sortOrder: Value(sortOrder),
        location: Value(location),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));
    final itemsAsync = ref.watch(itineraryProvider(tripId));
    final collapsedDays =
        ref.watch(collapsedDaysProvider(tripId)).value ?? const <DateTime>{};
    final tripCosts = ref.watch(costsForTripProvider(tripId)).value;
    final costsByItem = tripCosts?.byItem ?? const {};
    final costsByGroup = tripCosts?.byGroup ?? const {};
    final tripLevelCosts = tripCosts?.tripLevel ?? const <Cost>[];
    final groups =
        ref.watch(groupsProvider(tripId)).value ?? const <int, ItemGroup>{};
    final participants =
        ref.watch(tripParticipantsProvider(tripId)).value ?? const <Person>[];
    final localeName = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.itineraryTitle),
        actions: [
          IconButton(
            tooltip: l10n.statsOpen,
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/trip/$tripId/stats'),
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
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (trip) {
          final accent = Color(trip.colorValue);
          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (items) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _TripHeader(
                    trip: trip,
                    accent: accent,
                    allCosts: [
                      ...costsByItem.values.expand((c) => c),
                      ...costsByGroup.values.expand((c) => c),
                      ...tripLevelCosts,
                    ],
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
                    costsByItem: costsByItem,
                    groups: groups,
                    costsByGroup: costsByGroup,
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
                    onAddPlace: (day) => showItemFormSheet(
                      context,
                      tripId: tripId,
                      kind: ItemKind.place,
                      day: day,
                    ),
                    onQuickAddPlace: (day, location) =>
                        _quickAddPlace(ref, day, location),
                    onAddTransport: (day, fromDefault) => showItemFormSheet(
                      context,
                      tripId: tripId,
                      kind: ItemKind.transport,
                      day: day,
                      defaultFromLocation: fromDefault,
                    ),
                    onTapCost: (cost) => showCostFormSheet(
                      context,
                      itemId: cost.itemId,
                      groupId: cost.groupId,
                      existing: cost,
                    ),
                    onReorder: (dayItems, oldIndex, newIndex) =>
                        _onReorder(ref, dayItems, oldIndex, newIndex),
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
                        avatar: const Icon(Icons.person_outline, size: 16),
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
