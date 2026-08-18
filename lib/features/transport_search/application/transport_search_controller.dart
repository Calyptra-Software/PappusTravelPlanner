import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/stopovers.dart';
import '../data/journey_mapper.dart';
import '../data/live_refresh.dart';
import '../../trips/planned_journey.dart';
import '../domain/journey.dart';
import '../domain/journey_ends.dart';
import 'journey_search_options_provider.dart';
import 'transport_search_providers.dart';

final transportSearchControllerProvider = Provider<TransportSearchController>(
  (ref) => TransportSearchController(ref),
);

/// The localized labels an import needs to compose a leg's auto-notes. Bundled
/// because they always travel together and are always the same four strings;
/// passing them one at a time through every caller was four chances to forget
/// one.
typedef JourneyImportLabels = ({
  TrackLabel track,
  TrackLabel fromTrack,
  TrackLabel toTrack,
  DirectionLabel direction,
});

/// Turns a chosen [JourneyOption] into itinerary legs and writes them to a trip.
///
/// The three pure/data pieces meet here: the current [TransportModes] resolve a
/// [modeResolver], [journeyToLegs] maps the journey (local times, overnight flag,
/// mode ids), and [TripRepository.insertJourney] appends the legs and bundles
/// each day's run into a group. Requires the timezone database to be initialised
/// (done in `main`).
class TransportSearchController {
  TransportSearchController(this._ref);

  final Ref _ref;

  /// The modes an import maps the router's vocabulary onto, read **once from the
  /// repository** rather than from `transportModesProvider`.
  ///
  /// That provider is `autoDispose`: read from here, where nothing listens to
  /// it, it is disposed while its query is still in flight and its future throws
  /// ("disposed during loading state") — so an import worked only on a screen
  /// that happened to be watching the modes already. Stamping a trip out of a
  /// routine from the overview, where nothing does, threw on the first accepted
  /// connection: the legs stayed a copied plan with no `sourceTripId` to refresh,
  /// and the journeys after it were never offered. Whether the modes finish
  /// loading cannot depend on what is on screen.
  Future<List<TransportModeRow>> _modes() =>
      _ref.read(repositoryProvider).transportModes();

  /// The track/direction labels localize the auto-notes composed for each leg;
  /// the UI supplies them from its localizations. [trackLabel] writes a platform
  /// the arrow already places ("Pl. 5 → Pl. 20"), while
  /// [fromTrackLabel]/[toTrackLabel] name the end themselves, for a leg where
  /// the service gave only one of the two.
  ///
  /// [rebaseFrom] / [rebaseTo] move the whole run off the dates it was found on
  /// and onto a day of a dateless plan — what importing into a **routine** does.
  /// A timetable only exists on real dates, so the search is made on one and the
  /// answer is laid back onto the plan by the same number of days, which keeps
  /// an overnight leg on the next day of the plan. What is left behind is
  /// everything that belonged to that particular run: its `sourceTripId`, and
  /// any live times already read off it. A template must not look refreshable,
  /// and a delay measured on one Tuesday is not part of a plan.
  ///
  /// [fromPlaceId] / [toPlaceId] are the `queryId`s this search was issued
  /// against. They are kept on the run's outer legs so the same journey can be
  /// searched again for another date — which is how a routine's plan becomes a
  /// real, refreshable connection when a trip is stamped out of it. Unlike
  /// `sourceTripId` they say nothing about *when*, so they survive a copy.
  ///
  /// [alternativeId] plans the run inside one option of a decision instead of on
  /// the day: the search is reached from the *same* add-transport button the
  /// option offers for a hand-written leg, so it has to land in the same place.
  Future<List<int>> importJourney(
    int tripId,
    JourneyOption journey, {
    bool group = true,
    int? alternativeId,
    String? fromPlaceId,
    String? toPlaceId,
    DateTime? rebaseFrom,
    DateTime? rebaseTo,
    TrackLabel? trackLabel,
    TrackLabel? fromTrackLabel,
    TrackLabel? toTrackLabel,
    DirectionLabel? directionLabel,
  }) async {
    final modes = await _modes();
    final legs = journeyToLegs(
      journey,
      resolveMode: modeResolver(modes),
      trackLabel: trackLabel,
      fromTrackLabel: fromTrackLabel,
      toTrackLabel: toTrackLabel,
      directionLabel: directionLabel,
    );
    final rebase = rebaseFrom != null && rebaseTo != null;
    final companions = [
      for (final (index, leg) in legs.indexed)
        () {
          final companion = mappedLegToCompanion(
            tripId,
            leg,
            fromPlaceId: index == 0 ? fromPlaceId : null,
            toPlaceId: index == legs.length - 1 ? toPlaceId : null,
          );
          if (!rebase) return companion;
          return companion.copyWith(
            date: Value(
              rebasedLegDay(leg.date, foundOn: rebaseFrom, planDay: rebaseTo),
            ),
            sourceTripId: const Value(null),
            actualStartMinutes: const Value(null),
            actualEndMinutes: const Value(null),
          );
        }(),
    ];
    return _ref
        .read(repositoryProvider)
        .insertJourney(
          tripId,
          companions,
          group: group,
          alternativeId: alternativeId,
          // The shape is plan, not provenance: it says where the line goes, not
          // which dated run went along it, so it travels even into a routine —
          // exactly as the endpoint coordinates and the stops do, and unlike the
          // `sourceTripId` dropped just above.
          shapes: [for (final leg in legs) leg.shape],
        );
  }

