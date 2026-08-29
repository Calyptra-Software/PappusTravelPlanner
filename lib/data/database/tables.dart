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

/// Whether a [Trips] row is a trip or the template for one.
///
/// Deliberately *not* a scale: a trip is a trip whether it runs for a fortnight
/// or for the twenty minutes it takes to cycle to work, and the dates already
/// say which — a walk is simply a trip whose start and end are the same day.
/// What the app cannot derive from the dates is whether a plan is meant to be
/// *used again*, and that is the whole of this column. How a trip is sorted,
/// grouped or found is a matter for [Tags], which the user controls.
///
/// Persisted by integer index like every other stored enum here, so only ever
/// append new values at the end.
enum TripKind {
  /// An actual trip, on the calendar: every row written before this column, and
  /// everything the app shows in the overview, the widget and the exports.
  trip,

  /// A standing plan with no dates: the commute, the Saturday ride, the yearly
  /// route to the cabin. A template, not a log — its occurrences are
  /// **virtual**, and nothing is written for a day that simply went as the
  /// routine says. Recording one is explicit (`RoutineDao.materializeRoutine`),
  /// which copies the plan onto real dates as a [trip] of its own.
  ///
  /// Having no dates, a routine's items are laid out relative to
  /// [kRoutineAnchorDay]: day *n* of the routine sits on the anchor plus *n*
  /// days, so a multi-day routine needs no column of its own — the date it
  /// already has carries the offset, and every query, day block and reorder
  /// works on it unchanged.
  routine,
}

/// Day one of a [TripKind.routine], the day its [ItineraryItems] are laid out
/// from. A routine has no dates, but an item must have one
/// ([ItineraryItems.date] is not nullable — making it nullable would push a
/// null check into every query, every day block, the now-marker and the widget
/// to serve one kind), so day *n* sits on this day plus *n*. The absolute value
/// is never shown: a routine's days read as "Day 1", "Day 2".
final DateTime kRoutineAnchorDay = DateTime(1970, 1, 1);

