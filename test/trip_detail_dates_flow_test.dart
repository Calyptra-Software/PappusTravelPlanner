import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/clock.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/checklist/application/checklist_providers.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/trips/application/trip_connections_controller.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/planned_journey.dart';
import 'package:travelplanner/features/trips/presentation/trip_detail_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// The trip screen's part in putting a trip onto new dates: duplicating it
/// from the menu, and looking the journeys up once the form has moved them.
///
/// The form and the copy's own screen are stand-ins here; what is under test
/// is what the trip screen does with their answers.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late int tripId;
  late List<int> askedFor;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    askedFor = [];
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Lisbon',
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 3)),
      ),
    );
  });
  tearDown(() => db.close());

  /// Pumps the trip screen under a router. [formAnswer] is what the stand-in
  /// form closes with, the way the real one reports a move to be looked up.
  Future<void> pumpDetail(WidgetTester tester, {bool? formAnswer}) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    final trip = (await db.tripDao.findTrip(tripId))!;
    final router = GoRouter(
      initialLocation: '/trip/$tripId',
      routes: [
        GoRoute(
          path: '/trip/:id',
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id']!);
            // Only the original is a real screen; a copy just says it opened.
            return id == tripId
                ? TripDetailScreen(tripId: id)
                : Scaffold(body: Text('opened $id'));
          },
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(formAnswer),
                  child: const Text('save form'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...currencyOverrides,
          repositoryProvider.overrideWithValue(repo),
          ...attachmentTestOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
          tripProvider(tripId).overrideWith((ref) => Stream.value(trip)),
          itineraryProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          alternativeSetsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          alternativeBranchesProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          collapsedDaysProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          groupsProvider(tripId).overrideWith((ref) => Stream.value(const {})),
          costsForTripProvider(tripId).overrideWith(
            (ref) => Stream.value((
              byItem: const <int, List<Cost>>{},
              byGroup: const <int, List<Cost>>{},
              tripLevel: const <Cost>[],
            )),
          ),
          countedCostsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          tripParticipantsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          checklistsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
          mePersonProvider.overrideWith((ref) => Stream.value(null)),
          transportModesProvider.overrideWith((ref) => Stream.value(const [])),
          nowProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 4, 1, 9)),
          ),
          tripConnectionsControllerProvider.overrideWith(
            (ref) => _Recording(ref, askedFor),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> editAndSave(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save form'));
    await tester.pumpAndSettle();
  }

  testWidgets('a form that moved the entries has them looked up here', (
    tester,
  ) async {
    await pumpDetail(tester, formAnswer: true);
    await editAndSave(tester);
    expect(askedFor, [tripId]);
  });

  testWidgets('a form that did not, has nothing looked up', (tester) async {
    await pumpDetail(tester, formAnswer: false);
    await editAndSave(tester);
    expect(askedFor, isEmpty);
  });

  testWidgets('a form left without saving has nothing looked up', (
    tester,
  ) async {
    await pumpDetail(tester);
    await editAndSave(tester);
    expect(askedFor, isEmpty);
  });

  testWidgets('the menu duplicates the trip and opens the copy', (
    tester,
  ) async {
    await pumpDetail(tester);
    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate trip…'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    final trips = await db.select(db.trips).get();
    expect(trips, hasLength(2));
    final copy = trips.singleWhere((t) => t.id != tripId);
    expect(copy.title, 'Lisbon');
    expect(find.text('opened ${copy.id}'), findsOneWidget);
    expect(askedFor, isEmpty, reason: 'the lookup was switched off');
  });
}

/// Records which trip the lookup was asked about, and offers nothing.
class _Recording extends TripConnectionsController {
  _Recording(super.ref, this.askedFor);

  final List<int> askedFor;

  @override
  Future<List<PlannedJourney>> lookUpCandidates(int tripId) async {
    askedFor.add(tripId);
    return const [];
  }
}
