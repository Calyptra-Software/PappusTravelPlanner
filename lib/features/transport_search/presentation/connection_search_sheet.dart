import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/attribution.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/planned_journey.dart';
import '../application/journey_search_options_provider.dart';
import '../application/transport_search_controller.dart';
import '../application/transport_search_providers.dart';
import '../data/journey_mapper.dart' show localParts;
import '../domain/journey.dart';
import '../domain/transit_mode.dart';
import '../domain/transport_place.dart';
import '../domain/via_stop.dart';
import 'journey_formats.dart';
import 'journey_preview_sheet.dart';
import 'search_options_sheet.dart';

/// Opens the connection search for [tripId] on [day]. Resolves to true when a
/// journey was imported (so the caller can close its own sheet), false/null
/// otherwise.
///
/// [replacing] turns it into the search *for a run the trip already holds*: the
/// form opens on that run's endpoints, day and departure, and what is taken
/// replaces those legs instead of being added beside them.
///
/// [alternativeId] plans what is found inside one option of a decision rather
/// than on the day itself.
Future<bool> showConnectionSearchSheet(
  BuildContext context, {
  required int tripId,
  required DateTime day,
  bool intoRoutine = false,
  PlannedJourney? replacing,
  int? departFromMinutes,
  int? alternativeId,
}) async {
  final imported = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ConnectionSearchSheet(
      tripId: tripId,
      day: day,
      intoRoutine: intoRoutine,
      replacing: replacing,
      departFromMinutes: departFromMinutes,
      alternativeId: alternativeId,
    ),
  );
  return imported ?? false;
}

/// One via stop on the form: the station itself, and how long to stay there.
typedef _Via = ({TransportPlace place, int stayMinutes});

class ConnectionSearchSheet extends ConsumerStatefulWidget {
  const ConnectionSearchSheet({
    super.key,
    required this.tripId,
    required this.day,
    this.intoRoutine = false,
    this.replacing,
    this.departFromMinutes,
    this.alternativeId,
    // Replacing swaps the legs of a run that already sits somewhere — in an
    // option or on the day — and keeps that place; only an *added* run needs to
    // be told where it goes. (Replacing *into a routine* is a different matter
    // and allowed: see [replacing].)
  }) : assert(replacing == null || alternativeId == null);

  final int tripId;

  /// The day the imported legs belong to. For a routine this is a day of the
  /// *plan* (day one is `kRoutineAnchorDay`), which no timetable can answer for
  /// — see [intoRoutine].
  final DateTime day;

  /// Whether the legs are being added to a routine.
  ///
  /// A routine has no dates, but a timetable only exists on real ones: you
  /// cannot ask what runs on day one of a plan. So the search is made on a real
  /// date — today by default, changeable, since a Sunday timetable is not a
  /// Tuesday one — and the connection it finds is then laid back onto [day],
  /// keeping the shape of the journey (an overnight leg still lands on the next
  /// day of the plan) while carrying none of that date's own identity.
  final bool intoRoutine;

  /// The run this search is being made *for*, when it is being looked up again:
  /// the form starts on its ends, its day and its departure, and taking a result
  /// swaps its legs (`replaceJourney`) rather than adding a second run beside
  /// the first.
  ///
  /// The query is still the user's to change — another day, an hour later, a via
  /// stop, different modes — which is the whole reason this is the search sheet
  /// and not a single silent request: "the 07:32 was cancelled" and "I'll go in
  /// after lunch instead" are the same act.
  ///
  /// Composes with [intoRoutine]: re-routing a *routine's* run searches a real
  /// date and lays the answer back onto the plan day, which is the same trade the
  /// import makes there. The form then opens on today, as it does for an import,
  /// while the time still comes from the run — a commute leaves at the minute the
  /// plan says whichever day it is asked about.
  final PlannedJourney? replacing;

  /// The minute to open the time field on, when the run being replaced is not the
  /// best answer to "from when?" — one leg of a journey whose previous leg came in
  /// late, where the traveller is standing on the platform at the time they really
  /// arrived rather than the one the plan hoped for
  /// (`departureSeedMinutes`).
  final int? departFromMinutes;