/// A planned trip. Dates are optional so a trip can be sketched out before the
/// exact days are known — and a [TripKind.routine] has none at all.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get destination => text().withDefault(const Constant(''))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  /// Whether this is a trip or a template for one. Defaults to [TripKind.trip]
  /// so every row written before the column existed keeps its behaviour.
  IntColumn get kind => intEnum<TripKind>().withDefault(const Constant(0))();

  /// The [TripKind.routine] this trip was created from, when it was. Records
  /// where the plan came from — enough to warn before recording the same
  /// routine twice on one day, and to list what a routine has produced.
  /// `setNull` on delete: a trip that happened does not stop having happened
  /// because the template it came from was thrown away.
  IntColumn get fromRoutineId => integer().nullable().references(
    Trips,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// ARGB colour used as the card accent, e.g. 0xFF00695C.
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF00695C))();

  /// The photograph shown on this trip's overview card, when the user has
  /// picked one. Null means they have not, and the card falls back to the first
  /// picture in gallery order — see [coverHidden] for the third state.
  ///
  /// **Deliberately not a foreign key.** [Attachments] already references
  /// [Trips], so declaring the reverse would put the two tables in a *cycle* —
  /// and drift answers a cycle by silently dropping foreign keys until it can
  /// order its `CREATE TABLE`s again. Measured: adding it took the reference off
  /// `item_groups.trip_id` and `alternative_sets.trip_id` among others, so
  /// deleting a trip stopped cascading to its groups and its decisions. Losing
  /// half the schema's cascades to gain one `setNull` is not a trade; the
  /// invariant it would have enforced is cheap to live without instead.
  ///
  /// A deleted picture therefore leaves its id behind here, and nothing trusts
  /// it: `coverPhoto` looks the id up in the gallery it was handed and falls
  /// back to the derived photograph when it is not there. The id can never come
  /// to mean a *different* picture either, since `attachments.id` is
  /// `AUTOINCREMENT` and SQLite never reissues one.
  IntColumn get coverAttachmentId => integer().nullable()();

  /// Whether the overview card is to show **no** photograph at all, even though
  /// the trip has some.
  ///
  /// The third state, and the reason [coverAttachmentId] cannot carry this
  /// alone: null there means "nothing chosen", which is not the same statement
  /// as "nothing wanted". A trip whose pictures are all of receipts has photos
  /// and no cover, and deriving one anyway would be the app overruling that.
  ///
  /// Invariant, kept by `TripDao`: this being true implies [coverAttachmentId]
  /// is null. Hiding clears the choice rather than parking it, so no two
  /// columns can disagree about what the card shows — un-hiding returns to the
  /// derived picture, not to a remembered one nothing on screen could have
  /// hinted at.
  BoolColumn get coverHidden => boolean().withDefault(const Constant(false))();

  /// Whether the strip of photographs on the trip screen is shown collapsed.
  ///
  /// A column here rather than a table of its own — the shape [CollapsedDays]
  /// needs, because a trip has many days and only ever one photo strip — and in
  /// the database rather than in preferences, because this is per-trip state and
  /// that is where [Checklists.collapsed] and [CollapsedDays] both keep theirs:
  /// it belongs to the file the trip lives in, and travels with it when the
  /// database does.
  ///
  /// Defaults to false, so a trip that has never been told otherwise shows its
  /// photographs — the strip is how the gallery is found at all.
  BoolColumn get photosCollapsed =>
      boolean().withDefault(const Constant(false))();
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

  /// ARGB color this entry is drawn in **on the map**, or null to be drawn in
  /// the trip's own accent — which is what every entry written before this
  /// existed means, and what the great majority go on meaning.
  ///
  /// The one property of an entry that is purely about how it is *drawn*: the
  /// line of a leg (whichever line that is — its recorded track when it has one,
  /// the segment between its ends when it has not) and the pin of a place. It
  /// says nothing about the plan, which is why nothing outside the map reads it:
  /// the timeline, the PDF and the totals are unaffected, and a trip whose
  /// entries are all uncolored looks exactly as it did.
  ///
  /// Deliberately **not** on [Tracks]: a line has to be colorable before there
  /// is a track to hang the color on — the straight segment is the ordinary
  /// case — and an entry that later gains a recording would otherwise lose the
  /// color it was given. One entry, one color, however it is drawn.
  IntColumn get colorValue => integer().nullable()();

  // --- place-only ---
  TextColumn get location => text().nullable()();

  /// Coordinates (WGS84) of this place, when known — what the user pointed at on
  /// the map, null for a place that was only named.
  ///
  /// Deliberately independent of [location]: that is what the user *wrote*, and
  /// the app never turns a name into a position by itself. A place keeps its name
  /// when the coordinates are cleared, and keeps the coordinates when it is
  /// renamed, because the two answer different questions.
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();

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
  ///
  /// It names **one dated run of one service**, so it is the one imported field
  /// that must never be copied onto another day — see [fromPlaceId] for what is
  /// kept instead.
  TextColumn get sourceTripId => text().nullable()();

  /// How the routing service addresses this leg's endpoints — the `queryId` of
  /// the places the search was issued against: a stop id, or a `"lat,lon"` pair
  /// for an address or point of interest.
  ///
  /// Unlike [sourceTripId] these say nothing about *when*, so they survive a
  /// copy and are what lets a leg be searched again for another date — which is
  /// how a routine's journey becomes a real, refreshable connection when it is
  /// materialized. The coordinates alone would nearly do it, but a station
  /// addressed by its stop id routes from the platform, whereas the same
  /// station addressed by coordinate routes from a point outside it and picks
  /// up a spurious walk. Null for a hand-entered leg.
  TextColumn get fromPlaceId => text().nullable()();
  TextColumn get toPlaceId => text().nullable()();

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

