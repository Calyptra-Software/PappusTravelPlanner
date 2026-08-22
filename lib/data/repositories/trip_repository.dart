import 'dart:typed_data';
import 'package:latlong2/latlong.dart';

import '../../features/sharing/trip_bundle.dart';
import '../database/app_database.dart';
import '../database/tables.dart';
import '../database/track_points.dart';
import '../../features/attachments/attachment_import.dart'
    show PreparedAttachment;
import '../../features/map/track_import_plan.dart' show TrackEnd;

/// Thin wrapper over the Drift DAOs. Keeping the UI behind this interface means
/// a cloud-backed implementation could be swapped in later without touching the
/// feature layers.
class TripRepository {
  TripRepository(this._db);

  final AppDatabase _db;

  // --- trips ---
  Stream<List<Trip>> watchTrips() => _db.tripDao.watchAllTrips();
  Stream<Trip> watchTrip(int id) => _db.tripDao.watchTrip(id);
  Future<Trip?> findTrip(int id) => _db.tripDao.findTrip(id);
  Future<int> createTrip(TripsCompanion trip) => _db.tripDao.createTrip(trip);
  Future<bool> updateTrip(Trip trip) => _db.tripDao.updateTrip(trip);
  Future<int> deleteTrip(int id) => _db.tripDao.deleteTrip(id);

  /// Writes the routed [shapes] as tracks on the legs [ids] name, one for one.
  ///
  /// The two ways a connection enters a plan share it: [insertJourney], which
  /// adds a run, and [replaceJourneyLegs], which swaps one for a freshly
  /// searched one. A replacement is as much a routed connection as an import —
  /// the run being drawn is the one the router just returned — and leaving this
  /// out of it meant a re-routed journey silently fell back to chords between
  /// its stops, most visibly in a routine, where re-routing is the ordinary act
  /// and adding is the rare one.
  ///
  /// Not to be confused with `copyItemTracks`, which is deliberately *not* called
  /// on a replacement: that would carry the **old** run's line onto the new one
  /// and claim a route was followed that was not. This writes the new run's own.
  ///
  /// A shape that will not decode costs its own leg a line and nothing else: the
  /// rest of the journey is perfectly good. So does one of fewer than two points,
  /// which is not a line.
  Future<void> _writeRoutedShapes(List<int> ids, List<String?> shapes) async {
    for (final (index, shape) in shapes.indexed) {
      if (shape == null || index >= ids.length) continue;
      final List<LatLng> points;
      try {
        points = decodeTrackPoints(shape, precision: kRoutedShapePrecision);
      } on FormatException {
        continue;
      }
      if (points.length < 2) continue;
      await _db.trackDao.addTracks(ids[index], [
        // No name: it is the leg's own route, and "ICE 1081" is already written
        // above it. A name here would only repeat the label the entry carries.
        (points: points, name: null),
      ], source: TrackSource.routed);
    }
  }

  // --- routines ---
  Stream<List<Trip>> watchRoutines() => _db.routineDao.watchRoutines();

  /// Writes a routine's plan into a real trip starting on [startDate]. See
  /// [RoutineDao.materializeRoutine]: occurrences are virtual until asked for.
  Future<int> materializeRoutine(
    int routineId, {
    required DateTime startDate,
  }) => _db.routineDao.materializeRoutine(routineId, startDate: startDate);
  Future<int> duplicateRoutineReversed(
    int routineId, {
    required String title,
  }) => _db.routineDao.duplicateReversed(routineId, title: title);

  /// Swaps a run of legs for a freshly searched one — see
  /// [RoutineDao.replaceJourneyLegs] for what survives the exchange (the bundle,
  /// its ticket, the slot, the colour).
  ///
  /// [shapes] runs parallel to [legs], exactly as in [insertJourney]: the
  /// replacement is a routed connection too, and draws along its line rather
  /// than as chords between its stops. The DAO returns the new ids in [legs]
  /// order so the two line up.
  Future<List<int>> replaceJourneyLegs(
    int tripId, {
    required List<int> oldLegIds,
    required List<ItineraryItemsCompanion> legs,
    int? groupId,
    List<String?> shapes = const [],
  }) async {
    final ids = await _db.routineDao.replaceJourneyLegs(
      tripId,
      oldLegIds: oldLegIds,
      legs: legs,
      groupId: groupId,
    );
    await _writeRoutedShapes(ids, shapes);
    return ids;
  }

