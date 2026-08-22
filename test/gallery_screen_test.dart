import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';
import 'package:travelplanner/features/attachments/presentation/gallery_screen.dart';
import 'package:travelplanner/features/attachments/trip_gallery.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Swiping through a trip's photographs.
///
/// The gallery is a *reading*: the swipe browses and writes nothing, which is
/// the rule an `AlternativeCard` already follows, and the acts stay in the sheet
/// behind the ⋮.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Rome',
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 1)),
      ),
    );
  });
  tearDown(() => db.close());

  Uint8List png() {
    final image = img.Image(width: 24, height: 18);
    img.fill(image, color: img.ColorRgb8(80, 120, 160));
    return img.encodePng(image);
  }

  Future<Attachment> attach(String name, {required int itemId}) async {
    final id = await db.attachmentDao.addAttachment(
      prepareAttachment(png(), name: name),
      itemId: itemId,
    );
    return (await db.attachmentDao.attachment(id))!;
  }

  Future<int> addPlace(String title) => db.itineraryDao.addItem(
    ItineraryItemsCompanion.insert(
      tripId: tripId,
      date: DateTime(2026, 5, 1),
      kind: ItemKind.place,
      title: Value(title),
    ),
  );

  Future<void> pumpGallery(
    WidgetTester tester,
    List<GalleryPhoto> photos, {
    int initialIndex = 0,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: GalleryScreen(photos: photos, initialIndex: initialIndex),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the entry a picture hangs on, and counts the set', (
    tester,
  ) async {
    final museum = await addPlace('Kunsthalle');
    final forum = await addPlace('Forum');
    await pumpGallery(tester, [
      GalleryPhoto(
        attachment: await attach('a.jpg', itemId: museum),
        label: 'Kunsthalle',
      ),
      GalleryPhoto(
        attachment: await attach('b.jpg', itemId: forum),
        label: 'Forum',
      ),
    ]);

    // What one of twenty pictures cannot say for itself.
    expect(find.text('Kunsthalle'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('swiping moves to the next picture and its caption', (
    tester,
  ) async {
    final museum = await addPlace('Kunsthalle');
    final forum = await addPlace('Forum');
    await pumpGallery(tester, [
      GalleryPhoto(
        attachment: await attach('a.jpg', itemId: museum),
        label: 'Kunsthalle',
      ),
      GalleryPhoto(
        attachment: await attach('b.jpg', itemId: forum),
        label: 'Forum',
      ),
    ]);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('opens where it was told to', (tester) async {
    final museum = await addPlace('Kunsthalle');
    final forum = await addPlace('Forum');
    await pumpGallery(tester, [
      GalleryPhoto(
        attachment: await attach('a.jpg', itemId: museum),
        label: 'Kunsthalle',
      ),
      GalleryPhoto(
        attachment: await attach('b.jpg', itemId: forum),
        label: 'Forum',
      ),
    ], initialIndex: 1);

    // Tapping the third thumbnail of a strip has to land on the third picture.
    expect(find.text('Forum'), findsOneWidget);
  });

  testWidgets('a single picture is not counted at the reader', (tester) async {
    final museum = await addPlace('Kunsthalle');
    await pumpGallery(tester, [
      GalleryPhoto(
        attachment: await attach('a.jpg', itemId: museum),
        label: 'Kunsthalle',
      ),
    ]);

    // "1 / 1" is a fact about nothing.
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('a picture with no entry to name falls back to its file name', (
    tester,
  ) async {
    final museum = await addPlace('Kunsthalle');
    await pumpGallery(tester, [
      GalleryPhoto(
        attachment: await attach('insurance-photo.jpg', itemId: museum),
      ),
    ]);

    expect(find.text('insurance-photo.jpg'), findsOneWidget);
  });

  testWidgets('swiping writes nothing — it browses', (tester) async {
    final museum = await addPlace('Kunsthalle');
    final forum = await addPlace('Forum');
    final first = await attach('a.jpg', itemId: museum);
    final second = await attach('b.jpg', itemId: forum);
    await pumpGallery(tester, [
      GalleryPhoto(attachment: first, label: 'Kunsthalle'),
      GalleryPhoto(attachment: second, label: 'Forum'),
    ]);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    final rows = await (db.select(
      db.attachments,
    )..orderBy([(a) => OrderingTerm(expression: a.id)])).get();
    expect(rows.map((a) => a.name), ['a.jpg', 'b.jpg']);
    expect(rows.map((a) => a.itemId), [museum, forum]);
  });
}
