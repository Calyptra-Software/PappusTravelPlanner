import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format/date_format.dart';
import '../../core/format/money_format.dart';
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
/// to accept that fallback.
Future<Uint8List> buildTripPdf({
  required TripBundle bundle,
  required AppLocalizations l10n,
  required String localeName,
  Set<PdfSection> sections = kAllPdfSections,
  TripPdfFonts? fonts,
  DateTime? exportedAt,
}) async {
  final builder = _TripPdfBuilder(
    bundle: bundle,
    l10n: l10n,
    localeName: localeName,
    sections: sections,
    fonts: fonts,
    exportedAt: exportedAt ?? DateTime.now(),
  );
  return builder.build();
}

/// The TrueType fonts embedded in an exported PDF. Bundled with the app (Roboto,
/// Apache-2.0) because the built-in PDF fonts can't draw the € sign and other
/// non-Latin-1 glyphs, and the offline app can't fetch a webfont at export time.
class TripPdfFonts {
  const TripPdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;

  /// Loads the bundled Roboto faces from the asset bundle. Call once per export.
  static Future<TripPdfFonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return TripPdfFonts(regular: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
  }
}

class _TripPdfBuilder {
  _TripPdfBuilder({
    required this.bundle,
    required this.l10n,
    required this.localeName,
    required this.sections,
    required this.fonts,
    required this.exportedAt,
  }) : accent = PdfColor.fromInt(bundle.trip.colorValue),
       chosenBranchIds = chosenBranchLocalIds(bundle);

  final TripBundle bundle;
  final AppLocalizations l10n;
  final String localeName;
  final Set<PdfSection> sections;
  final TripPdfFonts? fonts;
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
    final entries = <({int order, pw.Widget widget})>[];

    for (final item in bundle.items) {
      if (item.alternativeLocalId != null) continue;
      if (normalizeDay(item.date) != day) continue;
      entries.add((order: item.sortOrder, widget: _itemRow(item)));
    }

    for (final set in bundle.alternativeSets) {
      if (normalizeDay(set.date) != day) continue;
      entries.add((order: set.sortOrder, widget: _decisionRow(set)));
    }

    entries.sort((a, b) => a.order.compareTo(b.order));

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
        if (entries.isEmpty)
          pw.Text('—', style: const pw.TextStyle(fontSize: 10, color: _faint))
        else
          for (final e in entries) e.widget,
      ],
    );
  }

  /// A decision: its chosen option's entries, plus a note of the alternatives
  /// that were considered but not counted.
  pw.Widget _decisionRow(BundleAlternativeSet set) {
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

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.only(left: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: accent, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (set.label != null && set.label!.trim().isNotEmpty)
            pw.Text(
              set.label!.trim(),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
              ),
            ),
          if (chosenItems.isEmpty)
            pw.Text('—', style: const pw.TextStyle(fontSize: 10, color: _faint))
          else
            for (final item in chosenItems) _itemRow(item),
          if (otherLabels.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
              child: pw.Text(
                l10n.pdfOtherOptions(otherLabels.join(', ')),
                style: const pw.TextStyle(fontSize: 8, color: _faint),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _itemRow(BundleItem item) {
    final time = formatTimeRange(item.startMinutes, item.endMinutes);
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

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 74,
            child: pw.Text(
              time,
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
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
  /// Rendered as two named columns rather than "A -> B" — the bundled Roboto
  /// has no arrow glyph.
  Iterable<pw.Widget> _transfersSection() sync* {
    // Part of the expenses section, not a choice of its own: a repayment only
    // reads next to the balances it settles.
    if (!sections.contains(PdfSection.expenses)) return;

    final transfers = bundleTransfers(bundle);
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
    yield _sectionTitle(l10n.transfers);
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
