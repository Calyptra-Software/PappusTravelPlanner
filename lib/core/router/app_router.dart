import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/presentation/settings_screen.dart';
import '../../features/trips/presentation/trip_detail_screen.dart';
import '../../features/trips/presentation/trip_form_screen.dart';
import '../../features/trips/presentation/trip_list_screen.dart';

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
            path: 'new',
            builder: (context, state) => const TripFormScreen(),
          ),
          GoRoute(
            path: 'trip/:id',
            builder: (context, state) => TripDetailScreen(
              tripId: int.parse(state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => TripFormScreen(
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
