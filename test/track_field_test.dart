import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/map/widgets/track_field.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// What the item form says about the lines an entry followed.
///
/// One row per stored line, because an entry carries several routinely — a
/// recording that stopped and started again, a second import, a route the
/// search computed — and each of them is a thing the user may want to keep or
/// throw away on its own. Drift's `.watch()` never resolves under fake-async, so
/// the stream is stubbed.
void main() {
  const itemId = 7;

  /// A line running [north] degrees north — a hundredth is about 1.1 km, which
  /// is what gives two rows under one name different lengths.
  Track track(
    int id, {
    String? name,
    double north = 0.01,
    TrackSource source = TrackSource.imported,
    TrackDisplay display = TrackDisplay.auto,
  }) => Track(
    id: id,
    itemId: itemId,
    source: source,
    name: name,
    points: encodeTrackPoints([
      const LatLng(53.55, 9.99),
      LatLng(53.55 + north, 9.99),
    ]),
    display: display,
    sortOrder: id,
  );

  Future<void> pump(WidgetTester tester, List<Track> tracks) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemTracksProvider(
            itemId,
          ).overrideWith((ref) => Stream.value(tracks)),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TrackField(itemId: itemId, tripId: 1)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('with no line it says so, and what the map draws instead', (
    tester,
  ) async {
    await pump(tester, const []);

    expect(
      find.text('None — the map draws the straight line between the ends.'),
      findsOneWidget,
    );
    expect(find.text('Import GPX…'), findsOneWidget);
    // Nothing to remove, either one at a time or all at once.
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Remove all'), findsNothing);
  });

  testWidgets('a line reads as its name, where it came from and how far', (
    tester,
  ) async {
    await pump(tester, [track(1, name: 'To the station')]);

    expect(find.text('To the station · Imported · 1.1 km'), findsOneWidget);
    // Its own remove button, and no "all" — with one line that would be the
    // same act under a second name.
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Remove all'), findsNothing);
  });

  testWidgets('a recording that stopped and resumed reads as two lines', (
    tester,
  ) async {
    // The name is the same on both rows, so the length is what tells them
    // apart — which is the whole reason it is printed.
    await pump(tester, [
      track(1, name: 'Morning walk'),
      track(2, name: 'Morning walk', north: 0.03),
    ]);

    expect(find.text('Morning walk · Imported · 1.1 km'), findsOneWidget);
    expect(find.text('Morning walk · Imported · 3.3 km'), findsOneWidget);
    expect(find.text('2 lines'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    expect(find.text('Remove all'), findsOneWidget);
  });

  testWidgets('a nameless line is not given a made-up name', (tester) async {
    await pump(tester, [track(1)]);

    expect(find.text('Imported · 1.1 km'), findsOneWidget);
  });

  testWidgets('a computed route says that it is one', (tester) async {
    // The map draws it dashed; here it reads differently for the same reason.
    await pump(tester, [track(1, source: TrackSource.routed)]);

    expect(find.text('Computed route · 1.1 km'), findsOneWidget);
    expect(find.byIcon(Icons.alt_route), findsOneWidget);
  });

  testWidgets('a line the map cannot draw is listed, so it can be removed', (
    tester,
  ) async {
    await pump(tester, [
      Track(
        id: 1,
        itemId: itemId,
        source: TrackSource.imported,
        name: null,
        points: 'not a polyline at all ~~~',
        display: TrackDisplay.auto,
        sortOrder: 1,
      ),
    ]);

    expect(find.text('Imported · Nothing to draw'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  group('whether the map draws a line', () {
    testWidgets('each row says whether its line is on the map', (tester) async {
      // The default: the recording is drawn, the route the router proposed is
      // not — and the list says which, from the same rule the map reads.
      await pump(tester, [
        track(1, source: TrackSource.routed),
        track(2, name: 'Morning walk'),
      ]);

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('a hidden line is still listed, and says it is off', (
      tester,
    ) async {
      // Hiding is not deleting: the row is there to be read and switched back
      // on, which is the whole difference.
      await pump(tester, [
        track(1, name: 'Tunnel', display: TrackDisplay.hidden),
      ]);

      expect(find.text('Tunnel · Imported · 1.1 km'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });

  group('against a real database', () {
    late AppDatabase db;
    late int trip;
    late int leg;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      trip = await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(title: 'T', destination: const Value('')),
          );
      leg = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: trip,
              date: DateTime(2026, 5, 1),
              kind: ItemKind.transport,
            ),
          );
      await db.trackDao.addTracks(leg, [
        (points: const [LatLng(53.1, 9.1), LatLng(53.2, 9.2)], name: 'A'),
        (points: const [LatLng(53.3, 9.3), LatLng(53.4, 9.4)], name: 'B'),
      ]);
    });

    tearDown(() => db.close());

    Future<void> pumpAgainstDb(WidgetTester tester) async {
      // A plain select, not `watchTracksForItem`: a drift `.watch()` never
      // resolves under fake-async, and what this needs is the rows as they are.
      final rows = await (db.select(
        db.tracks,
      )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            itemTracksProvider(leg).overrideWith((ref) => Stream.value(rows)),
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
              body: TrackField(itemId: leg, tripId: trip),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a row removes its own line and leaves the others', (
      tester,
    ) async {
      await pumpAgainstDb(tester);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      final left = await db.select(db.tracks).get();
      expect(left.map((t) => t.name), ['B']);
    });

    testWidgets('putting a line away leaves it in the database', (
      tester,
    ) async {
      // The case the switch exists for: the trace is wrong in the tunnel, so
      // it is put away and the computed route beside it comes forward —
      // without the recording being deleted to get at it.
      await pumpAgainstDb(tester);

      await tester.tap(find.byIcon(Icons.visibility).first);
      await tester.pump();

      final stored = await db.select(db.tracks).get();
      expect(stored, hasLength(2));
      expect(stored.first.display, TrackDisplay.hidden);
      expect(stored.first.name, 'A');
    });

    testWidgets('removing all takes every line off the entry', (tester) async {
      await pumpAgainstDb(tester);

      await tester.tap(find.text('Remove all'));
      await tester.pump();

      expect(await db.select(db.tracks).get(), isEmpty);
    });
  });
}