  /// The option of a decision the found run is planned in, or null for the day
  /// itself. A search reached from an option's *Add transport* has to land where
  /// that button plans everything else it offers — an imported connection is not
  /// a different kind of entry from a hand-written leg.
  final int? alternativeId;

  @override
  ConsumerState<ConnectionSearchSheet> createState() =>
      _ConnectionSearchSheetState();
}

class _ConnectionSearchSheetState extends ConsumerState<ConnectionSearchSheet> {
  TransportPlace? _from;
  TransportPlace? _to;

  /// The stops to be routed through, in the order the journey visits them, each
  /// with the least time to spend there.
  ///
  /// Empty until someone adds one, and a row exists only once it *has* a stop:
  /// travelling straight from A to B is the ordinary case, so an empty via field
  /// standing there would ask everyone a question almost nobody is answering —
  /// and a row with nothing in it would have to be silently dropped from the
  /// query anyway. Held as the picked places (the tiles show their names) while
  /// the query carries only their ids.
  final List<_Via> _vias = [];

  // A routine's own day is an offset origin, not a date anything runs on, so
  // the search starts from today and the result is rebased on import.
  late DateTime _date = widget.intoRoutine
      ? DateUtils.dateOnly(DateTime.now())
      : DateUtils.dateOnly(widget.day);
  TimeOfDay _time = TimeOfDay.now();
  bool _arriveBy = false;
  JourneyQuery? _query;
  bool _importing = false;

  /// Which end is currently fetching a window — true for "earlier", false for
  /// "later", null when nothing is on its way.
  bool? _pagingEarlier;

  bool get _canSearch => _from != null && _to != null;

  /// What the run being replaced called its ends, for an end that has no
  /// [TransportPlace] to fill the field with — a hand-entered leg knows
  /// "Rahlstedt" and nothing more.
  ///
  /// A name is not an address: the router takes stop ids and coordinates, and
  /// turning one into the other is the geocoder's job, with the user choosing
  /// between the answers. So the name is shown on the field and handed to the
  /// picker as its opening query — the station is a tap away, and which
  /// Rahlstedt it is stays the user's call.
  String? _fromHint;
  String? _toHint;

  @override
  void initState() {
    super.initState();
    // Looking a run up again starts from the run: its ends, and the minute it
    // was planned to leave. Everything stays editable — the point of arriving
    // here rather than firing one query is that the question can be changed.
    final replacing = widget.replacing;
    if (replacing == null) return;
    _from = replacing.fromPlace;
    _to = replacing.toPlace;
    if (_from == null) _fromHint = replacing.fromLocation;
    if (_to == null) _toHint = replacing.toLocation;
    final minutes = widget.departFromMinutes ?? replacing.departMinutes;
    if (minutes != null) {
      _time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    }
  }

