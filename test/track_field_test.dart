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
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/map/widgets/track_field.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// What the item form says about the line an entry followed.
///
/// The reading is the point: a track cannot be typed, only imported, so this
/// field's whole job is to say what is there and offer the two acts. Drift's
/// `.watch()` never resolves under fake-async, so the stream is stubbed.
void main() {
  const itemId = 7;

  Track track(int id, {String? name}) => Track(
    id: id,
    itemId: itemId,
    source: TrackSource.imported,
    name: name,
    points: '_p~iF~ps|U',
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
    // Nothing to remove.
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('one named line reads as its name alone', (tester) async {
    // The count would say nothing a name does not.
    await pump(tester, [track(1, name: 'To the station')]);

    expect(find.text('To the station'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('a recording that stopped and resumed says how many', (
    tester,
  ) async {
    // Several rows under one name: the name once, the count for the rest.
    await pump(tester, [
      track(1, name: 'Morning walk'),
      track(2, name: 'Morning walk'),
    ]);

    expect(find.textContaining('Morning walk'), findsOneWidget);
    expect(find.textContaining('2 lines'), findsOneWidget);
  });

  testWidgets('a nameless line is counted rather than given a made-up name', (
    tester,
  ) async {
    await pump(tester, [track(1)]);

    expect(find.text('1 line'), findsOneWidget);
  });

  testWidgets('removing takes every line off the entry', (tester) async {
    // "Remove the track" means the whole import, since one recording can arrive
    // as several segments.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final trip = await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(title: 'T', destination: const Value('')),
        );
    final leg = await db
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          itemTracksProvider(leg).overrideWith(
            (ref) => Stream.value([track(1, name: 'A'), track(2, name: 'B')]),
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
            body: TrackField(itemId: leg, tripId: trip),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Remove'));
    await tester.pump();

    expect(await db.select(db.tracks).get(), isEmpty);
  });
}
