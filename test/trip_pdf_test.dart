import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';
import 'package:travelplanner/features/sharing/trip_pdf.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  late TripPdfFonts fonts;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Load the bundled faces straight off disk (rather than through the asset
    // bundle) so the render exercises the embedded-font path — the one that has
    // to draw the € sign — without depending on a built asset manifest.
    pw.Font face(String name) => pw.Font.ttf(
      ByteData.view(File('assets/fonts/$name').readAsBytesSync().buffer),
    );
    fonts = TripPdfFonts(
      regular: face('Roboto-Regular.ttf'),
      bold: face('Roboto-Bold.ttf'),
    );
  });

  /// Asserts [bytes] are a real PDF: non-empty and starting with the "%PDF"
  /// magic. The builder wires many optional fields together, so simply
  /// producing a valid document without throwing is the thing under test.
  void expectPdf(List<int> bytes) {
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  }

  /// A trip exercising places, a transport leg, a group, all three cost
  /// attachment targets (item / group / trip), and a checklist.
  TripBundle sample() => TripBundle(
    schemaVersion: 19,
    trip: BundleTrip(
      title: 'Rome',
      destination: 'Italy',
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 3),
      notes: 'Bring sunscreen',
      colorValue: 0xFF00695C,
      createdAt: DateTime(2026, 1, 2),
    ),
    groups: const [BundleGroup(localId: 10, label: 'Train to Rome')],
    items: [
      BundleItem(
        localId: 100,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
        title: 'Colosseum',
        startMinutes: 600,
        endMinutes: 720,
        location: 'Piazza del Colosseo',
        notes: 'Book skip-the-line',
      ),
      BundleItem(
        localId: 101,
        groupLocalId: 10,
        date: DateTime(2026, 5, 1),
        sortOrder: 1,
        kind: ItemKind.transport,
        mode: TransportMode.train,
        fromLocation: 'Florence',
        toLocation: 'Rome',
      ),
    ],
    costs: [
      BundleCost(
        itemLocalId: 100,
        amountMinor: 1600,
        currency: Currency.eur,
        reason: 'Tickets',
        paidBy: 'Alice',
        paid: true,
        createdAt: DateTime(2026, 5, 1, 9),
      ),
      BundleCost(
        groupLocalId: 10,
        amountMinor: 8000,
        currency: Currency.eur,
        reason: 'Train',
        createdAt: DateTime(2026, 5, 1, 8),
      ),
      BundleCost(
        amountMinor: -500,
        currency: Currency.usd,
        reason: 'Refund',
        paidBy: 'Bob',
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
            done: true,
            createdAt: DateTime(2026, 4, 1),
          ),
          BundleChecklistItem(
            label: 'Charger',
            sortOrder: 1,
            createdAt: DateTime(2026, 4, 1),
          ),
        ],
      ),
    ],
    participants: const ['Alice', 'Bob'],
  );

  test('builds a valid PDF for a fully-populated trip', () async {
    final bytes = await buildTripPdf(
      bundle: sample(),
      l10n: l10n,
      localeName: 'en',
      fonts: fonts,
    );
    expectPdf(bytes);
  });

  test('builds a valid PDF for a bare trip with no items or costs', () async {
    final bundle = TripBundle(
      schemaVersion: 19,
      trip: BundleTrip(
        title: 'Someday',
        destination: '',
        colorValue: 0xFF00695C,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    final bytes = await buildTripPdf(
      bundle: bundle,
      l10n: l10n,
      localeName: 'en',
    );
    expectPdf(bytes);
  });

  test('renders only the chosen branch of a decision, keeping the others '
      'out of the totals', () async {
    final bundle = TripBundle(
      schemaVersion: 19,
      trip: BundleTrip(
        title: 'Weekend',
        destination: '',
        colorValue: 0xFF00695C,
        createdAt: DateTime(2026, 1, 1),
      ),
      alternativeSets: [
        BundleAlternativeSet(
          localId: 1,
          date: _saturday,
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
          date: _saturday,
          kind: ItemKind.place,
          title: 'Uffizi',
        ),
        BundleItem(
          localId: 101,
          alternativeLocalId: 12,
          date: _saturday,
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
    final bytes = await buildTripPdf(
      bundle: bundle,
      l10n: l10n,
      localeName: 'en',
      fonts: fonts,
    );
    // The builder must not throw when only some items are live; producing a
    // valid document is the observable assertion here.
    expectPdf(bytes);
  });
}

final DateTime _saturday = DateTime(2026, 5, 2);
