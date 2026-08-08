import 'dart:convert';
import 'dart:typed_data';

import '../../core/format/money_format.dart';
import '../../data/database/tables.dart' show ItemKind, TripKind;

/// MIME type used when sharing a trip bundle. Custom (vendor) type so the app's
/// share-sheet intent filter matches only Travel Planner trips, not every
/// binary file. Tapped `.tpt` files arrive as `application/octet-stream`
/// instead (the OS can't infer a type from the unknown extension), which the
/// `ACTION_VIEW` filter handles separately.
const String tripBundleMimeType = 'application/x-pappus-trip';

/// File extension for a shared trip bundle.
const String tripBundleExtension = 'tpt';

/// A self-contained, portable snapshot of a single trip and everything hanging
/// off it, used to share a trip with another user of the app.
///
/// The bundle is a cross-device interchange format, deliberately decoupled from
/// the local SQLite schema's autoincrement IDs:
///
/// - Trip-internal relationships (an item's group, a cost's item/group, a
///   checklist's items) are preserved using the **source database's row IDs as
///   opaque local keys** ([BundleGroup.localId] etc.). The importer remaps these
///   to fresh IDs; their absolute values are meaningless to the recipient.
/// - References to the app's **global** tables — [People] (participants,
///   `paidBy`, beneficiaries), [CostReasons] and [Currencies] — are denormalized
///   to their natural string keys (name / label / code) so the recipient doesn't
///   need matching IDs. Reason icons ride along in [reasonIcons] keyed by label,
///   and the currencies themselves in [currencies].
/// - Enums are serialized by their `name`, not their persisted integer index, so
///   an unknown or newly-appended value from a sender on a different app version
///   can be detected rather than silently misread.
///
/// This file is pure (no database or I/O), mirroring `trip_stats.dart`, so the
/// serialization round-trip is unit-testable without a database.
class TripBundle {
  const TripBundle({
    this.formatVersion = currentFormatVersion,
    required this.schemaVersion,
    required this.trip,
    this.groups = const [],
    this.alternativeSets = const [],
    this.items = const [],
    this.costs = const [],
    this.checklists = const [],
    this.collapsedDays = const [],
    this.participants = const [],
    this.tags = const [],
    this.reasonIcons = const {},
    this.modeIcons = const {},
    this.currencies = kBuiltinBundleCurrencies,
  });

  /// Version of the bundle format itself. Bump when the JSON shape changes in a
  /// way importers must branch on. Independent of the database [schemaVersion].
  ///
  /// v2 added [alternativeSets]. An exporter only *stamps* v2 on a trip that
  /// actually has alternatives (see `SharingDao.exportTrip`): an older app would
  /// drop the decisions it can't read and silently flatten every option's items
  /// into the day, so it must refuse such a bundle — but there is no reason to
  /// stop it reading an ordinary trip, which still goes out as v1.
  ///
  /// v3 turned the currencies into a managed list ([currencies]) and made
  /// [BundleCost.currency] a currency *code*. The same rule applies: a cost in
  /// one of the four currencies the old enum knew is still written under that
  /// enum's name, so an ordinary trip stays readable by an older app and only a
  /// trip using a currency the user added goes out as v3.
  ///
  /// v4 added [BundleTrip.kind], [tags], and a leg's place ids — a trip may now
  /// be a *routine*, a plan with no dates, and may be filed under tags. Same
  /// rule again: an ordinary trip goes out unchanged, because the kind an older
  /// app reads it as is exactly what it is, and tags it cannot see are only a
  /// filing it will not have. A **routine**, though, forces v4 and must be
  /// refused by an older app rather than silently imported as a dated trip
  /// whose entries all sit on a 1970 anchor day.
  static const int currentFormatVersion = 4;

  /// Magic string identifying the payload as a Travel Planner trip bundle.
  static const String kind = 'travelplanner.trip';

  final int formatVersion;

  /// `AppDatabase.schemaVersion` of the database this bundle was exported from.
  /// The importer uses it to refuse bundles from a newer app it can't read.
  final int schemaVersion;

  final BundleTrip trip;

  /// The names of the tags this trip is filed under. Denormalized to strings
  /// like the participants and the cost reasons, because a tag's identity is
  /// its name and the recipient's row ids are their own. A tag the recipient
  /// has never used is created on import; one they already have is reused,
  /// keeping their own colour and ordering.
  final List<String> tags;
  final List<BundleGroup> groups;

