import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/money_format.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/transport_stats.dart';
import '../../itinerary/widgets/transport_mode.dart';
import '../../trips/application/trip_providers.dart';
import '../application/cost_providers.dart';
import '../cost_reason_icons.dart';
import '../trip_stats.dart';

/// Which per-person figure the balances section shows.
enum _PersonView { paid, share, balances }

/// Per-trip expense statistics: a category breakdown plus per-person paid totals
/// and settle-up balances, one section per currency the trip uses.
class TripStatsScreen extends ConsumerStatefulWidget {
  const TripStatsScreen({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<TripStatsScreen> createState() => _TripStatsScreenState();
}

class _TripStatsScreenState extends ConsumerState<TripStatsScreen> {
  Currency? _currency;
  _PersonView _personView = _PersonView.balances;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).languageCode;
    final trip = ref.watch(tripProvider(widget.tripId)).value;
    final stats = ref.watch(tripStatsProvider(widget.tripId));
    final meName = ref.watch(mePersonProvider).value?.name;
    final accent = trip != null
        ? Color(trip.colorValue)
        : Theme.of(context).colorScheme.primary;

    // Keep the selected currency valid as data streams in.
    final currencies = [for (final c in stats.byCurrency) c.currency];
    final selected = currencies.contains(_currency)
        ? _currency!
        : (currencies.isEmpty ? null : currencies.first);
    final current = selected == null
        ? null
        : stats.byCurrency.firstWhere((c) => c.currency == selected);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.statsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.statsTabExpenses),
              Tab(text: l10n.statsTabTransport),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _expensesTab(
              context,
              l10n: l10n,
              localeName: localeName,
              accent: accent,
              meName: meName,
              currencies: currencies,
              selected: selected,
              current: current,
            ),
            _TransportTab(tripId: widget.tripId, accent: accent),
          ],
        ),
      ),
    );
  }

  Widget _expensesTab(
    BuildContext context, {
    required AppLocalizations l10n,
    required String localeName,
    required Color accent,
    required String? meName,
    required List<Currency> currencies,
    required Currency? selected,
    required CurrencyStats? current,
  }) {
    if (current == null) return _EmptyState(message: l10n.statsNoData);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (currencies.length > 1) ...[
          _CurrencySelector(
            currencies: currencies,
            selected: selected!,
            onChanged: (c) => setState(() => _currency = c),
          ),
          const SizedBox(height: 16),
        ],
        _SummaryStrip(stats: current, localeName: localeName),
        const SizedBox(height: 24),
        _SectionHeader(l10n.statsByCategory),
        const SizedBox(height: 12),
        _CategoryList(stats: current, accent: accent, localeName: localeName),
        const SizedBox(height: 24),
        _SectionHeader(l10n.statsByPerson),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<_PersonView>(
            segments: [
              ButtonSegment(
                value: _PersonView.paid,
                label: Text(l10n.statsScopePaid),
              ),
              ButtonSegment(
                value: _PersonView.share,
                label: Text(l10n.statsScopeShare),
              ),
              ButtonSegment(
                value: _PersonView.balances,
                label: Text(l10n.statsScopeBalances),
              ),
            ],
            selected: {_personView},
            onSelectionChanged: (s) => setState(() => _personView = s.first),
          ),
        ),
        const SizedBox(height: 12),
        switch (_personView) {
          _PersonView.paid => _PersonAmountList(
            stats: current,
            accent: accent,
            localeName: localeName,
            meName: meName,
            amountOf: (p) => p.paidMinor,
          ),
          _PersonView.share => _PersonAmountList(
            stats: current,
            accent: accent,
            localeName: localeName,
            meName: meName,
            amountOf: (p) => p.shareMinor,
          ),
          _PersonView.balances => _BalancesSection(
            stats: current,
            localeName: localeName,
            meName: meName,
          ),
        },
      ],
    );
  }
}

