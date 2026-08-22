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
import 'package:travelplanner/features/attachments/widgets/trip_photo_strip.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The band of thumbnails that leads into the gallery: when it is there, and
/// folding it away.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;
  late int itemId;

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
    itemId = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.place,
        title: const Value('Colosseum'),
      ),
    );
  });
  tearDown(() => db.close());

  Attachment photo(int id, String name) => Attachment(
    id: id,
    itemId: itemId,
    kind: AttachmentKind.photo,
    mimeType: 'image/jpeg',
    name: name,
    byteSize: 1024,
    sortOrder: 0,
    createdAt: day,
  );

  /// The photos and the items are stubbed: a drift `.watch()` never resolves
  /// under fake-async, and what is being tested is what the band draws.
  Future<void> pumpStrip(
    WidgetTester tester, {
    required List<Attachment> photos,
    bool collapsed = false,
    int? coverAttachmentId,
    bool coverHidden = false,
  }) async {
    final items = await db.itineraryDao.itemsFor(tripId);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          tripPhotosProvider.overrideWith((ref, id) => Stream.value(photos)),
          itineraryProvider.overrideWith((ref, id) => Stream.value(items)),
          groupsProvider.overrideWith(
            (ref, id) => Stream.value(const <int, ItemGroup>{}),
          ),
          // `chosenBranchIdsProvider` reads this one, and it is a drift stream
          // like the rest: left live, its cancellation at teardown leaves the
          // pending timer that fails the test after the assertions have passed.
          alternativeBranchesProvider.overrideWith(
            (ref, id) => Stream.value(const <int, List<Alternative>>{}),
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
            body: TripPhotoStrip(
              tripId: tripId,
              collapsed: collapsed,
              coverAttachmentId: coverAttachmentId,
              coverHidden: coverHidden,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('is not there at all when the trip has no photographs', (
    tester,
  ) async {
    await pumpStrip(tester, photos: const []);

    // An empty band would be a permanent advertisement for a feature this trip
    // is not using.
    expect(find.text('Photos'), findsNothing);
  });

  testWidgets('shows the heading and how many there are', (tester) async {
    await pumpStrip(tester, photos: [photo(1, 'a.jpg'), photo(2, 'b.jpg')]);

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('2 attachments'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('folds away, and says so in the database', (tester) async {
    await pumpStrip(tester, photos: [photo(1, 'a.jpg')]);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();

    // Remembered on the trip's own row, the way a checklist's state is: this
    // survives leaving the screen and closing the app.
    expect((await db.tripDao.findTrip(tripId))!.photosCollapsed, isTrue);
  });

  testWidgets('unfolds again from the collapsed state', (tester) async {
    await db.tripDao.setPhotosCollapsed(tripId, true);
    await pumpStrip(tester, photos: [photo(1, 'a.jpg')], collapsed: true);

    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();

    expect((await db.tripDao.findTrip(tripId))!.photosCollapsed, isFalse);
  });

  testWidgets('keeps the count while folded away', (tester) async {
    await pumpStrip(
      tester,
      photos: [photo(1, 'a.jpg'), photo(2, 'b.jpg')],
      collapsed: true,
    );

    // A collapsed section saying nothing about what is inside it would be a row
    // with no reason to be tapped.
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('2 attachments'), findsOneWidget);
  });

  group('the cover mark', () {
    testWidgets('is on the chosen thumbnail and on no other', (tester) async {
      await pumpStrip(
        tester,
        photos: [photo(1, 'a.jpg'), photo(2, 'b.jpg'), photo(3, 'c.jpg')],
        coverAttachmentId: 2,
      );

      // One star, not three: nineteen empty ones would answer a question
      // nobody asked, and each would need a target that steals the tap opening
      // the gallery.
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('is absent while the trip wants no cover', (tester) async {
      await pumpStrip(
        tester,
        photos: [photo(1, 'a.jpg'), photo(2, 'b.jpg')],
        coverAttachmentId: 2,
        coverHidden: true,
      );

      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('is absent when nothing has been chosen', (tester) async {
      // The card derives one, but the strip marks only a *choice* — a star on
      // the first thumbnail would look like a decision nobody made.
      await pumpStrip(tester, photos: [photo(1, 'a.jpg')]);

      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('"no cover" is written to the trip, and taken back', (
      tester,
    ) async {
      await pumpStrip(tester, photos: [photo(1, 'a.jpg')]);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No cover photo'));
      await tester.pumpAndSettle();

      expect((await db.tripDao.findTrip(tripId))!.coverHidden, isTrue);

      await pumpStrip(tester, photos: [photo(1, 'a.jpg')], coverHidden: true);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No cover photo'));
      await tester.pumpAndSettle();

      expect((await db.tripDao.findTrip(tripId))!.coverHidden, isFalse);
    });

    testWidgets('hiding is offered while a picture is marked too', (
      tester,
    ) async {
      // What hiding *does* to the stored choice is the DAO's rule and is tested
      // there against real rows; here the mark is a stub, and inserting one
      // just to satisfy the foreign key would be testing the wrong thing.
      await pumpStrip(
        tester,
        photos: [photo(1, 'a.jpg')],
        coverAttachmentId: 1,
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('No cover photo'), findsOneWidget);
    });
  });
}
