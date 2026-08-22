import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travelplanner/core/format/money_format.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/sharing/presentation/pdf_sections_sheet.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';
import 'package:travelplanner/features/sharing/trip_pdf.dart';
import 'package:travelplanner/features/sharing/trip_pdf_sections.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Covers choosing what goes into an exported PDF: the counts the picker shows
/// (which are the export's own reading of the plan, not a second one) and the
/// picker itself — a section the trip can't fill is not offered, and an export
/// of nothing can't be started.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// A real, decodable picture — `pw.MemoryImage` reads the bytes, so a handful
  /// of made-up ones would be dropped as unreadable and the section would come
  /// out empty for the wrong reason.
  String photoBytes() {
    final image = img.Image(width: 8, height: 6);
    img.fill(image, color: img.ColorRgb8(20, 120, 90));
    return base64Encode(img.encodePng(image));
  }

  /// A trip with something in every section: two days of entries, expenses in
  /// two currencies, a settlement, one checklist, and a photo.
  TripBundle sample() => TripBundle(
    schemaVersion: 22,
    trip: BundleTrip(
      title: 'Rome',
      destination: 'Italy',
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 2),
      colorValue: 0xFF00695C,
      createdAt: DateTime(2026, 1, 2),
    ),
    items: [
      BundleItem(
        localId: 100,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
        title: 'Colosseum',
        attachments: [
          BundleAttachment(
            kind: AttachmentKind.photo,
            mimeType: 'image/jpeg',
            bytes: photoBytes(),
            name: 'arena.jpg',
          ),
          // A document is not printable in a PDF and is not counted as one.
          BundleAttachment(
            kind: AttachmentKind.document,
            mimeType: 'application/pdf',
            bytes: photoBytes(),
            name: 'ticket.pdf',
          ),
        ],
      ),
      BundleItem(
        localId: 101,
        date: DateTime(2026, 5, 1),
        sortOrder: 1,
        kind: ItemKind.transport,
        mode: 'train',
        fromLocation: 'Rome',
        toLocation: 'Naples',
      ),
      BundleItem(
        localId: 102,
        date: DateTime(2026, 5, 2),
        kind: ItemKind.place,
        title: 'Pompeii',
      ),
    ],
    costs: [
      BundleCost(
        itemLocalId: 100,
        amountMinor: 1600,
        currency: 'EUR',
        reason: 'Tickets',
        createdAt: DateTime(2026, 5, 1, 9),
      ),
      BundleCost(
        amountMinor: 500,
        currency: 'USD',
        reason: 'Snacks',
        createdAt: DateTime(2026, 5, 1, 12),
      ),
      BundleCost(
        amountMinor: 2000,
        currency: 'EUR',
        reason: '',
        paidBy: 'Bob',
        isTransfer: true,
        beneficiaries: const ['Alice'],
        createdAt: DateTime(2026, 5, 2),
      ),
    ],
    checklists: [
      BundleChecklist(
        localId: 200,
        title: 'Packing',
        createdAt: DateTime(2026, 4, 1),
        items: [
          BundleChecklistItem(
            label: 'Passport',
            createdAt: DateTime(2026, 4, 1),
          ),
          BundleChecklistItem(
            label: 'Charger',
            sortOrder: 1,
            createdAt: DateTime(2026, 4, 1),
          ),
        ],
      ),
      // Empty lists aren't printed, so they aren't counted either.
      BundleChecklist(
        localId: 201,
        title: 'Ideas',
        sortOrder: 1,
        createdAt: DateTime(2026, 4, 1),
      ),
    ],
    participants: const ['Alice', 'Bob'],
  );

  group('summarizePdfSections', () {
    test('counts what each section would print', () {
      final s = summarizePdfSections(sample());

      expect(s.days, 2);
      expect(s.entries, 3);
      // The settlement is not one of the expenses; it is counted apart.
      expect(s.expenses, 2);
      expect(s.expenseTotals, {'EUR': 1600, 'USD': 500});
      expect(s.transfers, 1);
      expect(s.checklists, 1);
      expect(s.checklistItems, 2);
      // The ticket is an attachment but not a picture: a PDF cannot hold a PDF.
      expect(s.photos, 1);
      expect(s.photoBytes, greaterThan(0));
      expect(s.available, kAllPdfSections);
    });

    test('reads the plan the way the export does: only the chosen option '
        'counts', () {
      final saturday = DateTime(2026, 5, 2);
      final bundle = TripBundle(
        schemaVersion: 22,
        trip: BundleTrip(
          title: 'Weekend',
          destination: '',
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026, 1, 1),
        ),
        alternativeSets: [
          BundleAlternativeSet(
            localId: 1,
            date: saturday,
            label: 'Saturday afternoon',
            alternatives: const [
              BundleAlternative(localId: 11, label: 'Museum', chosen: true),
              BundleAlternative(localId: 12, label: 'Beach'),
            ],
          ),
        ],
        items: [
          BundleItem(
            localId: 100,
            alternativeLocalId: 11,
            date: saturday,
            kind: ItemKind.place,
            title: 'Uffizi',
          ),
          BundleItem(
            localId: 101,
            alternativeLocalId: 12,
            date: saturday,
            kind: ItemKind.place,
            title: 'Lido',
          ),
        ],
        costs: [
          BundleCost(
            itemLocalId: 100,
            amountMinor: 2000,
            currency: 'EUR',
            reason: 'Museum entry',
            createdAt: DateTime(2026, 5, 2),
          ),
          BundleCost(
            itemLocalId: 101,
            amountMinor: 500,
            currency: 'EUR',
            reason: 'Beach chair',
            createdAt: DateTime(2026, 5, 2),
          ),
        ],
      );

      final s = summarizePdfSections(bundle);
      expect(s.days, 1);
      expect(s.entries, 1);
      expect(s.expenses, 1);
      expect(s.expenseTotals, {'EUR': 2000});
    });

    test('offers nothing for a trip with nothing in it', () {
      final bundle = TripBundle(
        schemaVersion: 22,
        trip: BundleTrip(
          title: 'Someday',
          destination: '',
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      final s = summarizePdfSections(bundle);
      expect(s.available, isEmpty);
      for (final section in PdfSection.values) {
        expect(s.has(section), isFalse);
      }
    });
  });

  group('buildTripPdf sections', () {
    /// Asserts [bytes] are a real PDF: non-empty and starting with the "%PDF"
    /// magic.
    void expectPdf(List<int> bytes) {
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }

    test('renders each section on its own, and less than all of them '
        'together', () async {
      final bundle = sample();
      final sizes = <PdfSection, int>{};
      for (final section in PdfSection.values) {
        final bytes = await buildTripPdf(
          bundle: bundle,
          l10n: l10n,
          localeName: 'en',
          sections: {section},
        );
        expectPdf(bytes);
        sizes[section] = bytes.length;
      }

      final everything = await buildTripPdf(
        bundle: bundle,
        l10n: l10n,
        localeName: 'en',
      );
      expectPdf(everything);
      // A left-out section is really left out: any single one weighs less than
      // the whole document, which the header alone would not guarantee.
      for (final size in sizes.values) {
        expect(size, lessThan(everything.length));
      }
    });

    test('an itinerary-only export drops the settlements with the '
        'expenses', () async {
      final bundle = sample();
      final withMoney = await buildTripPdf(
        bundle: bundle,
        l10n: l10n,
        localeName: 'en',
        sections: const {PdfSection.itinerary, PdfSection.expenses},
      );
      final planOnly = await buildTripPdf(
        bundle: bundle,
        l10n: l10n,
        localeName: 'en',
        sections: const {PdfSection.itinerary},
      );
      expectPdf(planOnly);
      expect(planOnly.length, lessThan(withMoney.length));
    });
  });

  group('photos in the document', () {
    test('the section carries the pictures and nothing else does', () async {
      final bundle = sample();
      final without = await buildTripPdf(
        bundle: bundle,
        l10n: l10n,
        localeName: 'en',
        sections: kDefaultPdfSections,
      );
      final with_ = await buildTripPdf(
        bundle: bundle,
        l10n: l10n,
        localeName: 'en',
        sections: {...kDefaultPdfSections, PdfSection.photos},
      );

      // The default set is the one the app starts on, and it does not print
      // pictures: a section that multiplies the size of a document people mail
      // is one to be asked for.
      expect(kDefaultPdfSections.contains(PdfSection.photos), isFalse);
      expect(with_.length, greaterThan(without.length));
    });

    test('a picture that will not decode costs its own place only', () async {
      final bundle = sample();
      final broken = TripBundle(
        schemaVersion: bundle.schemaVersion,
        trip: bundle.trip,
        items: [
          for (final i in bundle.items)
            BundleItem(
              localId: i.localId,
              date: i.date,
              sortOrder: i.sortOrder,
              kind: i.kind,
              title: i.title,
              fromLocation: i.fromLocation,
              toLocation: i.toLocation,
              mode: i.mode,
              attachments: [
                for (final a in i.attachments)
                  BundleAttachment(
                    kind: a.kind,
                    mimeType: a.mimeType,
                    name: a.name,
                    bytes: 'AAAA',
                  ),
              ],
            ),
        ],
      );

      final bytes = await buildTripPdf(
        bundle: broken,
        l10n: l10n,
        localeName: 'en',
        sections: {PdfSection.itinerary, PdfSection.photos},
      );

      // The trip still prints: one unreadable file must not cost the reader the
      // document, the same trade the map makes with a line it cannot decode.
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('only the chosen option\'s pictures are printed', () {
      final bundle = TripBundle(
        schemaVersion: 22,
        trip: BundleTrip(
          title: 'Weekend',
          destination: '',
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026, 1, 2),
        ),
        alternativeSets: [
          BundleAlternativeSet(
            localId: 1,
            date: DateTime(2026, 5, 2),
            alternatives: [
              BundleAlternative(localId: 10, chosen: true),
              BundleAlternative(localId: 11),
            ],
          ),
        ],
        items: [
          BundleItem(
            localId: 100,
            alternativeLocalId: 10,
            date: DateTime(2026, 5, 2),
            kind: ItemKind.place,
            attachments: [
              BundleAttachment(
                kind: AttachmentKind.photo,
                mimeType: 'image/jpeg',
                bytes: photoBytes(),
                name: 'taken.jpg',
              ),
            ],
          ),
          BundleItem(
            localId: 101,
            alternativeLocalId: 11,
            date: DateTime(2026, 5, 2),
            kind: ItemKind.place,
            attachments: [
              BundleAttachment(
                kind: AttachmentKind.photo,
                mimeType: 'image/jpeg',
                bytes: photoBytes(),
                name: 'not-taken.jpg',
              ),
            ],
          ),
        ],
      );

      // The road not taken leaves the app in no export, pictures included.
      expect(printablePhotos(bundle).map((a) => a.name), ['taken.jpg']);
    });

    test("the trip's own pictures print, and come first", () {
      final bundle = TripBundle(
        schemaVersion: 22,
        trip: BundleTrip(
          title: 'Rome',
          destination: '',
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026, 1, 2),
        ),
        attachments: [
          BundleAttachment(
            kind: AttachmentKind.photo,
            mimeType: 'image/jpeg',
            bytes: photoBytes(),
            name: 'the-whole-trip.jpg',
          ),
        ],
        items: [
          BundleItem(
            localId: 100,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.place,
            attachments: [
              BundleAttachment(
                kind: AttachmentKind.photo,
                mimeType: 'image/jpeg',
                bytes: photoBytes(),
                name: 'one-day.jpg',
              ),
            ],
          ),
        ],
      );

      // About the journey rather than a day of it, which is the order the
      // document already reads in.
      expect(printablePhotos(bundle).map((a) => a.name), [
        'the-whole-trip.jpg',
        'one-day.jpg',
      ]);
    });

    test("a run's own pictures print while the run is part of the plan", () {
      final bundle = TripBundle(
        schemaVersion: 22,
        trip: BundleTrip(
          title: 'Rome',
          destination: '',
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026, 1, 2),
        ),
        groups: [
          BundleGroup(
            localId: 5,
            label: 'Train',
            attachments: [
              BundleAttachment(
                kind: AttachmentKind.photo,
                mimeType: 'image/jpeg',
                bytes: photoBytes(),
                name: 'platform.jpg',
              ),
            ],
          ),
        ],
        items: [
          BundleItem(
            localId: 100,
            groupLocalId: 5,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.transport,
          ),
        ],
      );

      expect(printablePhotos(bundle).map((a) => a.name), ['platform.jpg']);
    });
  });

  group('the picker', () {
    /// Pumps a screen whose one button opens the sheet, and hands back a box
    /// that fills with what the sheet returned once it closes (the sheet is
    /// still open when this returns, so the value can't be handed back
    /// directly).
    Future<List<Set<PdfSection>?>> openSheet(
      WidgetTester tester, {
      required PdfSectionSummary summary,
      required Set<PdfSection> initial,
    }) async {
      final result = <Set<PdfSection>?>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result.add(
                    await showPdfSectionsSheet(
                      context,
                      summary: summary,
                      book: sample().currencyBook,
                      initial: initial,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('says what each section holds', (tester) async {
      final summary = summarizePdfSections(sample());
      await openSheet(tester, summary: summary, initial: kAllPdfSections);

      expect(find.text('2 days · 3 entries'), findsOneWidget);
      final totals = formatTotals(
        summary.expenseTotals,
        sample().currencyBook,
        'en',
      );
      expect(
        find.text('2 expenses · $totals\nSettlements included'),
        findsOneWidget,
      );
      expect(find.text('1 list · 2 items'), findsOneWidget);
    });

    testWidgets('does not offer a section the trip cannot fill, and keeps the '
        'stored preference for it', (tester) async {
      final bundle = TripBundle(
        schemaVersion: 22,
        trip: BundleTrip(
          title: 'Rome',
          destination: '',
          startDate: DateTime(2026, 5, 1),
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026, 1, 1),
        ),
        items: [
          BundleItem(
            localId: 100,
            date: DateTime(2026, 5, 1),
            kind: ItemKind.place,
            title: 'Colosseum',
          ),
        ],
      );

      final result = await openSheet(
        tester,
        summary: summarizePdfSections(bundle),
        initial: kAllPdfSections,
      );
      // Three of the four rows have nothing to print, so they read as empty
      // and their switches are dead.
      expect(find.text('Nothing recorded'), findsNWidgets(3));
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches[0].onChanged, isNotNull);
      expect(switches[0].value, isTrue);
      expect(switches[1].onChanged, isNull);
      expect(switches[1].value, isFalse);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      // A trip without expenses or checklists must not switch them off for the
      // next trip, which does have them.
      expect(result.single, kAllPdfSections);
    });

    testWidgets('exports only what is ticked, and nothing at all is not an '
        'export', (tester) async {
      final summary = summarizePdfSections(sample());
      final result = await openSheet(
        tester,
        summary: summary,
        initial: kAllPdfSections,
      );

      await tester.tap(find.text('Expenses'));
      await tester.tap(find.text('Checklist'));
      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.text('Itinerary'));
      await tester.pumpAndSettle();
      // Everything off would print a cover page and no trip.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.text('Itinerary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(result.single, {PdfSection.itinerary});
    });
  });
}
