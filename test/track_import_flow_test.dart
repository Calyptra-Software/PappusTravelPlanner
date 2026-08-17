import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/track_import_flow.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Importing a recording, from picking the file to the answer the user gets.
///
/// The file is handed in rather than chosen, so the refusals — the two a user
/// actually meets — can be checked at all.
void main() {
  late AppDatabase db;
  late int tripId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tripId = await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(title: 'T', destination: const Value('')),
        );
    await db
        .into(db.itineraryItems)
        .insert(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.transport,
            title: const Value('A → B'),
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> run(WidgetTester tester, Future<String?> Function() read) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appVersionProvider.overrideWithValue('0.0.0-test'),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => startTrackImport(
                  context,
                  ref,
                  tripId: tripId,
                  readFile: read,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('choosing no file does nothing at all', (tester) async {
    await run(tester, () async => null);

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Which entries does it cover?'), findsNothing);
  });

  testWidgets('a file that is not GPX is refused, in words', (tester) async {
    await run(tester, () async => 'not xml at all <<<');

    expect(find.text('That file is not readable GPX'), findsOneWidget);
  });

  testWidgets('GPX with no line in it says so, rather than nothing', (
    tester,
  ) async {
    // Well-formed, and holding only a waypoint — which is a place, not a line.
    await run(
      tester,
      () async => '<gpx version="1.1"><wpt lat="1" lon="2"/></gpx>',
    );

    expect(find.text('No line in that file'), findsOneWidget);
  });

  testWidgets('a readable file asks which entries it covers', (tester) async {
    await run(
      tester,
      () async => '''
<gpx version="1.1"><trk><name>Walk</name><trkseg>
  <trkpt lat="53.50" lon="9.9"/><trkpt lat="53.51" lon="9.9"/>
</trkseg></trk></gpx>
''',
    );

    expect(find.text('Which entries does it cover?'), findsOneWidget);
    expect(find.text('A → B'), findsOneWidget);
  });
}