  /// The trip's decisions, each carrying its options. Items point back at an
  /// option through [BundleItem.alternativeLocalId].
  final List<BundleAlternativeSet> alternativeSets;
  final List<BundleItem> items;
  final List<BundleCost> costs;
  final List<BundleChecklist> checklists;

  /// Itinerary days (normalized to midnight) the user had collapsed.
  final List<DateTime> collapsedDays;

  /// Participant names, resolved to/from the global [People] table on the ends.
  final List<String> participants;

  /// Icon id for each reason label used by this trip's costs, so shared reasons
  /// keep their icon on import. Only labels with a non-null icon appear.
  final Map<String, int> reasonIcons;

  /// Icon id for each **custom** transport mode used by this trip's legs, keyed
  /// by the mode's name (its portable key in [BundleItem.mode]), so a shared
  /// custom mode keeps its icon on import. Built-in modes aren't listed — they
  /// take their icon from their key. Only custom modes with a non-null icon
  /// appear.
  final Map<String, int> modeIcons;

  /// The currencies this trip's costs are recorded in, plus the sender's base
  /// one — enough for the recipient (and the PDF and `.ics` builders, which see
  /// only the bundle) to label every amount and, where the rates allow it,
  /// convert. Defaults to [kBuiltinBundleCurrencies] so a bundle written before
  /// currencies were managed still prints its amounts with a symbol.
  final List<BundleCurrency> currencies;

  /// [currencies] as the pure [CurrencyBook] the exports format with. Costs name
  /// their currency by code, so the book is looked up the same way there.
  CurrencyBook get currencyBook => CurrencyBook([
    for (final c in currencies)
      CurrencyInfo(
        code: c.code,
        symbol: c.symbol,
        rateMicros: c.rateMicros,
        isBase: c.isBase,
      ),
  ]);

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'formatVersion': formatVersion,
    'tags': tags,
    'schemaVersion': schemaVersion,
    'trip': trip.toJson(),
    'groups': [for (final g in groups) g.toJson()],
    'alternativeSets': [for (final s in alternativeSets) s.toJson()],
    'items': [for (final i in items) i.toJson()],
    'costs': [for (final c in costs) c.toJson()],
    'checklists': [for (final c in checklists) c.toJson()],
    'collapsedDays': [for (final d in collapsedDays) _encodeDate(d)],
    'participants': participants,
    'reasonIcons': reasonIcons,
    'modeIcons': modeIcons,
    'currencies': [for (final c in currencies) c.toJson()],
  };

  factory TripBundle.fromJson(Map<String, dynamic> json) {
    final k = json['kind'];
    if (k != kind) {
      throw const FormatException('Not a Travel Planner trip bundle.');
    }
    return TripBundle(
      formatVersion: json['formatVersion'] as int,
      tags: [for (final t in (json['tags'] as List? ?? const [])) t as String],
      schemaVersion: json['schemaVersion'] as int,
      trip: BundleTrip.fromJson(json['trip'] as Map<String, dynamic>),
      groups: [
        for (final g in (json['groups'] as List? ?? const []))
          BundleGroup.fromJson(g as Map<String, dynamic>),
      ],
      alternativeSets: [
        for (final s in (json['alternativeSets'] as List? ?? const []))
          BundleAlternativeSet.fromJson(s as Map<String, dynamic>),
      ],
      items: [
        for (final i in (json['items'] as List? ?? const []))
          BundleItem.fromJson(i as Map<String, dynamic>),
      ],
      costs: [
        for (final c in (json['costs'] as List? ?? const []))
          BundleCost.fromJson(c as Map<String, dynamic>),
      ],
      checklists: [
        for (final c in (json['checklists'] as List? ?? const []))
          BundleChecklist.fromJson(c as Map<String, dynamic>),
      ],
      collapsedDays: [
        for (final d in (json['collapsedDays'] as List? ?? const []))
          _decodeDate(d as String)!,
      ],
      participants: [
        for (final p in (json['participants'] as List? ?? const []))
          p as String,
      ],
      reasonIcons: {
        for (final e in (json['reasonIcons'] as Map? ?? const {}).entries)
          e.key as String: e.value as int,
      },
      modeIcons: {
        for (final e in (json['modeIcons'] as Map? ?? const {}).entries)
          e.key as String: e.value as int,
      },
      // Absent in bundles written before currencies were managed; those only
      // ever held the four built-ins, which is exactly the fallback.
      currencies: json['currencies'] == null
          ? kBuiltinBundleCurrencies
          : [
              for (final c in (json['currencies'] as List))
                BundleCurrency.fromJson(c as Map<String, dynamic>),
            ],
    );
  }

  /// Encodes the bundle to UTF-8 JSON bytes, ready to write to a file or hand to
  /// a share sheet.
  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// Decodes a bundle from UTF-8 JSON [bytes]. Throws [FormatException] if the
  /// bytes aren't a valid trip bundle.
  factory TripBundle.decode(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Malformed trip bundle.');
    }
    return TripBundle.fromJson(decoded);
  }
}

