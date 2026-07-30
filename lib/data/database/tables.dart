import 'package:drift/drift.dart';

/// The two kinds of entry that make up an itinerary. Keeping both in one table
/// lets a trip read as a natural timeline: place -> transport leg -> place ...
enum ItemKind { place, transport }

/// The built-in currencies the database is seeded with. No longer a stored
/// column type: a cost now points at a [Currencies] row via [Costs.currency],
/// and the built-ins are seeded as rows the user can add to, re-code, re-symbol,
/// reorder, or delete (see `CurrencyDao`) — exactly as [TransportMode] became a
/// catalogue rather than a type. Each value's [code] is the row's identity, so
/// only append new values at the end (the v23 migration maps a cost's old enum
/// index onto the row seeded at that position).
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

  /// ISO-ish currency code — the seeded row's unique [Currencies.code].
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

/// The built-in modes of transport a trip is seeded with. No longer a stored
/// column type: a transport leg now points at a [TransportModes] row via
/// [ItineraryItems.mode], and the built-ins are seeded as rows the user can add
/// to, rename, re-icon, reorder, or delete (see `TransportModeDao`). This enum
/// stays the catalogue those seed rows are built from — each value's `name` is
/// the stable `builtinKey` stored on its row, giving it a localized label and a
/// default icon (see `transport_mode.dart`). Only append new values at the end.
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Groups several adjacent itinerary items into one logical unit — e.g. a train
/// journey made up of multiple legs and intermediate stops that share a single
/// ticket. A group's costs (attached via [Costs.groupId]) cover all its members
/// at once. Deleting the group leaves its members intact (their [groupId] is set
/// to null); deleting the trip cascades.
class ItemGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// Optional display name (e.g. "Train to Rome"); falls back to a default label.
  TextColumn get label => text().nullable()();

  /// Whether the group is shown collapsed in the itinerary overview. Persisted
  /// like [Checklists.collapsed] so the state survives reopening.
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();
}

/// A decision point in a day's plan: "what do we do on Saturday afternoon?".
/// Holds two or more [Alternatives] — competing versions of one stretch of the
/// day — of which exactly one is [Alternatives.chosen].
///
/// A set occupies a single slot in its day's timeline: [date] and [sortOrder]
/// place it among that day's loose items exactly as an item's own [date] and
/// [ItineraryItems.sortOrder] would. Only the chosen branch's items are shown
/// there, and only their costs count toward any total (see [Alternatives]).
///
/// There is deliberately no "this is what we actually did" flag: the chosen
/// branch *is* what the trip counts, so after the fact you simply point it at
/// what happened. A second marker would only record whether the decision was
/// still open — which nothing in the app asks.
class AlternativeSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// The day this decision sits on (normalized to midnight, like
  /// [ItineraryItems.date]). Branches are day-scoped: every item in every branch
  /// belongs to this day.
  DateTimeColumn get date => dateTime()();

  /// The set's position within its day, sharing one ordering space with that
  /// day's loose items — the whole set is a single block in the timeline.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Optional display name (e.g. "Saturday afternoon"); falls back to a default
  /// label in the UI.
  TextColumn get label => text().nullable()();
}

/// One branch of an [AlternativeSets] decision: a competing version of that
/// stretch of the day, holding its own [ItineraryItems] (which may in turn be
/// bundled into [ItemGroups] — a group never straddles two branches).
///
/// At most one branch per set has [chosen] set, enforced in `AlternativeDao`
/// rather than by the schema (mirroring [People.isMe]); this avoids a circular
/// foreign key between the two tables. The chosen branch is the one the timeline
/// shows by default and the only one whose costs count toward the trip's totals
/// and its expense splitting — the roads not taken must not inflate the budget.
///
/// Deleting a branch **deletes its items** (unlike dissolving an [ItemGroups]
/// group, which frees them): a branch's items exist only as part of that branch,
/// so rejecting an option is meant to remove its plan, not scatter it across the
/// day.
class Alternatives extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId =>
      integer().references(AlternativeSets, #id, onDelete: KeyAction.cascade)();

  /// Optional display name (e.g. "Museum day"); falls back to "Option A/B/C".
  TextColumn get label => text().nullable()();

  /// Order of the branches within the set — the order they are swiped through.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Whether this is the branch currently selected for the plan. At most one per
  /// set; see the class doc.
  BoolColumn get chosen => boolean().withDefault(const Constant(false))();
}