class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({
    required this.currencies,
    required this.selected,
    required this.onChanged,
  });

  final List<Currency> currencies;
  final Currency selected;
  final ValueChanged<Currency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<Currency>(
        segments: [
          for (final c in currencies)
            ButtonSegment(value: c, label: Text(c.code)),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.stats, required this.localeName});

  final CurrencyStats stats;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Split the total into paid/open percentages; the open share takes the
    // remainder so the two always add up to 100 (no rounding drift).
    final paidPercent = stats.totalMinor == 0
        ? 0
        : (stats.paidMinor * 100 / stats.totalMinor).round();
    final openPercent = stats.totalMinor == 0 ? 0 : 100 - paidPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatMoney(stats.totalMinor, stats.currency, localeName),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.statsExpenses(stats.count),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.statsPaidAmount(
                formatMoney(stats.paidMinor, stats.currency, localeName),
                paidPercent,
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.pending_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.statsOpenAmount(
                formatMoney(stats.openMinor, stats.currency, localeName),
                openPercent,
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({
    required this.stats,
    required this.accent,
    required this.localeName,
  });

  final CurrencyStats stats;
  final Color accent;
  final String localeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icons = ref.watch(reasonIconsProvider);
    return Column(
      children: [
        for (final cat in stats.byCategory)
          _BarRow(
            leading: Icon(
              iconForReason(icons[cat.reason]),
              size: 20,
              color: accent,
            ),
            label: cat.reason,
            trailing: formatMoney(cat.amountMinor, stats.currency, localeName),
            secondary: '${(cat.fraction * 100).round()}%',
            fraction: cat.fraction,
            color: accent,
          ),
      ],
    );
  }
}

/// Per-person breakdown of a single figure ([amountOf]) — either what each
/// person paid or their share of the expenses — as bars sized against the
/// largest amount. Shared by the "Paid" and "Share" views.
class _PersonAmountList extends StatelessWidget {
  const _PersonAmountList({
    required this.stats,
    required this.accent,
    required this.localeName,
    required this.meName,
    required this.amountOf,
  });

  final CurrencyStats stats;
  final Color accent;
  final String localeName;
  final String? meName;
  final int Function(PersonStat) amountOf;

  @override
  Widget build(BuildContext context) {
    final people = [...stats.byPerson]
      ..sort((a, b) => amountOf(b).compareTo(amountOf(a)));
    final maxAmount = people.fold<int>(
      0,
      (m, p) => amountOf(p) > m ? amountOf(p) : m,
    );
    return Column(
      children: [
        for (final person in people)
          _BarRow(
            leading: Icon(
              person.name == meName ? Icons.person : Icons.person_outline,
              size: 20,
            ),
            label: person.name,
            trailing: formatMoney(amountOf(person), stats.currency, localeName),
            fraction: maxAmount == 0 ? 0 : amountOf(person) / maxAmount,
            color: accent,
          ),
      ],
    );
  }
}

class _BalancesSection extends StatelessWidget {
  const _BalancesSection({
    required this.stats,
    required this.localeName,
    required this.meName,
  });

