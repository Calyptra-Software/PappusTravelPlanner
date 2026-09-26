import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/clock.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/attachments/application/attachment_providers.dart';
import 'package:travelplanner/features/attachments/application/cover_providers.dart';
import 'package:travelplanner/features/attachments/presentation/attachment_sheet.dart';
import 'package:travelplanner/features/attachments/presentation/gallery_screen.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/transport_mode.dart';
import 'package:travelplanner/features/map/map_features.dart';
import 'package:travelplanner/features/map/presentation/map_item_sheet.dart';
import 'package:travelplanner/features/map/widgets/device_location_overlay.dart'
    show kLocationZoom;
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/features/map/widgets/track_row.dart';
import 'package:travelplanner/features/map/presentation/trip_map_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'location_fixture.dart';

/// The trip map screen. Drift's `.watch()` streams never resolve under
/// `flutter_test`'s fake-async clock, so every provider it reads is overridden
/// with a plain stream — including `nowProvider`, whose real implementation
/// schedules a timer onto the next minute boundary and would outlive the test.
void main() {
  const tripId = 7;

  // The locate button reads the remembered switch when it is built, so the map
  // needs somewhere to read it from. Empty unless a test says otherwise, which
  // is what a fresh install looks like.
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // `PolylineLayer` is generic in its hit value, so `byType(PolylineLayer)` —
  // which means `PolylineLayer<dynamic>` — matches nothing now that the lines
  // carry one. The same finder the all-trips map's test uses.
  final polylineLayer = find.byWidgetPredicate((w) => w is PolylineLayer);

  /// The trip's accent. Deliberately not one of the theme's colors, so a test
  /// asserting on it cannot pass by coincidence.
  const accent = 0xFF112233;

  final trip = Trip(
    id: tripId,
    title: 'Frankfurt',
    destination: '',
    colorValue: accent,
    coverHidden: false,
    photosCollapsed: false,
    createdAt: DateTime(2026, 5, 1),
    kind: TripKind.trip,
  );

  ItineraryItem place({
    required int id,
    double? lat,
    double? lon,
    int? startMinutes,
    int? endMinutes,
  }) => ItineraryItem(
    id: id,
    tripId: tripId,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.place,
    title: 'Place $id',
    endDayOffset: 0,
    chordDisplay: TrackDisplay.auto,
    lat: lat,
    lon: lon,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );

  Future<void> pumpMap(
    WidgetTester tester, {
    required List<ItineraryItem> items,
    DateTime? now,
    EdgeInsets systemInsets = EdgeInsets.zero,
    Map<int, List<TrackLine>> tracks = const {},
    Map<int, List<Track>> trackRows = const {},
    List<Attachment> photos = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The map's tiles carry the app's version in their User-Agent, which
          // `main` resolves from the package metadata; a test has no bundle to
          // read it from.
          appVersionProvider.overrideWithValue('0.0.0-test'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          tripProvider(tripId).overrideWith((ref) => Stream.value(trip)),
          itineraryProvider(tripId).overrideWith((ref) => Stream.value(items)),
          alternativeBranchesProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          transportModesByIdProvider.overrideWith((ref) => const {}),
          nowProvider.overrideWith(
            (ref) => Stream.value(now ?? DateTime(2026, 5, 1, 3)),
          ),
          tripTracksProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(tracks)),
          // What the sheet a tapped line opens reads: the rows themselves,
          // which it summarizes. Overridden per entry, as the app asks for
          // them.
          for (final entry in trackRows.entries)
            itemTracksProvider(
              entry.key,
            ).overrideWith((ref) => Stream.value(entry.value)),
          tripPhotoMarkersProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(photos)),
          // What the gallery a tapped photograph opens reads: the star over it
          // and the picture itself.
          tripCoverIdProvider(tripId).overrideWith((ref) => null),
          attachmentBytesProvider.overrideWith((ref, id) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(padding: systemInsets),
            child: const TripMapScreen(tripId: tripId),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a trip with no positions says so instead of drawing a map', (
    tester,
  ) async {
    await pumpMap(tester, items: [place(id: 1)]);

    expect(find.text('Nothing to place yet'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a trip with positions draws them', (tester) async {
    await pumpMap(
      tester,
      items: [
        place(id: 1, lat: 50.1, lon: 8.6),
        place(id: 2, lat: 50.2, lon: 8.7),
      ],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Nothing to place yet'), findsNothing);
    // Attribution is a condition of use, so it is on screen without being asked
    // for.
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a leg is drawn in the trip\'s own accent, not the theme\'s', (
    tester,
  ) async {
    await pumpMap(
      tester,
      items: [
        ItineraryItem(
          id: 3,
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          sortOrder: 0,
          kind: ItemKind.transport,
          endDayOffset: 0,
          chordDisplay: TrackDisplay.auto,
          fromLat: 53.5511,
          fromLon: 9.9937,
          toLat: 50.1109,
          toLon: 8.6821,
        ),
      ],
    );

    final layer = tester.widget<PolylineLayer>(polylineLayer);
    final polyline = layer.polylines.single;
    expect(polyline.color, const Color(accent));
    // And a casing under it, so a user-chosen color stays legible over whatever
    // the tiles happen to show there.
    expect(polyline.borderStrokeWidth, greaterThan(0));

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  group('a line can be pointed at', () {
    ItineraryItem leg() => ItineraryItem(
      id: 3,
      tripId: tripId,
      date: DateTime(2026, 5, 1),
      sortOrder: 0,
      kind: ItemKind.transport,
      endDayOffset: 0,
      chordDisplay: TrackDisplay.auto,
      title: 'To the station',
      fromLat: 53.5511,
      fromLon: 9.9937,
      toLat: 53.5600,
      toLon: 10.0100,
    );

    Track row(
      int id, {
      required String name,
      TrackSource source = TrackSource.imported,
    }) => Track(
      id: id,
      itemId: 3,
      source: source,
      name: name,
      points: 'x',
      display: TrackDisplay.auto,
      sortOrder: id,
    );

    const first = [LatLng(53.5511, 9.9937), LatLng(53.5540, 9.9990)];
    const second = [LatLng(53.5570, 10.0050), LatLng(53.5600, 10.0100)];

    /// A line running the leg's whole length, so that the camera — framed on
    /// the first build, when the tracks had not arrived yet, and never re-fitted
    /// — is centred on it and a tap in the middle of the map lands on it.
    const whole = [LatLng(53.5511, 9.9937), LatLng(53.5600, 10.0100)];

    testWidgets('every stored line is drawn as itself and can be hit', (
      tester,
    ) async {
      await pumpMap(
        tester,
        items: [leg()],
        tracks: {
          3: [
            const TrackLine(
              id: 11,
              points: first,
              source: TrackSource.imported,
            ),
            const TrackLine(
              id: 12,
              points: second,
              source: TrackSource.imported,
            ),
          ],
        },
      );

      // A second frame: the tracks are watched for the first time *during* the
      // build the items arrive on, so their own value lands one pump later.
      await tester.pump();

      final layer = tester.widget<PolylineLayer>(polylineLayer);
      expect(layer.polylines, hasLength(2));
      // Each polyline names the row it was drawn from, so a tap can answer with
      // the line rather than with the leg.
      expect(layer.polylines.map((p) => (p.hitValue! as MapPath).trackId), [
        11,
        12,
      ]);
      // And the hitbox is a fingertip, not the 3.5px stroke.
      expect(
        layer.minimumHitbox,
        greaterThan(layer.polylines.first.strokeWidth),
      );

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('the sheet can put a line away, against the picture', (
      tester,
    ) async {
      // The second thing on that sheet that is about the drawing rather than
      // the plan, and it is there for the reason the color is: you notice you
      // are looking at the wrong line while looking at it.
      await pumpMap(
        tester,
        items: [leg()],
        tracks: {
          3: [
            const TrackLine(
              id: 11,
              points: whole,
              source: TrackSource.imported,
            ),
          ],
        },
        trackRows: {
          3: [
            row(11, name: 'Tunnel'),
            row(12, name: 'Route', source: TrackSource.routed),
          ],
        },
      );
      await tester.pump();

      await tester.tapAt(
        tester.getCenter(find.byType(FlutterMap)) + const Offset(44, -40),
      );
      await tester.pumpAndSettle();

      // The recording is drawn, the computed route beside it is not — and each
      // row carries the switch, where removing is deliberately absent.
      final rows = tester.widgetList<TrackRow>(find.byType(TrackRow)).toList();
      expect(rows.map((r) => r.track.drawn), [true, false]);
      expect(rows.every((r) => r.onSetDisplay != null), isTrue);
      expect(rows.every((r) => r.onRemove == null), isTrue);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a leg wears one mode badge, however many lines it has', (
      tester,
    ) async {
      // One badge per entry, not per line. Three icons on one leg would claim
      // three legs — and each of them takes the taps of the line under it,
      // which is what made the middle of a line the one place tapping it said
      // nothing about which line it was.
      await pumpMap(
        tester,
        items: [leg()],
        tracks: {
          3: [
            const TrackLine(
              id: 11,
              points: first,
              source: TrackSource.imported,
            ),
            const TrackLine(
              id: 12,
              points: second,
              source: TrackSource.imported,
            ),
          ],
        },
      );
      await tester.pump();

      // The modes are overridden away, so every leg wears the default icon and
      // counting it counts the badges.
      expect(find.byIcon(kDefaultTransportModeIcon), findsOneWidget);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a tap where two legs run together lists them both', (
      tester,
    ) async {
      // Overlap is normal on one trip's map as well: a walk out and back lies
      // exactly on itself. Answering with whichever line was drawn last would
      // be a coin toss the user cannot see — the rule the all-trips map already
      // follows for trips.
      await pumpMap(
        tester,
        items: [
          leg(),
          leg().copyWith(id: 4, title: const Value('And back again')),
        ],
        tracks: {
          3: [
            const TrackLine(
              id: 11,
              points: whole,
              source: TrackSource.imported,
            ),
          ],
          4: [
            const TrackLine(
              id: 12,
              points: whole,
              source: TrackSource.imported,
            ),
          ],
        },
      );
      await tester.pump();

      await tester.tapAt(
        tester.getCenter(find.byType(FlutterMap)) + const Offset(44, -40),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 entries here'), findsOneWidget);
      expect(find.text('To the station'), findsOneWidget);
      expect(find.text('And back again'), findsOneWidget);
      // Looking is not opening: the entry's own sheet comes after the choice.
      expect(find.byType(MapItemSheet), findsNothing);

      await tester.tap(find.text('And back again'));
      await tester.pumpAndSettle();
      expect(find.byType(MapItemSheet), findsOneWidget);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('tapping one opens its entry with that line marked', (
      tester,
    ) async {
      // One line, down the middle of the map — which is where the tap lands.
      await pumpMap(
        tester,
        items: [leg()],
        tracks: {
          3: [
            const TrackLine(
              id: 11,
              points: whole,
              source: TrackSource.imported,
            ),
          ],
        },
        trackRows: {
          3: [row(11, name: 'Morning walk'), row(12, name: 'The way back')],
        },
      );

      // The line is drawn a frame after the entries — see above — and the tap
      // has to land on it.
      await tester.pump();

      // Beside the middle, not on it: the mode badge sits half way along the
      // longest piece — which is the middle of the map here — and it is a
      // marker, so it wins the hit test over the line under it. The offset runs
      // along the line's own screen slope (its ends differ by 0.0163° of
      // longitude and 0.0089° of latitude, which at this latitude is about the
      // same distance), far enough out to clear the 28px badge.
      await tester.tapAt(
        tester.getCenter(find.byType(FlutterMap)) + const Offset(44, -40),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MapItemSheet), findsOneWidget);
      // Both of the entry\'s lines are listed — the comparison is the point —
      // and the one under the finger is the one marked.
      final rows = tester.widgetList<TrackRow>(find.byType(TrackRow)).toList();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.track.id), [11, 12]);
      expect(rows.map((r) => r.highlighted), [true, false]);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('tapping the straight line marks the straight line', (
      tester,
    ) async {
      // No stored line: what is under the finger is the segment between the
      // ends, and its row is where it can be put away.
      await pumpMap(tester, items: [leg()]);
      await tester.pump();

      await tester.tapAt(
        tester.getCenter(find.byType(FlutterMap)) + const Offset(44, -40),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MapItemSheet), findsOneWidget);
      final chord = tester.widget<ChordRow>(find.byType(ChordRow));
      expect(chord.highlighted, isTrue);
      expect(chord.chord.drawn, isTrue);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });
  });

  testWidgets('a leg whose straight line is put away draws no line', (
    tester,
  ) async {
    await pumpMap(
      tester,
      items: [
        ItineraryItem(
          id: 3,
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          sortOrder: 0,
          kind: ItemKind.transport,
          endDayOffset: 0,
          chordDisplay: TrackDisplay.hidden,
          fromLat: 53.5511,
          fromLon: 9.9937,
          toLat: 50.1109,
          toLon: 8.6821,
        ),
        // Something else on the map, so it is a map and not the empty state.
        ItineraryItem(
          id: 4,
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          sortOrder: 1,
          kind: ItemKind.place,
          endDayOffset: 0,
          chordDisplay: TrackDisplay.auto,
          title: 'Office',
          lat: 50.1109,
          lon: 8.6821,
        ),
      ],
    );

    expect(tester.widget<PolylineLayer>(polylineLayer).polylines, isEmpty);

    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets("an entry's own color outranks the trip's accent", (
    tester,
  ) async {
    const own = 0xFF1B5E20;
    await pumpMap(
      tester,
      items: [
        ItineraryItem(
          id: 3,
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          sortOrder: 0,
          kind: ItemKind.transport,
          endDayOffset: 0,
          chordDisplay: TrackDisplay.auto,
          fromLat: 53.5511,
          fromLon: 9.9937,
          toLat: 50.1109,
          toLon: 8.6821,
          colorValue: own,
        ),
        place(
          id: 4,
          lat: 50.1,
          lon: 8.6,
        ).copyWith(colorValue: const Value(own)),
      ],
    );

    final layer = tester.widget<PolylineLayer>(polylineLayer);
    expect(layer.polylines.single.color, const Color(own));
    // The pin follows: a color is a statement about the entry, not about which
    // kind of mark it happens to be drawn as.
    expect(
      tester.widget<MapPlacePin>(find.byType(MapPlacePin)).color,
      const Color(own),
    );

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('the entry under way stays red, whatever color it carries', (
    tester,
  ) async {
    // Red is the app's one reserved color — the timeline, the widget and the map
    // all say "you are here" with it — so a chosen color must not hide it.
    await pumpMap(
      tester,
      items: [
        place(
          id: 1,
          lat: 50.1,
          lon: 8.6,
          startMinutes: 9 * 60,
          endMinutes: 11 * 60,
        ).copyWith(colorValue: const Value(0xFF1B5E20)),
      ],
      now: DateTime(2026, 5, 1, 10),
    );

    final pin = tester.widget<MapPlacePin>(find.byType(MapPlacePin));
    expect(pin.color, isNot(const Color(0xFF1B5E20)));

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('the attribution clears the system navigation bar', (
    tester,
  ) async {
    // A phone with three-button navigation: the map draws edge to edge, so the
    // bottom strip would otherwise sit underneath the bar and be unreadable.
    const navBar = 48.0;
    await pumpMap(
      tester,
      items: [
        place(id: 1, lat: 50.1, lon: 8.6),
        place(id: 2, lat: 50.2, lon: 8.7),
      ],
      systemInsets: const EdgeInsets.only(bottom: navBar),
    );

    final attribution = find.textContaining('OpenStreetMap');
    final bottom = tester.getBottomLeft(attribution).dy;
    final screenBottom = tester.getSize(find.byType(MaterialApp)).height;
    expect(bottom, lessThanOrEqualTo(screenBottom - navBar));

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('tapping a place marker says what it stands for', (tester) async {
    await pumpMap(
      tester,
      items: [
        place(
          id: 1,
          lat: 50.1109,
          lon: 8.6821,
          startMinutes: 600,
          endMinutes: 660,
        ),
        place(id: 2, lat: 50.2, lon: 8.7),
      ],
    );

    await tester.tap(find.byType(MapPlacePin).first);
    await tester.pumpAndSettle();

    // The name the map cannot draw, the times it has no axis for, and the
    // numbers behind the pin.
    expect(find.text('Place 1'), findsOneWidget);
    expect(find.textContaining('50.11090'), findsOneWidget);
    expect(find.text('Edit place'), findsOneWidget);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  testWidgets('a lone photograph opens the gallery, not its sheet', (
    tester,
  ) async {
    // Whether a mark holds one picture or several depends on the zoom, so the
    // answer to a tap must not: one picture opens full screen too, and its
    // sheet is behind the gallery's ⋮.
    await pumpMap(
      tester,
      items: [place(id: 1, lat: 50.1109, lon: 8.6821)],
      photos: [
        Attachment(
          id: 11,
          itemId: 1,
          kind: AttachmentKind.photo,
          mimeType: 'image/jpeg',
          name: 'Römer.jpg',
          byteSize: 1024,
          lat: 50.1107,
          lon: 8.6822,
          sortOrder: 0,
          createdAt: DateTime(2026, 5, 1),
        ),
      ],
    );

    // The markers' stream answers a frame after the entries'.
    await tester.pump();
    await tester.tap(find.byType(MapPhotoMarker));
    await tester.pumpAndSettle();

    expect(find.byType(GalleryScreen), findsOneWidget);
    expect(find.byType(AttachmentSheet), findsNothing);

    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  group('places that would hide each other', () {
    testWidgets('are gathered under one mark that says how many', (
      tester,
    ) async {
      // A hotel returned to every evening, a station passed through twice: a pin
      // under another cannot be tapped at all, since a marker wins the hit test
      // against everything beneath it.
      await pumpMap(
        tester,
        items: [
          place(id: 1, lat: 50.1109, lon: 8.6821),
          place(id: 2, lat: 50.1109, lon: 8.6821),
          place(id: 3, lat: 50.0, lon: 8.6821),
        ],
      );

      // A frame more than the others need: the marks are gathered against the
      // camera, and the camera fits itself to the trip during the first frame's
      // layout — so the first frame's marks were measured through the map's
      // opening view rather than the one it settles on.
      await tester.pump();

      final pins = tester
          .widgetList<MapPlacePin>(find.byType(MapPlacePin))
          .toList();
      expect(pins, hasLength(2), reason: 'the far one keeps its own mark');
      expect(pins.map((p) => p.count).toList()..sort(), [1, 2]);
      // Every entry here is the trip's own, and nothing was given a color of
      // its own, so the mark still says which trip it belongs to.
      expect(pins.first.color, const Color(accent));

      // Tile loading is throttled, so a timer outlives the last pump. It runs on
      // once after firing (the trailing call), hence twice — otherwise the tree
      // is disposed with a timer still pending.
      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a gathered mark names what it holds, and opens one', (
      tester,
    ) async {
      await pumpMap(
        tester,
        items: [
          place(id: 1, lat: 50.1109, lon: 8.6821),
          place(id: 2, lat: 50.1109, lon: 8.6821),
        ],
      );

      await tester.tap(find.byType(MapPlacePin));
      await tester.pumpAndSettle();

      // The rule the lines already follow: several under the finger name
      // themselves and let the tap be finished deliberately.
      expect(find.text('2 entries here'), findsOneWidget);
      expect(find.text('Place 1'), findsOneWidget);
      expect(find.text('Place 2'), findsOneWidget);

      await tester.tap(find.text('Place 2'));
      await tester.pumpAndSettle();
      expect(find.byType(MapItemSheet), findsOneWidget);
      expect(find.text('Edit place'), findsOneWidget);

      // Tile loading is throttled, so a timer outlives the last pump. It runs on
      // once after firing (the trailing call), hence twice — otherwise the tree
      // is disposed with a timer still pending.
      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a mark of entries with different colors wears neither', (
      tester,
    ) async {
      // A color here is a statement about the entry under it, so a mark holding
      // two of them may not pick one — it would be saying something false about
      // the other.
      await pumpMap(
        tester,
        items: [
          place(
            id: 1,
            lat: 50.1109,
            lon: 8.6821,
          ).copyWith(colorValue: const Value(0xFF1B5E20)),
          place(
            id: 2,
            lat: 50.1109,
            lon: 8.6821,
          ).copyWith(colorValue: const Value(0xFFEF6C00)),
        ],
      );

      expect(
        tester.widget<MapPlacePin>(find.byType(MapPlacePin)).color,
        kMixedPinColor,
      );

      // Tile loading is throttled, so a timer outlives the last pump. It runs on
      // once after firing (the trailing call), hence twice — otherwise the tree
      // is disposed with a timer still pending.
      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a mark keeps a color both entries were given', (tester) async {
      const own = 0xFF1B5E20;
      await pumpMap(
        tester,
        items: [
          place(
            id: 1,
            lat: 50.1109,
            lon: 8.6821,
          ).copyWith(colorValue: const Value(own)),
          place(
            id: 2,
            lat: 50.1109,
            lon: 8.6821,
          ).copyWith(colorValue: const Value(own)),
        ],
      );

      expect(
        tester.widget<MapPlacePin>(find.byType(MapPlacePin)).color,
        const Color(own),
      );

      // Tile loading is throttled, so a timer outlives the last pump. It runs on
      // once after firing (the trailing call), hence twice — otherwise the tree
      // is disposed with a timer still pending.
      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('the entry under way still turns the mark red', (tester) async {
      // Red is reserved, and gathering is a decision about drawing: it must not
      // be the thing that hides where you are.
      await pumpMap(
        tester,
        items: [
          place(
            id: 1,
            lat: 50.1109,
            lon: 8.6821,
            startMinutes: 9 * 60,
            endMinutes: 11 * 60,
          ),
          place(id: 2, lat: 50.1109, lon: 8.6821),
        ],
        now: DateTime(2026, 5, 1, 10),
      );

      final pin = tester.widget<MapPlacePin>(find.byType(MapPlacePin));
      expect(pin.count, 2);
      expect(pin.color, isNot(const Color(accent)));
      expect(pin.color, isNot(kMixedPinColor));

      // Tile loading is throttled, so a timer outlives the last pump. It runs on
      // once after firing (the trailing call), hence twice — otherwise the tree
      // is disposed with a timer still pending.
      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });
  });

  testWidgets('tapping a leg badge names the leg, not a place', (tester) async {
    await pumpMap(
      tester,
      items: [
        ItineraryItem(
          id: 3,
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          sortOrder: 0,
          kind: ItemKind.transport,
          title: 'ICE 507',
          fromLocation: 'Hamburg Hbf',
          toLocation: 'Frankfurt(Main) Hbf',
          endDayOffset: 0,
          chordDisplay: TrackDisplay.auto,
          fromLat: 53.5511,
          fromLon: 9.9937,
          toLat: 50.1109,
          toLon: 8.6821,
        ),
      ],
    );

    // The camera is fitted to the whole leg on the first layout pass; before
    // that the view sits on its first point and the badge — which hangs at the
    // leg's midpoint — is culled as off-screen.
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(kDefaultTransportModeIcon).first);
    await tester.pumpAndSettle();

    expect(find.text('ICE 507'), findsOneWidget);
    expect(find.text('Hamburg Hbf → Frankfurt(Main) Hbf'), findsOneWidget);
    // Both ends, labeled — two numbers under each other must not be mistakable.
    expect(find.textContaining('53.55110'), findsOneWidget);
    expect(find.textContaining('50.11090'), findsOneWidget);
    expect(find.text('Edit transport'), findsOneWidget);

    // Tile loading is throttled, so a timer outlives the last pump. It runs on
    // once after firing (the trailing call), hence twice — otherwise the tree is
    // disposed with a timer still pending.
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  });

  group('where the device is', () {
    late FakeGeolocator platform;

    /// The button's tooltip while the mark is on, which is also where the long
    /// press that switches it off is advertised.
    const centerTooltip = 'Center on my position (long press to hide)';

    setUp(() {
      platform = FakeGeolocator()..permission = LocationPermission.whileInUse;
      GeolocatorPlatform.instance = platform;
    });

    /// The mark: the reading as a dot, and the error around it as a circle.
    final locationCircle = find.byWidgetPredicate((w) => w is CircleLayer);

    testWidgets('nothing is asked for until the button is pressed', (
      tester,
    ) async {
      await pumpMap(tester, items: [place(id: 1, lat: 53.55, lon: 9.99)]);
      await tester.pumpAndSettle();

      // A map that switched a receiver on because it was opened would be asking
      // for a permission the user never requested.
      expect(find.byTooltip('Show my position'), findsOneWidget);
      expect(locationCircle, findsNothing);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a reading draws the mark and its error', (tester) async {
      await pumpMap(tester, items: [place(id: 1, lat: 53.55, lon: 9.99)]);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show my position'));
      await tester.pump();
      platform.emit(latitude: 53.56, longitude: 9.98, accuracy: 40);
      await tester.pumpAndSettle();

      expect(locationCircle, findsOneWidget);
      final circle = tester.widget<CircleLayer>(locationCircle);
      // The radius is the platform's own figure, in meters — drawn to scale, so
      // an uncertain fix looks uncertain.
      expect(circle.circles.single.radius, 40);
      expect(circle.circles.single.useRadiusInMeter, isTrue);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('switching it off again takes the mark with it', (
      tester,
    ) async {
      await pumpMap(tester, items: [place(id: 1, lat: 53.55, lon: 9.99)]);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show my position'));
      await tester.pump();
      platform.emit(latitude: 53.56, longitude: 9.98, accuracy: 40);
      await tester.pumpAndSettle();

      // The long press, since the tap now centers the map on the mark — and
      // this is the act that also says "not on the next map either".
      await tester.longPress(find.byTooltip(centerTooltip));
      await tester.pumpAndSettle();

      expect(locationCircle, findsNothing);
      expect(platform.streamCancelled, isTrue);
      expect(prefs.getBool('map_show_my_location'), isFalse);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a map opened later puts the mark back on its own', (
      tester,
    ) async {
      // What the last press left behind. The complaint this answers is a map
      // that had to be told again on every screen.
      await prefs.setBool('map_show_my_location', true);

      await pumpMap(tester, items: [place(id: 1, lat: 53.55, lon: 9.99)]);
      // Pumped rather than settled throughout: the button spins while it waits
      // for the first reading, and an indefinite spinner never settles.
      await tester.pump();
      platform.emit(latitude: 53.56, longitude: 9.98, accuracy: 40);
      await tester.pump();

      expect(locationCircle, findsOneWidget);
      expect(find.byTooltip(centerTooltip), findsOneWidget);
      // Nothing was asked of the user: the grant was already there.
      expect(platform.permissionRequests, 0);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a press while it is on centers the map again', (tester) async {
      await prefs.setBool('map_show_my_location', true);
      await pumpMap(tester, items: [place(id: 1, lat: 53.55, lon: 9.99)]);
      await tester.pump();
      // A long way from the trip, so the two cameras cannot be confused.
      platform.emit(latitude: 40.0, longitude: 10.0, accuracy: 40);
      await tester.pump();

      // The resume drew the mark and left the camera on the trip, which is the
      // half a plain toggle could not have given back in one press.
      expect(
        MapCamera.of(tester.element(locationCircle)).center.latitude,
        closeTo(53.55, 0.01),
      );

      await tester.tap(find.byTooltip(centerTooltip));
      await tester.pump();

      final camera = MapCamera.of(tester.element(locationCircle));
      expect(camera.center.latitude, closeTo(40.0, 0.01));
      expect(camera.zoom, greaterThanOrEqualTo(kLocationZoom));
      // Still on: a press asks to be found, it does not switch anything off.
      expect(find.byTooltip(centerTooltip), findsOneWidget);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a map opened later never brings up the dialog', (
      tester,
    ) async {
      platform.permission = LocationPermission.denied;
      await prefs.setBool('map_show_my_location', true);

      await pumpMap(tester, items: [place(id: 1, lat: 53.55, lon: 9.99)]);
      await tester.pumpAndSettle();

      // The one thing a screen may not do by being opened — and it says nothing
      // about it either, since nobody asked it anything.
      expect(platform.permissionRequests, 0);
      expect(find.text('Location access was declined'), findsNothing);
      expect(find.byTooltip('Show my position'), findsOneWidget);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });

    testWidgets('a refusal is said out loud, once', (tester) async {
      platform.permission = LocationPermission.denied;
      await pumpMap(tester, items: [place(id: 1, lat: 53.55, lon: 9.99)]);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show my position'));
      await tester.pumpAndSettle();

      expect(find.text('Location access was declined'), findsOneWidget);
      expect(locationCircle, findsNothing);

      await tester.pump(kTileUpdateThrottle);
      await tester.pump(kTileUpdateThrottle);
    });
  });
}
