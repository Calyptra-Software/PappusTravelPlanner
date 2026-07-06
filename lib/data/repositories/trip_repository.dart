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

  // --- itinerary items ---
  Stream<List<ItineraryItem>> watchItems(int tripId) =>
      _db.itineraryDao.watchItemsForTrip(tripId);
  Future<int> addItem(ItineraryItemsCompanion item) =>
      _db.itineraryDao.addItem(item);
  Future<bool> updateItem(ItineraryItem item) =>
      _db.itineraryDao.updateItem(item);
  Future<int> deleteItem(int id) => _db.itineraryDao.deleteItem(id);
  Future<int> nextSortOrder(int tripId, DateTime date) =>
      _db.itineraryDao.nextSortOrder(tripId, date);

  // --- costs ---
  Stream<List<Cost>> watchCostsForTrip(int tripId) =>
      _db.costDao.watchCostsForTrip(tripId);
  Future<int> addCost(CostsCompanion cost) => _db.costDao.addCost(cost);
  Future<bool> updateCost(Cost cost) => _db.costDao.updateCost(cost);
  Future<int> deleteCost(int id) => _db.costDao.deleteCost(id);
  Future<void> upsertReason(String label) => _db.costDao.upsertReason(label);
  Stream<List<String>> watchReasons() => _db.costDao.watchReasons();
  Stream<List<CostReason>> watchReasonRows() => _db.costDao.watchReasonRows();
  Future<void> setReasonIcon(String label, int? iconId) =>
      _db.costDao.setReasonIcon(label, iconId);
  Future<int> deleteReason(String label) => _db.costDao.deleteReason(label);
}