/// A country the user says they have been to, without a trip in this app to
/// show for it.
///
/// The app derives most of them: an entry with coordinates stands in a country,
/// and that is that. But a life has journeys in it that were never planned here
/// — everything before the app existed, and everything nobody bothered to file
/// — and a map that can only show what happens to be typed in is not a record of
/// where somebody has been.
///
/// A row here is therefore a **statement**, not a derivation, which is exactly
/// why it is a table of its own rather than a flag on something: the two answers
/// come from different places and must not be able to overwrite each other.
/// Removing the mark leaves any trip-derived visit standing, and adding one
/// changes nothing about the trips. On the map they are drawn identically —
/// having been somewhere is having been somewhere, and a second shade would be
/// the app disagreeing with the user about their own past.
///
/// Keyed by the code of `assets/geo/countries.json`, which is ISO 3166-1
/// alpha-2 where the source has one. A code the current outline set does not
/// know is kept rather than dropped: the set may be replaced by a finer one, and
/// a mark nobody can currently draw is still something the user said.
@DataClassName('VisitedCountry')
class VisitedCountries extends Table {
  TextColumn get code => text()();
  DateTimeColumn get markedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {code};
}

/// Where a track's line came from.
///
/// Persisted by integer index like every other stored enum here, so only ever
/// append new values at the end.
enum TrackSource {
  /// Read out of a GPX file the user picked. What most tracks are, and the only
  /// one the app can make today.
  imported,

  /// Recorded by this app from the device's own position. Not built yet — it
  /// needs the first runtime permission in the app — but named here because the
  /// distinction is about the *line*, and a table that cannot express it would
  /// have to be migrated to say "this one was actually walked".
  recorded,

  /// Computed by a router: the road or path between two ends, rather than a
  /// record of anyone travelling it.
  routed,
}

/// Whether a stored line is drawn on the map, when the default is not what the
/// user wants.
///
/// Three states in one column, the arrangement `Trips.coverAttachmentId` /
/// `coverHidden` makes for the cover photo: [auto] is where every line starts
/// and is what every row written before this meant, and the other two are the
/// user overruling it. Persisted by **index**, so only ever append.
///
/// The default ([auto]) is the rule the map has always followed — what was
/// followed supersedes what a router proposed — and it is right nearly always.
/// What it cannot know is that a recording is wrong *here*: a tunnel takes the
/// fix, the trace jumps the block, and the computed route beside it is the
/// better drawing of that stretch. Deleting the recording to get at it would
/// throw away the thing that actually happened, so the line is [hidden] instead
/// and stays in the row, in every copy and in the bundle. [shown] is the other
/// direction: a routed line drawn *beside* a recording, which the default
/// suppresses — a trace broken in two by that same tunnel plus the route that
/// bridges it is one picture of one journey, and only the user can say so.
enum TrackDisplay {
  /// The map decides, by the rule it has always used.
  auto,

  /// Drawn, whatever the other lines on the entry are doing.
  shown,

  /// Not drawn, whatever it is.
  hidden,
}

