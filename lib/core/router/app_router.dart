import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/costs/presentation/trip_stats_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/trips/presentation/trip_detail_screen.dart';
import '../../features/trips/presentation/trip_form_screen.dart';
import '../../features/trips/presentation/routine_list_screen.dart';
import '../../features/trips/presentation/trip_list_screen.dart';
import '../../features/trips/widgets/tag_editor.dart';
import '../../features/trips/trip_kind.dart';

/// App route table. Paths are web-friendly so deep links work on the web build.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TripListScreen(),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'stats',
            builder: (context, state) => const TripStatsScreen(),
          ),
          GoRoute(
            path: 'routines',
            builder: (context, state) => const RoutineListScreen(),
          ),
          GoRoute(
            path: 'tags',
            builder: (context, state) => const TagSettingsScreen(),
          ),
          GoRoute(
            path: 'new',
            // ?kind=outing / ?kind=routine picks what is being created; absent
            // (or unrecognized) means the ordinary multi-day trip, so the plain
            // /new link keeps working.
            builder: (context, state) => TripFormScreen(
              kind: tripKindFromName(state.uri.queryParameters['kind']),
            ),
          ),
          GoRoute(
            path: 'trip/:id',
            builder: (context, state) => TripDetailScreen(
              tripId: int.parse(state.pathParameters['id']!),
              initialItemId: int.tryParse(
                state.uri.queryParameters['item'] ?? '',
              ),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => TripFormScreen(
                  tripId: int.parse(state.pathParameters['id']!),
                ),
              ),
              GoRoute(
                path: 'stats',
                builder: (context, state) => TripStatsScreen(
                  tripId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