/// Thrown when a bundle can't be imported because it was produced by a newer
/// version of the app than the one importing it — the importer can't be sure it
/// understands the format, so it refuses rather than silently dropping data.
class IncompatibleBundleException implements Exception {
  const IncompatibleBundleException(this.message);
  final String message;
  @override
  String toString() => 'IncompatibleBundleException: $message';
}

/// The trip row itself. `id` is intentionally omitted — the importer always
/// inserts a fresh trip.
class BundleTrip {
  const BundleTrip({
    required this.title,
    required this.destination,
    this.startDate,
    this.endDate,
    this.notes,
    this.kind = TripKind.trip,
    required this.colorValue,
    required this.createdAt,
  });

  final String title;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;

  /// Whether this is a trip or a routine. Written by `name` like every other
  /// enum here, and defaulted to [TripKind.trip] when absent — which is exactly
  /// what a bundle written before v4 holds.
  final TripKind kind;

  final int colorValue;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'destination': destination,
    'startDate': _encodeDate(startDate),
    'endDate': _encodeDate(endDate),
    'notes': notes,
    'kind': kind.name,
    'colorValue': colorValue,
    'createdAt': _encodeDate(createdAt),
  };

  factory BundleTrip.fromJson(Map<String, dynamic> json) => BundleTrip(
    title: json['title'] as String,
    destination: json['destination'] as String? ?? '',
    startDate: _decodeDate(json['startDate'] as String?),
    endDate: _decodeDate(json['endDate'] as String?),
    notes: json['notes'] as String?,
    // An unknown kind from a newer sender reads as an ordinary trip rather
    // than throwing: the plan is all there, and a trip is the shape that shows
    // every entry of it.
    kind: TripKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => TripKind.trip,
    ),
    colorValue: json['colorValue'] as int,
    createdAt: _decodeDate(json['createdAt'] as String)!,
  );
}

/// An [ItemGroups] row. [localId] is the source row id, used only to link items
/// and costs within the bundle.
class BundleGroup {
  const BundleGroup({
    required this.localId,
    this.label,
    this.collapsed = false,
  });

  final int localId;
  final String? label;
  final bool collapsed;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'label': label,
    'collapsed': collapsed,
  };

  factory BundleGroup.fromJson(Map<String, dynamic> json) => BundleGroup(
    localId: json['localId'] as int,
    label: json['label'] as String?,
    collapsed: json['collapsed'] as bool? ?? false,
  );
}

/// An [AlternativeSets] row together with its [Alternatives]: one decision on one
/// day and the competing options it holds. [localId] links the options' items
/// back to it within the bundle.
class BundleAlternativeSet {
  const BundleAlternativeSet({
    required this.localId,
    required this.date,
    this.sortOrder = 0,
    this.label,
    this.alternatives = const [],
  });

  final int localId;
  final DateTime date;
  final int sortOrder;
  final String? label;

  /// The options, in swipe order. Exactly one is [BundleAlternative.chosen].
  final List<BundleAlternative> alternatives;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'date': _encodeDate(date),
    'sortOrder': sortOrder,
    'label': label,
    'alternatives': [for (final a in alternatives) a.toJson()],
  };

  factory BundleAlternativeSet.fromJson(Map<String, dynamic> json) =>
      BundleAlternativeSet(
        localId: json['localId'] as int,
        date: _decodeDate(json['date'] as String)!,
        sortOrder: json['sortOrder'] as int? ?? 0,
        label: json['label'] as String?,
        alternatives: [
          for (final a in (json['alternatives'] as List? ?? const []))
            BundleAlternative.fromJson(a as Map<String, dynamic>),
        ],
      );
}

