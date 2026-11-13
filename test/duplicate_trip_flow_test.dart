import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/format/civil_date.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/trips/application/trip_connections_controller.dart';
import 'package:travelplanner/features/trips/planned_journey.dart';
import 'package:travelplanner/features/trips/presentation/duplicate_trip.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The sheet in front of a duplicate, and what it hands on: the title as
/// typed, and the lookup asked of the *copy* rather than the original.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late List<int> askedFor;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    askedFor = [];
    final id = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Lisbon',
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 3)),
      ),
    );
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: id,
        date: DateTime(2026, 5, 2),
        kind: ItemKind.place,
        title: const Value('Sintra'),
      ),
    );
  });
  tearDown(() => db.close());

  Future<Future<int?> Function()> start(WidgetTester tester) async {
    int? result;
    var done = false;
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          tripConnectionsControllerProvider.overrideWith(
            (ref) => _RecordingController(ref, askedFor),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () async {
                  final trip = (await repo.findTrip(1))!;
                  if (!context.mounted) return;
                  result = await duplicateTrip(context, ref, trip);
                  done = true;
                },
                child: const Text('duplicate'),
              ),
            ),
          ),
        ),
      ),
    );
    return () async {
      expect(done, isTrue, reason: 'the flow ran to its end');
      return result;
    };
  }

  testWidgets('writes the copy under the title typed, then looks it up', (
    tester,
  ) async {
    final result = await start(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('duplicate'));
    await tester.pumpAndSettle();

    // The title starts as the original's and can be changed.
    expect(find.widgetWithText(TextField, 'Lisbon'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Lisbon in autumn');
    final today = normalizeDay(DateTime.now());
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    final newId = await result();
    expect(newId, isNotNull);
    expect(newId, isNot(1));
    final copy = await repo.findTrip(newId!);
    expect(copy!.title, 'Lisbon in autumn');
    expect(copy.startDate, today);
    expect(copy.endDate, addDays(today, 2));
    expect(askedFor, [
      newId,
    ], reason: 'the copy is what needs connections on its new dates');
  });

  testWidgets('starts on the day picked, and the sheet shows the range', (
    tester,
  ) async {
    final result = await start(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('duplicate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start date'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      '03/05/2027',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // Three days long, so the sheet names the range the copy will take.
    expect(find.textContaining('2027'), findsOneWidget);

    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    final copy = await repo.findTrip((await result())!);
    expect(copy!.startDate, DateTime(2027, 3, 5));
    expect(copy.endDate, DateTime(2027, 3, 7));
  });

  testWidgets('no lookup when it is switched off', (tester) async {
    final result = await start(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('duplicate'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(await result(), isNotNull);
    expect(askedFor, isEmpty);
  });

  testWidgets('an empty title cannot be confirmed', (tester) async {
    await start(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('duplicate'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Duplicate'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}

/// Records which trip the lookup was asked about, and finds nothing to offer,
/// so no network and no offer sheet is involved.
class _RecordingController extends TripConnectionsController {
  _RecordingController(super.ref, this.askedFor);

  final List<int> askedFor;

  @override
  Future<List<PlannedJourney>> lookUpCandidates(int tripId) async {
    askedFor.add(tripId);
    return const [];
  }
}
