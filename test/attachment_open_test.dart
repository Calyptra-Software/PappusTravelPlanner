import 'dart:convert';

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
import 'package:travelplanner/features/attachments/attachment_flow.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';
import 'package:travelplanner/features/attachments/presentation/attachment_sheet.dart';
import 'package:travelplanner/features/attachments/widgets/attachments_field.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Opening a document: a tap hands it to whatever program on the device reads
/// it, and where nothing will, the sheet says so with *Share* in reach.
///
/// The platform is stood in for through [openBytesProvider] — `flutter test`
/// has no viewer to hand anything to — so what is tested is what the app sends
/// and what it does with the answer.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int itemId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    final tripId = await db.tripDao.createTrip(
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
        title: const Value('Hotel'),
      ),
    );
  });
  tearDown(() => db.close());

  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n%fake booking\n'));

  Future<Attachment> attachPdf({String? name = 'booking.pdf'}) async {
    final id = await db.attachmentDao.addAttachment(
      prepareAttachment(pdf, name: name, kind: AttachmentKind.document),
      itemId: itemId,
    );
    return (await db.attachmentDao.attachment(id))!;
  }

  group('the name a file leaves under', () {
    Attachment named(String? name, {String mimeType = 'application/pdf'}) =>
        Attachment(
          id: 7,
          itemId: 1,
          kind: AttachmentKind.document,
          mimeType: mimeType,
          name: name,
          byteSize: 10,
          sortOrder: 0,
          createdAt: DateTime(2026, 5, 1),
        );

    test('keeps a name that already carries an extension', () {
      expect(attachmentFileName(named('booking.pdf')), 'booking.pdf');
    });

    test('gives a renamed file its extension back', () {
      // A desktop picks the program by the extension, so "Ticket" would open
      // in nothing.
      expect(attachmentFileName(named('Ticket')), 'Ticket.pdf');
      expect(attachmentFileName(named('Hotel Dr. Kurz')), 'Hotel Dr. Kurz.pdf');
    });

    test('names a file that arrived without one', () {
      expect(attachmentFileName(named(null)), 'attachment-7.pdf');
      expect(attachmentFileName(named('  ')), 'attachment-7.pdf');
    });

    test('takes out what a file system would read as a folder or refuse', () {
      expect(
        attachmentFileName(named('Rome/Hotel: 2.pdf')),
        'Rome_Hotel_ 2.pdf',
      );
      expect(attachmentFileName(named('ticket.')), 'ticket.pdf');
    });

    test('adds nothing for a type it has no name for', () {
      expect(
        attachmentFileName(
          named('notes', mimeType: 'application/octet-stream'),
        ),
        'notes',
      );
    });
  });

  test('the media types a document is stored as come back as extensions', () {
    // One table in both directions, so a type recognised on the way in is
    // named on the way out.
    for (final extension in ['pdf', 'txt', 'csv', 'json', 'ics', 'zip']) {
      final prepared = prepareAttachment(
        pdf,
        name: 'x.$extension',
        kind: AttachmentKind.document,
      );
      expect(extensionForMimeType(prepared.mimeType), extension);
    }
    expect(extensionForMimeType('image/png'), 'png');
  });

  group('a tap on a document', () {
    late List<({String fileName, Uint8List bytes, String mimeType})> handed;
    late bool answer;

    setUp(() {
      handed = [];
      answer = true;
    });

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
            attachmentProvider.overrideWith(
              (ref, id) =>
                  Stream.value(attachments.firstWhere((a) => a.id == id)),
            ),
            openBytesProvider.overrideWithValue(({
              required fileName,
              required bytes,
              required mimeType,
              required slot,
            }) async {
              handed.add((
                fileName: fileName,
                bytes: bytes,
                mimeType: mimeType,
              ));
              return answer;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AttachmentsField(itemId: itemId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hands the stored bytes over, and opens nothing of its own', (
      tester,
    ) async {
      final booking = await attachPdf();
      await pumpField(tester, [booking]);

      await tester.tap(find.text('booking.pdf'));
      await tester.pumpAndSettle();

      expect(handed, hasLength(1));
      expect(handed.single.fileName, 'booking.pdf');
      expect(handed.single.mimeType, 'application/pdf');
      expect(handed.single.bytes, pdf);
      expect(find.byType(AttachmentSheet), findsNothing);
    });

    testWidgets('where nothing takes it, the sheet opens and says so', (
      tester,
    ) async {
      answer = false;
      final booking = await attachPdf();
      await pumpField(tester, [booking]);

      await tester.tap(find.text('booking.pdf'));
      await tester.pumpAndSettle();

      // Inside the sheet, not in a snack bar drawn underneath it.
      expect(
        find.descendant(
          of: find.byType(AttachmentSheet),
          matching: find.textContaining('Nothing on this device opened'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AttachmentSheet),
          matching: find.text('Share'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the row’s ⋮ still reaches the sheet, quietly', (tester) async {
      final booking = await attachPdf();
      await pumpField(tester, [booking]);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.byType(AttachmentSheet), findsOneWidget);
      expect(handed, isEmpty);
      expect(
        find.textContaining('Nothing on this device opened'),
        findsNothing,
      );
    });

    testWidgets('the sheet opens it too, and says so when that fails', (
      tester,
    ) async {
      final booking = await attachPdf();
      await pumpField(tester, [booking]);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      answer = false;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(handed, hasLength(1));
      expect(
        find.textContaining('Nothing on this device opened'),
        findsOneWidget,
      );
    });
  });
}