/// One option of a [BundleAlternativeSet]. [localId] is the source row id, which
/// the bundle's items refer to via [BundleItem.alternativeLocalId].
class BundleAlternative {
  const BundleAlternative({
    required this.localId,
    this.label,
    this.sortOrder = 0,
    this.chosen = false,
  });

  final int localId;
  final String? label;
  final int sortOrder;

  /// Whether this is the option the plan follows. Only its items' costs count
  /// toward the trip, so this flag carries real money with it.
  final bool chosen;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'label': label,
    'sortOrder': sortOrder,
    'chosen': chosen,
  };

  factory BundleAlternative.fromJson(Map<String, dynamic> json) =>
      BundleAlternative(
        localId: json['localId'] as int,
        label: json['label'] as String?,
        sortOrder: json['sortOrder'] as int? ?? 0,
        chosen: json['chosen'] as bool? ?? false,
      );
}

/// An [ItineraryItems] row (place or transport leg). [localId] is the source row
/// id; [groupLocalId] refers to a [BundleGroup.localId] within the same bundle,
/// and [alternativeLocalId] to a [BundleAlternative.localId] when the item is
/// planned inside one of a decision's options rather than loose on its day.
class BundleItem {
  const BundleItem({
    required this.localId,
    this.groupLocalId,
    this.alternativeLocalId,
    required this.date,
    this.sortOrder = 0,
    required this.kind,
    this.title,
    this.startMinutes,
    this.endMinutes,
    this.actualStartMinutes,
    this.actualEndMinutes,
    this.spansNextDay = false,
    this.notes,
    this.location,
    this.mode,
    this.fromLocation,
    this.toLocation,
    this.stopovers,
    this.fromPlaceId,
    this.toPlaceId,
  });

  final int localId;
  final int? groupLocalId;
  final int? alternativeLocalId;
  final DateTime date;
  final int sortOrder;
  final ItemKind kind;
  final String? title;
  final int? startMinutes;
  final int? endMinutes;

  /// When the entry really started/ended. Absent from bundles written before
  /// they were recorded at all, and simply unset on import then.
  final int? actualStartMinutes;
  final int? actualEndMinutes;

  /// Whether the entry's end falls on the day after [date] — an overnight leg.
  /// Absent from bundles written before it was recorded, and read as false then,
  /// which is what such a bundle meant.
  final bool spansNextDay;
  final String? notes;

  // place-only
  final String? location;

  // transport-only
  /// The leg's transport mode as a portable key: a built-in's `builtinKey`
  /// (e.g. "train") or a custom mode's name. Resolved to a local mode row on
  /// import; null when the leg has no mode. A custom mode's icon rides along in
  /// [TripBundle.modeIcons].
  final String? mode;
  final String? fromLocation;
  final String? toLocation;

  /// The leg's intermediate stops, in the encoding `stopovers.dart` reads — the
  /// one part of a routed leg that is content rather than provenance, so it
  /// travels while the routing trip id does not. Null for a leg with none.
  final String? stopovers;

  /// How the routing service addresses this leg's ends, when it came from a
  /// search. Part of the plan — they say *where*, never *when* — so they travel
  /// with it and let the recipient look the journey up for their own dates.
  /// `sourceTripId` deliberately does not travel: it names one dated run.
  final String? fromPlaceId;
  final String? toPlaceId;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'groupLocalId': groupLocalId,
    'alternativeLocalId': alternativeLocalId,
    'date': _encodeDate(date),
    'sortOrder': sortOrder,
    'kind': kind.name,
    'title': title,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'actualStartMinutes': actualStartMinutes,
    'actualEndMinutes': actualEndMinutes,
    'spansNextDay': spansNextDay,
    'notes': notes,
    'location': location,
    'mode': mode,
    'fromLocation': fromLocation,
    'toLocation': toLocation,
    'stopovers': stopovers,
    'fromPlaceId': fromPlaceId,
    'toPlaceId': toPlaceId,
  };

  factory BundleItem.fromJson(Map<String, dynamic> json) => BundleItem(
    localId: json['localId'] as int,
    groupLocalId: json['groupLocalId'] as int?,
    alternativeLocalId: json['alternativeLocalId'] as int?,
    date: _decodeDate(json['date'] as String)!,
    sortOrder: json['sortOrder'] as int? ?? 0,
    kind: _enumByName(ItemKind.values, json['kind'] as String),
    title: json['title'] as String?,
    startMinutes: json['startMinutes'] as int?,
    endMinutes: json['endMinutes'] as int?,
    actualStartMinutes: json['actualStartMinutes'] as int?,
    actualEndMinutes: json['actualEndMinutes'] as int?,
    spansNextDay: json['spansNextDay'] as bool? ?? false,
    notes: json['notes'] as String?,
    location: json['location'] as String?,
    mode: json['mode'] as String?,
    fromLocation: json['fromLocation'] as String?,
    toLocation: json['toLocation'] as String?,
    stopovers: json['stopovers'] as String?,
    fromPlaceId: json['fromPlaceId'] as String?,
    toPlaceId: json['toPlaceId'] as String?,
  );
}

