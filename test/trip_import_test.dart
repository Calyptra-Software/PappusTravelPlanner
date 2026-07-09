import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/sharing/presentation/trip_import.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Pumps a two-route app whose home has a button that imports [bytes]. The
  /// `/trip/:id` destination is a stub, so navigation is observable without the
  /// real trip screen's hanging database streams.
  Future<void> pumpImporter(WidgetTester tester, Uint8List bytes) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => importTripBytes(context, ref, bytes),
                child: const Text('import'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/trip/:id',
          builder: (context, state) =>
              Text('trip ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(TripRepository(db))],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }

  Uint8List validBundle() => TripBundle(
        schemaVersion: db.schemaVersion,
        trip: BundleTrip(
          title: 'Rome',
          destination: 'Italy',
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026),
        ),
      ).encode();

  testWidgets('imports a valid bundle and opens the new trip', (tester) async {
    await pumpImporter(tester, validBundle());

    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();

    // Navigated to the freshly-created trip (id 1 in an empty database).
    expect(find.text('trip 1'), findsOneWidget);
    // And the trip really landed in the database.
    final trips = await db.select(db.trips).get();
    expect(trips.single.title, 'Rome');
  });

  testWidgets('shows an error and stays put for an invalid file',
      (tester) async {
    await pumpImporter(tester, Uint8List.fromList([1, 2, 3, 4]));

    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();

    // Still on the home screen; an error SnackBar was shown; nothing imported.
    expect(find.text('import'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    final trips = await db.select(db.trips).get();
    expect(trips, isEmpty);
  });

  testWidgets('shows an error for a bundle from a newer app version',
      (tester) async {
    final bytes = TripBundle(
      formatVersion: TripBundle.currentFormatVersion + 1,
      schemaVersion: db.schemaVersion,
      trip: BundleTrip(
        title: 'X',
        destination: '',
        colorValue: 0,
        createdAt: DateTime(2026),
      ),
    ).encode();
    await pumpImporter(tester, bytes);

    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();

    expect(find.text('import'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    final trips = await db.select(db.trips).get();
    expect(trips, isEmpty);
  });
}