/// The actual line an itinerary entry followed, as opposed to the straight
/// segment the map otherwise draws between its ends.
///
/// A *line with a provenance*, deliberately not "the GPX file": a recorded walk,
/// an imported route and a path a router computed later are the same row wearing
/// different [source] values, so nothing has to be migrated when the second and
/// third arrive. What is stored is the geometry and nothing else — [points] is
/// the packed encoding from `track_points.dart`, and elevation, timestamps and
/// the file's own markup are dropped on the way in (see `parseGpx` for why each
/// of those is a deliberate omission rather than an oversight).
///
/// One row per line, so a GPX whose recording stopped and started again arrives
/// as several rows under one [name]: joining them would draw a line through
/// ground nobody covered, which is the same rule the map already follows between
/// two places.
///
/// Hangs off an **item**, not a trip: a track is what *this leg* actually
/// followed, and it travels with the leg through every copy the app makes (see
/// `copyItemTracks`). Cascades with it, since a line with no leg under it
/// describes nothing.
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId =>
      integer().references(ItineraryItems, #id, onDelete: KeyAction.cascade)();

  /// Where the line came from. Defaults to [TrackSource.imported], which is
  /// what every row written today is.
  IntColumn get source =>
      intEnum<TrackSource>().withDefault(const Constant(0))();

  /// The name the file gave this line, when it had one. Not defaulted to
  /// anything: an unnamed track reads as the leg it is on, which is more than a
  /// made-up "Track 1" would say.
  TextColumn get name => text().nullable()();

  /// The line itself, packed by `encodeTrackPoints`. Never XML: the file was a
  /// transport, and keeping it would mean re-parsing foreign markup on every
  /// draw.
  TextColumn get points => text()();

  /// Whether the map draws this line — see [TrackDisplay]. Defaults to
  /// [TrackDisplay.auto], which is what every row written before v36 means.
  IntColumn get display =>
      intEnum<TrackDisplay>().withDefault(const Constant(0))();

  /// Manual ordering among the tracks of one item, appended at the end — a leg
  /// can carry the walk out of the station and the walk into the next one.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
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

/// A user-defined label a trip can be filed under: "walks", "bike rides",
/// "vacation", "commute".
///
/// Tags are how the overview is kept navigable, and they are deliberately the
/// *only* such axis: the app does not decide that a bike ride is a lesser kind
/// of trip than a holiday, because that judgement is the user's and differs
/// from person to person. Managed like [CostReasons] and [People] — a reusable
/// roster kept independently of whether any trip currently uses a row.
///
/// Nothing may *behave* differently because of a tag. A tag is renameable and
/// deletable, so hanging logic off one would break the moment it was renamed;
/// what the app must branch on lives in [Trips.kind] instead.
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The tag's identity, so the same label cannot exist twice.
  TextColumn get name => text().unique()();

  /// ARGB colour for the tag's chip, so a row of them is scannable at a glance.
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF546E7A))();

  /// Manual ordering for the filter bar, so the tags used daily can be put
  /// first.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Links a tag to a trip: a many-to-many between [Trips] and [Tags], exactly as
/// [TripParticipants] links people. A trip can carry any number of tags and a
/// tag any number of trips; the pair is unique and deleting either side removes
/// the link.
class TripTags extends Table {
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {tripId, tagId};
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

/// What the app *does* with an attachment.
///
/// Deliberately not derived from [Attachments.mimeType]: that string is what
/// gets handed back to the operating system when the file is opened or shared,
/// and it comes from a picker rather than from us. This is the app's own
/// reading — a photo is shown, thumbnailed, and drawn on the map when it
/// carries a position; a document is a row with an icon and a way out to
/// whatever program owns the format.
///
/// Persisted by integer index like every other stored enum here, so only ever
/// append new values at the end.
enum AttachmentKind {
  /// A picture, re-encoded on the way in (see `attachment_import.dart`).
  photo,

  /// Anything else, stored byte for byte: a ticket PDF, a booking confirmation,
  /// a scan. The app cannot make it smaller and does not pretend to understand
  /// it.
  document,
}

/// Where an attachment's position came from.
///
/// A provenance, for the reason [TrackSource] is one: the two answers are not
/// equally strong. A camera's own reading is a measurement of where the camera
/// was, which is *near* the subject and may be minutes and metres off; a
/// position the user pointed at on the map is a statement about where the photo
/// belongs. Neither is corrected by the other, and the form says which it is
/// holding rather than presenting both as the same fact.
///
/// Null exactly when there is no position. Persisted by integer index, so only
/// ever append new values at the end.
enum AttachmentPositionSource {
  /// Read out of the file's own EXIF on import, and shown as such.
  exif,