  /// Asks the timetable about a run the trip already holds: the same endpoints
  /// it was searched by, on the day it now sits on, around its planned
  /// departure.
  ///
  /// Returns the options the router offers, best first, or an empty list when
  /// nothing runs. Throws on a network failure, which the caller reports — there
  /// is a real difference between "no train" and "no signal", and the user must
  /// not be told the first when it was the second.
  ///
  /// Two callers ask the same question of the same shape: the routine flow, for
  /// every journey of a trip it has just stamped out, and the journey sheet, for
  /// the one run being read. Only [PlannedJourney.canLookUp] runs may be passed
  /// — the ids and the departure are asserted here rather than guessed.
  Future<List<JourneyOption>> searchPlannedJourney(
    PlannedJourney journey,
  ) async {
    final minutes = journey.departMinutes!;
    // Built as a wall clock, not by adding a Duration to midnight: on the day a
    // clock goes forward, adding 7h42m to 00:00 lands at 08:42, and the search
    // would be for an hour after the one the plan asks for.
    final when = DateTime(
      journey.date.year,
      journey.date.month,
      journey.date.day,
      minutes ~/ 60,
      minutes % 60,
    );
    final results = await _ref
        .read(transportSearchProvider)
        .journeys(
          fromId: journey.fromPlaceId!,
          toId: journey.toPlaceId!,
          time: when,
          options: _ref.read(journeySearchOptionsProvider),
        );
    // The direct options (walking or cycling the whole way) are part of the
    // answer for a short hop, which a commute often is.
    //
    // The other of the two places a search's answer arrives (see
    // `journey_ends.dart`). The names to fall back on are the run's own: this
    // journey is already in the plan, calling its ends `Schlump` and
    // `Geomatikum`, and a re-routing of it should go on saying so rather than
    // renaming them `START` and `END`.
    return [
      for (final option in [...results.options, ...results.direct])
        resolvedOptionEnds(
          option,
          fromName: journey.fromLocation,
          toName: journey.toLocation,
        ),
    ];
  }

