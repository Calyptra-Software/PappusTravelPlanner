import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/attachments/application/attachment_providers.dart';
import 'package:travelplanner/features/attachments/application/cover_providers.dart';
import 'package:travelplanner/features/attachments/presentation/gallery_screen.dart';
import 'package:travelplanner/features/attachments/trip_gallery.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The way from an entry in the plan straight to its photographs.
///
/// The alternative today is opening the entry's form and finding the file in a
/// list — two levels down from a thing already on screen.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;

  final day = DateTime(2026, 5, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Rome',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
  });
  tearDown(() => db.close());

  Future<ItineraryItem> addPlace(String title, {int sortOrder = 0}) async {
    final id = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
        title: Value(title),
        sortOrder: Value(sortOrder),
      ),
    );
    return (await db.itineraryDao.itemsFor(
      tripId,
    )).firstWhere((i) => i.id == id);
  }

  Attachment file(
    int id, {
    required String name,
    int? itemId,
    AttachmentKind kind = AttachmentKind.photo,
  }) => Attachment(
    id: id,
    itemId: itemId,
    kind: kind,
    mimeType: kind == AttachmentKind.photo ? 'image/jpeg' : 'application/pdf',
    name: name,
    byteSize: 512,
    sortOrder: 0,
    createdAt: day,
  );

  /// The tile, with the trip's gallery and counts stubbed — both are drift
  /// streams, and what is under test is what the tile does with their answers.
  Future<void> pumpTile(
    WidgetTester tester,
    ItineraryItem item, {
    required List<GalleryPhoto> gallery,
    required int count,
  }) async {
    final trip = (await db.tripDao.findTrip(tripId))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          tripGalleryProvider.overrideWith((ref, id) => gallery),
          // The gallery's cover star reads the trip row. A snapshot, not
          // `watchTrip`: a live drift stream here is the teardown timer again.
          tripProvider.overrideWith((ref, id) => Stream.value(trip)),
          // A transport tile resolves its mode through this one — another
          // drift stream, and the teardown timer if it is left live.
          transportModesProvider.overrideWith(
            (ref) => Stream.value(const <TransportModeRow>[]),
          ),
          tripAttachmentCountsProvider.overrideWith(
            (ref, id) =>
                Stream.value((byItem: {item.id: count}, byGroup: <int, int>{})),
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
            body: TimelineTile(
              item: item,
              accent: Colors.teal,
              onTap: () {},
              costs: const [],
              localeName: 'en',
              onTapCost: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an entry with a photograph offers the shortcut', (tester) async {
    final museum = await addPlace('Kunsthalle');
    await pumpTile(
      tester,
      museum,
      gallery: [
        GalleryPhoto(
          attachment: file(1, name: 'a.jpg', itemId: museum.id),
          label: 'Kunsthalle',
        ),
      ],
      count: 1,
    );

    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsNothing);
  });

  testWidgets('an entry with only documents keeps the paperclip, inert', (
    tester,
  ) async {
    final museum = await addPlace('Kunsthalle');
    await pumpTile(tester, museum, gallery: const [], count: 2);

    // A gallery is of pictures, and a shortcut that opened an empty one would
    // be worse than none. (The tile itself is an `InkWell`, so what says the
    // line is inert is that pressing it opens nothing.)
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryScreen), findsNothing);
  });

  testWidgets('an entry with nothing shows no line at all', (tester) async {
    final museum = await addPlace('Kunsthalle');
    await pumpTile(tester, museum, gallery: const [], count: 0);

    expect(find.byIcon(Icons.attach_file), findsNothing);
    expect(find.textContaining('attachment'), findsNothing);
  });

  testWidgets('the shortcut opens the trip gallery at this entry\'s first', (
    tester,
  ) async {
    final breakfast = await addPlace('Breakfast');
    final museum = await addPlace('Kunsthalle', sortOrder: 1);
    await pumpTile(
      tester,
      museum,
      gallery: [
        // An earlier entry's picture comes first in the trip's gallery.
        GalleryPhoto(
          attachment: file(1, name: 'breakfast.jpg', itemId: breakfast.id),
          label: 'Breakfast',
        ),
        GalleryPhoto(
          attachment: file(2, name: 'museum.jpg', itemId: museum.id),
          label: 'Kunsthalle',
        ),
      ],
      count: 1,
    );

    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    // The trip's gallery, opened at *this* entry — so the neighbours are still
    // a swipe away, which is what the timeline is a view of.
    expect(find.byType(GalleryScreen), findsOneWidget);
    expect(find.text('Kunsthalle'), findsWidgets);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('the count still counts documents, not just pictures', (
    tester,
  ) async {
    final museum = await addPlace('Kunsthalle');
    await pumpTile(
      tester,
      museum,
      gallery: [
        GalleryPhoto(
          attachment: file(1, name: 'a.jpg', itemId: museum.id),
          label: 'Kunsthalle',
        ),
      ],
      // One picture and two tickets: the line says what is attached, the icon
      // says what a tap will show.
      count: 3,
    );

    expect(find.text('3 attachments'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });

  testWidgets('a transport leg gets the line too, not only a place', (
    tester,
  ) async {
    final leg = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.transport,
        fromLocation: const Value('Hamburg'),
        toLocation: const Value('Berlin'),
      ),
    );
    final item = (await db.itineraryDao.itemsFor(tripId)).single;

    await pumpTile(
      tester,
      item,
      gallery: [
        GalleryPhoto(
          attachment: file(1, name: 'platform.jpg', itemId: leg),
          label: 'Hamburg → Berlin',
        ),
      ],
      count: 1,
    );

    // The badge was drawn twice on a place and not at all on a leg until these
    // tests were written, which is exactly the kind of thing nothing else
    // notices.
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });
}