  Future<int> routineDaySpan(int routineId) =>
      _db.routineDao.routineDaySpan(routineId);
  Future<List<Trip>> tripsFromRoutineOn(int routineId, DateTime day) =>
      _db.routineDao.tripsFromRoutineOn(routineId, day);

  // --- tags ---
  Stream<List<Tag>> watchTags() => _db.tagDao.watchAllTags();
  Stream<List<Tag>> watchTagsForTrip(int tripId) =>
      _db.tagDao.watchTagsForTrip(tripId);
  Stream<Map<int, List<Tag>>> watchTagsByTrip() => _db.tagDao.watchTagsByTrip();
  Future<int> createTag(TagsCompanion tag) => _db.tagDao.createTag(tag);
  Future<bool> updateTag(Tag tag) => _db.tagDao.updateTag(tag);
  Future<int> deleteTag(int id) => _db.tagDao.deleteTag(id);
  Future<int> ensureTag(String name) => _db.tagDao.ensureTag(name);
  Future<void> setTagsForTrip(int tripId, Set<int> tagIds) =>
      _db.tagDao.setTagsForTrip(tripId, tagIds);

  // --- participants ---
  Stream<List<Person>> watchParticipants(int tripId) =>
      _db.tripDao.watchParticipants(tripId);
  Stream<Map<int, List<Person>>> watchAllParticipants() =>
      _db.tripDao.watchAllParticipants();
  Future<void> addParticipant(int tripId, String name) =>
      _db.tripDao.addParticipant(tripId, name);
  Future<int> removeParticipant(int tripId, int personId) =>
      _db.tripDao.removeParticipant(tripId, personId);

  // --- itinerary items ---
  Stream<List<ItineraryItem>> watchItems(int tripId) =>
      _db.itineraryDao.watchItemsForTrip(tripId);

  /// Every *live* entry carrying a position, across all trips — what the
  /// overview's map draws, before the overview's own filter narrows it.
  /// A trip's entries as they stand — a question asked at a moment, not watched.
  Future<List<ItineraryItem>> itemsFor(int tripId) =>
      _db.itineraryDao.itemsFor(tripId);

  Stream<List<ItineraryItem>> watchPositionedItems() =>
      _db.itineraryDao.watchPositionedItems();

  /// The lines a trip's entries actually followed — live ones only, the same
  /// rule the items above follow.
  Stream<List<Track>> watchTracksForTrip(int tripId) =>
      _db.trackDao.watchTracksForTrip(tripId);

  /// Every trip's, for the all-trips map. Unfiltered for the reason
  /// [watchPositionedItems] is.
  Stream<List<Track>> watchAllTracks() => _db.trackDao.watchAllTracks();

  /// Countries the user marked by hand, with no trip here to show for them.
  Stream<Set<String>> watchMarkedCountries() =>
      _db.visitedCountryDao.watchMarked();

  Future<void> setCountryMarked(String code, bool marked) =>
      _db.visitedCountryDao.setMarked(code, marked);

  Future<void> clearCountryMarks(Set<String> codes) =>
      _db.visitedCountryDao.clearMarks(codes);

  /// What one entry carries, whatever its trip is doing — the item form's
  /// reading.
  Stream<List<Track>> watchTracksForItem(int itemId) =>
      _db.trackDao.watchTracksForItem(itemId);

  Future<void> addTracks(
    int itemId,
    List<({List<LatLng> points, String? name})> lines,
  ) => _db.trackDao.addTracks(itemId, lines);

  Future<void> deleteTracksForItem(int itemId) =>
      _db.trackDao.deleteTracksForItem(itemId);

  /// One recording across the entries it covered, with the coordinates the
  /// import learned on the way.
  Future<void> importTrackAcross({
    required String? name,
    required List<({int itemId, List<LatLng> points})> pieces,
    required List<({int itemId, TrackEnd end, LatLng at})> ends,
  }) => _db.trackDao.importTrackAcross(name: name, pieces: pieces, ends: ends);

  // --- attachments ---