  final CurrencyStats stats;
  final String localeName;
  final String? meName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final people = [...stats.byPerson]
      ..sort((a, b) => b.netMinor.compareTo(a.netMinor));
    // Green for positive (owed), red for negative (owes) — same hues as chips.
    final owedColor = theme.colorScheme.primary;
    final owesColor = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final person in people)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  person.name == meName ? Icons.person : Icons.person_outline,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(person.name, style: theme.textTheme.bodyLarge),
                ),
                Text(
                  person.netMinor == 0
                      ? l10n.statsEven
                      : '${person.netMinor > 0 ? l10n.statsGetsBack : l10n.statsOwes} '
                            '${formatMoney(person.netMinor.abs(), stats.currency, localeName)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: person.netMinor == 0
                        ? theme.colorScheme.onSurfaceVariant
                        : (person.netMinor > 0 ? owedColor : owesColor),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _SectionHeader(l10n.statsSettleUp),
        const SizedBox(height: 8),
        if (stats.settlements.isEmpty)
          Text(
            l10n.statsSettledUp,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final t in stats.settlements)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l10n.statsTransfer(t.from, t.to))),
                  Text(
                    formatMoney(t.amountMinor, stats.currency, localeName),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Which time axis the transport breakdown reports — the plan, or what actually
/// happened.
enum _TransportView { planned, actual }

/// Per-mode transport breakdown: a summary of total legs and time, then each
/// [TransportMode] with its leg count and total time stacked as two bars. A
/// planned/actual toggle swaps both figures between the plan and what was
/// recorded — the transport mirror of the expense tab. See [computeTransportStats].
class _TransportTab extends ConsumerStatefulWidget {
  const _TransportTab({required this.tripId, required this.accent});

  final int tripId;
  final Color accent;

  @override
  ConsumerState<_TransportTab> createState() => _TransportTabState();
}

class _TransportTabState extends ConsumerState<_TransportTab> {
  _TransportView _view = _TransportView.planned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(transportStatsProvider(widget.tripId));
    if (stats.isEmpty) return _EmptyState(message: l10n.statsNoTransport);

    // The selected axis picks each mode's count and time; the largest of each
    // across modes sizes its column of bars. Order stays by leg usage so the
    // list doesn't reshuffle when the axis changes.
    final actual = _view == _TransportView.actual;
    int countOf(TransportModeStat m) => actual ? m.actualCount : m.legs;
    int timeOf(TransportModeStat m) =>
        actual ? m.actualMinutes : m.plannedMinutes;
    final maxCount = stats.byMode.fold<int>(
      0,
      (m, s) => countOf(s) > m ? countOf(s) : m,
    );
    final maxTime = stats.byMode.fold<int>(
      0,
      (m, s) => timeOf(s) > m ? timeOf(s) : m,
    );
    final totalCount = actual ? stats.totalActualCount : stats.totalLegs;
    final totalTime = actual
        ? stats.totalActualMinutes
        : stats.totalPlannedMinutes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              l10n.statsLegs(totalCount),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.statsTotalTime(formatDurationHm(totalTime)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<_TransportView>(
            segments: [
              ButtonSegment(
                value: _TransportView.planned,
                label: Text(l10n.plannedTimes),
              ),
              ButtonSegment(
                value: _TransportView.actual,
                label: Text(l10n.actualTimes),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(l10n.statsByMode),
        const SizedBox(height: 4),
        for (final mode in stats.byMode)
          _TransportModeRow(
            mode: mode.mode,
            legs: countOf(mode),
            minutes: timeOf(mode),
            legsFraction: maxCount == 0 ? 0 : countOf(mode) / maxCount,
            timeFraction: maxTime == 0 ? 0 : timeOf(mode) / maxTime,
            accent: widget.accent,
          ),
      ],
    );
  }
}

/// One mode's row in the transport breakdown: its icon and name, with the leg
/// count and total time stacked underneath as two labelled bars.
class _TransportModeRow extends StatelessWidget {
  const _TransportModeRow({
    required this.mode,
    required this.legs,
    required this.minutes,
    required this.legsFraction,
    required this.timeFraction,
    required this.accent,
  });

  final TransportMode mode;
  final int legs;
  final int minutes;
  final double legsFraction;
  final double timeFraction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(mode.icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.label(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                _MetricBar(
                  caption: l10n.statsScopeLegs,
                  value: '$legs',
                  fraction: legsFraction,
                  color: accent,
                ),
                const SizedBox(height: 6),
                _MetricBar(
                  caption: l10n.statsScopeTime,
                  value: formatDurationHm(minutes),
                  fraction: timeFraction,
                  color: accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A captioned proportional bar with a trailing value — one line of a
/// [_TransportModeRow] (its legs or its time).
class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.caption,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String caption;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            caption,
            style: muted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A label with a proportional bar underneath and a trailing value; the shared
/// row for the category and paid breakdowns.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.leading,
    required this.label,
    required this.trailing,
    required this.fraction,
    required this.color,
    this.secondary,
  });

  final Widget leading;
  final String label;
  final String trailing;
  final String? secondary;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (secondary != null) ...[
                      Text(
                        secondary!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      trailing,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