/// A single itinerary entry belonging to a trip. Columns are shared across both
/// [ItemKind]s; the ones that only apply to one kind are nullable.
class ItineraryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// The group this item belongs to, or null when it stands alone. On group
  /// deletion this is set to null (see [ItemGroups]) rather than cascading, so
  /// dissolving a group never removes the underlying places/legs.
  IntColumn get groupId => integer().nullable().references(
    ItemGroups,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The branch this item belongs to, or null when it is a *loose* item sitting
  /// directly on its day (the ordinary case). Cascades on branch deletion — see
  /// [Alternatives]. An item in an unchosen branch is invisible to the day's
  /// timeline, the trip totals and the home-screen widget.
  IntColumn get alternativeId => integer().nullable().references(
    Alternatives,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// The day this entry belongs to (time component ignored, normalised to midnight).
  DateTimeColumn get date => dateTime()();

  /// Manual ordering, used for reordering the timeline. For a loose item this
  /// orders it within its day, in one space shared with that day's
  /// [AlternativeSets]; for an item inside a branch it orders it within that
  /// branch.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  IntColumn get kind => intEnum<ItemKind>()();
  TextColumn get title => text().nullable()();

  /// The **planned** times — when the entry is meant to start/end (for a
  /// transport leg: to depart/arrive). Minutes since midnight (0-1439), or null
  /// if unset.
  IntColumn get startMinutes => integer().nullable()();
  IntColumn get endMinutes => integer().nullable()();

  /// The **actual** times — when the entry really started/ended, recorded during
  /// or after the trip. Same encoding as the planned pair, and just as optional:
  /// an entry the trip never got round to timing simply has none. Each is
  /// compared against its planned counterpart to show how late or early the
  /// entry ran; with no plan to compare against, an actual time just stands on
  /// its own.
  IntColumn get actualStartMinutes => integer().nullable()();
  IntColumn get actualEndMinutes => integer().nullable()();

  /// Whether this entry's **end** falls on the day *after* [date]. Almost always
  /// an overnight transport leg — a night train that departs before midnight and
  /// arrives the next morning: the entry stays anchored to its departure [date]
  /// and appears once, on that day, while [endMinutes]/[actualEndMinutes] are
  /// read as minutes into the following calendar day. This keeps the 0-1439
  /// encoding intact rather than letting a single row straddle two dates.
  BoolColumn get spansNextDay => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();

  // --- place-only ---
  TextColumn get location => text().nullable()();

  // --- transport-only ---
  /// The transport mode of this leg — a row in [TransportModes], or null when
  /// unassigned. On mode deletion this is set to null (the leg keeps its route,
  /// it just loses its mode), like an item losing its group.
  IntColumn get mode => integer().nullable().references(
    TransportModes,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get fromLocation => text().nullable()();
  TextColumn get toLocation => text().nullable()();

  /// Coordinates (WGS84) of this leg's endpoints, when known — filled in by the
  /// connection search from the routing service, null for a hand-entered leg.
  /// Nothing renders them yet; they are stored so a future map can draw the leg
  /// without having to re-geocode its stations.
  RealColumn get fromLat => real().nullable()();
  RealColumn get fromLon => real().nullable()();
  RealColumn get toLat => real().nullable()();
  RealColumn get toLon => real().nullable()();

  /// The routing provider's trip identifier for an imported leg, kept so the
  /// live-times refresh can re-query this exact trip and fill in the actual
  /// departure/arrival. Null for a hand-entered leg (nothing to refresh).
  TextColumn get sourceTripId => text().nullable()();

  /// The stops this leg passes through, encoded by `stopovers.dart` — written by
  /// the connection import, null for a hand-entered leg. Stored on the leg
  /// rather than in a table of their own so they are read offline, with the row
  /// they belong to, long after the routing service is out of reach.
  TextColumn get stopovers => text().nullable()();
}

/// A single cost. Attached to exactly one of: a single itinerary item (via
/// [itemId]), a group of items sharing one expense (via [groupId], e.g. a train
/// ticket covering several legs), or the trip as a whole (via [tripId]) for
/// costs that don't belong to any one place or leg. All three count toward the
/// trip's total the same way — the statistics engine only ever sees one row per
/// cost, so how it is attached never affects the maths.
class Costs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().nullable().references(
    ItineraryItems,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Set for costs shared across an [ItemGroups] group instead of a single item.
  IntColumn get groupId => integer().nullable().references(
    ItemGroups,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Set for trip-level costs that aren't tied to a specific itinerary item.
  IntColumn get tripId => integer().nullable().references(
    Trips,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Amount in the currency's minor unit (e.g. cents) to avoid float rounding.
  IntColumn get amountMinor => integer()();

  /// The currency the amount is in — a row in [Currencies]. Unlike a leg's
  /// transport mode, this can never be dropped: an amount with no currency says
  /// nothing, so the reference restricts the delete instead of nulling itself.
  IntColumn get currency =>
      integer().references(Currencies, #id, onDelete: KeyAction.restrict)();
  TextColumn get reason => text()();

  /// Name of the person who paid, or null if unassigned. Stored as text (like
  /// [reason]) so an expense keeps its payer even if the person is later
  /// removed; renaming a person repoints every expense they paid.
  TextColumn get paidBy => text().nullable()();

  /// Whether this expense has already been paid/settled. Defaults to false.
  BoolColumn get paid => boolean().withDefault(const Constant(false))();

  /// Marks the row as a **transfer** — money handed from one person to another
  /// (settling a debt) rather than money spent on the trip. A transfer is
  /// always trip-level, its [paidBy] is the sender and its single beneficiary
  /// the receiver, and it carries no [reason] (the category makes no sense for
  /// it). It moves the two people's balances and nothing else: totals, the
  /// paid/open split and the category breakdown all leave it out, because no
  /// money left the group. See `computeTripStats`.
  BoolColumn get isTransfer => boolean().withDefault(const Constant(false))();
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

  /// Whether the card is shown collapsed in the trip overview. Persisted so the
  /// collapse state is restored when reopening the trip or the app.
  BoolColumn get collapsed => boolean().withDefault(const Constant(false))();
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

/// Records which itinerary days the user has collapsed in the trip overview.
/// A day is derived from the itinerary (not its own entity), so only collapsed
/// days are stored, keyed by trip and the day normalized to midnight; the
/// absence of a row means the day is expanded (the default). Persisted so the
/// collapse state is restored when reopening the trip or the app.
class CollapsedDays extends Table {
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// The day, normalized to midnight (see `normalizeDay`).
  DateTimeColumn get day => dateTime()();

  @override
  Set<Column> get primaryKey => {tripId, day};
}

/// The modes of transport a leg can use, managed in settings and reused in the
/// item form's mode dropdown — the transport counterpart to [CostReasons], but
/// referenced by row id ([ItineraryItems.mode]) rather than by text, since a
/// leg carries no free-form mode of its own.
///
/// The database is seeded with one row per [TransportMode] (its `builtinKey`),
/// and the user may add more, or rename / re-icon / reorder / delete any of
/// them. A row's display label is its [name] when set, and otherwise the
/// localized label of its [builtinKey] — so a pristine built-in stays localized,
/// while a custom mode (or a renamed built-in) shows the text the user typed.
@DataClassName('TransportModeRow')
class TransportModes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The [TransportMode] value this row was seeded from (its `name`), or null
  /// for a user-created mode. Gives a built-in its localized label and default
  /// icon, and a stable identity that survives sharing across databases.
  TextColumn get builtinKey => text().nullable().unique()();

  /// The user-visible label. Null on a pristine built-in (whose label comes from
  /// [builtinKey] instead); set for a custom mode or a renamed built-in. Unique
  /// among the modes that have one, so no two read the same.
  TextColumn get name => text().nullable().unique()();

  /// Stable key into the curated icon set (`kTransportModeIcons`), or null to
  /// use the default icon. Not a font code point, so the set can change safely.
  IntColumn get iconId => integer().nullable()();

  /// Manual ordering for the picker and settings list.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// An exchange rate of exactly 1, in the fixed-point encoding [Currencies]
/// stores rates in: millionths of a unit of the base currency. Rates are held as
/// integers for the same reason amounts are held in minor units — a float would
/// round differently on every platform, and a rate is multiplied into money.
const int kRateOne = 1000000;

/// The currencies an expense can be recorded in, managed in settings and reused
/// in the expense form — the money counterpart to [TransportModes], and
/// referenced by row id ([Costs.currency]) rather than by text, since an amount
/// carries no currency of its own.
///
/// The database is seeded with one row per [Currency] built-in, and the user may
/// add more, or re-code / re-symbol / reorder / delete any of them. A currency
/// in use by an expense cannot be deleted (the reference is `restrict`, and
/// `CurrencyDao` checks before trying): unlike a transport mode, which a leg can
/// simply lose, an amount without a currency means nothing.
///
/// Exactly one row is the **base** ([isBase]), and every other row's
/// [rateMicros] says what one of its units is worth in that base. A rate is
/// optional: an unset one means the user has not told the app what the currency
/// is worth, and the app then declines to convert rather than guessing. The app
/// still computes every total per currency exactly as before — a converted
/// figure is only ever shown *beside* those, never instead of them.
@DataClassName('CurrencyRow')
class Currencies extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// ISO-ish code, e.g. `EUR`. Unique, and the currency's portable identity:
  /// it is what a shared trip carries instead of a row id.
  TextColumn get code => text().unique()();

  /// Symbol shown next to amounts, e.g. `€`. Free text — plenty of currencies
  /// have no symbol beyond their code, which is then simply repeated here.
  TextColumn get symbol => text()();

  /// What one unit of this currency is worth in the base currency, in millionths
  /// (see [kRateOne]) — so with base EUR, a USD worth €0.92 stores `920000`.
  /// Null when no rate has been set; the base row's own rate is [kRateOne] by
  /// definition.
  IntColumn get rateMicros => integer().nullable()();

  /// Marks the single currency every rate is expressed in. At most one row is
  /// true, enforced in `CurrencyDao` rather than by the schema (mirroring
  /// [People.isMe]). Travels with the database file.
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();

  /// Manual ordering for the expense form's picker and the settings list. Also
  /// the order per-currency totals are printed in.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
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

/// Distinct people who can pay for expenses, managed in settings and reused in
/// the expense form's payer dropdown. Kept independently of whether any expense
/// currently names them, mirroring [CostReasons].
@DataClassName('Person')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();

  /// Marks the single person the app's user identifies as, used to filter the
  /// trip overview down to "my" expenses. At most one row is true; setting a new
  /// "me" clears the previous one. Travels with the database file.
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
}

/// Links a person to a trip as a participant: a many-to-many between [Trips]
/// and [People]. A person can join many trips and a trip can have many
/// participants; the pair is unique. Deleting either side removes the link.
class TripParticipants extends Table {
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId =>
      integer().references(People, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {tripId, personId};
}

/// Links a person to a cost as a beneficiary: the people an expense was paid
/// *for* (its split). A many-to-many between [Costs] and [People]; the pair is
/// unique and deleting either side removes the link. Independent of
/// [Costs.paidBy], which records who *paid*.
class CostBeneficiaries extends Table {
  IntColumn get costId =>
      integer().references(Costs, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId =>
      integer().references(People, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {costId, personId};
}