/// A [Currencies] row, carried by code rather than id. [rateMicros] is what one
/// unit was worth in the *sender's* base currency; the importer only adopts it
/// when its own base has the same code, since a rate against someone else's base
/// says nothing here.
class BundleCurrency {
  const BundleCurrency({
    required this.code,
    required this.symbol,
    this.rateMicros,
    this.isBase = false,
  });

  final String code;
  final String symbol;
  final int? rateMicros;

  /// Whether this was the sender's base currency.
  final bool isBase;

  Map<String, dynamic> toJson() => {
    'code': code,
    'symbol': symbol,
    'rateMicros': rateMicros,
    'isBase': isBase,
  };

  factory BundleCurrency.fromJson(Map<String, dynamic> json) => BundleCurrency(
    code: json['code'] as String,
    symbol: json['symbol'] as String,
    rateMicros: json['rateMicros'] as int?,
    isBase: json['isBase'] as bool? ?? false,
  );
}

/// The currencies the bundle format knew before v3: the four the [Currency]
/// enum used to be, under the names it wrote them as. **Frozen** — it describes
/// what older bundles hold and what an older app can read, so appending to the
/// enum must not change it.
const Map<String, String> _legacyCurrencyTokens = {
  'EUR': 'eur',
  'USD': 'usd',
  'GBP': 'gbp',
  'CHF': 'chf',
};

/// The currencies a bundle is assumed to hold when it names none — the four
/// above, with EUR as the base. Only ever the stand-in for a bundle written
/// before currencies were managed.
const List<BundleCurrency> kBuiltinBundleCurrencies = [
  BundleCurrency(code: 'EUR', symbol: '\u20AC', isBase: true),
  BundleCurrency(code: 'USD', symbol: r'US$'),
  BundleCurrency(code: 'GBP', symbol: '\u00A3'),
  BundleCurrency(code: 'CHF', symbol: 'CHF'),
];

/// The token a currency [code] is written under in a bundle: the name the old
/// enum used when the code is one of [_legacyCurrencyTokens], and the code
/// itself otherwise.
///
/// The indirection keeps an ordinary trip readable by an app from before
/// currencies were managed, which expects that name here — see
/// [TripBundle.currentFormatVersion]. [bundleCurrencyCode] reads it back.
String bundleCurrencyToken(String code) => _legacyCurrencyTokens[code] ?? code;

/// The currency code a bundle's [token] names — the inverse of
/// [bundleCurrencyToken], accepting both spellings so v3 and older bundles read
/// the same way.
String bundleCurrencyCode(String token) {
  for (final entry in _legacyCurrencyTokens.entries) {
    if (entry.value == token) return entry.key;
  }
  return token;
}

/// Whether a trip whose costs use [codes] has to go out as a v3 bundle: it does
/// exactly when some currency is one the old enum never had, and so cannot be
/// written under a name an older app would recognise.
bool bundleNeedsCurrencyFormat(Iterable<String> codes) =>
    codes.any((code) => !_legacyCurrencyTokens.containsKey(code));

/// A [Costs] row. A cost attaches to exactly one of an item, a group, or the
/// trip: [itemLocalId] and [groupLocalId] refer to bundle-local ids and are both
/// null for a trip-level cost. [paidBy] and [beneficiaries] are person names.
class BundleCost {
  const BundleCost({
    this.itemLocalId,
    this.groupLocalId,
    required this.amountMinor,
    required this.currency,
    required this.reason,
    this.paidBy,
    this.paid = false,
    this.isTransfer = false,
    required this.createdAt,
    this.beneficiaries = const [],
  });

