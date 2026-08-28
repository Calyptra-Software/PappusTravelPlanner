import 'package:flutter/material.dart';

import '../../../core/format/byte_format.dart';
import '../../../core/format/money_format.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../trip_pdf_sections.dart';

/// Asks which parts of the trip go into the PDF, and returns the chosen
/// sections — or null if the user backed out.
///
/// Shown *after* the bundle has been read, so every row can say what it is
/// about to print ("5 days · 18 entries") and a section the trip has nothing
/// for can be greyed out instead of offering a switch that yields no pages.
/// Sheet, not a submenu of checkboxes: this is the button that commits, and it
/// needs the room.
Future<Set<PdfSection>?> showPdfSectionsSheet(
  BuildContext context, {
  required PdfSectionSummary summary,
  required CurrencyBook book,
  required Set<PdfSection> initial,
}) {
  return showAppSheet<Set<PdfSection>>(
    context,
    builder: (_) =>
        _PdfSectionsSheet(summary: summary, book: book, initial: initial),
  );
}

class _PdfSectionsSheet extends StatefulWidget {
  const _PdfSectionsSheet({
    required this.summary,
    required this.book,
    required this.initial,
  });

  final PdfSectionSummary summary;

  /// Labels and orders [PdfSectionSummary.expenseTotals] — the bundle's own
  /// currencies, so the row reads exactly as the document will.
  final CurrencyBook book;
  final Set<PdfSection> initial;

  @override
  State<_PdfSectionsSheet> createState() => _PdfSectionsSheetState();
}

class _PdfSectionsSheetState extends State<_PdfSectionsSheet> {
  /// Only sections this trip can actually fill start out ticked — the stored
  /// preference for the others is left alone (see [_confirm]).
  late final Set<PdfSection> _draft = {
    for (final section in widget.initial)
      if (widget.summary.has(section)) section,
  };

  void _toggle(PdfSection section, bool on) {
    setState(() => on ? _draft.add(section) : _draft.remove(section));
  }

  /// Hands back the ticked sections plus whatever the user had stored for the
  /// sections this trip couldn't offer: a trip without checklists must not
  /// silently switch checklists off for the next one.
  void _confirm() {
    final unavailable = widget.initial.where((s) => !widget.summary.has(s));
    Navigator.of(context).pop({..._draft, ...unavailable});
  }

  String _label(AppLocalizations l10n, PdfSection section) => switch (section) {
    PdfSection.itinerary => l10n.itineraryTitle,
    PdfSection.expenses => l10n.costs,
    PdfSection.checklists => l10n.checklist,
    PdfSection.photos => l10n.pdfSectionPhotos,
  };

  IconData _icon(PdfSection section) => switch (section) {
    PdfSection.itinerary => Icons.route_outlined,
    PdfSection.expenses => Icons.payments_outlined,
    PdfSection.checklists => Icons.checklist_outlined,
    PdfSection.photos => Icons.photo_library_outlined,
  };

  /// What the section would contain — the reason this is a sheet and not a
  /// menu. Null where the trip has nothing, so the caller prints "nothing
  /// recorded" instead.
  String? _contents(
    AppLocalizations l10n,
    String localeName,
    PdfSection section,
  ) {
    final s = widget.summary;
    switch (section) {
      case PdfSection.itinerary:
        if (s.days == 0) return null;
        return '${l10n.days(s.days)} · ${l10n.entries(s.entries)}';
      case PdfSection.expenses:
        if (s.expenses == 0 && s.transfers == 0) return null;
        final totals = formatTotals(s.expenseTotals, widget.book, localeName);
        final counts = l10n.statsExpenses(s.expenses);
        final line = totals.isEmpty ? counts : '$counts · $totals';
        return s.transfers == 0 ? line : '$line\n${l10n.pdfInclSettlements}';
      case PdfSection.checklists:
        if (s.checklists == 0) return null;
        return '${l10n.pdfLists(s.checklists)} · '
            '${l10n.pdfItems(s.checklistItems)}';
      case PdfSection.photos:
        if (s.photos == 0) return null;
        // The size is named because it is the whole reason this one is a
        // choice: "12 photos" invites a tick, "12 photos · 4.1 MB" invites a
        // decision.
        return '${l10n.pdfPhotos(s.photos)} · ${formatBytes(s.photoBytes)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localeName = Localizations.localeOf(context).languageCode;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pdfSectionsTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.pdfSectionsSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final section in PdfSection.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(_icon(section)),
                  title: Text(_label(l10n, section)),
                  subtitle: Text(
                    _contents(l10n, localeName, section) ??
                        l10n.pdfSectionEmpty,
                  ),
                  value: _draft.contains(section),
                  onChanged: widget.summary.has(section)
                      ? (on) => _toggle(section, on)
                      : null,
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    // Nothing ticked would print a cover page and no trip.
                    onPressed: _draft.isEmpty ? null : _confirm,
                    label: Text(l10n.exportAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
