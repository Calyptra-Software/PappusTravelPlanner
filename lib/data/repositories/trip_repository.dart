import '../database/app_database.dart';

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

  // --- participants ---
  Stream<List<Person>> watchParticipants(int tripId) =>
      _db.tripDao.watchParticipants(tripId);
  Future<void> addParticipant(int tripId, String name) =>
      _db.tripDao.addParticipant(tripId, name);
  Future<int> removeParticipant(int tripId, int personId) =>
      _db.tripDao.removeParticipant(tripId, personId);

  // --- itinerary items ---
  Stream<List<ItineraryItem>> watchItems(int tripId) =>
      _db.itineraryDao.watchItemsForTrip(tripId);
  Future<int> addItem(ItineraryItemsCompanion item) =>
      _db.itineraryDao.addItem(item);
  Future<bool> updateItem(ItineraryItem item) =>
      _db.itineraryDao.updateItem(item);
  // Routes through GroupDao so deleting a grouped item also tidies its group
  // (dissolving a group left with <2 members, preserving its shared costs).
  Future<void> deleteItem(int id) => _db.groupDao.deleteItem(id);
  Future<int> nextSortOrder(int tripId, DateTime date) =>
      _db.itineraryDao.nextSortOrder(tripId, date);
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
  Future<void> dissolveGroup(int groupId) =>
      _db.groupDao.dissolveGroup(groupId);
  Future<void> setGroupLabel(int groupId, String? label) =>
      _db.groupDao.setGroupLabel(groupId, label);
  Future<void> setGroupCollapsed(int groupId, bool collapsed) =>
      _db.groupDao.setGroupCollapsed(groupId, collapsed);

  // --- costs ---
  Stream<List<Cost>> watchCostsForTrip(int tripId) =>
      _db.costDao.watchCostsForTrip(tripId);
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
  Future<int> nextChecklistSortOrder(int tripId) =>
      _db.checklistDao.nextChecklistSortOrder(tripId);

  // --- checklist items ---
  Stream<List<ChecklistItem>> watchChecklistItems(int checklistId) =>
      _db.checklistDao.watchItems(checklistId);
  Future<int> addChecklistItem(ChecklistItemsCompanion item) =>
      _db.checklistDao.addItem(item);
  Future<bool> updateChecklistItem(ChecklistItem item) =>
      _db.checklistDao.updateItem(item);
  Future<int> deleteChecklistItem(int id) =>
      _db.checklistDao.deleteItem(id);
  Future<int> nextChecklistItemSortOrder(int checklistId) =>
      _db.checklistDao.nextItemSortOrder(checklistId);
}