  /// What one entry carries, and what one run does. Two readings rather than
  /// one, because an attachment belongs to exactly one of the two and the two
  /// are edited in different places: an entry's in its own form, a run's on the
  /// label above it, where everything about the run is done.
  Stream<List<Attachment>> watchAttachmentsForItem(int itemId) =>
      _db.attachmentDao.watchAttachmentsForItem(itemId);

  Stream<List<Attachment>> watchAttachmentsForGroup(int groupId) =>
      _db.attachmentDao.watchAttachmentsForGroup(groupId);

  /// What the trip itself carries, rather than any one part of it.
  Stream<List<Attachment>> watchAttachmentsForTrip(int tripId) =>
      _db.attachmentDao.watchAttachmentsForTrip(tripId);

  /// How much each entry and each run of a trip carries — what the timeline
  /// needs to show that there is something there, without reading it.
  Stream<({Map<int, int> byItem, Map<int, int> byGroup})>
  watchAttachmentCountsForTrip(int tripId) =>
      _db.attachmentDao.watchAttachmentCountsForTrip(tripId);

  /// Every photo of one trip, before the live rule is applied to them — what
  /// the gallery reads (see `tripGallery`).
  Stream<List<Attachment>> watchPhotosForTrip(int tripId) =>
      _db.attachmentDao.watchPhotosForTrip(tripId);

  /// The positioned ones among those — what the map draws (see
  /// `tripMapFeatures`).
  Stream<List<Attachment>> watchPositionedPhotosForTrip(int tripId) =>
      _db.attachmentDao.watchPositionedPhotosForTrip(tripId);

  /// What every attachment in the database adds up to — the settings screen's
  /// reading, and about the file rather than about any one trip.
  Future<({int count, int bytes})> attachmentStorage() =>
      _db.attachmentDao.attachmentStorage();

  Future<Attachment?> attachment(int id) => _db.attachmentDao.attachment(id);

  Stream<Attachment?> watchAttachment(int id) =>
      _db.attachmentDao.watchAttachment(id);

  /// The payload. The one read here that touches a full-size file.
  Future<Uint8List?> readAttachmentBytes(int id) =>
      _db.attachmentDao.readAttachmentBytes(id);

  Future<int> addAttachment(
    PreparedAttachment prepared, {
    int? itemId,
    int? groupId,
    int? tripId,
  }) => _db.attachmentDao.addAttachment(
    prepared,
    itemId: itemId,
    groupId: groupId,
    tripId: tripId,
  );

  Future<int> deleteAttachment(int id) =>
      _db.attachmentDao.deleteAttachment(id);

  Future<void> renameAttachment(int id, String? name) =>
      _db.attachmentDao.renameAttachment(id, name);

  Future<void> setAttachmentPosition(
    int id,
    LatLng? at, {
    AttachmentPositionSource source = AttachmentPositionSource.picked,
  }) => _db.attachmentDao.setAttachmentPosition(id, at, source: source);
  Future<int> addItem(ItineraryItemsCompanion item) =>
      _db.itineraryDao.addItem(item);
  Future<bool> updateItem(ItineraryItem item) =>
      _db.itineraryDao.updateItem(item);
  Future<void> setItemColor(int itemId, int? colorValue) =>
      _db.itineraryDao.setItemColor(itemId, colorValue);
  Future<void> setLiveTimes(
    int itemId, {
    required int? actualStart,
    required int? actualEnd,
    required String? stopovers,
  }) => _db.itineraryDao.setLiveTimes(
    itemId,
    actualStart: actualStart,
    actualEnd: actualEnd,
    stopovers: stopovers,
  );
  // Routes through GroupDao so deleting a grouped item also tidies its group
  // (dissolving a group left with <2 members, preserving its shared costs).
  Future<void> deleteItem(int id) => _db.groupDao.deleteItem(id);
  Future<void> moveItem(
    int itemId, {
    required DateTime day,
    int? alternativeId,
  }) =>
      _db.itineraryDao.moveItem(itemId, day: day, alternativeId: alternativeId);
  Future<int> duplicateItem(
    int itemId, {
    required DateTime day,
    int? alternativeId,
  }) => _db.itineraryDao.duplicateItem(
    itemId,
    day: day,
    alternativeId: alternativeId,
  );