  /// Opens the place picker and hands what was chosen to [onPicked].
  ///
  /// [stopsOnly] narrows it to stations, which is what a via stop must be: the
  /// routing service takes a stop id there and no coordinates, so an address
  /// offered in that list would be a choice that could only fail.
  Future<void> _pick({
    required ValueSetter<TransportPlace> onPicked,
    bool stopsOnly = false,
    String? initialQuery,
  }) async {
    final place = await showModalBottomSheet<TransportPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _PlacePickerSheet(stopsOnly: stopsOnly, initialQuery: initialQuery),
    );
    if (place != null && mounted) setState(() => onPicked(place));
  }

  /// Adds a via stop — by picking it, so the row appears already holding one.
  /// Backing out of the picker leaves the form exactly as it was.
  Future<void> _addVia() => _pick(
    stopsOnly: true,
    onPicked: (place) => _vias.add((place: place, stayMinutes: 0)),
  );

  /// Swaps the station at [index], keeping the stay: this is an edit of that
  /// row — "not *that* Hannover" — where removing the row is how one says the
  /// journey should not go this way at all.
  Future<void> _changeVia(int index) => _pick(
    stopsOnly: true,
    onPicked: (place) =>
        _vias[index] = (place: place, stayMinutes: _vias[index].stayMinutes),
  );

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
        // Not `id`: only a stop is addressable by one, and a picked address
        // has to travel as a coordinate (see `TransportPlace.queryId`).
        fromId: _from!.queryId,
        toId: _to!.queryId,
        // A via *is* always a stop (the picker allows nothing else), so each
        // queryId here is a stop id — the only thing the service takes.
        via: ViaStops([
          for (final via in _vias)
            ViaStop(id: via.place.queryId, minimumStayMinutes: via.stayMinutes),
        ]),
        time: when,
        arriveBy: _arriveBy,
        options: ref.read(journeySearchOptionsProvider),
      );
    });
  }

  /// Narrowing the search invalidates results already on screen — they were
  /// found under the old rules — so it is re-run with the new options rather
  /// than left showing a flight, or a four-minute change, the user just ruled
  /// out.
  Future<void> _pickOptions() async {
    final picked = await showSearchOptionsSheet(
      context,
      initial: ref.read(journeySearchOptionsProvider),
    );
    if (picked == null || !mounted) return;
    await ref.read(journeySearchOptionsProvider.notifier).setOptions(picked);
    if (_query != null && mounted) _runSearch();
  }

  /// Opens a result, and imports it only if the preview is confirmed there.
  ///
  /// A row cannot say which platform, or how long the change in Frankfurt is —
  /// so tapping one *shows* the journey and the preview's own button commits
  /// it. That keeps the rule the rest of the app runs on: a tap browses, a
  /// button spends. It also means the results list is safe to poke at.
  Future<void> _preview(JourneyOption option) async {
    final l10n = AppLocalizations.of(context);
    // Replacing, the choice is between two journeys rather than between adding
    // one and adding none, so both ways out of the preview are named.
    final replacing = widget.replacing != null;
    final confirmed = await showJourneyPreviewSheet(
      context,
      option: option,
      confirmLabel: replacing ? l10n.connectionsUseThis : null,
      cancelLabel: replacing ? l10n.connectionsKeepPlan : null,
    );
    if (confirmed && mounted) await _import(option);
  }

  Future<void> _import(JourneyOption option) async {
    setState(() => _importing = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final labels = (
      track: l10n.platformShort,
      fromTrack: l10n.platformFromShort,
      toTrack: l10n.platformToShort,
      direction: l10n.directionTo,
    );
    final replacing = widget.replacing;
    try {
      final controller = ref.read(transportSearchControllerProvider);
      if (replacing != null) {
        // The run's own legs make way for it, keeping the bundle and so the
        // ticket. Nothing is announced: the legs it replaced are in the timeline
        // this sheet closes onto.
        await controller.replaceJourney(
          widget.tripId,
          journey: replacing,
          option: option,
          labels: labels,
          // The ends *this* search used, not the ones the old run carried: they
          // may well be different — a hand-entered run had none at all, and the
          // form lets either end be changed outright.
          fromPlaceId: _from?.queryId,
          toPlaceId: _to?.queryId,
          // Into a routine, what is kept is the *shape*: which legs, in which
          // order, how far into the plan each falls.
          rebaseFrom: widget.intoRoutine ? _date : null,
          rebaseTo: widget.intoRoutine ? widget.day : null,
        );
      } else {
        await controller.importJourney(
          widget.tripId,
          option,
          // Into the option the search was opened from, when it was — not onto
          // the day behind it.
          alternativeId: widget.alternativeId,
          // The ids this search was issued against, kept so the same journey
          // can be looked up again for another date.
          fromPlaceId: _from?.queryId,
          toPlaceId: _to?.queryId,
          // Into a routine, the connection is a *shape*: which legs, in which
          // order, how far into the plan each falls. Rebasing keeps that and
          // drops the rest.
          rebaseFrom: widget.intoRoutine ? _date : null,
          rebaseTo: widget.intoRoutine ? widget.day : null,
          trackLabel: labels.track,
          fromTrackLabel: labels.fromTrack,
          toTrackLabel: labels.toTrack,
          directionLabel: labels.direction,
        );
        messenger.showSnackBar(SnackBar(content: Text(l10n.connectionAdded)));
      }
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
              hint: _fromHint,
              onTap: () => _pick(
                initialQuery: _fromHint,
                onPicked: (place) {
                  _from = place;
                  _fromHint = null;
                },
              ),
            ),
            for (var i = 0; i < _vias.length; i++) ...[
              _EndpointTile(
                // The dots on the rail between origin and destination: this is
                // somewhere the journey passes, not somewhere it ends.
                icon: Icons.more_vert,
                label: l10n.connectionVia,
                place: _vias[i].place,
                onTap: () => _changeVia(i),
                // The stay hangs off the stop, so removing the row takes it
                // with it — and the next via starts from no minimum again.
                onClear: () => setState(() => _vias.removeAt(i)),
                clearTooltip: l10n.connectionViaRemove,
              ),
              _viaStayRow(l10n, i),
            ],
            // Between the two ends, because that is where a via stop goes. It
            // stops being offered at the service's own limit rather than
            // standing there disabled with nothing to say why.
            if (_vias.length < kMaxViaStops)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.connectionViaAdd),
                    onPressed: _addVia,
                  ),
                ),
              ),
            _EndpointTile(
              icon: Icons.place_outlined,
              label: l10n.connectionTo,
              place: _to,
              hint: _toHint,
              onTap: () => _pick(
                initialQuery: _toHint,
                onPicked: (place) {
                  _to = place;
                  _toHint = null;
                },
              ),
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
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.connectionOptionsTitle),
              subtitle: Text(
                searchOptionsSummary(
                  l10n,
                  ref.watch(journeySearchOptionsProvider),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: _pickOptions,
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
              child: const AttributionFooter(),
            ),
          ],
        ),
      ),
    );
  }

  /// How long to spend at the via stop at [index] before travelling on.
  ///
  /// It sits under its stop rather than in the search options: it is a fact
  /// about *this* journey ("two hours in Nuremberg"), not a preference to carry
  /// into the next search, and it means nothing on its own. Indented to the
  /// stop's title so it reads as belonging to it rather than to the row below.
  Widget _viaStayRow(AppLocalizations l10n, int index) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.connectionViaStay,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _vias[index].stayMinutes,
            underline: const SizedBox.shrink(),
            items: [
              for (final minutes in kViaStayMinuteOptions)
                DropdownMenuItem(
                  value: minutes,
                  child: Text(
                    // Zero is not the absence of an answer: it tells the
                    // service the traveller need not get off at all.
                    minutes == 0
                        ? l10n.connectionViaStayNone
                        : formatStayDuration(l10n, minutes),
                  ),
                ),
            ],
            onChanged: (v) => setState(
              () => _vias[index] = (
                place: _vias[index].place,
                stayMinutes: v ?? 0,
              ),
            ),
          ),
        ],
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
            if (results.direct.isNotEmpty) _directRow(l10n, results.direct),
            _pageRow(l10n, earlier: true, cursor: results.earlierCursor),
            // An empty window is not an empty timetable — the rows above and
            // below still lead somewhere, so the message goes between them
            // rather than in their place. It is also not said at all when the
            // journey can simply be walked: the answer is right above.
            if (results.options.isEmpty && results.direct.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    // Bike carriage and step-free travel are the two filters
                    // that routinely find nothing through no fault of the
                    // route: most feeds simply do not say whether bikes are
                    // allowed or whether a service is accessible, and silence
                    // counts as "no". Naming the filter beats "no connections
                    // found" sending someone hunting for a better departure
                    // time. Accessibility is named first when both are on: it
                    // is the harder constraint to trade away.
                    switch (query.options) {
                      final o when o.wheelchair =>
                        l10n.connectionNoAccessibleConnections,
                      final o when o.bikeOnBoard =>
                        l10n.connectionNoBikeConnections,
                      _ => l10n.connectionSearchNoResults,
                    },
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final option in results.options)
              _ResultCard(option: option, onTap: () => _preview(option)),
            _pageRow(l10n, earlier: false, cursor: results.laterCursor),
          ],
        ),
      ),
    );
  }

  /// Ways to make the journey without public transport, as compact chips above
  /// the timetable.
  ///
  /// Chips rather than result cards because a direct connection has no
  /// departure: it starts when the traveller does, so the times a card is built
  /// around — and the delay marks beside them — would be inventing precision.
  /// It sits above the "earlier" row because it belongs to no window: paging
  /// moves the trains, not the walk.
  Widget _directRow(AppLocalizations l10n, List<JourneyOption> direct) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.connectionWithoutTransit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in direct)
                ActionChip(
                  avatar: Icon(
                    transitIcon(option.legs.firstOrNull?.mode),
                    size: 18,
                  ),
                  label: Text(formatJourneyDuration(option.duration)),
                  onPressed: () => _preview(option),
                ),
            ],
          ),
        ],
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

