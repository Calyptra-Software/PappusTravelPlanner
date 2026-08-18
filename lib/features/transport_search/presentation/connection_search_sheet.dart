import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/attribution.dart';
import '../../../data/database/app_database.dart' show Trip;
import '../../../data/database/tables.dart' show TripKind;
import '../../../l10n/app_localizations.dart';
import '../../map/presentation/map_picker_screen.dart';
import '../../trips/application/trip_providers.dart';
import '../../trips/widgets/trip_picker.dart';
import '../application/journey_search_options_provider.dart';
import '../application/transport_search_controller.dart';
import '../application/transport_search_providers.dart';
import '../data/journey_mapper.dart' show localParts;
import '../domain/journey.dart';
import '../domain/transit_mode.dart';
import '../domain/transport_place.dart';
import '../domain/via_stop.dart';
import 'journey_destination.dart';
import 'journey_formats.dart';
import 'journey_preview_sheet.dart';
import 'search_options_sheet.dart';

/// Opens the connection search, writing what is taken to [destination] — a day
/// of a trip, one option of a decision, the run being replaced, or nowhere at
/// all ([JourneyLookup]). Resolves to true when a journey was written (so the
/// caller can close its own sheet), false/null otherwise — and so always false
/// for a lookup, which writes nothing.
Future<bool> showConnectionSearchSheet(
  BuildContext context, {
  required JourneyDestination destination,
}) async {
  final imported = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ConnectionSearchSheet(destination: destination),
  );
  return imported ?? false;
}

/// One via stop on the form: the station itself, and how long to stay there.
typedef _Via = ({TransportPlace place, int stayMinutes});

class ConnectionSearchSheet extends ConsumerStatefulWidget {
  const ConnectionSearchSheet({super.key, required this.destination});

  /// What becomes of a connection taken here: added to a day or an option,
  /// swapped in for a run the trip already holds, or — for a [JourneyLookup] —
  /// nothing, the search having been made from the overview with no plan behind
  /// it.
  final JourneyDestination destination;

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
  // the search starts from today and the result is rebased on import. A lookup
  // has no day of its own at all, and today is the day a question asked from the
  // overview is nearly always about.
  late DateTime _date = switch (widget.destination) {
    final TripJourneyDestination d when !d.intoRoutine => DateUtils.dateOnly(
      d.day,
    ),
    _ => DateUtils.dateOnly(DateTime.now()),
  };
  TimeOfDay _time = TimeOfDay.now();
  bool _arriveBy = false;
  JourneyQuery? _query;
  bool _importing = false;

  /// Which end is currently fetching a window — true for "earlier", false for
  /// "later", null when nothing is on its way.
  bool? _pagingEarlier;

  bool get _canSearch => _from != null && _to != null;

  /// The trip this search writes into, or null when it writes nowhere — the one
  /// question the sheet keeps asking, since it decides whether a result can be
  /// committed at all.
  TripJourneyDestination? get _destinationTrip {
    final destination = widget.destination;
    return destination is TripJourneyDestination ? destination : null;
  }

  /// Whether the answer has to be laid back onto a dateless plan. False for a
  /// lookup, which lands nowhere and so rebases nothing.
  bool get _intoRoutine => _destinationTrip?.intoRoutine ?? false;

  /// The trips a looked-up journey could be filed into: everything but the
  /// routines, which have no dates for a real connection to sit on — laying one
  /// onto a plan needs a *plan day*, which a flat list of trips cannot ask for
  /// (importing into a routine goes through the routine's own timeline, where
  /// the day is known).
  ///
  /// Kept from the last build, and **watched** there rather than read off
  /// whoever else happens to be listening: the provider is autoDispose, so a
  /// read from a callback can find it disposed mid-flight (the trap
  /// `TransportSearchController._modes` documents). The button is offered only
  /// when there is somewhere for it to lead, so the answer is needed a build
  /// before the tap in any case. Always empty for a trip-bound search, which has
  /// its destination already and never asks.
  List<Trip> _saveTargets = const [];

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
    final destination = widget.destination;
    if (destination is! ReplaceRun) return;
    final replacing = destination.journey;
    _from = replacing.fromPlace;
    _to = replacing.toPlace;
    if (_from == null) _fromHint = replacing.fromLocation;
    if (_to == null) _toHint = replacing.toLocation;
    final minutes = destination.departFromMinutes ?? replacing.departMinutes;
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
        // Carried so an end answered as a bare coordinate can be named by what
        // the user picked rather than by the router's `START` / `END` — see
        // `journey_ends.dart`.
        fromName: _from!.name,
        toName: _to!.name,
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
  ///
  /// A lookup has no destination *yet*, so its button asks for one — and when
  /// there is no trip to ask about, there is no button: the sheet is then the
  /// whole answer, read and dismissed.
  Future<void> _preview(JourneyOption option) async {
    final l10n = AppLocalizations.of(context);
    // Replacing, the choice is between two journeys rather than between adding
    // one and adding none, so both ways out of the preview are named.
    final replacing = widget.destination is ReplaceRun;
    final targets = _saveTargets;
    final lookup = _destinationTrip == null;
    final confirmed = await showJourneyPreviewSheet(
      context,
      option: option,
      confirmable: !lookup || targets.isNotEmpty,
      confirmLabel: switch (widget.destination) {
        ReplaceRun() => l10n.connectionsUseThis,
        // The ellipsis is the promise that a question follows: nothing is
        // written until a trip has been named.
        JourneyLookup() => l10n.connectionSaveToTrip,
        AddToDay() => null,
      },
      cancelLabel: replacing ? l10n.connectionsKeepPlan : null,
    );
    if (!confirmed || !mounted) return;
    if (lookup) {
      await _saveToTrip(option, targets);
    } else {
      await _import(option);
    }
  }