  /// Imports a planned journey as a run of transport legs. Each leg is appended
  /// to the end of its day — or, with [alternativeId], to the end of that option
  /// of a decision, which is where the search opened from an option's *Add
  /// transport* puts what it finds. Then, unless [group] is false, each maximal
  /// run of legs sharing a day is bundled into one group (a shared ticket) — a
  /// journey crossing midnight becomes one group per day, since a group lives
  /// within a single day. Returns the new item ids in order.
  /// [shapes] runs parallel to [legs]: the route each one takes, as the routing
  /// service's own encoded polyline at *its* precision. Each becomes a
  /// [TrackSource.routed] track on the leg it belongs to, which is what lets the
  /// map draw a train along its line instead of a chord across the country.
  ///
  /// Passed separately because a shape is not a column — it is a row in another
  /// table, and a companion cannot carry it. Null entries (an older server, a
  /// leg the router has no geometry for) simply write nothing, and the map falls
  /// back to the straight line it drew before.
  Future<List<int>> insertJourney(
    int tripId,
    List<ItineraryItemsCompanion> legs, {
    bool group = true,
    int? alternativeId,
    List<String?> shapes = const [],
  }) async {
    final ids = await _db.itineraryDao.insertJourneyLegs(
      tripId,
      legs,
      alternativeId: alternativeId,
    );
    await _writeRoutedShapes(ids, shapes);
    if (group) {
      var i = 0;
      while (i < legs.length) {
        var j = i;
        while (j + 1 < legs.length &&
            legs[j + 1].date.value == legs[i].date.value) {
          j++;
        }
        // Fold the whole same-day run onto its first member's group.
        for (var k = i; k < j; k++) {
          await _db.groupDao.groupItems(ids[i], ids[k + 1]);
        }
        i = j + 1;
      }
    }
    return ids;
  }

  Future<int> nextSortOrder(int tripId, DateTime date) =>
      _db.itineraryDao.nextSortOrder(tripId, date);
  Future<int> nextSortOrderInAlternative(int alternativeId) =>
      _db.itineraryDao.nextSortOrderInAlternative(alternativeId);
  Stream<Set<DateTime>> watchCollapsedDays(int tripId) =>
      _db.itineraryDao.watchCollapsedDays(tripId);
  Future<void> setDayCollapsed(int tripId, DateTime day, bool collapsed) =>
      _db.itineraryDao.setDayCollapsed(tripId, day, collapsed);

  // --- item groups ---
  Stream<Map<int, ItemGroup>> watchGroups(int tripId) =>
      _db.groupDao.watchGroupsForTrip(tripId);
  Future<int> groupItems(int firstItemId, int secondItemId) =>
      _db.groupDao.groupItems(firstItemId, secondItemId);
  Future<void> removeFromGroup(int itemId) =>
      _db.groupDao.removeFromGroup(itemId);
  Future<void> moveGroup(
    int groupId, {
    required DateTime day,
    int? alternativeId,
  }) => _db.groupDao.moveGroup(groupId, day: day, alternativeId: alternativeId);
  Future<int> copyGroup(
    int groupId, {
    required DateTime day,
    int? alternativeId,
  }) => _db.groupDao.copyGroup(groupId, day: day, alternativeId: alternativeId);
  Future<void> dissolveGroup(int groupId) =>
      _db.groupDao.dissolveGroup(groupId);
  Future<void> deleteGroup(int groupId) => _db.groupDao.deleteGroup(groupId);
  Future<void> setGroupLabel(int groupId, String? label) =>
      _db.groupDao.setGroupLabel(groupId, label);
  Future<void> setGroupCollapsed(int groupId, bool collapsed) =>
      _db.groupDao.setGroupCollapsed(groupId, collapsed);

  // --- alternatives ---
  Stream<Map<int, AlternativeSet>> watchAlternativeSets(int tripId) =>
      _db.alternativeDao.watchSetsForTrip(tripId);
  Stream<Map<int, List<Alternative>>> watchAlternativeBranches(int tripId) =>
      _db.alternativeDao.watchBranchesForTrip(tripId);

