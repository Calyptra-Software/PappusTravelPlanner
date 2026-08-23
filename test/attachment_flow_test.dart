import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/attachments/application/attachment_providers.dart';
import 'package:travelplanner/features/attachments/application/cover_providers.dart';
import 'package:travelplanner/features/attachments/attachment_flow.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';
import 'package:travelplanner/features/attachments/presentation/gallery_screen.dart';
import 'package:travelplanner/features/attachments/widgets/attachments_field.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Attaching a file, without a file chooser.
///
/// `addAttachments` takes [PickedAttachment]s from an injected picker for
/// exactly this: everything after the picking — what is refused, what is said
/// about it, and what ends up in the database — is behaviour worth a test, and
/// a native dialog in the middle would put all of it out of reach.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;
  late int itemId;

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
    itemId = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
        title: const Value('Colosseum'),
      ),
    );
  });
  tearDown(() => db.close());

  Uint8List png(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(90, 140, 190));
    return img.encodePng(image);
  }

  /// The flow started by the last tap, so a test can wait for it.
  ///
  /// `compute` runs on a real isolate, which the fake-async clock inside
  /// `testWidgets` does not drive: `pumpAndSettle` returns long before the
  /// picture has been decoded. Holding the future lets [tapAttach] await it
  /// under `runAsync`, where real time passes — which is deterministic, unlike
  /// sleeping for long enough and hoping.
  Future<int>? pending;

  /// A screen with one button that runs the flow against [files].
  Future<void> pumpAdder(
    WidgetTester tester,
    List<PickedAttachment>? files, {
    int? onItem,
    int? onGroup,
    AttachmentKind kind = AttachmentKind.photo,
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => pending = addAttachments(
                    context,
                    ref,
                    itemId: onGroup == null ? (onItem ?? itemId) : null,
                    groupId: onGroup,
                    kind: kind,
                    pickFiles: () async => files,
                  ),
                  child: const Text('attach'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapAttach(WidgetTester tester) async {
    // The tap *and* the flow it starts run under `runAsync`: the future is
    // created inside the tap, so awaiting it from the fake-async zone would
    // wait on continuations that only a pump can drain, while the isolate it is
    // waiting for needs real time to finish. Both inside gets one live zone.
    await tester.runAsync(() async {
      await tester.tap(find.text('attach'));
      await pending!;
    });
    await tester.pumpAndSettle();
  }

  /// A one-shot read, not `watchAttachmentsForItem(...).first`: a drift
  /// `.watch()` never resolves under `flutter_test`'s fake-async clock, so
  /// awaiting one inside `testWidgets` hangs the test outright. The DAO tests
  /// use the streams because they are plain `test`s with a real clock.
  Future<List<Attachment>> storedOn(int owner, {bool group = false}) =>
      (db.select(db.attachments)
            ..where(
              (a) => group ? a.groupId.equals(owner) : a.itemId.equals(owner),
            )
            ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
          .get();

  Future<List<Attachment>> stored() => storedOn(itemId);

  testWidgets('a picked photo is re-encoded and written to its entry', (
    tester,
  ) async {
    await pumpAdder(tester, [(bytes: png(64, 48), name: 'view.png')]);
    await tapAttach(tester);

    final rows = await stored();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'view.png');
    // Ours, not the picker's: the app wrote these bytes.
    expect(rows.single.mimeType, 'image/jpeg');
    expect(rows.single.kind, AttachmentKind.photo);
    expect(rows.single.thumbnail, isNotNull);
    expect(rows.single.width, 64);
  });

  testWidgets('backing out of the picker writes nothing and says nothing', (
    tester,
  ) async {
    await pumpAdder(tester, null);
    await tapAttach(tester);

    expect(await stored(), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('several files are attached, and the count is reported', (
    tester,
  ) async {
    await pumpAdder(tester, [
      (bytes: png(20, 20), name: 'a.png'),
      (bytes: png(20, 20), name: 'b.png'),
      (bytes: png(20, 20), name: 'c.png'),
    ]);
    await tapAttach(tester);

    expect(await stored(), hasLength(3));
    expect(find.text('3 files attached.'), findsOneWidget);
  });

  testWidgets('one file says nothing — the row appearing is the message', (
    tester,
  ) async {
    await pumpAdder(tester, [(bytes: png(20, 20), name: 'a.png')]);
    await tapAttach(tester);

    expect(await stored(), hasLength(1));
    expect(find.textContaining('attached.'), findsNothing);
  });

  group('a photograph whose place the system withheld', () {
    /// A picture as Android hands one to an app without
    /// `ACCESS_MEDIA_LOCATION`: `GPSLatitude` and `GPSLongitude` removed, and
    /// only those — the refs and the timestamps left where the camera put
    /// them. Taken from a real file that reached the Linux build with its
    /// position and the Android build without it.
    Uint8List redactedPhoto() {
      final image = img.Image(width: 24, height: 18);
      img.fill(image, color: img.ColorRgb8(90, 140, 190));
      image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
      image.exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('E');
      return img.encodeJpg(image);
    }

    testWidgets('is attached, and the reason it has no place is said', (
      tester,
    ) async {
      await pumpAdder(tester, [(bytes: redactedPhoto(), name: 'a.jpg')]);
      await tapAttach(tester);

      // The picture is kept — nothing is refused here, the app simply cannot
      // put it on the map — and the sentence is what stops that reading as the
      // app having lost it.
      expect((await stored()).single.lat, isNull);
      expect(find.textContaining('withheld'), findsOneWidget);
    });

    testWidgets('and the plain count gives way to it', (tester) async {
      await pumpAdder(tester, [
        (bytes: redactedPhoto(), name: 'a.jpg'),
        (bytes: png(20, 20), name: 'b.png'),
      ]);
      await tapAttach(tester);

      expect(await stored(), hasLength(2));
      // One message: "2 files attached" over this would leave a photograph on
      // the map's doorstep with no explanation.
      expect(find.textContaining('withheld'), findsOneWidget);
      expect(find.textContaining('2 files attached'), findsNothing);
    });

    testWidgets('but a refusal still comes first', (tester) async {
      await pumpAdder(tester, [
        (bytes: redactedPhoto(), name: 'a.jpg'),
        (bytes: Uint8List.fromList([0, 1, 2, 3]), name: 'IMG_1.HEIC'),
      ]);
      await tapAttach(tester);

      // A file is missing, which outranks a file that merely arrived without
      // its place.
      expect(find.textContaining('HEIC'), findsOneWidget);
      expect(find.textContaining('withheld'), findsNothing);
    });

    testWidgets('a photograph that never had a position says nothing', (
      tester,
    ) async {
      await pumpAdder(tester, [(bytes: png(20, 20), name: 'a.png')]);
      await tapAttach(tester);

      expect(await stored(), hasLength(1));
      expect(find.textContaining('withheld'), findsNothing);
    });
  });

  testWidgets('a picture nothing can read is refused by name', (tester) async {
    await pumpAdder(tester, [
      (bytes: Uint8List.fromList([0, 1, 2, 3]), name: 'IMG_1.HEIC'),
    ]);
    await tapAttach(tester);

    expect(await stored(), isEmpty);
    expect(find.textContaining('HEIC'), findsOneWidget);
  });

  testWidgets('the door decides the kind, not the decoder', (tester) async {
    // A ticket saved as a picture: through *Add file* it stays a document, and
    // it is stored exactly as it arrived rather than re-encoded.
    final bytes = png(40, 30);
    await pumpAdder(tester, [
      (bytes: bytes, name: 'ticket.png'),
    ], kind: AttachmentKind.document);
    await tapAttach(tester);

    final row = (await stored()).single;
    expect(row.kind, AttachmentKind.document);
    expect(row.mimeType, 'image/png');
    expect(row.byteSize, bytes.length);
    // Still viewable, which is what lets the documents list open it in a
    // gallery of its own.
    expect(row.width, 40);
    expect(row.thumbnail, isNotNull);
  });

  testWidgets('a file over the limit is refused with both figures', (
    tester,
  ) async {
    await pumpAdder(tester, [
      (bytes: Uint8List(kMaxAttachmentBytes + 1), name: 'scan.pdf'),
    ], kind: AttachmentKind.document);
    await tapAttach(tester);

    expect(await stored(), isEmpty);
    expect(find.textContaining('20 MB'), findsOneWidget);
  });

  testWidgets('a refusal costs its own file and no others', (tester) async {
    await pumpAdder(tester, [
      (bytes: png(20, 20), name: 'good.png'),
      (bytes: Uint8List.fromList([0, 1, 2, 3]), name: 'bad.heic'),
      (bytes: png(20, 20), name: 'also-good.png'),
    ]);
    await tapAttach(tester);

    // A refusal is about one file. The other two are in, and the reason the
    // third did not make it is what gets said — one message, not three.
    expect((await stored()).map((a) => a.name), ['good.png', 'also-good.png']);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('HEIC'), findsOneWidget);
  });

  testWidgets('a run takes files of its own', (tester) async {
    final second = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.transport,
        sortOrder: const Value(1),
      ),
    );
    final groupId = await db.groupDao.groupItems(itemId, second);

    await pumpAdder(tester, [
      (bytes: png(20, 20), name: 'ticket.png'),
    ], onGroup: groupId);
    await tapAttach(tester);

    expect(await storedOn(groupId, group: true), hasLength(1));
    // On the run, not on one of its legs.
    expect(await stored(), isEmpty);
  });

  group('the field that offers it', () {
    /// The field's own stream, stubbed. A drift `.watch()` never resolves under
    /// fake-async, so the list would stay empty however much is written — and
    /// what is being tested here is what the widget *draws*, which the DAO
    /// tests have no opinion about.
    Attachment row({
      required int id,
      required String name,
      AttachmentKind kind = AttachmentKind.photo,
      LatLng? at,
      bool image = false,
    }) => Attachment(
      id: id,
      itemId: itemId,
      kind: kind,
      mimeType: kind == AttachmentKind.photo ? 'image/jpeg' : 'application/pdf',
      name: name,
      byteSize: 2048,
      // What says a document can be looked at: the bytes decoded on the way in.
      width: kind == AttachmentKind.photo || image ? 40 : null,
      lat: at?.latitude,
      lon: at?.longitude,
      positionSource: at == null ? null : AttachmentPositionSource.exif,
      sortOrder: 0,
      createdAt: DateTime(2026, 5, 1),
    );

    Future<void> pumpField(
      WidgetTester tester,
      List<Attachment> attachments,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            itemAttachmentsProvider.overrideWith(
              (ref, id) => Stream.value(attachments),
            ),
            // The gallery's star resolves the trip's current cover, which walks
            // three drift streams to get there — the teardown timer again.
            tripCoverIdProvider.overrideWith((ref, id) => null),
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
              body: AttachmentsField(itemId: itemId, coverTripId: tripId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers both doors, headed, when an entry carries nothing', (
      tester,
    ) async {
      await pumpField(tester, const []);

      // An empty section is its heading and its button and nothing else: a
      // line saying "nothing here" under each of two headings would be noise
      // where the point is to see at a glance what there is.
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
      expect(find.text('Add file'), findsOneWidget);
    });

    testWidgets('files each one under its own heading', (tester) async {
      await pumpField(tester, [
        row(id: 1, name: 'view.jpg'),
        row(id: 2, name: 'ticket.png', kind: AttachmentKind.document),
      ]);

      // A picture filed as a document is under Documents — which is the whole
      // point of having filed it there.
      final photos = tester.getRect(find.text('Photos'));
      final documents = tester.getRect(find.text('Documents'));
      final view = tester.getRect(find.text('view.jpg'));
      final ticket = tester.getRect(find.text('ticket.png'));

      expect(view.top, greaterThan(photos.top));
      expect(view.top, lessThan(documents.top));
      expect(ticket.top, greaterThan(documents.top));
    });

    testWidgets('each heading carries its own count', (tester) async {
      await pumpField(tester, [
        row(id: 1, name: 'a.jpg'),
        row(id: 2, name: 'b.jpg'),
        row(id: 3, name: 'ticket.pdf', kind: AttachmentKind.document),
      ]);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('lists what is there, by name and size', (tester) async {
      await pumpField(tester, [
        row(id: 1, name: 'view.jpg'),
        row(id: 2, name: 'ticket.pdf', kind: AttachmentKind.document),
      ]);

      expect(find.text('view.jpg'), findsOneWidget);
      expect(find.text('ticket.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsNWidgets(2));
    });

    testWidgets('a pin marks the one that carries a position', (tester) async {
      await pumpField(tester, [
        row(id: 1, name: 'placed.jpg', at: const LatLng(53.55, 9.99)),
        row(id: 2, name: 'unplaced.jpg'),
      ]);

      // A list says *that* there is one; where it came from is the sheet's
      // question.
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    });

    testWidgets('a document with no thumbnail still draws an icon', (
      tester,
    ) async {
      await pumpField(tester, [
        row(id: 1, name: 'ticket.pdf', kind: AttachmentKind.document),
      ]);

      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('a photograph here can still be made the trip cover', (
      tester,
    ) async {
      await pumpField(tester, [row(id: 1, name: 'view.jpg')]);

      await tester.tap(find.text('view.jpg'));
      await tester.pumpAndSettle();

      // The star needs to know *which* trip, and an attachment names one of
      // three owners — only one of which is the trip. The form hands it in.
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('a picture filed as a document cannot be, and shows no star', (
      tester,
    ) async {
      await pumpField(tester, [
        row(
          id: 1,
          name: 'ticket.png',
          kind: AttachmentKind.document,
          image: true,
        ),
      ]);

      await tester.tap(find.text('ticket.png'));
      await tester.pumpAndSettle();

      // It opens — a picture filed as a document is still something to look at
      // — but it is not one of the trip's photographs, and `coverPhoto` would
      // never find it again.
      expect(find.byType(GalleryScreen), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('a photograph is dragged into place, and only its own list '
        'is renumbered', (tester) async {
      final leg = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 5, 1),
          kind: ItemKind.transport,
        ),
      );
      final first = await db.attachmentDao.addAttachment(
        prepareAttachment(png(16, 16), name: 'first.jpg'),
        itemId: leg,
      );
      final second = await db.attachmentDao.addAttachment(
        prepareAttachment(png(16, 16), name: 'second.jpg'),
        itemId: leg,
      );
      final ticket = await db.attachmentDao.addAttachment(
        prepareAttachment(
          Uint8List.fromList('%PDF'.codeUnits),
          name: 'ticket.pdf',
          kind: AttachmentKind.document,
        ),
        itemId: leg,
      );
      final rows = await (db.select(
        db.attachments,
      )..where((a) => a.itemId.equals(leg))).get();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            itemAttachmentsProvider.overrideWith(
              (ref, id) => Stream.value(rows),
            ),
            tripCoverIdProvider.overrideWith((ref, id) => null),
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
              body: AttachmentsField(itemId: leg, coverTripId: tripId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The second photograph's grip, dragged above the first. A step at a
      // time: a single `drag` is one synthetic move, which a reorderable list
      // does not follow.
      final grips = find.byIcon(Icons.drag_indicator);
      final gesture = await tester.startGesture(tester.getCenter(grips.at(1)));
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -15));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final after =
          await (db.select(db.attachments)
                ..where((a) => a.itemId.equals(leg))
                ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
              .get();
      final photos = [
        for (final a in after)
          if (a.kind == AttachmentKind.photo) a.name,
      ];
      expect(photos, ['second.jpg', 'first.jpg']);
      expect(first, isNot(second));

      // The documents list is numbered on its own and was not touched.
      final document = after.firstWhere((a) => a.id == ticket);
      expect(document.sortOrder, 2);
    });
  });
}
