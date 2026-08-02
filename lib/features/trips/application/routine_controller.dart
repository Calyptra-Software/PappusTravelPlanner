import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../transport_search/application/transport_search_controller.dart';
import '../../transport_search/application/journey_search_options_provider.dart';
import '../../transport_search/application/transport_search_providers.dart';
import '../../transport_search/domain/journey.dart';
import '../../itinerary/live_items.dart';
import '../planned_journey.dart';

final routineControllerProvider = Provider<RoutineController>(
  (ref) => RoutineController(ref),
);

/// Stamping a real trip out of a routine, and — the part that needs the network
/// — turning the journeys it copied into connections that actually run on the
/// days it was stamped onto.
///
/// The two halves are deliberately separate. Copying the plan is a database
/// write that always succeeds: it is offline-safe, instant, and enough on its
/// own. Looking the journeys up is a network call per journey that may fail,
/// may find nothing, and wants the user's eye on the result — so it happens
/// *after* the trip exists, and the trip is none the worse if it is skipped.
class RoutineController {
  RoutineController(this._ref);

  final Ref _ref;

  /// Copies [routineId]'s plan onto real dates starting at [startDate].
  /// Offline-safe: no network, no failure mode beyond the write itself.
  Future<int> createTrip(int routineId, {required DateTime startDate}) {
    return _ref
        .read(repositoryProvider)
        .materializeRoutine(routineId, startDate: startDate);
  }

  /// The journeys in [tripId]'s plan that could be looked up again.
  ///
  /// Only *live* entries are offered: a journey sitting in an option that was
  /// not chosen is not what the trip is doing, and searching it would spend a
  /// request and the user's attention on a road not taken.
  Future<List<PlannedJourney>> lookUpCandidates(int tripId) async {
    final repo = _ref.read(repositoryProvider);
    final items = await repo.watchItems(tripId).first;
    final branches = await repo.watchAlternativeBranches(tripId).first;
    return plannedJourneys(liveItems(items, chosenBranchIds(branches)));
  }

  /// Searches for [journey] as it now stands: the same endpoints the routine
  /// was built from, on the day the trip put it on, departing at its planned
  /// time.
  ///
  /// Returns the options the router offers, best first, or an empty list when
  /// nothing runs. Throws on a network failure, which the caller reports —
  /// there is a real difference between "no train" and "no signal", and the
  /// user should not be told the first when it was the second.
  Future<List<JourneyOption>> lookUp(PlannedJourney journey) async {
    final minutes = journey.departMinutes!;
    // Built as a wall clock, not by adding a Duration to midnight: on the day a
    // clock goes forward, adding 7h42m to 00:00 lands at 08:42, and the search
    // would be for an hour after the one the routine asks for.
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
    return [...results.options, ...results.direct];
  }

  /// Puts [option] into the plan in [journey]'s place, keeping its bundle — and
  /// so its ticket — intact. See `RoutineDao.replaceJourneyLegs`.
  Future<void> useConnection(
    int tripId,
    PlannedJourney journey,
    JourneyOption option, {
    required JourneyImportLabels labels,
  }) {
    return _ref
        .read(transportSearchControllerProvider)
        .replaceJourney(
          tripId,
          journey: journey,
          option: option,
          labels: labels,
        );
  }
}