  /// Replaces one run of legs in a trip with a freshly-searched connection,
  /// keeping the bundle they travel in — see `RoutineDao.replaceJourneyLegs`,
  /// which explains why the group survives rather than being remade.
  ///
  /// This is what turns a plan copied from a routine into a journey that really
  /// runs on the day it was copied onto: same endpoints, same time of day, but
  /// the service the timetable actually has — and so a `sourceTripId` that the
  /// live-times refresh can use.
  ///
  /// [fromPlaceId] / [toPlaceId] are the ids this particular search was issued
  /// against, kept on the replacement's outer legs so it can be searched again in
  /// turn. They default to the ones [journey] carried, which is right when it was
  /// searched by its own ends — the routine flow, which issues the query itself.
  /// The search *form* passes its own: an end there can be repicked outright, and
  /// a hand-entered run had no id to inherit in the first place.
  ///
  /// [rebaseFrom] / [rebaseTo] lay the answer back onto a **routine's** plan day,
  /// exactly as [importJourney] does and for the same reason: a routine's days are
  /// ordinals, no timetable answers for them, so the search is made on a real date
  /// and what it finds is moved back by the same number of days — an overnight leg
  /// still landing a day further into the plan. What is left behind is what belongs
  /// to that one dated run: its `sourceTripId` and any live times read off it,
  /// since a template must not look refreshable and a delay measured on one Tuesday
  /// is not part of a plan. Re-routing a routine is the only caller: an ordinary
  /// trip's run already sits on the day it runs on.
  Future<void> replaceJourney(
    int tripId, {
    required PlannedJourney journey,
    required JourneyOption option,
    required JourneyImportLabels labels,
    String? fromPlaceId,
    String? toPlaceId,
    DateTime? rebaseFrom,
    DateTime? rebaseTo,
  }) async {
    final modes = await _modes();
    final legs = journeyToLegs(
      option,
      resolveMode: modeResolver(modes),
      trackLabel: labels.track,
      fromTrackLabel: labels.fromTrack,
      toTrackLabel: labels.toTrack,
      directionLabel: labels.direction,
    );
    final rebase = rebaseFrom != null && rebaseTo != null;
    final companions = [
      for (final (index, leg) in legs.indexed)
        () {
          final companion = mappedLegToCompanion(
            tripId,
            leg,
            // The endpoints are the ones this journey was searched by, so the
            // result stays searchable in turn.
            fromPlaceId: index == 0
                ? (fromPlaceId ?? journey.fromPlaceId)
                : null,
            toPlaceId: index == legs.length - 1
                ? (toPlaceId ?? journey.toPlaceId)
                : null,
          );
          if (!rebase) return companion;
          return companion.copyWith(
            date: Value(
              rebasedLegDay(leg.date, foundOn: rebaseFrom, planDay: rebaseTo),
            ),
            sourceTripId: const Value(null),
            actualStartMinutes: const Value(null),
            actualEndMinutes: const Value(null),
          );
        }(),
    ];
    await _ref
        .read(repositoryProvider)
        .replaceJourneyLegs(
          tripId,
          oldLegIds: journey.legIds,
          legs: companions,
          groupId: journey.groupId,
        );
  }

  /// Refreshes one imported leg's live (real-time) times: re-queries its trip and
  /// writes the actual departure/arrival read off the live stops, together with
  /// the delay at each stop the leg passes through. A network failure propagates
  /// (the UI shows it). Manual only — invoked from the leg's own refresh button,
  /// never on a timer.
  Future<LegRefresh> refreshLeg(ItineraryItem item) async {
    final sourceTripId = item.sourceTripId;
    final start = item.startMinutes;
    final end = item.endMinutes;
    if (sourceTripId == null || start == null || end == null) {
      return LegRefresh.nothing;
    }

    final stops = await _ref
        .read(transportSearchProvider)
        .tripStops(sourceTripId);
    final stopovers = decodeStopovers(item.stopovers);
    final refreshed = refreshedActualTimes(
      stops: stops,
      date: item.date,
      startMinutes: start,
      endMinutes: end,
      spansNextDay: item.spansNextDay,
      fromName: item.fromLocation ?? '',
      toName: item.toLocation ?? '',
    );
    if (refreshed == null) return LegRefresh.nothing;
    // A cancelled service reports no times at all, so there is nothing to
    // write — and nothing *should* be written: an actual time would say the leg
    // ran. What the traveller needs is the news itself.
    if (refreshed.cancelled) return LegRefresh.cancelled;
    // The stops in between ride along with the ends: the same live trip answers
    // for all of them, so one tap leaves the whole leg current.
    await _ref
        .read(repositoryProvider)
        .setLiveTimes(
          item.id,
          actualStart: refreshed.actualStartMinutes,
          actualEnd: refreshed.actualEndMinutes,
          stopovers: encodeStopovers(
            refreshedStopovers(
              stops: stops,
              stopovers: stopovers,
              date: item.date,
            ),
          ),
        );
    return LegRefresh.updated;
  }
}

/// What asking a leg's trip for live information turned up.
enum LegRefresh {
  /// Actual times were read and written; the tile now shows the delay marks.
  updated,

  /// The service is not running — cancelled outright, or skipping the stops
  /// this leg uses.
  cancelled,

  /// Nothing live to apply: no trip id, or a trip carrying no real-time at all
  /// (it has already run, or its schedule no longer matches what was imported).
  nothing,
}
