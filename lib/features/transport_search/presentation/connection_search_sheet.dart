import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart' show formatSignedMinutes;
import '../../../l10n/app_localizations.dart';
import '../../itinerary/widgets/item_times.dart' show delayColor;
import '../application/transit_filter_provider.dart';
import '../application/transport_search_controller.dart';
import '../application/transport_search_providers.dart';
import '../data/journey_mapper.dart' show localParts;
import '../domain/journey.dart';
import '../domain/journey_options.dart';
import '../domain/transit_mode.dart';
import '../domain/transport_place.dart';
import 'transit_filter_sheet.dart';

/// Opens the connection search for [tripId] on [day]. Resolves to true when a
/// journey was imported (so the caller can close its own sheet), false/null
/// otherwise.
Future<bool> showConnectionSearchSheet(
  BuildContext context, {
  required int tripId,
  required DateTime day,
}) async {
  final imported = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ConnectionSearchSheet(tripId: tripId, day: day),
  );
  return imported ?? false;
}

class ConnectionSearchSheet extends ConsumerStatefulWidget {
  const ConnectionSearchSheet({
    super.key,
    required this.tripId,
    required this.day,
  });

  final int tripId;
  final DateTime day;

  @override
  ConsumerState<ConnectionSearchSheet> createState() =>
      _ConnectionSearchSheetState();
}

class _ConnectionSearchSheetState extends ConsumerState<ConnectionSearchSheet> {
  TransportPlace? _from;
  TransportPlace? _to;
  late DateTime _date = DateUtils.dateOnly(widget.day);
  TimeOfDay _time = TimeOfDay.now();
  bool _arriveBy = false;
  JourneyQuery? _query;
  bool _importing = false;

  /// Which end is currently fetching a window — true for "earlier", false for
  /// "later", null when nothing is on its way.
  bool? _pagingEarlier;

  bool get _canSearch => _from != null && _to != null;

  Future<void> _pick({required bool isFrom}) async {
    final place = await showModalBottomSheet<TransportPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _PlacePickerSheet(),
    );
    if (place != null) {
      setState(() => isFrom ? _from = place : _to = place);
    }
  }

  void _runSearch() {
    final when = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    setState(() {
      _query = (
        fromId: _from!.id,
        toId: _to!.id,
        time: when,
        arriveBy: _arriveBy,
        options: JourneySearchOptions(modes: ref.read(transitFilterProvider)),
      );
    });
  }

  /// Narrowing the means of transport invalidates results already on screen —
  /// they were found under the old rules — so the search is re-run with the new
  /// filter rather than left showing a flight the user just excluded.
  Future<void> _pickModes() async {
    final picked = await showTransitFilterSheet(
      context,
      initial: ref.read(transitFilterProvider),
    );
    if (picked == null || !mounted) return;
    await ref.read(transitFilterProvider.notifier).setFilters(picked);
    if (_query != null && mounted) _runSearch();
  }

  Future<void> _import(JourneyOption option) async {
    setState(() => _importing = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(transportSearchControllerProvider)
          .importJourney(
            widget.tripId,
            option,
            trackLabel: l10n.platformShort,
            directionLabel: l10n.directionTo,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.connectionAdded)));
      navigator.pop(true);
    } catch (_) {
      if (mounted) setState(() => _importing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.connectionSearchError)),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final materialL10n = MaterialLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                l10n.connectionSearch,
                style: theme.textTheme.titleLarge,
              ),
            ),
            _EndpointTile(
              icon: Icons.trip_origin,
              label: l10n.connectionFrom,
              place: _from,
              onTap: () => _pick(isFrom: true),
            ),
            _EndpointTile(
              icon: Icons.place_outlined,
              label: l10n.connectionTo,
              place: _to,
              onTap: () => _pick(isFrom: false),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(materialL10n.formatMediumDate(_date)),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(materialL10n.formatTimeOfDay(_time)),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.connectionDepart),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.connectionArrive),
                  ),
                ],
                selected: {_arriveBy},
                onSelectionChanged: (s) => setState(() => _arriveBy = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.tune),
                label: Text(
                  transitFilterSummary(l10n, ref.watch(transitFilterProvider)),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _pickModes,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: FilledButton.icon(
                icon: const Icon(Icons.search),
                label: Text(l10n.search),
                onPressed: _canSearch ? _runSearch : null,
              ),
            ),
            Flexible(child: _results(l10n)),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8 + media.padding.bottom),
              child: Text(
                l10n.connectionAttribution,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(AppLocalizations l10n) {
    final query = _query;
    if (query == null) return const SizedBox.shrink();
    final async = ref.watch(journeyResultsProvider(query));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _ErrorRow(
        message: l10n.connectionSearchError,
        retryLabel: l10n.connectionRetry,
        onRetry: () => ref.invalidate(journeyResultsProvider(query)),
      ),
      data: (results) => AbsorbPointer(
        absorbing: _importing,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            _pageRow(l10n, earlier: true, cursor: results.earlierCursor),
            // An empty window is not an empty timetable — the rows above and
            // below still lead somewhere, so the message goes between them
            // rather than in their place.
            if (results.options.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(l10n.connectionSearchNoResults)),
              ),
            for (final option in results.options)
              _ResultCard(option: option, onTap: () => _import(option)),
            _pageRow(l10n, earlier: false, cursor: results.laterCursor),
          ],
        ),
      ),
    );
  }

  /// The "earlier"/"later" row, or nothing when the service offers no window
  /// that way.
  ///
  /// While a window is on its way, the row that asked for it carries the
  /// spinner: the wait belongs where the tap was, and a bar elsewhere would
  /// only say that *something* is loading.
  Widget _pageRow(
    AppLocalizations l10n, {
    required bool earlier,
    required String? cursor,
  }) {
    if (cursor == null) return const SizedBox.shrink();
    return Center(
      child: TextButton.icon(
        icon: _pagingEarlier == earlier
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(earlier ? Icons.expand_less : Icons.expand_more),
        label: Text(earlier ? l10n.connectionEarlier : l10n.connectionLater),
        onPressed: _pagingEarlier == null
            ? () => _loadPage(earlier: earlier)
            : null,
      ),
    );
  }

  /// Loads a neighbouring window onto the list. A failure is a snackbar, not an
  /// emptied screen: what was already found is still good, and the button is
  /// still there to tap again.
  Future<void> _loadPage({required bool earlier}) async {
    final query = _query;
    if (query == null || _pagingEarlier != null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(journeyResultsProvider(query).notifier);
    setState(() => _pagingEarlier = earlier);
    final loaded = earlier
        ? await controller.loadEarlier()
        : await controller.loadLater();
    if (!mounted) return;
    setState(() => _pagingEarlier = null);
    if (!loaded) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.connectionSearchError)),
      );
    }
  }
}

