import 'package:flutter/material.dart';
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

  /// A trip with something in every section: two days of entries, expenses in
  /// two currencies, a settlement, and one checklist.
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
        currency: Currency.eur,
        reason: 'Tickets',
        createdAt: DateTime(2026, 5, 1, 9),
      ),
      BundleCost(
        amountMinor: 500,
        currency: Currency.usd,
        reason: 'Snacks',
        createdAt: DateTime(2026, 5, 1, 12),
      ),
      BundleCost(
        amountMinor: 2000,
        currency: Currency.eur,
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
      expect(s.expenseTotals, {Currency.eur: 1600, Currency.usd: 500});
      expect(s.transfers, 1);
      expect(s.checklists, 1);
      expect(s.checklistItems, 2);
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
            currency: Currency.eur,
            reason: 'Museum entry',
            createdAt: DateTime(2026, 5, 2),
          ),
          BundleCost(
            itemLocalId: 101,
            amountMinor: 500,
            currency: Currency.eur,
            reason: 'Beach chair',
            createdAt: DateTime(2026, 5, 2),
          ),
        ],
      );

      final s = summarizePdfSections(bundle);
      expect(s.days, 1);
      expect(s.entries, 1);
      expect(s.expenses, 1);
      expect(s.expenseTotals, {Currency.eur: 2000});
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
      final totals = formatTotals(summary.expenseTotals, 'en');
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
      // Two of the three rows have nothing to print, so they read as empty and
      // their switches are dead.
      expect(find.text('Nothing recorded'), findsNWidgets(2));
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
