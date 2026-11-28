import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/date_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/route_plan.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../map/location/device_location.dart';
import '../../map/map_features.dart';
import '../../transport_search/journey_map_features.dart';
import '../../transport_search/presentation/journey_formats.dart';
import '../../transport_search/vehicle_progress.dart';
import '../domain/pace.dart';
import '../domain/route_profile.dart';
import '../domain/route_progress.dart';

/// Within how much of the plan a traveler is on it, rather than ahead or
/// behind: a minute or two is no news on a walk.
const Duration kOnPlan = Duration(minutes: 2);

/// The legs among [legs] the route planner laid out, as progress against the
/// plan reads them: each with its times, actual where set, and its line, the
/// drawn one from [tracks] or the chord between its ends. A leg without times
/// or without a line has nothing to be measured against and is left out.
List<PlannedStretch> plannedStretches(
  List<ItineraryItem> legs,
  Map<int, List<TrackLine>> tracks,
) {
  final stretches = <PlannedStretch>[];
  for (final leg in legs) {
    if (leg.kind != ItemKind.transport) continue;
    final plan = decodeRoutePlan(leg.routePlan);
    if (plan == null || !plan.isLeg) continue;
    final calls = legCalls(leg);
    final start = calls
        .where((call) => call.part == CallPart.board)
        .firstOrNull
        ?.departure;
    final end = calls
        .where((call) => call.part == CallPart.alight)
        .firstOrNull
        ?.arrival;
    if (start == null || end == null || end.isBefore(start)) continue;
    final line = drawnRouteLine(tracks[leg.id] ?? const []);
    final points =
        line?.points ??
        [
          if (leg.fromLat != null && leg.fromLon != null)
            LatLng(leg.fromLat!, leg.fromLon!),
          if (leg.toLat != null && leg.toLon != null)
            LatLng(leg.toLat!, leg.toLon!),
        ];
    if (points.length < 2) continue;
    stretches.add(
      PlannedStretch(
        points: points,
        effort: effortAlong(
          RouteProfile.byName(plan.profile),
          points,
          line?.elevations,
        ),
        start: start,
        end: end,
      ),
    );
  }
  return stretches;
}

/// One line on the journey screen saying where the traveler stands against
/// the plan of a route: ahead of it or behind, with the arrival that makes, or
/// off the route. It reads the device's position only while the map shows it,
/// and asks for nothing: without a fix it says where to switch it on, while
/// the route is under way.
///
/// It says nothing before the route starts, and nothing once the route is
/// over: after its planned end unless the traveler is still on it and not yet
/// arrived.
class PlanStatus extends ConsumerWidget {
  const PlanStatus({
    super.key,
    required this.tripId,
    required this.legs,
    required this.clock,
  });

  final int tripId;
  final List<ItineraryItem> legs;
  final ValueListenable<DateTime?> clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tripTracksProvider(tripId)).value ?? const {};
    final stretches = plannedStretches(legs, tracks);
    if (stretches.isEmpty) return const SizedBox.shrink();
    final fix = ref.watch(deviceLocationProvider).fix;
    return ValueListenableBuilder<DateTime?>(
      valueListenable: clock,
      builder: (context, now, _) {
        if (now == null) return const SizedBox.shrink();
        final text = planStatusText(
          AppLocalizations.of(context),
          stretches,
          now,
          fix?.position,
          accuracyMeters: fix?.accuracyMeters ?? 0,
        );
        if (text == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
      },
    );
  }
}

/// What [PlanStatus] says at [now] with the device at [position], or null
/// when it says nothing.
String? planStatusText(
  AppLocalizations l10n,
  List<PlannedStretch> stretches,
  DateTime now,
  LatLng? position, {
  double accuracyMeters = 0,
}) {
  if (stretches.isEmpty || now.isBefore(stretches.first.start)) return null;
  final over = now.isAfter(stretches.last.end);
  if (position == null) return over ? null : l10n.routeProgressNoLocation;
  final progress = progressAgainstPlan(
    stretches,
    position,
    now,
    accuracyMeters: accuracyMeters,
  );
  switch (progress) {
    case null:
      return null;
    case OffRoute():
      return over ? null : l10n.routeProgressOffRoute;
    case OnRoute(:final behind, :final arrival):
      // Standing at the end, the arrival is now: arrived.
      if (!arrival.isAfter(now)) return null;
      final minutes = (behind.inSeconds.abs() / 60).round();
      final status = behind.abs() < kOnPlan
          ? l10n.routeProgressOnPlan
          : behind.isNegative
          ? l10n.routeProgressAhead(formatStayDuration(l10n, minutes))
          : l10n.routeProgressBehind(formatStayDuration(l10n, minutes));
      final local = arrival.toLocal();
      return l10n.routeProgressArrival(
        status,
        formatMinutes(local.hour * 60 + local.minute),
      );
  }
}
