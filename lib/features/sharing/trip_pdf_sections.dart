import '../../core/format/date_format.dart';
import '../../data/database/tables.dart' show AttachmentKind;
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
/// [photos] prints the pictures attached to the trip's live entries and runs.
/// It is the one section a fresh install leaves *off* (see [kDefaultPdfSections]):
/// every other one costs a few kilobytes of text, and this one can turn a
/// two-page itinerary into a document too large to mail.
enum PdfSection { itinerary, expenses, checklists, photos }

/// Every section there is.
const Set<PdfSection> kAllPdfSections = {
  PdfSection.itinerary,
  PdfSection.expenses,
  PdfSection.checklists,
  PdfSection.photos,
};

/// What an export includes until the user says otherwise: everything except the
/// pictures.
///
/// Not the same set as [kAllPdfSections], and the difference is the point. A
/// PDF is the export people hand out and mail, and a section that multiplies
/// its size by twenty is one to be *asked* for. Someone who has exported before
/// is unaffected either way — their stored mask predates this value, so photos
/// are off for them too, which is the same answer.
const Set<PdfSection> kDefaultPdfSections = {
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

/// Every picture on the trip, on its live entries and on its runs, in the order
/// they would be printed.
///
/// Documents are left out, and that is not an oversight — a PDF can hold a
/// picture and cannot hold a PDF. Printing a ticket's *name* under a heading
/// would be a list of files the reader does not have.
List<BundleAttachment> printablePhotos(
  TripBundle bundle, {
  Set<int>? chosenBranchIds,
}) {
  final chosen = chosenBranchIds ?? chosenBranchLocalIds(bundle);
  final liveGroupIds = {
    for (final i in bundle.items)
      if (bundleItemIsLive(i, chosen) && i.groupLocalId != null)
        i.groupLocalId!,
  };
  return [
    // The trip's own first: they are about the journey rather than about a day
    // of it, which is the order the document already reads in.
    for (final a in bundle.attachments)
      if (a.kind == AttachmentKind.photo) a,
    for (final i in bundle.items)
      if (bundleItemIsLive(i, chosen))
        for (final a in i.attachments)
          if (a.kind == AttachmentKind.photo) a,
    for (final g in bundle.groups)
      if (liveGroupIds.contains(g.localId))
        for (final a in g.attachments)
          if (a.kind == AttachmentKind.photo) a,
  ];
}

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
    required this.photos,
    required this.photoBytes,
  });

  /// Itinerary: days with something on them, and live entries across them.
  final int days;
  final int entries;

  /// Expenses: how many count, and their total per currency code (the totals
  /// themselves are never converted between currencies).
  final int expenses;
  final Map<String, int> expenseTotals;

  /// Settlements, printed as part of the expenses section.
  final int transfers;

  /// Checklists with at least one item, and the items across them.
  final int checklists;
  final int checklistItems;

  /// Pictures that would be printed, and roughly what they would add to the
  /// document.
  ///
  /// The size is shown because it is the whole reason this section is a choice:
  /// a row that says "12 photos" invites a tick, and one that says "12 photos ·
  /// 4.1 MB" invites a decision. Measured from the Base64 the bundle carries, so
  /// it is an over-estimate of the bytes and an under-estimate of the page count
  /// — near enough for the only judgement anyone makes with it.
  final int photos;
  final int photoBytes;

  /// Whether the trip has anything to put in [section].
  bool has(PdfSection section) => switch (section) {
    PdfSection.itinerary => days > 0,
    PdfSection.expenses => expenses > 0 || transfers > 0,
    PdfSection.checklists => checklists > 0,
    PdfSection.photos => photos > 0,
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
  final totals = <String, int>{};
  for (final c in counted) {
    totals.update(
      c.currency,
      (v) => v + c.amountMinor,
      ifAbsent: () => c.amountMinor,
    );
  }

  final lists = printableChecklists(bundle);
  final pictures = printablePhotos(bundle, chosenBranchIds: chosen);

  return PdfSectionSummary(
    days: days.length,
    entries: entries,
    expenses: counted.length,
    expenseTotals: totals,
    transfers: bundleTransfers(bundle).length,
    checklists: lists.length,
    checklistItems: lists.fold(0, (sum, cl) => sum + cl.items.length),
    photos: pictures.length,
    photoBytes: pictures.fold(0, (sum, a) => sum + a.bytes.length),
  );
}
