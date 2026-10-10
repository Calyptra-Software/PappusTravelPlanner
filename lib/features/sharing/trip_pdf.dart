import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show IconData;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format/date_format.dart';
import '../../core/format/money_format.dart';
import '../../core/icons/transport_glyphs.dart';
import '../../data/database/tables.dart';
import '../../l10n/app_localizations.dart';
import '../itinerary/widgets/transport_mode.dart';
import 'trip_bundle.dart';
import 'trip_pdf_sections.dart';

/// Renders a [TripBundle] — the same portable, database-free snapshot the app
/// shares as a `.tpt` file — into a printable PDF a traveller can save or hand
/// out on paper.
///
/// Pure (no database, no `BuildContext`): everything it needs is the bundle plus
/// the localized [l10n] labels and [localeName], so the layout is unit-testable
/// exactly like `trip_bundle.dart` and `trip_stats.dart`. The bundle is also
/// what decides "the plan": only *live* entries (loose ones and the chosen
/// branch of each decision) are laid out and only their costs are totalled, so
/// the PDF shows the trip as it currently stands, matching the app's timeline.
///
/// [sections] chooses which parts are laid out — the picker in
/// `presentation/pdf_sections_sheet.dart` writes it — and defaults to all of
/// them, so a caller that has no opinion gets the whole trip. The header is
/// not among them: a document that can't say which trip it is isn't shareable.
///
/// [fonts] are embedded so glyphs the PDF standard fonts can't draw — the €
/// sign above all — render correctly; without them the document falls back to
/// Helvetica and non-Latin-1 characters come out blank. The app loads
/// [TripPdfFonts.load] once; a caller may pass null (e.g. a layout smoke test)
/// to accept that fallback, in which case a leg's node on the rail is drawn
/// without its icon.
///
/// [modeIcons] is the icon each transport mode wears in this database, keyed by
/// the bundle's portable mode key (see [transportModeIconsByKey]). A bundle
/// carries a custom mode's icon but not one chosen for a built-in, so without
/// this a re-iconed train would print with the default one; see
/// [pdfTransportModeIcon] for the order the sources are asked in.
Future<Uint8List> buildTripPdf({
  required TripBundle bundle,
  required AppLocalizations l10n,
  required String localeName,
  Set<PdfSection> sections = kAllPdfSections,
  TripPdfFonts? fonts,
  Map<String, IconData> modeIcons = const {},
  DateTime? exportedAt,
}) async {
  final builder = _TripPdfBuilder(
    bundle: bundle,
    l10n: l10n,
    localeName: localeName,
    sections: sections,
    fonts: fonts,
    modeIcons: modeIcons,
    exportedAt: exportedAt ?? DateTime.now(),
  );
  return builder.build();
}

