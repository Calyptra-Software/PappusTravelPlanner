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
import 'package:travelplanner/features/attachments/application/attachment_providers.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';
import 'package:travelplanner/features/attachments/widgets/attachments_field.dart';
import 'package:travelplanner/features/attachments/widgets/trip_attachments_section.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The trip's own paperwork — the insurance, the passport scan, the season
/// ticket — and the one decision behind this widget: it is a **section on the
/// trip screen**, not an entry in a ⋮ menu.
///
/// An attachment on an entry or a run announces itself with a badge on the
/// timeline row it hangs on. The trip has no row, so a file filed at this level
/// appears nowhere at all unless the screen shows it, and behind a menu it would
/// be the insurance nobody can find in the one situation it exists for.
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
    final image = img.Image(width: 12, height: 9);
    img.fill(image, color: img.ColorRgb8(70, 110, 150));
    return img.encodePng(image);
  }

  Future<Attachment> attach(
    String name, {
    AttachmentKind kind = AttachmentKind.document,
  }) async {
    final id = await db.attachmentDao.addAttachment(
      prepareAttachment(
        kind == AttachmentKind.photo ? png() : Uint8List.fromList([1, 2, 3]),
        name: name,
        kind: kind,
      ),
      tripId: tripId,
    );
    return (await db.attachmentDao.attachment(id))!;
  }

  /// [attachments] null stands for "the first read has not come back yet",
  /// which is a different state from "there are none" and has to draw the same.
  Future<void> pumpSection(
    WidgetTester tester, {
    List<Attachment>? attachments = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          tripAttachmentsProvider.overrideWith(
            (ref, id) => attachments == null
                ? const Stream<List<Attachment>>.empty()
                : Stream.value(attachments),
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
            body: TripAttachmentsSection(tripId: tripId, accent: Colors.teal),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty trip is one button, not a heading over nothing', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Add trip document'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('and the same while the first read is still in flight', (
    tester,
  ) async {
    // Otherwise the row appears and then rearranges itself under the reader's
    // finger a frame later.
    await pumpSection(tester, attachments: null);

    expect(find.text('Add trip document'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('files present make it a headed card that counts them', (
    tester,
  ) async {
    await pumpSection(
      tester,
      attachments: [await attach('insurance.pdf'), await attach('visa.pdf')],
    );

    expect(find.text('Trip documents'), findsOneWidget);
    expect(find.text('2 attachments'), findsOneWidget);
    expect(find.text('Add trip document'), findsNothing);
  });

  testWidgets('one file is counted in the singular', (tester) async {
    await pumpSection(tester, attachments: [await attach('insurance.pdf')]);

    expect(find.text('1 attachment'), findsOneWidget);
  });

  testWidgets('the button opens the same field the card does', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('Add trip document'));
    await tester.pumpAndSettle();

    // Both doors lead to one list with one set of acts, which is the reason
    // this is a field and not a screen of its own.
    expect(find.byType(AttachmentsField), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
  });

  testWidgets('tapping the card opens it too, listing what is there', (
    tester,
  ) async {
    await pumpSection(tester, attachments: [await attach('insurance.pdf')]);

    await tester.tap(find.text('Trip documents'));
    await tester.pumpAndSettle();

    expect(find.byType(AttachmentsField), findsOneWidget);
    expect(find.text('insurance.pdf'), findsOneWidget);
  });

  testWidgets('a photograph filed here is listed under Photos', (tester) async {
    await pumpSection(
      tester,
      attachments: [
        await attach('platform.jpg', kind: AttachmentKind.photo),
        await attach('insurance.pdf'),
      ],
    );

    await tester.tap(find.text('Trip documents'));
    await tester.pumpAndSettle();

    // The two are kept apart here as everywhere: one is looked at, the other
    // is opened — and the photographs come first, since that is the section
    // whose order the cover and the PDF are read from.
    expect(
      tester.getTopLeft(find.text('platform.jpg')).dy,
      lessThan(tester.getTopLeft(find.text('insurance.pdf')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Photos')).dy,
      lessThan(tester.getTopLeft(find.text('platform.jpg')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Documents')).dy,
      lessThan(tester.getTopLeft(find.text('insurance.pdf')).dy),
    );
  });
}
