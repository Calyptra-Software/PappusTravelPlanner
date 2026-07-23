import 'package:drift/drift.dart';

import 'app_database.dart';

/// The **plan** an itinerary item carries, as a companion ready to insert a
/// copy: its title, times, notes, location, route and mode — everything that
/// describes what the entry *is*.
///
/// Deliberately not its identity, and not its **costs**: a cost records a
/// payment that happened once, so duplicating it would invent money inside a
/// trip whose totals and settle-up depend on it. Grouping is dropped too unless
/// [groupId] is given — the caller decides where the copy lands ([date],
/// [alternativeId], [groupId], [sortOrder]).
///
/// Shared by every duplicate in the app (an item, a group, a whole option) so
/// they all carry exactly the same fields — a new column added here reaches all
/// of them at once.
ItineraryItemsCompanion copyItemPlan(
  ItineraryItem item, {
  required DateTime date,
  int? alternativeId,
  int? groupId,
  required int sortOrder,
}) => ItineraryItemsCompanion.insert(
  tripId: item.tripId,
  date: date,
  kind: item.kind,
  sortOrder: Value(sortOrder),
  alternativeId: Value(alternativeId),
  groupId: Value(groupId),
  title: Value(item.title),
  startMinutes: Value(item.startMinutes),
  endMinutes: Value(item.endMinutes),
  actualStartMinutes: Value(item.actualStartMinutes),
  actualEndMinutes: Value(item.actualEndMinutes),
  notes: Value(item.notes),
  location: Value(item.location),
  mode: Value(item.mode),
  fromLocation: Value(item.fromLocation),
  toLocation: Value(item.toLocation),
);
