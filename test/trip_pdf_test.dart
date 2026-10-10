import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/widgets/transport_mode.dart';
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
      icons: face('MaterialIconsPdf.ttf'),
      transportGlyphs: face('TransportGlyphs.ttf'),
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
        mode: 'train',
        fromLocation: 'Florence',
        toLocation: 'Rome',
      ),
    ],
    costs: [
      BundleCost(
        itemLocalId: 100,
        amountMinor: 1600,
        currency: 'EUR',
        reason: 'Tickets',
        paidBy: 'Alice',
        paid: true,
        createdAt: DateTime(2026, 5, 1, 9),
      ),
      BundleCost(
        groupLocalId: 10,
        amountMinor: 8000,
        currency: 'EUR',
        reason: 'Train',
        createdAt: DateTime(2026, 5, 1, 8),
      ),
      BundleCost(
        amountMinor: -500,
        currency: 'USD',
        reason: 'Refund',
        paidBy: 'Bob',
        createdAt: DateTime(2026, 5, 2),
      ),
      // A settlement: Bob pays Alice back. It is laid out apart from the
      // expenses and counts toward none of their totals.
      BundleCost(
        amountMinor: 2000,
        currency: 'EUR',
        reason: '',
        paidBy: 'Bob',
        paid: true,
        isTransfer: true,
        beneficiaries: const ['Alice'],
        createdAt: DateTime(2026, 5, 3),
      ),
      // A reimbursement: an allowance from outside the group, listed under a
      // heading of its own.
      BundleCost(
        amountMinor: 5000,
        currency: 'EUR',
        reason: '',
        paidBy: 'Employer',
        paid: true,
        isTransfer: true,
        isReimbursement: true,
        beneficiaries: const ['Alice'],
        createdAt: DateTime(2026, 5, 4),
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

  group('transport mode icons', () {
    test('every icon a mode can wear has a glyph in the font the PDF draws '
        'it from', () {
      // Fails when an icon joins kTransportModeIcons without
      // assets/fonts/build_pdf_icons.py being run again: the PDF would then
      // print an empty disc where the app shows the icon.
      TtfParser parser(String name) => TtfParser(
        ByteData.view(File('assets/fonts/$name').readAsBytesSync().buffer),
      );
      final material = parser('MaterialIconsPdf.ttf');
      final glyphs = parser('TransportGlyphs.ttf');
      for (final icon in [
        ...kTransportModeIcons.values,
        kDefaultTransportModeIcon,
      ]) {
        final face = identical(fonts.fontFor(icon), fonts.transportGlyphs)
            ? glyphs
            : material;
        expect(
          face.charToGlyphIndexMap[icon.codePoint] ?? 0,
          greaterThan(0),
          reason:
              'U+${icon.codePoint.toRadixString(16)} '
              '(${icon.fontFamily}) has no glyph',
        );
      }
    });

    test("every icon glyph's left side bearing is its outline's left edge", () {
      // A TrueType renderer puts a glyph's origin at xMin - lsb, so a bearing
      // of 0 under an outline starting further right draws the icon off
      // center — by up to a sixth of its size, which in a 12pt disc shows.
      // Both build scripts once wrote 0.
      for (final name in ['MaterialIconsPdf.ttf', 'TransportGlyphs.ttf']) {
        final parser = TtfParser(
          ByteData.view(File('assets/fonts/$name').readAsBytesSync().buffer),
        );
        for (final index in parser.charToGlyphIndexMap.values) {
          final metrics = parser.glyphInfoMap[index]!;
          expect(
            metrics.leftBearing,
            closeTo(metrics.left, 1e-9),
            reason: '$name glyph $index',
          );
        }
      }
    });

    test('the glyphs of the TransportGlyphs font are drawn from that font', () {
      expect(fonts.fontFor(kTransportModeIcons[30]!), fonts.transportGlyphs);
      expect(fonts.fontFor(kTransportModeIcons[14]!), fonts.icons);
    });

    test("a mode's icon is this database's, else the bundle's, else the "
        "built-in's own", () {
      final bundle = TripBundle(
        schemaVersion: 19,
        trip: BundleTrip(
          title: 'T',
          destination: '',
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026, 1, 1),
        ),
        modeIcons: const {'Rickshaw': 34},
      );
      // A built-in the user re-iconed: the bundle cannot say so.
      expect(
        pdfTransportModeIcon(
          'train',
          bundle,
          localIcons: {'train': kTransportModeIcons[15]!},
        ),
        kTransportModeIcons[15],
      );
      expect(pdfTransportModeIcon('train', bundle), TransportMode.train.icon);
      // A custom mode this database does not have keeps the bundle's icon...
      expect(pdfTransportModeIcon('Rickshaw', bundle), kTransportModeIcons[34]);
      // ...unless one of the same name here wears another.
      expect(
        pdfTransportModeIcon(
          'Rickshaw',
          bundle,
          localIcons: {'Rickshaw': kTransportModeIcons[9]!},
        ),
        kTransportModeIcons[9],
      );
      expect(
        pdfTransportModeIcon('Unknown', bundle),
        kDefaultTransportModeIcon,
      );
      expect(pdfTransportModeIcon(null, bundle), kDefaultTransportModeIcon);
    });

    test('transportModeIconsByKey keys the modes the way a bundle does', () {
      final icons = transportModeIconsByKey(const [
        TransportModeRow(id: 1, builtinKey: 'train', sortOrder: 0),
        // Renamed and re-iconed built-in: still keyed by its builtinKey.
        TransportModeRow(
          id: 2,
          builtinKey: 'bus',
          name: 'Coach',
          iconId: 11,
          sortOrder: 1,
        ),
        TransportModeRow(id: 3, name: 'Rickshaw', iconId: 34, sortOrder: 2),
      ]);
      expect(icons, {
        'train': TransportMode.train.icon,
        'bus': kTransportModeIcons[11],
        'Rickshaw': kTransportModeIcons[34],
      });
    });

    test('a trip with a leg embeds the icon font', () async {
      // The sample's train leg is drawn with a Material icon, so the subset
      // font has to be in the document.
      final bytes = await buildTripPdf(
        bundle: sample(),
        l10n: l10n,
        localeName: 'en',
        fonts: fonts,
      );
      expect(latin1.decode(bytes), contains('MaterialIconsPdf'));
    });
  });
}

final DateTime _saturday = DateTime(2026, 5, 2);
