import 'package:drift/drift.dart';

/// The two kinds of entry that make up an itinerary. Keeping both in one table
/// lets a trip read as a natural timeline: place -> transport leg -> place ...
enum ItemKind { place, transport }

/// Currencies a cost can be entered in. Stored as the integer index, so only
/// append new values at the end.
enum Currency {
  eur,
  usd,
  gbp,
  chf;

  /// Symbol shown next to amounts.
  String get symbol {
    switch (this) {
      case Currency.eur:
        return '€';
      case Currency.usd:
        return 'US\$';
      case Currency.gbp:
        return '£';
      case Currency.chf:
        return 'CHF';
    }
  }

  /// ISO-ish currency code.
  String get code {
    switch (this) {
      case Currency.eur:
        return 'EUR';
      case Currency.usd:
        return 'USD';
      case Currency.gbp:
        return 'GBP';
      case Currency.chf:
        return 'CHF';
    }
  }
}

/// Supported modes of transport for a transport leg. Ordering here is stable and
/// used as the stored integer index, so only append new values at the end.
enum TransportMode {
  walk,
  bike,
  car,
  taxi,
  bus,
  train,
  tram,
  subway,
  ferry,
  flight,
  other,
  ski,
}

/// A planned trip. Dates are optional so a trip can be sketched out before the
/// exact days are known.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get destination => text().withDefault(const Constant(''))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  /// ARGB colour used as the card accent, e.g. 0xFF00695C.
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF00695C))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// A single itinerary entry belonging to a trip. Columns are shared across both
/// [ItemKind]s; the ones that only apply to one kind are nullable.
class ItineraryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// The day this entry belongs to (time component ignored, normalised to midnight).
  DateTimeColumn get date => dateTime()();

  /// Manual ordering within a day, used for reordering the timeline.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  IntColumn get kind => intEnum<ItemKind>()();
  TextColumn get title => text().nullable()();

  /// Times stored as minutes since midnight (0-1439), or null if unset.
  IntColumn get startMinutes => integer().nullable()();
  IntColumn get endMinutes => integer().nullable()();
  TextColumn get notes => text().nullable()();

  // --- place-only ---
  TextColumn get location => text().nullable()();

  // --- transport-only ---
  IntColumn get mode => intEnum<TransportMode>().nullable()();
  TextColumn get fromLocation => text().nullable()();
  TextColumn get toLocation => text().nullable()();
}

/// A single cost. Attached either to an itinerary item (via [itemId]) or to the
/// trip as a whole (via [tripId]) for costs that don't belong to any one place
/// or transport leg. Exactly one of the two is set; both count toward the
/// trip's total.
class Costs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer()
      .nullable()
      .references(ItineraryItems, #id, onDelete: KeyAction.cascade)();

  /// Set for trip-level costs that aren't tied to a specific itinerary item.
  IntColumn get tripId => integer()
      .nullable()
      .references(Trips, #id, onDelete: KeyAction.cascade)();

  /// Amount in the currency's minor unit (e.g. cents) to avoid float rounding.
  IntColumn get amountMinor => integer()();
  IntColumn get currency => intEnum<Currency>()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A named checklist belonging to a trip. A trip can have any number of these
/// (packing list, to-dos, …); each holds its own [ChecklistItems]. An empty
/// [title] falls back to the default label in the UI.
class Checklists extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Manual ordering of a trip's checklists (appended to the end).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A checklist entry: a piece of text that can be ticked off, belonging to one
/// [Checklists] row.
class ChecklistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get checklistId =>
      integer().references(Checklists, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// Manual ordering within the checklist (appended to the end).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Distinct reason labels the user has entered, kept for reuse in the dropdown
/// independently of whether any cost currently uses them.
class CostReasons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text().unique()();

  /// Stable key into the curated icon set (`kCostReasonIcons`), or null to use
  /// the default icon. Not a font code point, so the set can change safely.
  IntColumn get iconId => integer().nullable()();
}