  /// Pointed at on the map, or moved there after an EXIF reading was wrong.
  picked,
}

/// A file the user hung on part of their plan: a photo of the place, the ticket
/// for the run, a booking confirmation.
///
/// **The bytes live in the database.** Not beside it: one portable SQLite file
/// is what the app *is*, and an attachment kept in a sidecar directory would
/// mean every copy, backup and export that has ever worked silently stops
/// carrying everything — the file would go on claiming to be the whole trip. The
/// price is paid on the way in instead: a photo is re-encoded to a bounded size
/// and a document is capped (see `attachment_import.dart`), because the whole
/// database is read into memory to be exported on Android and on the web, which
/// is the real ceiling here and not disk space.
///
/// **It belongs to exactly one of an item, a group, or the trip**, the way a
/// [Costs] row does and for the same reason: a ticket covers the run and not
/// one leg of it, and a passport scan belongs to the journey and not to
/// Tuesday's train, so the unit the file belongs to is the unit it hangs off.
/// All three columns cascade — unlike [ItineraryItems.groupId], which is nulled
/// when a group dissolves, because an item outlives its group and an attachment
/// of that group does not.
///
/// The trip level is also where a **routine's** own paperwork goes, and the one
/// level that travels when the routine is stamped out (`materializeRoutine`).
/// That rule is by *level* and not by kind, because the level is something the
/// user chose deliberately: on the routine means "needed every time", on a leg
/// means "about that one morning". The app cannot tell a season ticket from a
/// scanned receipt, and does not try.
///
/// The payload sits in [AttachmentBlobs] rather than here, so that listing what
/// an entry carries — which the timeline does for every visible day, in a
/// stream — does not drag the originals off disk with it. What this table holds
/// is what a list needs: the name, the size, and a [thumbnail] small enough to
/// ride along.
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The entry this hangs off, or null when it belongs to a [groupId] instead.
  IntColumn get itemId => integer().nullable().references(
    ItineraryItems,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// The run this hangs off, or null when it belongs to a single [itemId].
  IntColumn get groupId => integer().nullable().references(
    ItemGroups,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Set for a file that belongs to the whole trip rather than to any one part
  /// of it: the insurance, the passport scan, the visa, a routine's season
  /// ticket. Null when it hangs on an [itemId] or a [groupId] instead.
  IntColumn get tripId => integer().nullable().references(
    Trips,
    #id,
    onDelete: KeyAction.cascade,
  )();

  IntColumn get kind => intEnum<AttachmentKind>()();

  /// The media type, kept to hand the file back to the platform when it is
  /// opened or shared. Ours for a photo (the app re-encoded it and knows what it
  /// wrote); the picker's for a document, which is a claim about a file we did
  /// not write and is treated as one.
  TextColumn get mimeType => text()();

  /// The name the file arrived under, when it had one — as with [Tracks.name],
  /// not defaulted to anything, since an unnamed attachment reads as the entry
  /// it hangs on and that says more than "Attachment 1" would.
  TextColumn get name => text().nullable()();

  /// The size of what is stored, in bytes. Denormalised from the blob on
  /// purpose: it is the one number a list has to show, and reading it off the
  /// payload would mean loading the payload.
  IntColumn get byteSize => integer()();

  /// Pixel dimensions of a photo, so a viewer can lay out space for it before
  /// the bytes arrive. Null for a document.
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();

  /// Where the photo was taken, when that is known — read from the file's EXIF
  /// or pointed at on the map, see [positionSource]. Null for everything else,
  /// and deliberately **not** inherited from the entry it hangs on: the entry
  /// already has a pin there, and a second one at the same spot would be the app
  /// claiming to know where a picture was taken.
  ///
  /// A pair, like a place's own coordinates: half of one is not half a position,
  /// so the two are written and cleared together.
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();

  /// Which of the two the position above is. Null exactly when there is none.
  IntColumn get positionSource =>
      intEnum<AttachmentPositionSource>().nullable()();

  /// A small copy of a photo, for lists and for the map marker. Null for a
  /// document, which has nothing to show but its icon.
  ///
  /// Stored rather than derived: decoding a full-size photo to draw it at 40 px
  /// is the shape of the pinch freeze this app has already been through, and
  /// on the web there is no disk cache to fall back on.
  BlobColumn get thumbnail => blob().nullable()();

  /// Manual ordering among the attachments of one owner, appended at the end.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// The payload of one [Attachments] row — the only place a full-size file is
/// held.
///
/// A table of its own purely so that reading *about* an attachment is not
/// reading it: drift selects every column of a table it is asked for, so a
/// stream over the attachments of a day would otherwise carry every photo in
/// that day on every rebuild.
class AttachmentBlobs extends Table {
  IntColumn get attachmentId =>
      integer().references(Attachments, #id, onDelete: KeyAction.cascade)();
  BlobColumn get bytes => blob()();

  @override
  Set<Column> get primaryKey => {attachmentId};
}
