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
/// Nor its **provenance**: `sourceTripId` names one dated run of one service at
/// the routing provider, so a copy on another day would refresh its live times
/// from a train it is not. What the routing service told us *about the plan* —
/// the overnight flag, the endpoint coordinates, the stops passed through — is
/// part of what the entry is and does travel.
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
  spansNextDay: Value(item.spansNextDay),
  notes: Value(item.notes),
  location: Value(item.location),
  // Where the place is, beside what it is called. A copy lands on another day,
  // never in another town, so the position travels exactly as the name does.
  lat: Value(item.lat),
  lon: Value(item.lon),
  mode: Value(item.mode),
  fromLocation: Value(item.fromLocation),
  toLocation: Value(item.toLocation),
  fromLat: Value(item.fromLat),
  fromLon: Value(item.fromLon),
  toLat: Value(item.toLat),
  toLon: Value(item.toLon),
  // How the router addresses the ends — not *when* the service ran, unlike
  // `sourceTripId`, which is why these travel and it does not. They are what
  // lets a copied journey be looked up again for the day it was copied onto.
  fromPlaceId: Value(item.fromPlaceId),
  toPlaceId: Value(item.toPlaceId),
  stopovers: Value(item.stopovers),
);