  /// Files a looked-up journey into a trip the user names.
  ///
  /// No day is asked for: the connection was searched on a real date and its
  /// legs carry it, so the day it belongs on is the one it runs on. A *dated*
  /// trip whose range does not reach that far is widened to cover it
  /// (`insertJourney` → `TripDao.widenToCover`), exactly as importing into the
  /// trip's own timeline would — a journey booked for the day after a trip was
  /// meant to end has extended the trip, and the overview card should say so.
  /// A trip with no dates keeps none: an absent range there is a deliberate "not
  /// decided yet", not a range to be guessed from a timetable.
  ///
  /// The sheet stays open afterwards, unlike every trip-bound import: those
  /// close onto a timeline that has just changed underneath them, while this one
  /// leaves the screen behind it as it was. Keeping the form standing is also
  /// what makes the return journey one search away rather than a re-opened sheet
  /// with both ends to pick again.
  Future<void> _saveToTrip(JourneyOption option, List<Trip> targets) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final target = await showTripPicker(context, targets);
    if (target == null || !mounted) return;
    setState(() => _importing = true);
    try {
      await ref
          .read(transportSearchControllerProvider)
          .importJourney(
            target.id,
            option,
            // The ids this search was issued against, kept so the same journey
            // can be looked up again for another date.
            fromPlaceId: _from?.queryId,
            toPlaceId: _to?.queryId,
            trackLabel: l10n.platformShort,
            fromTrackLabel: l10n.platformFromShort,
            toTrackLabel: l10n.platformToShort,
            directionLabel: l10n.directionTo,
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.connectionSavedTo(target.title))),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.connectionSearchError)),
      );
    }
    if (mounted) setState(() => _importing = false);
  }

  /// Writes [option] where the destination says. Never reached for a
  /// [JourneyLookup]: nothing there offers to confirm a result in the first
  /// place, which is why this can take the trip destination as given.
  Future<void> _import(JourneyOption option) async {
    final destination = _destinationTrip;
    if (destination == null) return;
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
    // Into a routine, what is kept is the *shape*: which legs, in which order,
    // how far into the plan each falls. Rebasing keeps that and drops the rest.
    final rebaseFrom = _intoRoutine ? _date : null;
    final rebaseTo = _intoRoutine ? destination.day : null;
    try {
      final controller = ref.read(transportSearchControllerProvider);
      switch (destination) {
        // The run's own legs make way for it, keeping the bundle and so the
        // ticket. Nothing is announced: the legs it replaced are in the timeline
        // this sheet closes onto.
        case ReplaceRun(:final journey):
          await controller.replaceJourney(
            destination.tripId,
            journey: journey,
            option: option,
            labels: labels,
            // The ends *this* search used, not the ones the old run carried:
            // they may well be different — a hand-entered run had none at all,
            // and the form lets either end be changed outright.
            fromPlaceId: _from?.queryId,
            toPlaceId: _to?.queryId,
            rebaseFrom: rebaseFrom,
            rebaseTo: rebaseTo,
          );
        case AddToDay(:final alternativeId):
          await controller.importJourney(
            destination.tripId,
            option,
            // Into the option the search was opened from, when it was — not
            // onto the day behind it.
            alternativeId: alternativeId,
            // The ids this search was issued against, kept so the same journey
            // can be looked up again for another date.
            fromPlaceId: _from?.queryId,
            toPlaceId: _to?.queryId,
            rebaseFrom: rebaseFrom,
            rebaseTo: rebaseTo,
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
    // Only a lookup ever asks where to file a journey, so only a lookup pays for
    // the trip list — a trip-bound search must not start a stream it has no
    // question for.
    _saveTargets = _destinationTrip != null
        ? const []
        : [
            for (final trip
                in ref.watch(tripListProvider).value ?? const <Trip>[])
              if (trip.kind != TripKind.routine) trip,
          ];

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

  /// Picks a bare coordinate from the map and answers the sheet with it.
  ///
  /// The result is a [TransportPlace] of kind [PlaceKind.place], which is what
  /// makes `queryId` send `lat,lon` rather than an id — there is no id to send,
  /// and a coordinate is what the router wants for a door anyway. It is named by
  /// its own numbers: the app does not ask the geocoder what is there, because
  /// that would be putting a name on the user's choice that they did not make.
  Future<void> _pickOnMap(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final point = await pickPointOnMap(context, title: l10n.mapPickTitlePlace);
    if (point == null || !context.mounted) return;
    Navigator.of(context).pop(
      TransportPlace(
        id: coordinateQueryId(point.latitude, point.longitude),
        name: formatCoordinates(point),
        kind: PlaceKind.place,
        lat: point.latitude,
        lon: point.longitude,
      ),
    );
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
                  // Pointing at the map is the answer when naming the place
                  // fails — an address the geocoder does not know, a trailhead
                  // with no name at all, or simply "from here". The router takes
                  // a coordinate anywhere it takes a stop id.
                  //
                  // Not offered for a **via** stop: the spec allows only stop
                  // ids there, so a coordinate would be a choice that could only
                  // fail — which is the same reason that list is filtered to
                  // stations.
                  if (!widget.stopsOnly)
                    ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: Text(l10n.connectionPickOnMap),
                      onTap: () => _pickOnMap(context),
                    ),
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
