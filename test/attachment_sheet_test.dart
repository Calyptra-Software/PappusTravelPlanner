import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/attachments/application/attachment_providers.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';
import 'package:travelplanner/features/attachments/presentation/attachment_sheet.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// One attachment, and the four things that can be done to it.
///
/// This sheet is the only place a file exists as something to act on — there is
/// no other form that owns one — so renaming, positioning, handing it out and
/// deleting all have to work from here, and the reading above them has to say
/// what the row actually holds rather than what it held when the tile was
/// tapped.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;
  late int itemId;

  /// The live row, pushed by hand.
  ///
  /// The sheet watches [attachmentProvider], which is a drift `.watch()` — a
  /// stream that does not resolve under the fake-async clock and leaves a timer
  /// behind when its tree is disposed (see `AGENTS.md`). A controller stands in
  /// for it, and being able to withhold the first value is what lets the
  /// fallback below be tested at all.
  late StreamController<Attachment?> live;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    live = StreamController<Attachment?>.broadcast();
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
  tearDown(() async {
    await live.close();
    await db.close();
  });

  Uint8List png() {
    final image = img.Image(width: 24, height: 18);
    img.fill(image, color: img.ColorRgb8(80, 120, 160));
    return img.encodePng(image);
  }

  Future<Attachment> attach({
    String? name = 'ticket.jpg',
    AttachmentKind kind = AttachmentKind.photo,
    Uint8List? bytes,
    LatLng? at,
    AttachmentPositionSource source = AttachmentPositionSource.picked,
  }) async {
    final id = await db.attachmentDao.addAttachment(
      prepareAttachment(bytes ?? png(), name: name, kind: kind),
      itemId: itemId,
    );
    if (at != null) {
      await db.attachmentDao.setAttachmentPosition(id, at, source: source);
    }
    return (await db.attachmentDao.attachment(id))!;
  }

  /// Opens the sheet the way the app does, from a tap on something else, so
  /// what [_delete] pops has a route under it.
  Future<void> openSheet(WidgetTester tester, Attachment attachment) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          appVersionProvider.overrideWithValue('0.0.0-test'),
          attachmentProvider.overrideWith((ref, id) => live.stream),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showAttachmentSheet(context, attachment),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('what it says the file is', () {
    testWidgets('names it, and prints its size beside its dimensions', (
      tester,
    ) async {
      await openSheet(tester, await attach());

      expect(find.text('ticket.jpg'), findsOneWidget);
      // A photograph is re-encoded, so the byte count is not the file's own —
      // the dimensions are what pin the line down.
      expect(find.textContaining('24×18'), findsOneWidget);
    });

    testWidgets('a file that arrived without a name still has a heading', (
      tester,
    ) async {
      await openSheet(tester, await attach(name: null));

      expect(find.text('Attachments'), findsOneWidget);
    });

    testWidgets('a document names its format and offers no position', (
      tester,
    ) async {
      await openSheet(
        tester,
        await attach(
          name: 'booking.pdf',
          kind: AttachmentKind.document,
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      );

      // The format is named from the extension when the bytes say nothing —
      // it is the one thing this placeholder has to show.
      expect(find.text('application/pdf'), findsOneWidget);
      // The visible half of the rule the DAO also enforces: a document is a
      // file, not a place, whatever it is a picture of.
      expect(find.text('No position'), findsNothing);
      expect(find.byTooltip('Place on map'), findsNothing);
    });

    testWidgets('a picture filed as a document is still not a place', (
      tester,
    ) async {
      await openSheet(
        tester,
        await attach(name: 'ticket.png', kind: AttachmentKind.document),
      );

      expect(find.byTooltip('Place on map'), findsNothing);
    });
  });

  group('the row it shows', () {
    testWidgets('falls back to what it was opened with until the row arrives', (
      tester,
    ) async {
      // Nothing pushed into `live`, so the provider has no value yet: the sheet
      // draws the snapshot it was handed rather than an empty frame.
      await openSheet(tester, await attach(name: 'as-tapped.jpg'));

      expect(find.text('as-tapped.jpg'), findsOneWidget);
    });

    testWidgets('and then follows the row, so an edit is not left invisible', (
      tester,
    ) async {
      final attachment = await attach(name: 'as-tapped.jpg');
      await openSheet(tester, attachment);

      await db.attachmentDao.renameAttachment(attachment.id, 'renamed.jpg');
      live.add(await db.attachmentDao.attachment(attachment.id));
      await tester.pumpAndSettle();

      expect(find.text('renamed.jpg'), findsOneWidget);
      expect(find.text('as-tapped.jpg'), findsNothing);
    });
  });

  group('renaming', () {
    testWidgets('writes the new name', (tester) async {
      final attachment = await attach();
      await openSheet(tester, attachment);

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Rail ticket  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final stored = await db.attachmentDao.attachment(attachment.id);
      // Trimmed: a name is what it is called, not how it was typed.
      expect(stored!.name, 'Rail ticket');
    });

    testWidgets('an empty name is no name, not an empty one', (tester) async {
      final attachment = await attach();
      await openSheet(tester, attachment);

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect((await db.attachmentDao.attachment(attachment.id))!.name, isNull);
    });

    testWidgets('backing out of the dialog changes nothing', (tester) async {
      final attachment = await attach();
      await openSheet(tester, attachment);

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'never saved');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        (await db.attachmentDao.attachment(attachment.id))!.name,
        'ticket.jpg',
      );
    });

    testWidgets('the field opens on the name it has', (tester) async {
      await openSheet(tester, await attach());

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'ticket.jpg',
      );
    });
  });

  group('deleting', () {
    testWidgets('asks first, and says why it cannot be undone', (tester) async {
      final attachment = await attach();
      await openSheet(tester, attachment);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this attachment?'), findsOneWidget);
      // The file is here and nowhere else, which is what makes this different
      // from removing a note.
      expect(find.textContaining('nowhere else'), findsOneWidget);
    });

    testWidgets('backing out keeps the file', (tester) async {
      final attachment = await attach();
      await openSheet(tester, attachment);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await db.attachmentDao.attachment(attachment.id), isNotNull);
      expect(find.byType(AttachmentSheet), findsOneWidget);
    });

    testWidgets('confirming removes the row and closes the sheet', (
      tester,
    ) async {
      final attachment = await attach();
      await openSheet(tester, attachment);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // Two buttons say "Delete" once the dialog is up — the sheet's and the
      // dialog's — so the confirmation is taken from inside the dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(await db.attachmentDao.attachment(attachment.id), isNull);
      expect(find.byType(AttachmentSheet), findsNothing);
      // The payload goes with it: the whole reason the blob is a table of its
      // own is that it must not outlive the row that names it.
      expect(await db.attachmentDao.readAttachmentBytes(attachment.id), isNull);
    });
  });

  group('the position', () {
    testWidgets('says there is none, and offers nothing to clear', (
      tester,
    ) async {
      await openSheet(tester, await attach());

      expect(find.text('No position'), findsOneWidget);
      expect(find.byTooltip('Remove position'), findsNothing);
    });

    testWidgets('names where a reading came from, and prints it', (
      tester,
    ) async {
      await openSheet(
        tester,
        await attach(
          at: const LatLng(41.8902, 12.4922),
          source: AttachmentPositionSource.exif,
        ),
      );

      // The provenance is spelled out: where the camera stood is not the same
      // claim as a point somebody pointed at.
      expect(
        find.textContaining('Position taken from the photo'),
        findsOneWidget,
      );
      expect(find.textContaining('41.89020, 12.49220'), findsOneWidget);
    });

    testWidgets('a pointed-at position says so instead', (tester) async {
      await openSheet(tester, await attach(at: const LatLng(41.8902, 12.4922)));

      expect(find.textContaining('Position chosen on the map'), findsOneWidget);
    });

    testWidgets('can be cleared, and the clearing survives on the row', (
      tester,
    ) async {
      final attachment = await attach(at: const LatLng(41.8902, 12.4922));
      await openSheet(tester, attachment);

      await tester.tap(find.byTooltip('Remove position'));
      await tester.pumpAndSettle();

      final stored = await db.attachmentDao.attachment(attachment.id);
      expect(stored!.lat, isNull);
      expect(stored.lon, isNull);
    });

    testWidgets('is pointed at on the map, and stored as a statement', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final attachment = await attach(
        at: const LatLng(41.8902, 12.4922),
        source: AttachmentPositionSource.exif,
      );
      await openSheet(tester, attachment);

      await tester.tap(find.byTooltip('Place on map'));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      // flutter_map waits out a possible second tap before reporting one, and
      // that wait is a Timer `pumpAndSettle` does not advance.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this point'));
      await tester.pumpAndSettle();

      final stored = await db.attachmentDao.attachment(attachment.id);
      // The camera's fix has been overruled by a person, and the row now says
      // so — the app does not quietly upgrade one claim into the other.
      expect(stored!.positionSource, AttachmentPositionSource.picked);
      expect(stored.lat, isNotNull);
    });

    testWidgets('backing out of the map leaves the reading alone', (
      tester,
    ) async {
      final attachment = await attach(
        at: const LatLng(41.8902, 12.4922),
        source: AttachmentPositionSource.exif,
      );
      await openSheet(tester, attachment);

      await tester.tap(find.byTooltip('Place on map'));
      await tester.pumpAndSettle();
      // The picker is a full-screen dialog, so its way out is a close button
      // rather than a back arrow — which is what `pageBack` looks for.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      final stored = await db.attachmentDao.attachment(attachment.id);
      expect(stored!.positionSource, AttachmentPositionSource.exif);
      expect(stored.lat, closeTo(41.8902, 1e-6));
    });
  });

  group('handing it out', () {
    testWidgets('a file whose payload has gone says so rather than nothing', (
      tester,
    ) async {
      final attachment = await attach();
      await openSheet(tester, attachment);
      // The row as the sheet holds it, with its blob deleted underneath — what
      // a delete from another screen leaves an open sheet looking at.
      await db.attachmentDao.deleteAttachment(attachment.id);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(find.text('That file could not be opened.'), findsOneWidget);
    });
  });
}