  final int? itemLocalId;
  final int? groupLocalId;
  final int amountMinor;

  /// The currency's [Currencies.code] — its identity across databases. Listed
  /// with its symbol and rate in [TripBundle.currencies].
  final String currency;
  final String reason;
  final String? paidBy;
  final bool paid;

  /// Whether this row is a transfer between two people rather than an expense
  /// ([Costs.isTransfer]): [paidBy] handed the money to its one beneficiary.
  /// Absent in bundles written before transfers existed, and read back as
  /// false there — an older bundle only ever held expenses.
  final bool isTransfer;

  final DateTime createdAt;

  /// Person names this cost was split among; empty means "all participants".
  final List<String> beneficiaries;

  Map<String, dynamic> toJson() => {
    'itemLocalId': itemLocalId,
    'groupLocalId': groupLocalId,
    'amountMinor': amountMinor,
    'currency': bundleCurrencyToken(currency),
    'reason': reason,
    'paidBy': paidBy,
    'paid': paid,
    'isTransfer': isTransfer,
    'createdAt': _encodeDate(createdAt),
    'beneficiaries': beneficiaries,
  };

  factory BundleCost.fromJson(Map<String, dynamic> json) => BundleCost(
    itemLocalId: json['itemLocalId'] as int?,
    groupLocalId: json['groupLocalId'] as int?,
    amountMinor: json['amountMinor'] as int,
    currency: bundleCurrencyCode(json['currency'] as String),
    reason: json['reason'] as String,
    paidBy: json['paidBy'] as String?,
    paid: json['paid'] as bool? ?? false,
    isTransfer: json['isTransfer'] as bool? ?? false,
    createdAt: _decodeDate(json['createdAt'] as String)!,
    beneficiaries: [
      for (final b in (json['beneficiaries'] as List? ?? const [])) b as String,
    ],
  );
}

/// A [Checklists] row together with its [ChecklistItems]. [localId] is unused on
/// import (checklists don't reference each other) but kept for symmetry.
class BundleChecklist {
  const BundleChecklist({
    required this.localId,
    this.title = '',
    this.sortOrder = 0,
    this.collapsed = false,
    required this.createdAt,
    this.items = const [],
  });

  final int localId;
  final String title;
  final int sortOrder;
  final bool collapsed;
  final DateTime createdAt;
  final List<BundleChecklistItem> items;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'title': title,
    'sortOrder': sortOrder,
    'collapsed': collapsed,
    'createdAt': _encodeDate(createdAt),
    'items': [for (final i in items) i.toJson()],
  };

  factory BundleChecklist.fromJson(Map<String, dynamic> json) =>
      BundleChecklist(
        localId: json['localId'] as int,
        title: json['title'] as String? ?? '',
        sortOrder: json['sortOrder'] as int? ?? 0,
        collapsed: json['collapsed'] as bool? ?? false,
        createdAt: _decodeDate(json['createdAt'] as String)!,
        items: [
          for (final i in (json['items'] as List? ?? const []))
            BundleChecklistItem.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// A single [ChecklistItems] row.
class BundleChecklistItem {
  const BundleChecklistItem({
    required this.label,
    this.done = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String label;
  final bool done;
  final int sortOrder;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'label': label,
    'done': done,
    'sortOrder': sortOrder,
    'createdAt': _encodeDate(createdAt),
  };

  factory BundleChecklistItem.fromJson(Map<String, dynamic> json) =>
      BundleChecklistItem(
        label: json['label'] as String,
        done: json['done'] as bool? ?? false,
        sortOrder: json['sortOrder'] as int? ?? 0,
        createdAt: _decodeDate(json['createdAt'] as String)!,
      );
}

// --- serialization helpers ---

/// Dates are encoded as ISO-8601 strings, preserving the wall-clock value so a
/// calendar day (itinerary date, normalized to midnight) survives crossing
/// timezones unchanged.
String? _encodeDate(DateTime? d) => d?.toIso8601String();

DateTime? _decodeDate(String? s) => s == null ? null : DateTime.parse(s);

T _enumByName<T extends Enum>(List<T> values, String name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('Unknown ${values.first.runtimeType} value: $name');
}
