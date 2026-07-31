import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/stopovers.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../data/journey_mapper.dart';
import '../data/live_refresh.dart';
import '../domain/journey.dart';
import 'transport_search_providers.dart';

final transportSearchControllerProvider = Provider<TransportSearchController>(
  (ref) => TransportSearchController(ref),
);

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

  /// The track/direction labels localize the auto-notes composed for each leg;
  /// the UI supplies them from its localizations. [trackLabel] writes a platform
  /// the arrow already places ("Pl. 5 → Pl. 20"), while
  /// [fromTrackLabel]/[toTrackLabel] name the end themselves, for a leg where
  /// the service gave only one of the two.
  Future<List<int>> importJourney(
    int tripId,
    JourneyOption journey, {
    bool group = true,
    TrackLabel? trackLabel,
    TrackLabel? fromTrackLabel,
    TrackLabel? toTrackLabel,
    DirectionLabel? directionLabel,
  }) async {
    final modes = await _ref.read(transportModesProvider.future);
    final legs = journeyToLegs(
      journey,
      resolveMode: modeResolver(modes),
      trackLabel: trackLabel,
      fromTrackLabel: fromTrackLabel,
      toTrackLabel: toTrackLabel,
      directionLabel: directionLabel,
    );
    final companions = [
      for (final leg in legs) mappedLegToCompanion(tripId, leg),
    ];
    return _ref
        .read(repositoryProvider)
        .insertJourney(tripId, companions, group: group);
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