  /// A trip's decisions, read once rather than watched — the shape [itemsFor]
  /// is in, and for the same reason: a plan being *chosen from* must hold still.
  Future<Map<int, AlternativeSet>> alternativeSetsFor(int tripId) =>
      _db.alternativeDao.setsForTrip(tripId);
  Future<Map<int, List<Alternative>>> alternativeBranchesFor(int tripId) =>
      _db.alternativeDao.branchesForTrip(tripId);
  Future<int> createAlternativeSetFromItem(int itemId, {String? label}) =>
      _db.alternativeDao.createSetFromItem(itemId, label: label);
  Future<int> addAlternative(int setId, {String? label}) =>
      _db.alternativeDao.addAlternative(setId, label: label);
  Future<int> duplicateAlternative(int alternativeId) =>
      _db.alternativeDao.duplicateAlternative(alternativeId);
  Future<void> chooseAlternative(int alternativeId) =>
      _db.alternativeDao.chooseAlternative(alternativeId);
  Future<void> deleteAlternative(int alternativeId) =>
      _db.alternativeDao.deleteAlternative(alternativeId);
  Future<void> keepOnlyAlternative(int alternativeId) =>
      _db.alternativeDao.keepOnly(alternativeId);
  Future<int> deleteAlternativeSet(int setId) =>
      _db.alternativeDao.deleteSet(setId);
  Future<void> setAlternativeSetSortOrder(int setId, int sortOrder) =>
      _db.alternativeDao.setSortOrder(setId, sortOrder);
  Future<void> setAlternativeSetLabel(int setId, String? label) =>
      _db.alternativeDao.setSetLabel(setId, label);
  Future<void> setAlternativeLabel(int alternativeId, String? label) =>
      _db.alternativeDao.setAlternativeLabel(alternativeId, label);

  // --- costs ---
  Stream<List<Cost>> watchCostsForTrip(int tripId) =>
      _db.costDao.watchCostsForTrip(tripId);
  Stream<List<Cost>> watchCountedCostsForTrip(int tripId) =>
      _db.costDao.watchCountedCostsForTrip(tripId);
  Stream<Map<int, Map<String, int>>> watchTotalsByTrip() =>
      _db.costDao.watchTotalsByTrip();
  Future<int> addCost(CostsCompanion cost) => _db.costDao.addCost(cost);
  Future<bool> updateCost(Cost cost) => _db.costDao.updateCost(cost);
  Future<int> deleteCost(int id) => _db.costDao.deleteCost(id);
  Stream<List<Person>> watchBeneficiaries(int costId) =>
      _db.costDao.watchBeneficiaries(costId);
  Stream<Map<int, List<Person>>> watchBeneficiariesForTrip(int tripId) =>
      _db.costDao.watchBeneficiariesForTrip(tripId);
  Future<void> setBeneficiaries(int costId, List<String> names) =>
      _db.costDao.setBeneficiaries(costId, names);
  Future<void> upsertReason(String label) => _db.costDao.upsertReason(label);
  Stream<List<String>> watchReasons() => _db.costDao.watchReasons();
  Stream<List<CostReason>> watchReasonRows() => _db.costDao.watchReasonRows();
  Future<void> setReasonIcon(String label, int? iconId) =>
      _db.costDao.setReasonIcon(label, iconId);
  Future<int> deleteReason(String label) => _db.costDao.deleteReason(label);
  Future<void> renameReason(String from, String to) =>
      _db.costDao.renameReason(from, to);

  // --- currencies ---
  Stream<List<CurrencyRow>> watchCurrencies() =>
      _db.currencyDao.watchCurrencies();
  Stream<Map<int, int>> watchCurrencyCostCounts() =>
      _db.currencyDao.watchCostCounts();
  Future<int> addCurrency({
    required String code,
    required String symbol,
    int? rateMicros,
  }) => _db.currencyDao.addCurrency(
    code: code,
    symbol: symbol,
    rateMicros: rateMicros,
  );
  Future<void> editCurrency(int id, {String? code, String? symbol}) =>
      _db.currencyDao.editCurrency(id, code: code, symbol: symbol);
  Future<void> setCurrencyRate(int id, int? rateMicros) =>
      _db.currencyDao.setRate(id, rateMicros);
  Future<void> setBaseCurrency(int id) => _db.currencyDao.setBase(id);
  Future<bool> rebaseClearsRates(int id) =>
      _db.currencyDao.rebaseClearsRates(id);
  Future<void> deleteCurrency(int id) => _db.currencyDao.deleteCurrency(id);
  Future<void> reorderCurrencies(List<int> orderedIds) =>
      _db.currencyDao.reorderCurrencies(orderedIds);