/// A From/To row showing the chosen place or a prompt.
class _EndpointTile extends StatelessWidget {
  const _EndpointTile({
    required this.icon,
    required this.label,
    required this.place,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final TransportPlace? place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = this.place;
    return ListTile(
      leading: Icon(icon),
      title: Text(place?.name ?? label),
      subtitle: place?.area == null ? null : Text(place!.area!),
      onTap: onTap,
    );
  }
}

/// One journey option: overall departure–arrival, duration, change count and a
/// per-leg line summary.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.option, required this.onTap});

  final JourneyOption option;
  final VoidCallback onTap;

  /// The local departure/arrival time of a leg end, plus — when the option
  /// carries real-time data — a coloured signed delta ("(+5)", or green "(+0)"
  /// when it is running to plan), matching the itinerary's delay marks.
  List<InlineSpan> _timeSpans(BuildContext context, LegPoint end) {
    final theme = Theme.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final scheduled = localParts(end.scheduled, end.timeZone);
    final spans = <InlineSpan>[
      TextSpan(
        text: materialL10n.formatTimeOfDay(
          TimeOfDay(
            hour: scheduled.minutes ~/ 60,
            minute: scheduled.minutes % 60,
          ),
        ),
      ),
    ];
    final actual = end.actual;
    if (actual != null) {
      final delta =
          localParts(actual, end.timeZone).minutes - scheduled.minutes;
      spans.add(
        TextSpan(
          text: ' (${formatSignedMinutes(delta)})',
          style: TextStyle(
            color: delayColor(theme, delta),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final dep = option.legs.first.from;
    final arr = option.legs.last.to;
    final depParts = localParts(dep.scheduled, dep.timeZone);
    final arrParts = localParts(arr.scheduled, arr.timeZone);
    final nextDay = arrParts.date.isAfter(depParts.date);

    final vehicleLegs = option.legs
        .where((l) => l.mode != TransitMode.walk)
        .toList();
    final summary = vehicleLegs.map((l) => l.line ?? l.mode.name).join(' → ');
    final h = option.duration.inHours;
    final m = option.duration.inMinutes % 60;

    return ListTile(
      leading: Icon(_transitIcon(vehicleLegs.firstOrNull?.mode)),
      title: Text.rich(
        TextSpan(
          children: [
            ..._timeSpans(context, dep),
            const TextSpan(text: ' – '),
            ..._timeSpans(context, arr),
            if (nextDay)
              TextSpan(
                text: ' +1',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
      subtitle: Text(
        '${h}h ${m}m · ${l10n.connectionChanges(option.transfers)}'
        '${summary.isEmpty ? '' : ' · $summary'}',
      ),
      onTap: onTap,
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(retryLabel),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// A place picker: a search field over live geocode suggestions.
class _PlacePickerSheet extends ConsumerStatefulWidget {
  const _PlacePickerSheet();

  @override
  ConsumerState<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<_PlacePickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final async = ref.watch(geocodeProvider(_query));

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l10n.connectionPickPlace,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (async.isLoading) const LinearProgressIndicator(minHeight: 2),
            if (async.hasError)
              _ErrorRow(
                message: l10n.connectionSearchError,
                retryLabel: l10n.connectionRetry,
                onRetry: () => ref.invalidate(geocodeProvider(_query)),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: 12 + media.padding.bottom),
                children: [
                  for (final place in async.value ?? const <TransportPlace>[])
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.name),
                      subtitle: place.area == null ? null : Text(place.area!),
                      onTap: () => Navigator.of(context).pop(place),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _transitIcon(TransitMode? mode) {
  switch (mode) {
    case TransitMode.walk:
      return Icons.directions_walk;
    case TransitMode.bike:
      return Icons.directions_bike;
    case TransitMode.car:
      return Icons.directions_car;
    case TransitMode.bus:
    case TransitMode.coach:
      return Icons.directions_bus;
    case TransitMode.tram:
      return Icons.tram;
    case TransitMode.subway:
    case TransitMode.monorail:
      return Icons.subway;
    case TransitMode.ferry:
      return Icons.directions_boat;
    case null:
      return Icons.more_horiz;
    default:
      return Icons.train;
  }
}