/// A From/Via/To row showing the chosen place or a prompt.
class _EndpointTile extends StatelessWidget {
  const _EndpointTile({
    required this.icon,
    required this.label,
    required this.place,
    required this.onTap,
    this.hint,
    this.onClear,
    this.clearTooltip,
  });

  final IconData icon;
  final String label;
  final TransportPlace? place;

  /// What the journey being replaced calls this end, when no [place] has been
  /// picked for it yet. Shown greyed under the field's own label, so the form
  /// says which station is being asked about without pretending it is settled.
  final String? hint;
  final VoidCallback onTap;

  /// Offered only where the place is optional — a journey always has two ends,
  /// so From and To have nothing to clear *to*.
  final VoidCallback? onClear;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final place = this.place;
    final theme = Theme.of(context);
    final hint = this.hint;
    return ListTile(
      leading: Icon(icon),
      title: Text(place?.name ?? label),
      subtitle: switch ((place, hint)) {
        (final p?, _) when p.area != null => Text(p.area!),
        (null, final h?) when h.trim().isNotEmpty => Text(
          h,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        _ => null,
      },
      trailing: onClear == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              tooltip: clearTooltip,
              onPressed: onClear,
            ),
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
    // The router plans around cancellations, so this is all but unreachable in
    // practice — which is exactly why it must not import silently if it ever is
    // reached.
    final cancelled = option.legs.any((l) => l.cancelled);
    final summary = vehicleLegs.map((l) => l.line ?? l.mode.name).join(' → ');

    return ListTile(
      leading: Icon(transitIcon(vehicleLegs.firstOrNull?.mode)),
      title: Text.rich(
        TextSpan(
          children: [
            ...legTimeSpans(context, dep),
            const TextSpan(text: ' – '),
            ...legTimeSpans(context, arr),
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
      subtitle: Text.rich(
        TextSpan(
          children: [
            if (cancelled)
              TextSpan(
                text: '${l10n.connectionCancelled} · ',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            TextSpan(
              text:
                  '${formatJourneyDuration(option.duration)} · '
                  '${l10n.connectionChanges(option.transfers)}'
                  '${summary.isEmpty ? '' : ' · $summary'}',
            ),
          ],
        ),
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
  const _PlacePickerSheet({this.stopsOnly = false, this.initialQuery});

  /// Whether addresses and points of interest are dropped from the suggestions,
  /// leaving stations alone. Set for a via stop, which the routing service
  /// addresses by stop id and by nothing else — an address offered here could
  /// only be picked and then fail.
  final bool stopsOnly;

  /// What to search for on opening — the name a leg being replaced gives this
  /// end. The field is editable as ever: it is a starting point, not an answer.
  final String? initialQuery;

  @override
  ConsumerState<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<_PlacePickerSheet> {
  late final _controller = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  late String _query = widget.initialQuery ?? '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final async = ref.watch(geocodeProvider(_query));
    final places = [
      for (final place in async.value ?? const <TransportPlace>[])
        if (!widget.stopsOnly || place.kind == PlaceKind.stop) place,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: widget.stopsOnly
                          ? l10n.connectionPickStop
                          : l10n.connectionPickPlace,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  // Said here rather than discovered as a suggestion list that
                  // silently omits the address just typed into it.
                  if (widget.stopsOnly) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.connectionViaHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
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
                  for (final place in places)
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
