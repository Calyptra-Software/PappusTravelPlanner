import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

final routineControllerProvider = Provider<RoutineController>(
  (ref) => RoutineController(ref),
);

/// Stamping a real trip out of a routine. Looking its journeys up for the days
/// it was stamped onto is the separate, network-bound half, and lives in
/// `TripConnectionsController`, since a duplicated or moved trip asks the same.
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
}
