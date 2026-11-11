import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../transport_search/application/transport_search_controller.dart';
import '../../transport_search/domain/journey.dart';
import '../../itinerary/live_items.dart';
import '../planned_journey.dart';

final tripConnectionsControllerProvider = Provider<TripConnectionsController>(
  (ref) => TripConnectionsController(ref),
);

/// Turning the journeys a trip carries as a *plan* into connections that
/// actually run on the days they now sit on: the part of putting a plan onto
/// new dates that needs the network.
///
/// Every way of doing that writes the plan first and asks here afterwards: a
/// routine stamped out onto real dates, a trip duplicated onto new ones, a trip
/// moved to new dates. Copying or moving is a database write that always
/// succeeds; looking the journeys up is a network call per journey that may
/// fail, may find nothing, and wants the user's eye on the result. So it
/// happens *after* the trip is right as a plan, and the trip is none the worse
/// if it is skipped.
class TripConnectionsController {
  TripConnectionsController(this._ref);

  final Ref _ref;

  /// The journeys in [tripId]'s plan that are worth looking up again.
  ///
  /// Only *live* entries are offered: a journey sitting in an option that was
  /// not chosen is not what the trip is doing, and searching it would spend a
  /// request and the user's attention on a road not taken. The modes are read
  /// for the same kind of reason — a run of nothing but walking is one the
  /// timetable cannot improve on, see [plannedJourneys].
  Future<List<PlannedJourney>> lookUpCandidates(int tripId) async {
    final repo = _ref.read(repositoryProvider);
    final items = await repo.watchItems(tripId).first;
    final branches = await repo.watchAlternativeBranches(tripId).first;
    return plannedJourneys(
      liveItems(items, chosenBranchIds(branches)),
      streetModeIds: streetTransportModeIds(await repo.transportModes()),
    );
  }

  /// Searches for [journey] as it now stands: the same endpoints the plan
  /// was built from, on the day the trip put it on, departing at its planned
  /// time.
  ///
  /// Returns the options the router offers, best first, or an empty list when
  /// nothing runs. Throws on a network failure, which the caller reports —
  /// there is a real difference between "no train" and "no signal", and the
  /// user should not be told the first when it was the second.
  ///
  /// The search itself lives on `TransportSearchController`, since asking the
  /// timetable about a planned run has nothing to do with this flow: the same
  /// question is asked of a single journey from the sheet that reads it.
  Future<List<JourneyOption>> lookUp(PlannedJourney journey) => _ref
      .read(transportSearchControllerProvider)
      .searchPlannedJourney(journey);

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
