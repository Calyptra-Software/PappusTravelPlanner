import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
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

  /// [trackLabel]/[directionLabel] localize the auto-notes (platform/direction)
  /// composed for each leg; the UI supplies them from its localizations.
  Future<List<int>> importJourney(
    int tripId,
    JourneyOption journey, {
    bool group = true,
    TrackLabel? trackLabel,
    DirectionLabel? directionLabel,
  }) async {
    final modes = await _ref.read(transportModesProvider.future);
    final legs = journeyToLegs(
      journey,
      resolveMode: modeResolver(modes),
      trackLabel: trackLabel,
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
  /// writes the actual departure/arrival read off the live stops. Returns whether
  /// anything was written — false for a leg with no `sourceTripId`, or whose trip
  /// carries no real-time (e.g. it has already run, or its schedule no longer
  /// matches). A network failure propagates (the UI shows it). Manual only —
  /// invoked from the leg's own refresh button, never on a timer.
  Future<bool> refreshLeg(ItineraryItem item) async {
    final sourceTripId = item.sourceTripId;
    final start = item.startMinutes;
    final end = item.endMinutes;
    if (sourceTripId == null || start == null || end == null) return false;

    final stops = await _ref
        .read(transportSearchProvider)
        .tripStops(sourceTripId);
    final refreshed = refreshedActualTimes(
      stops: stops,
      date: item.date,
      startMinutes: start,
      endMinutes: end,
      spansNextDay: item.spansNextDay,
      fromName: item.fromLocation ?? '',
      toName: item.toLocation ?? '',
    );
    if (refreshed == null) return false;
    await _ref
        .read(repositoryProvider)
        .setActualTimes(
          item.id,
          actualStart: refreshed.actualStartMinutes,
          actualEnd: refreshed.actualEndMinutes,
        );
    return true;
  }
}
