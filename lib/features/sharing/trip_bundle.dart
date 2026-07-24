import 'dart:convert';
import 'dart:typed_data';

import '../../data/database/tables.dart' show Currency, ItemKind;

/// MIME type used when sharing a trip bundle. Custom (vendor) type so the app's
/// share-sheet intent filter matches only Travel Planner trips, not every
/// binary file. Tapped `.tpt` files arrive as `application/octet-stream`
/// instead (the OS can't infer a type from the unknown extension), which the
/// `ACTION_VIEW` filter handles separately.
const String tripBundleMimeType = 'application/x-travelplanner-trip';

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
///   `paidBy`, beneficiaries) and [CostReasons] — are denormalized to their
///   natural string keys (name / label) so the recipient doesn't need matching
///   IDs. Reason icons ride along in [reasonIcons] keyed by label.
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
    this.reasonIcons = const {},
    this.modeIcons = const {},
  });

  /// Version of the bundle format itself. Bump when the JSON shape changes in a
  /// way importers must branch on. Independent of the database [schemaVersion].
  ///
  /// v2 added [alternativeSets]. An exporter only *stamps* v2 on a trip that
  /// actually has alternatives (see `SharingDao.exportTrip`): an older app would
  /// drop the decisions it can't read and silently flatten every option's items
  /// into the day, so it must refuse such a bundle — but there is no reason to
  /// stop it reading an ordinary trip, which still goes out as v1.
  static const int currentFormatVersion = 2;

  /// Magic string identifying the payload as a Travel Planner trip bundle.
  static const String kind = 'travelplanner.trip';

  final int formatVersion;

  /// `AppDatabase.schemaVersion` of the database this bundle was exported from.
  /// The importer uses it to refuse bundles from a newer app it can't read.
  final int schemaVersion;

  final BundleTrip trip;
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

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'formatVersion': formatVersion,
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
  };

  factory TripBundle.fromJson(Map<String, dynamic> json) {
    final k = json['kind'];
    if (k != kind) {
      throw const FormatException('Not a Travel Planner trip bundle.');
    }
    return TripBundle(
      formatVersion: json['formatVersion'] as int,
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
    required this.colorValue,
    required this.createdAt,
  });

  final String title;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final int colorValue;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'destination': destination,
    'startDate': _encodeDate(startDate),
    'endDate': _encodeDate(endDate),
    'notes': notes,
    'colorValue': colorValue,
    'createdAt': _encodeDate(createdAt),
  };

  factory BundleTrip.fromJson(Map<String, dynamic> json) => BundleTrip(
    title: json['title'] as String,
    destination: json['destination'] as String? ?? '',
    startDate: _decodeDate(json['startDate'] as String?),
    endDate: _decodeDate(json['endDate'] as String?),
    notes: json['notes'] as String?,
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
    this.notes,
    this.location,
    this.mode,
    this.fromLocation,
    this.toLocation,
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
    'notes': notes,
    'location': location,
    'mode': mode,
    'fromLocation': fromLocation,
    'toLocation': toLocation,
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
    notes: json['notes'] as String?,
    location: json['location'] as String?,
    mode: json['mode'] as String?,
    fromLocation: json['fromLocation'] as String?,
    toLocation: json['toLocation'] as String?,
  );
}

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
  final Currency currency;
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
    'currency': currency.name,
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
    currency: _enumByName(Currency.values, json['currency'] as String),
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