/// The TrueType fonts embedded in an exported PDF. Bundled with the app (Roboto,
/// Apache-2.0) because the built-in PDF fonts can't draw the € sign and other
/// non-Latin-1 glyphs, and the offline app can't fetch a webfont at export time.
///
/// The two icon fonts draw a leg's transport mode on the rail. [icons] is not
/// the Material Icons font the app draws with: that one is CFF-based, and
/// package:pdf parses TrueType outlines only, so `build_pdf_icons.py` converts
/// the transport icons out of it. [transportGlyphs] is the app's own font,
/// TrueType already.
class TripPdfFonts {
  const TripPdfFonts({
    required this.regular,
    required this.bold,
    required this.icons,
    required this.transportGlyphs,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font icons;
  final pw.Font transportGlyphs;

  /// Loads the bundled faces from the asset bundle. Call once per export.
  static Future<TripPdfFonts> load() async {
    Future<pw.Font> font(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name'));
    return TripPdfFonts(
      regular: await font('Roboto-Regular.ttf'),
      bold: await font('Roboto-Bold.ttf'),
      icons: await font('MaterialIconsPdf.ttf'),
      transportGlyphs: await font('TransportGlyphs.ttf'),
    );
  }

  /// The face that holds [icon]'s glyph.
  pw.Font fontFor(IconData icon) =>
      icon.fontFamily == kTransportGlyphsFamily ? transportGlyphs : icons;
}

/// The icon a leg of mode [key] is drawn with: what this database gives the
/// mode ([localIcons]), else the custom mode's icon the bundle carries, else
/// the built-in's own, else the generic one — the one a leg with no mode wears
/// in the app too. The first source wins because the PDF is printed from this
/// device's app, which shows its own choice; the bundle's is there for a trip
/// whose custom mode does not exist here.
IconData pdfTransportModeIcon(
  String? key,
  TripBundle bundle, {
  Map<String, IconData> localIcons = const {},
}) {
  if (key == null) return kDefaultTransportModeIcon;
  return localIcons[key] ??
      kTransportModeIcons[bundle.modeIcons[key]] ??
      builtinTransportModeFor(key)?.icon ??
      kDefaultTransportModeIcon;
}

class _TripPdfBuilder {
  _TripPdfBuilder({
    required this.bundle,
    required this.l10n,
    required this.localeName,
    required this.sections,
    required this.fonts,
    required this.modeIcons,
    required this.exportedAt,
  }) : accent = PdfColor.fromInt(bundle.trip.colorValue),
       chosenBranchIds = chosenBranchLocalIds(bundle);

  final TripBundle bundle;
  final AppLocalizations l10n;
  final String localeName;
  final Set<PdfSection> sections;
  final TripPdfFonts? fonts;
  final Map<String, IconData> modeIcons;
  final DateTime exportedAt;
  final PdfColor accent;

  /// Local ids of the chosen branch of every decision — the ones that count.
  final Set<int> chosenBranchIds;

  static const _muted = PdfColors.grey700;
  static const _faint = PdfColors.grey500;

  bool _itemIsLive(BundleItem i) => bundleItemIsLive(i, chosenBranchIds);

  Future<Uint8List> build() async {
    final doc = pw.Document(
      title: bundle.trip.title,
      subject: bundle.trip.destination,
    );

    final font = fonts;
    final theme = font == null
        ? null
        : pw.ThemeData.withFont(base: font.regular, bold: font.bold);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 44),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  bundle.trip.title,
                  style: const pw.TextStyle(fontSize: 9, color: _faint),
                ),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _faint),
          ),
        ),
        build: (context) => [
          _headerBlock(),
          ..._itinerarySection(),
          ..._costsSection(),
          ..._transfersSection(),
          ..._checklistsSection(),
          ..._photosSection(),
        ],
      ),
    );

    return doc.save();
  }

  // --- header ---

  pw.Widget _headerBlock() {
    final trip = bundle.trip;
    final lines = <pw.Widget>[
      pw.Text(
        trip.title,
        style: pw.TextStyle(
          fontSize: 24,
          fontWeight: pw.FontWeight.bold,
          color: accent,
        ),
      ),
    ];
    if (trip.destination.isNotEmpty) {
      lines.add(pw.SizedBox(height: 4));
      lines.add(pw.Text(trip.destination, style: pw.TextStyle(fontSize: 13)));
    }
    lines.add(pw.SizedBox(height: 6));
    lines.add(
      pw.Text(
        formatDateRange(l10n, localeName, trip.startDate, trip.endDate),
        style: const pw.TextStyle(fontSize: 11, color: _muted),
      ),
    );
    if (trip.notes != null && trip.notes!.trim().isNotEmpty) {
      lines.add(pw.SizedBox(height: 8));
      lines.add(pw.Text(trip.notes!, style: const pw.TextStyle(fontSize: 10)));
    }
    if (bundle.participants.isNotEmpty) {
      lines.add(pw.SizedBox(height: 8));
      lines.add(
        pw.Text(
          '${l10n.participants}: ${bundle.participants.join(', ')}',
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
      );
    }
    lines.add(pw.SizedBox(height: 6));
    lines.add(
      pw.Text(
        l10n.pdfExportedOn(formatFullDate(exportedAt, localeName)),
        style: const pw.TextStyle(fontSize: 8, color: _faint),
      ),
    );
    lines.add(pw.SizedBox(height: 4));
    lines.add(pw.Divider(color: accent, thickness: 1.2));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines,
    );
  }

  // --- itinerary ---

  Iterable<pw.Widget> _itinerarySection() sync* {
    if (!sections.contains(PdfSection.itinerary)) return;

    final days = <DateTime>{};
    for (final i in bundle.items) {
      if (_itemIsLive(i)) days.add(normalizeDay(i.date));
    }
    for (final s in bundle.alternativeSets) {
      days.add(normalizeDay(s.date));
    }
    if (days.isEmpty) return;

    yield pw.SizedBox(height: 14);
    yield _sectionTitle(l10n.itineraryTitle);

    final sorted = days.toList()..sort();
    for (final day in sorted) {
      yield pw.SizedBox(height: 10);
      yield _dayBlock(day);
    }
  }

  pw.Widget _dayBlock(DateTime day) {
    final entries = <({int order, List<_DayLine> lines})>[];

    for (final item in bundle.items) {
      if (item.alternativeLocalId != null) continue;
      if (normalizeDay(item.date) != day) continue;
      entries.add((order: item.sortOrder, lines: [_itemLine(item)]));
    }

    for (final set in bundle.alternativeSets) {
      if (normalizeDay(set.date) != day) continue;
      entries.add((order: set.sortOrder, lines: _decisionLines(set)));
    }

    entries.sort((a, b) => a.order.compareTo(b.order));
    final lines = [for (final e in entries) ...e.lines];

    // The rail runs from the first node to the last, as a line strung between
    // the entries rather than a ruler down the page.
    final firstNode = lines.indexWhere((l) => l.node != null);
    final lastNode = lines.lastIndexWhere((l) => l.node != null);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          formatFullDate(day, localeName),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
        pw.SizedBox(height: 4),
        if (lines.isEmpty)
          pw.Text('—', style: const pw.TextStyle(fontSize: 10, color: _faint))
        else
          for (var i = 0; i < lines.length; i++)
            _lineRow(
              lines[i],
              railAbove: i > firstNode && i <= lastNode,
              railBelow: i >= firstNode && i < lastNode,
            ),
      ],
    );
  }

  // The day's columns: the time, then the rail's gutter, then the text. The
  // node is centered on the first line of a 10pt title.
  static const double _timeWidth = 74;
  static const double _gutterWidth = 18;
  static const double _railWidth = 1.2;
  static const double _linePadding = 3;
  static const double _nodeBox = 12;
  static const double _nodeCenter = _linePadding + _nodeBox / 2;
  static const _railColor = PdfColors.grey400;

  /// One [_DayLine] with its piece of the rail: from the top of the row down to
  /// the node ([railAbove]), on from the node to the bottom ([railBelow]), or
  /// right through a row with no node of its own (a decision's label).
  pw.Widget _lineRow(
    _DayLine line, {
    required bool railAbove,
    required bool railBelow,
  }) {
    const left = _timeWidth + (_gutterWidth - _railWidth) / 2;
    pw.Widget rail(double height) =>
        pw.Container(width: _railWidth, height: height, color: _railColor);
    final hasNode = line.node != null;

    return pw.Stack(
      children: [
        if (railAbove && railBelow)
          pw.Positioned(
            left: left,
            top: 0,
            bottom: 0,
            child: pw.Container(width: _railWidth, color: _railColor),
          )
        else if (railAbove && hasNode)
          pw.Positioned(left: left, top: 0, child: rail(_nodeCenter))
        else if (railBelow && hasNode)
          pw.Positioned(
            left: left,
            top: _nodeCenter,
            bottom: 0,
            child: pw.Container(width: _railWidth, color: _railColor),
          ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: _timeWidth,
              padding: const pw.EdgeInsets.only(top: _linePadding + 1),
              child: pw.Text(
                line.time,
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ),
            pw.Container(
              width: _gutterWidth,
              height: _nodeBox,
              margin: const pw.EdgeInsets.only(top: _linePadding),
              alignment: pw.Alignment.center,
              child: line.node,
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Container(
                padding: pw.EdgeInsets.only(
                  left: line.inDecision ? 6 : 0,
                  top: _linePadding,
                  bottom: _linePadding,
                ),
                // The decision's accent bar, drawn per row so that it runs
                // unbroken down the rows the decision is made of.
                decoration: line.inDecision
                    ? pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(color: accent, width: 2),
                        ),
                      )
                    : null,
                child: line.content,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A place's node: a dot in the trip's accent, as on the app's timeline.
  pw.Widget _placeNode() => pw.Container(
    width: 7,
    height: 7,
    decoration: pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
  );

  /// A leg's node: its mode's icon in a disc, as on the app's timeline. The
  /// disc is drawn without the icon when no icon font was handed in.
  pw.Widget _transportNode(BundleItem item) {
    final icon = pdfTransportModeIcon(item.mode, bundle, localIcons: modeIcons);
    final font = fonts;
    return pw.Container(
      width: _nodeBox,
      height: _nodeBox,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        shape: pw.BoxShape.circle,
      ),
      child: font == null
          ? null
          : pw.Icon(
              pw.IconData(icon.codePoint),
              font: font.fontFor(icon),
              size: 8.5,
              color: PdfColors.grey800,
            ),
    );
  }

  /// A decision: its chosen option's entries, plus a note of the alternatives
  /// that were considered but not counted.
  List<_DayLine> _decisionLines(BundleAlternativeSet set) {
    final chosen = set.alternatives.firstWhere(
      (a) => a.chosen,
      orElse: () => set.alternatives.first,
    );
    final chosenItems =
        bundle.items
            .where((i) => i.alternativeLocalId == chosen.localId)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final otherLabels = [
      for (final a in set.alternatives)
        if (a.localId != chosen.localId &&
            (a.label?.trim().isNotEmpty ?? false))
          a.label!.trim(),
    ];

    _DayLine note(pw.Widget content) =>
        (node: null, time: '', content: content, inDecision: true);

    return [
      if (set.label != null && set.label!.trim().isNotEmpty)
        note(
          pw.Text(
            set.label!.trim(),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _muted,
            ),
          ),
        ),
      if (chosenItems.isEmpty)
        note(
          pw.Text('—', style: const pw.TextStyle(fontSize: 10, color: _faint)),
        )
      else
        for (final item in chosenItems) _itemLine(item, inDecision: true),
      if (otherLabels.isNotEmpty)
        note(
          pw.Text(
            l10n.pdfOtherOptions(otherLabels.join(', ')),
            style: const pw.TextStyle(fontSize: 8, color: _faint),
          ),
        ),
    ];
  }

  _DayLine _itemLine(BundleItem item, {bool inDecision = false}) {
    final time = formatTimeRange(
      item.startMinutes,
      item.endMinutes,
      endDayOffset: item.endDayOffset,
    );
    final isTransport = item.kind == ItemKind.transport;

    final title = isTransport
        ? _transportTitle(item)
        : (item.title?.trim().isNotEmpty ?? false)
        ? item.title!.trim()
        : (item.location?.trim() ?? '');

    final subtitleParts = <String>[];
    if (!isTransport &&
        (item.location?.trim().isNotEmpty ?? false) &&
        item.location!.trim() != title) {
      subtitleParts.add(item.location!.trim());
    }
    if (item.notes != null && item.notes!.trim().isNotEmpty) {
      subtitleParts.add(item.notes!.trim());
    }

    final costs = _costLabelsForItem(item.localId);

    return (
      node: isTransport ? _transportNode(item) : _placeNode(),
      time: time,
      inDecision: inDecision,
      content: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.isEmpty ? '—' : title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isTransport
                  ? pw.FontWeight.normal
                  : pw.FontWeight.bold,
              color: isTransport ? _muted : PdfColors.black,
            ),
          ),
          for (final part in subtitleParts)
            pw.Text(
              part,
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          if (costs.isNotEmpty)
            pw.Text(
              costs.join('  ·  '),
              style: const pw.TextStyle(fontSize: 9, color: _faint),
            ),
        ],
      ),
    );
  }

  String _transportTitle(BundleItem item) {
    final mode = item.mode == null
        ? l10n.modeOther
        : labelForTransportModeKey(item.mode!, l10n);
    final from = item.fromLocation?.trim() ?? '';
    final to = item.toLocation?.trim() ?? '';
    if (from.isEmpty && to.isEmpty) return mode;
    // An en dash, not an arrow: the bundled Roboto has no U+2192 glyph.
    return '$mode: $from – $to';
  }

  // --- costs ---

  List<String> _costLabelsForItem(int itemLocalId) => [
    for (final c in bundle.costs)
      if (c.itemLocalId == itemLocalId) _costLabel(c),
  ];

  String _costLabel(BundleCost c) {
    final amount = formatMoney(
      c.amountMinor,
      bundle.currencyBook.byCode(c.currency),
      localeName,
    );
    return c.reason.trim().isEmpty ? amount : '${c.reason.trim()} $amount';
  }

  Iterable<pw.Widget> _costsSection() sync* {
    if (!sections.contains(PdfSection.expenses)) return;

    final counted = countedBundleCosts(
      bundle,
      chosenBranchIds: chosenBranchIds,
    );
    if (counted.isEmpty) return;

    yield pw.SizedBox(height: 16);
    yield _sectionTitle(l10n.costs);
    yield pw.SizedBox(height: 6);

    final book = bundle.currencyBook;
    final totals = <String, int>{};
    for (final c in counted) {
      totals.update(
        c.currency,
        (v) => v + c.amountMinor,
        ifAbsent: () => c.amountMinor,
      );
    }
    yield pw.Text(
      '${l10n.costsTotal}: ${formatTotals(totals, book, localeName)}',
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    );
    yield pw.SizedBox(height: 8);
    yield _costsTable(counted);
  }

  pw.Widget _costsTable(List<BundleCost> costs) {
    pw.Widget cell(String text, {bool bold = false, pw.Alignment? align}) {
      final child = pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: align == null ? child : pw.Align(alignment: align, child: child),
      );
    }

    return pw.Table(
      border: pw.TableBorder(
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        horizontalInside: const pw.BorderSide(
          color: PdfColors.grey300,
          width: 0.5,
        ),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            cell(l10n.costReason, bold: true),
            cell(l10n.costPaidBy, bold: true),
            cell(l10n.costsTotal, bold: true, align: pw.Alignment.centerRight),
          ],
        ),
        for (final c in costs)
          pw.TableRow(
            children: [
              cell(c.reason.trim().isEmpty ? '—' : c.reason.trim()),
              cell(
                c.paidBy?.trim().isNotEmpty ?? false ? c.paidBy!.trim() : '—',
              ),
              cell(
                formatMoney(
                  c.amountMinor,
                  bundle.currencyBook.byCode(c.currency),
                  localeName,
                ),
                align: pw.Alignment.centerRight,
              ),
            ],
          ),
      ],
    );
  }

  /// The settlements between people, listed apart from the expenses because
  /// they are not spending: they only move money from one person to another.
  /// Reimbursements from outside the group follow under a heading of their
  /// own, since they square nobody up. Rendered as two named columns rather
  /// than "A -> B" — the bundled Roboto has no arrow glyph.
  Iterable<pw.Widget> _transfersSection() sync* {
    // Part of the expenses section, not a choice of its own: a repayment only
    // reads next to the balances it settles.
    if (!sections.contains(PdfSection.expenses)) return;

    final all = bundleTransfers(bundle);
    yield* _transferTable(l10n.transfers, [
      for (final c in all)
        if (!c.isReimbursement) c,
    ]);
    yield* _transferTable(l10n.reimbursements, [
      for (final c in all)
        if (c.isReimbursement) c,
    ]);
  }

  Iterable<pw.Widget> _transferTable(
    String title,
    List<BundleCost> transfers,
  ) sync* {
    if (transfers.isEmpty) return;

    pw.Widget cell(String text, {bool bold = false, pw.Alignment? align}) {
      final child = pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: align == null ? child : pw.Align(alignment: align, child: child),
      );
    }

    yield pw.SizedBox(height: 16);
    yield _sectionTitle(title);
    yield pw.SizedBox(height: 6);
    yield pw.Table(
      border: pw.TableBorder(
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        horizontalInside: const pw.BorderSide(
          color: PdfColors.grey300,
          width: 0.5,
        ),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            cell(l10n.transferFrom, bold: true),
            cell(l10n.transferTo, bold: true),
            cell(l10n.costAmount, bold: true, align: pw.Alignment.centerRight),
          ],
        ),
        for (final c in transfers)
          pw.TableRow(
            children: [
              cell(
                c.paidBy?.trim().isNotEmpty ?? false ? c.paidBy!.trim() : '—',
              ),
              cell(c.beneficiaries.isEmpty ? '—' : c.beneficiaries.first),
              cell(
                formatMoney(
                  c.amountMinor,
                  bundle.currencyBook.byCode(c.currency),
                  localeName,
                ),
                align: pw.Alignment.centerRight,
              ),
            ],
          ),
      ],
    );
  }

  // --- photos ---

  /// The pictures, two to a row, each captioned with the entry it hangs on.
  ///
  /// Last in the document on purpose: the itinerary, the money and the lists are
  /// what a printed trip is *for*, and a reader flipping to any of them should
  /// not have to page through the photographs first.
  ///
  /// Each is embedded at the size the app stored it — the bounded copy
  /// `attachment_import.dart` made, not a camera original. Making a third size
  /// here would mean decoding and rescaling every picture at export time, on a
  /// phone, to save megabytes in a document the picker has already put a figure
  /// on; the user has been told what it costs and has said yes.
  Iterable<pw.Widget> _photosSection() sync* {
    if (!sections.contains(PdfSection.photos)) return;

    final photos = printablePhotos(bundle);
    if (photos.isEmpty) return;

    // A picture that will not decode costs its own place and nothing else — it
    // may have arrived in a bundle from outside, and one bad file must not cost
    // the reader the whole section. The same trade the map makes with a line.
    final tiles = <pw.Widget>[];
    for (final photo in photos) {
      final image = _photoImage(photo);
      if (image == null) continue;
      tiles.add(_photoTile(photo, image));
    }
    if (tiles.isEmpty) return;

    yield pw.SizedBox(height: 16);
    yield _sectionTitle(l10n.pdfSectionPhotos);

    for (var i = 0; i < tiles.length; i += 2) {
      yield pw.SizedBox(height: 8);
      yield pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: tiles[i]),
          pw.SizedBox(width: 12),
          // An odd one out keeps its half of the row rather than stretching
          // across it: a single wide picture beside nothing reads as a mistake.
          pw.Expanded(
            child: i + 1 < tiles.length ? tiles[i + 1] : pw.SizedBox(),
          ),
        ],
      );
    }
  }

  pw.MemoryImage? _photoImage(BundleAttachment photo) {
    try {
      final bytes = base64Decode(photo.bytes);
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _photoTile(BundleAttachment photo, pw.MemoryImage image) {
    final caption = photo.name?.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Image(image, fit: pw.BoxFit.cover, height: 150),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          caption == null || caption.isEmpty ? l10n.pdfPhotoUnnamed : caption,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    );
  }

  // --- checklists ---

  Iterable<pw.Widget> _checklistsSection() sync* {
    if (!sections.contains(PdfSection.checklists)) return;

    final lists = printableChecklists(bundle);
    if (lists.isEmpty) return;

    yield pw.SizedBox(height: 16);
    yield _sectionTitle(l10n.checklist);

    for (final cl in lists) {
      yield pw.SizedBox(height: 8);
      if (cl.title.trim().isNotEmpty) {
        yield pw.Text(
          cl.title.trim(),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        );
        yield pw.SizedBox(height: 2);
      }
      final items = [...cl.items]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final item in items) {
        yield pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                item.done ? '[x] ' : '[ ] ',
                style: const pw.TextStyle(fontSize: 10, color: _muted),
              ),
              pw.Expanded(
                child: pw.Text(
                  item.label,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: item.done ? _faint : PdfColors.black,
                    decoration: item.done
                        ? pw.TextDecoration.lineThrough
                        : pw.TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  // --- shared ---

  pw.Widget _sectionTitle(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 15,
      fontWeight: pw.FontWeight.bold,
      color: accent,
    ),
  );
}

/// One line of a day as the PDF lays it out: what sits on the rail ([node],
/// null for a line between entries such as a decision's label), the [time]
/// beside it, the text, and whether it belongs to a decision, which marks its
/// rows with the accent bar.
typedef _DayLine = ({
  pw.Widget? node,
  String time,
  pw.Widget content,
  bool inDecision,
});
