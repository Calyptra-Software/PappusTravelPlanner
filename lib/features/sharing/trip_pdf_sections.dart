import '../../core/format/date_format.dart';
import '../../data/database/tables.dart';
import 'trip_bundle.dart';

/// A part of the exported PDF the user may include or leave out. The trip's
/// header — title, dates, participants, notes — is not among them: it is the
/// document's identity, not a section, so it is always printed.
///
/// [expenses] carries the settlements with it: a repayment is only legible
/// beside the balances it settles.
///
/// Persisted as a bitmask of these indices (see `PdfSectionsController`), so
/// only ever append new values at the end.
enum PdfSection { itinerary, expenses, checklists }

/// Every section — what an export includes unless the user says otherwise.
const Set<PdfSection> kAllPdfSections = {
  PdfSection.itinerary,
  PdfSection.expenses,
  PdfSection.checklists,
};

/// Local ids of the chosen option of every decision — the ones that count.
Set<int> chosenBranchLocalIds(TripBundle bundle) => {
  for (final s in bundle.alternativeSets)
    for (final a in s.alternatives)
      if (a.chosen) a.localId,
};

/// Whether [item] is part of the plan: loose, or in the chosen option of its
/// decision. Mirrors `features/itinerary/live_items.dart` on the bundle side.
bool bundleItemIsLive(BundleItem item, Set<int> chosenBranchIds) =>
    item.alternativeLocalId == null ||
    chosenBranchIds.contains(item.alternativeLocalId);

/// The expenses that count toward the trip's totals: not settlements, and
/// attached to the trip, to a live item, or to a group with a live member —
/// mirroring `CostDao._countsTowardTotals` on the bundle side.
List<BundleCost> countedBundleCosts(
  TripBundle bundle, {
  Set<int>? chosenBranchIds,
}) {
  final chosen = chosenBranchIds ?? chosenBranchLocalIds(bundle);
  final liveItemIds = {
    for (final i in bundle.items)
      if (bundleItemIsLive(i, chosen)) i.localId,
  };
  final liveGroupIds = {
    for (final i in bundle.items)
      if (bundleItemIsLive(i, chosen) && i.groupLocalId != null)
        i.groupLocalId!,
  };
  return [
    for (final c in bundle.costs)
      if (!c.isTransfer &&
          (c.itemLocalId == null && c.groupLocalId == null ||
              (c.itemLocalId != null && liveItemIds.contains(c.itemLocalId)) ||
              (c.groupLocalId != null &&
                  liveGroupIds.contains(c.groupLocalId))))
        c,
  ];
}

/// The settlements: money handed from one person to another to square up.
List<BundleCost> bundleTransfers(TripBundle bundle) => [
  for (final c in bundle.costs)
    if (c.isTransfer) c,
];

/// The checklists worth printing — an empty list prints as a bare heading —
/// in the order they appear in the app.
List<BundleChecklist> printableChecklists(TripBundle bundle) => [
  for (final cl in bundle.checklists)
    if (cl.items.isNotEmpty) cl,
]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

/// What each section of the PDF would actually contain for a given bundle, so
/// the picker can say what it is about to print — and grey out a section the
/// trip has nothing for, rather than offering a switch that yields no pages.
class PdfSectionSummary {
  const PdfSectionSummary({
    required this.days,
    required this.entries,
    required this.expenses,
    required this.expenseTotals,
    required this.transfers,
    required this.checklists,
    required this.checklistItems,
  });

  /// Itinerary: days with something on them, and live entries across them.
  final int days;
  final int entries;

  /// Expenses: how many count, and their total per currency (the app never
  /// converts between currencies).
  final int expenses;
  final Map<Currency, int> expenseTotals;

  /// Settlements, printed as part of the expenses section.
  final int transfers;

  /// Checklists with at least one item, and the items across them.
  final int checklists;
  final int checklistItems;

  /// Whether the trip has anything to put in [section].
  bool has(PdfSection section) => switch (section) {
    PdfSection.itinerary => days > 0,
    PdfSection.expenses => expenses > 0 || transfers > 0,
    PdfSection.checklists => checklists > 0,
  };

  /// The sections this trip can fill — what the picker offers.
  Set<PdfSection> get available => {
    for (final s in PdfSection.values)
      if (has(s)) s,
  };
}

/// Counts what [bundle] would put into each section of the PDF, reading the
/// plan exactly as `buildTripPdf` does.
PdfSectionSummary summarizePdfSections(TripBundle bundle) {
  final chosen = chosenBranchLocalIds(bundle);

  final days = <DateTime>{};
  var entries = 0;
  for (final i in bundle.items) {
    if (!bundleItemIsLive(i, chosen)) continue;
    days.add(normalizeDay(i.date));
    entries++;
  }
  for (final s in bundle.alternativeSets) {
    days.add(normalizeDay(s.date));
  }

  final counted = countedBundleCosts(bundle, chosenBranchIds: chosen);
  final totals = <Currency, int>{};
  for (final c in counted) {
    totals.update(
      c.currency,
      (v) => v + c.amountMinor,
      ifAbsent: () => c.amountMinor,
    );
  }

  final lists = printableChecklists(bundle);

  return PdfSectionSummary(
    days: days.length,
    entries: entries,
    expenses: counted.length,
    expenseTotals: totals,
    transfers: bundleTransfers(bundle).length,
    checklists: lists.length,
    checklistItems: lists.fold(0, (sum, cl) => sum + cl.items.length),
  );
}