  // --- transport modes ---
  Stream<List<TransportModeRow>> watchTransportModes() =>
      _db.transportModeDao.watchModes();
  Future<List<TransportModeRow>> transportModes() =>
      _db.transportModeDao.modes();
  Future<int> addTransportMode(String name, {int? iconId}) =>
      _db.transportModeDao.addMode(name, iconId: iconId);
  Future<void> renameTransportMode(int id, String name) =>
      _db.transportModeDao.renameMode(id, name);
  Future<void> setTransportModeIcon(int id, int? iconId) =>
      _db.transportModeDao.setModeIcon(id, iconId);
  Future<int> deleteTransportMode(int id) =>
      _db.transportModeDao.deleteMode(id);
  Future<void> reorderTransportModes(List<int> orderedIds) =>
      _db.transportModeDao.reorderModes(orderedIds);
  Future<void> restoreBuiltinTransportMode(TransportMode mode) =>
      _db.transportModeDao.restoreBuiltinMode(mode);

  // --- people ---
  Stream<List<String>> watchPeople() => _db.costDao.watchPeople();
  Stream<List<Person>> watchPeopleRows() => _db.costDao.watchPeopleRows();
  Stream<Person?> watchMePerson() => _db.costDao.watchMePerson();
  Future<void> setMePerson(int? personId) => _db.costDao.setMePerson(personId);
  Future<void> upsertPerson(String name) => _db.costDao.upsertPerson(name);
  Future<int> deletePerson(String name) => _db.costDao.deletePerson(name);
  Future<void> renamePerson(String from, String to) =>
      _db.costDao.renamePerson(from, to);

  // --- checklists ---
  Stream<List<Checklist>> watchChecklists(int tripId) =>
      _db.checklistDao.watchChecklists(tripId);
  Future<int> addChecklist(ChecklistsCompanion checklist) =>
      _db.checklistDao.addChecklist(checklist);
  Future<bool> updateChecklist(Checklist checklist) =>
      _db.checklistDao.updateChecklist(checklist);
  Future<int> deleteChecklist(int id) => _db.checklistDao.deleteChecklist(id);
  Future<void> moveChecklist(int checklistId, int tripId) =>
      _db.checklistDao.moveChecklist(checklistId, tripId);
  Future<int> copyChecklist(int checklistId, int tripId, {String? title}) =>
      _db.checklistDao.copyChecklist(checklistId, tripId, title: title);
  Future<int> nextChecklistSortOrder(int tripId) =>
      _db.checklistDao.nextChecklistSortOrder(tripId);

  // --- checklist items ---
  Stream<List<ChecklistItem>> watchChecklistItems(int checklistId) =>
      _db.checklistDao.watchItems(checklistId);
  Future<int> addChecklistItem(ChecklistItemsCompanion item) =>
      _db.checklistDao.addItem(item);
  Future<bool> updateChecklistItem(ChecklistItem item) =>
      _db.checklistDao.updateItem(item);
  Future<int> deleteChecklistItem(int id) => _db.checklistDao.deleteItem(id);
  Future<int> nextChecklistItemSortOrder(int checklistId) =>
      _db.checklistDao.nextItemSortOrder(checklistId);

  // --- sharing ---
  /// Serializes the trip [id] and all its data to a portable bundle's bytes for
  /// sharing. Returns null if the trip no longer exists.
  Future<Uint8List?> exportTrip(int id) async {
    final bundle = await _db.sharingDao.exportTrip(id);
    return bundle?.encode();
  }

  /// Loads the trip [id] and all its data as a portable [TripBundle] — the same
  /// database-free snapshot behind [exportTrip], handed to the PDF builder.
  /// Returns null if the trip no longer exists.
  Future<TripBundle?> tripBundle(int id) => _db.sharingDao.exportTrip(id);

  /// Imports a shared trip bundle's [bytes] as a new trip, returning its id.
  /// Throws [FormatException] if the bytes aren't a valid bundle, or
  /// [IncompatibleBundleException] if they came from a newer app version.
  Future<int> importTrip(Uint8List bytes) =>
      _db.sharingDao.importTrip(TripBundle.decode(bytes));
}
