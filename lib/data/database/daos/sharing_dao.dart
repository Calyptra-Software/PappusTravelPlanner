import 'package:drift/drift.dart';

import '../../../features/sharing/trip_bundle.dart';
import '../app_database.dart';
import '../tables.dart';

part 'sharing_dao.g.dart';

/// Reads a single trip and everything hanging off it into a portable
/// [TripBundle] (and, later, writes one back). Spans every trip-scoped table
/// plus the two global rosters ([People], [CostReasons]) it must denormalize,
/// so it lives in its own accessor rather than any one feature's DAO.
@DriftAccessor(
  tables: [
    Trips,
    ItemGroups,
    AlternativeSets,
    Alternatives,
    ItineraryItems,
    Costs,
    CostReasons,
    TransportModes,
    People,
    TripParticipants,
    CostBeneficiaries,
    Checklists,
    ChecklistItems,
    CollapsedDays,
  ],
)
class SharingDao extends DatabaseAccessor<AppDatabase> with _$SharingDaoMixin {
  SharingDao(super.db);

  /// Assembles the trip [tripId] and all of its data into a [TripBundle].
  /// Returns null if no such trip exists. Row IDs are carried through as the
  /// bundle's opaque local keys; references to the shared [People] and
  /// [CostReasons] rosters are denormalized to names / labels.
  Future<TripBundle?> exportTrip(int tripId) async {
    final trip = await (select(
      trips,
    )..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) return null;

    final groupRows = await (select(
      itemGroups,
    )..where((g) => g.tripId.equals(tripId))).get();
    final setRows = await (select(
      alternativeSets,
    )..where((s) => s.tripId.equals(tripId))).get();
    final branchRows = setRows.isEmpty
        ? <Alternative>[]
        : await (select(alternatives)
                ..where((a) => a.setId.isIn([for (final s in setRows) s.id]))
                ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
              .get();
    final itemRows = await (select(
      itineraryItems,
    )..where((i) => i.tripId.equals(tripId))).get();
    final costRows = await _costsForTrip(tripId);
    final beneficiariesByCost = await _beneficiaryNamesByCost(tripId);
    final checklistRows = await (select(
      checklists,
    )..where((c) => c.tripId.equals(tripId))).get();
    final checklistItemRows = checklistRows.isEmpty
        ? <ChecklistItem>[]
        : await (select(checklistItems)..where(
                (ci) =>
                    ci.checklistId.isIn([for (final c in checklistRows) c.id]),
              ))
              .get();
    final collapsedRows = await (select(
      collapsedDays,
    )..where((d) => d.tripId.equals(tripId))).get();
    final participantNames = await _participantNames(tripId);
    final reasonIcons = await _reasonIconsFor({
      for (final c in costRows) c.reason,
    });

    // Modes are denormalized to a portable key per leg (a built-in's key or a
    // custom mode's name); a custom mode's icon is carried alongside so it
    // survives import.
    final modeRows = await select(transportModes).get();
    final modeById = {for (final m in modeRows) m.id: m};
    final modeIcons = <String, int>{};
    for (final i in itemRows) {
      final row = i.mode == null ? null : modeById[i.mode];
      if (row != null &&
          row.builtinKey == null &&
          row.name != null &&
          row.iconId != null) {
        modeIcons[row.name!] = row.iconId!;
      }
    }

    return TripBundle(
      // A trip without decisions stays readable by an older app, which knows
      // nothing of them; one *with* decisions goes out as v2, so an older app
      // refuses it outright rather than flattening every option into the day.
      formatVersion: setRows.isEmpty ? 1 : TripBundle.currentFormatVersion,
      schemaVersion: db.schemaVersion,
      trip: BundleTrip(
        title: trip.title,
        destination: trip.destination,
        startDate: trip.startDate,
        endDate: trip.endDate,
        notes: trip.notes,
        colorValue: trip.colorValue,
        createdAt: trip.createdAt,
      ),
      groups: [
        for (final g in groupRows)
          BundleGroup(localId: g.id, label: g.label, collapsed: g.collapsed),
      ],
      alternativeSets: [
        for (final s in setRows)
          BundleAlternativeSet(
            localId: s.id,
            date: s.date,
            sortOrder: s.sortOrder,
            label: s.label,
            alternatives: [
              for (final a in branchRows.where((a) => a.setId == s.id))
                BundleAlternative(
                  localId: a.id,
                  label: a.label,
                  sortOrder: a.sortOrder,
                  chosen: a.chosen,
                ),
            ],
          ),
      ],
      items: [
        for (final i in itemRows)
          BundleItem(
            localId: i.id,
            groupLocalId: i.groupId,
            alternativeLocalId: i.alternativeId,
            date: i.date,
            sortOrder: i.sortOrder,
            kind: i.kind,
            title: i.title,
            startMinutes: i.startMinutes,
            endMinutes: i.endMinutes,
            actualStartMinutes: i.actualStartMinutes,
            actualEndMinutes: i.actualEndMinutes,
            notes: i.notes,
            location: i.location,
            mode: _modeKey(i.mode, modeById),
            fromLocation: i.fromLocation,
            toLocation: i.toLocation,
          ),
      ],
      costs: [
        for (final c in costRows)
          BundleCost(
            itemLocalId: c.itemId,
            groupLocalId: c.groupId,
            amountMinor: c.amountMinor,
            currency: c.currency,
            reason: c.reason,
            paidBy: c.paidBy,
            paid: c.paid,
            createdAt: c.createdAt,
            beneficiaries: beneficiariesByCost[c.id] ?? const [],
          ),
      ],
      checklists: [
        for (final c in checklistRows)
          BundleChecklist(
            localId: c.id,
            title: c.title,
            sortOrder: c.sortOrder,
            collapsed: c.collapsed,
            createdAt: c.createdAt,
            items: [
              for (final ci in checklistItemRows.where(
                (ci) => ci.checklistId == c.id,
              ))
                BundleChecklistItem(
                  label: ci.label,
                  done: ci.done,
                  sortOrder: ci.sortOrder,
                  createdAt: ci.createdAt,
                ),
            ],
          ),
      ],
      collapsedDays: [for (final d in collapsedRows) d.day],
      participants: participantNames,
      reasonIcons: reasonIcons,
      modeIcons: modeIcons,
    );
  }

  /// The portable key for a leg's mode row id: a built-in's `builtinKey`, or a
  /// custom mode's name. Null when the leg has no mode (or its row is gone).
  String? _modeKey(int? modeId, Map<int, TransportModeRow> byId) {
    if (modeId == null) return null;
    final row = byId[modeId];
    return row?.builtinKey ?? row?.name;
  }

  /// Imports [bundle] as a brand-new trip, returning its id. Runs in a single
  /// transaction so a failure leaves nothing behind.
  ///
  /// Global rosters are merged, not duplicated: [People] and [CostReasons] are
  /// matched by their unique name / label, created only when missing. An
  /// imported person never carries the sender's `isMe` flag, and an existing
  /// reason keeps the importer's own icon. Every trip-internal reference is
  /// remapped from the bundle's local keys to the freshly-inserted row ids.
  Future<int> importTrip(TripBundle bundle) {
    if (bundle.formatVersion > TripBundle.currentFormatVersion) {
      throw IncompatibleBundleException(
        'Bundle format v${bundle.formatVersion} is newer than supported '
        'v${TripBundle.currentFormatVersion}.',
      );
    }
    return transaction(() async {
      // People for every referenced name: participants, beneficiaries, and
      // payers. `paidBy` is stored as text on the cost, but seeding the roster
      // keeps the payer selectable afterwards, as elsewhere in the app.
      final personNames = <String>{
        ...bundle.participants,
        for (final c in bundle.costs) ...[
          if (c.paidBy != null) c.paidBy!,
          ...c.beneficiaries,
        ],
      };
      final personIds = <String, int>{};
      for (final name in personNames) {
        personIds[name] = await _ensurePerson(name);
      }

      await _ensureReasons(bundle);

      final tripId = await into(trips).insert(
        TripsCompanion.insert(
          title: bundle.trip.title,
          destination: Value(bundle.trip.destination),
          startDate: Value(bundle.trip.startDate),
          endDate: Value(bundle.trip.endDate),
          notes: Value(bundle.trip.notes),
          colorValue: Value(bundle.trip.colorValue),
          createdAt: Value(bundle.trip.createdAt),
        ),
      );

      // Groups first, so items and costs can point at their new ids.
      final groupIds = <int, int>{};
      for (final g in bundle.groups) {
        groupIds[g.localId] = await into(itemGroups).insert(
          ItemGroupsCompanion.insert(
            tripId: tripId,
            label: Value(g.label),
            collapsed: Value(g.collapsed),
          ),
        );
      }

      // Decisions and their options next, for the same reason: an item planned
      // inside an option needs the option's fresh id.
      final branchIds = <int, int>{};
      for (final s in bundle.alternativeSets) {
        final setId = await into(alternativeSets).insert(
          AlternativeSetsCompanion.insert(
            tripId: tripId,
            date: s.date,
            sortOrder: Value(s.sortOrder),
            label: Value(s.label),
          ),
        );
        for (final a in s.alternatives) {
          branchIds[a.localId] = await into(alternatives).insert(
            AlternativesCompanion.insert(
              setId: setId,
              label: Value(a.label),
              sortOrder: Value(a.sortOrder),
              chosen: Value(a.chosen),
            ),
          );
        }
      }

      // Resolve each leg's mode key to a local mode row, seeding a missing
      // built-in or creating a missing custom mode as we go. Cached by key so a
      // mode shared by many legs is resolved once.
      final modeIds = <String, int>{};

      final itemIds = <int, int>{};
      for (final i in bundle.items) {
        itemIds[i.localId] = await into(itineraryItems).insert(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            groupId: Value(_mapId(groupIds, i.groupLocalId)),
            alternativeId: Value(_mapId(branchIds, i.alternativeLocalId)),
            date: i.date,
            sortOrder: Value(i.sortOrder),
            kind: i.kind,
            title: Value(i.title),
            startMinutes: Value(i.startMinutes),
            endMinutes: Value(i.endMinutes),
            actualStartMinutes: Value(i.actualStartMinutes),
            actualEndMinutes: Value(i.actualEndMinutes),
            notes: Value(i.notes),
            location: Value(i.location),
            mode: Value(await _ensureMode(i.mode, bundle, modeIds)),
            fromLocation: Value(i.fromLocation),
            toLocation: Value(i.toLocation),
          ),
        );
      }

      for (final c in bundle.costs) {
        final itemId = _mapId(itemIds, c.itemLocalId);
        final groupId = _mapId(groupIds, c.groupLocalId);
        // A cost attaches to exactly one target. Fall back to the trip if it was
        // a trip-level cost (or, defensively, if its item/group didn't resolve).
        final tripLevel = itemId == null && groupId == null;
        final costId = await into(costs).insert(
          CostsCompanion.insert(
            itemId: Value(itemId),
            groupId: Value(groupId),
            tripId: Value(tripLevel ? tripId : null),
            amountMinor: c.amountMinor,
            currency: c.currency,
            reason: c.reason,
            paidBy: Value(c.paidBy),
            paid: Value(c.paid),
            createdAt: Value(c.createdAt),
          ),
        );
        for (final name in c.beneficiaries) {
          await into(costBeneficiaries).insert(
            CostBeneficiariesCompanion.insert(
              costId: costId,
              personId: personIds[name]!,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }

      for (final cl in bundle.checklists) {
        final checklistId = await into(checklists).insert(
          ChecklistsCompanion.insert(
            tripId: tripId,
            title: Value(cl.title),
            sortOrder: Value(cl.sortOrder),
            collapsed: Value(cl.collapsed),
            createdAt: Value(cl.createdAt),
          ),
        );
        for (final ci in cl.items) {
          await into(checklistItems).insert(
            ChecklistItemsCompanion.insert(
              checklistId: checklistId,
              label: ci.label,
              done: Value(ci.done),
              sortOrder: Value(ci.sortOrder),
              createdAt: Value(ci.createdAt),
            ),
          );
        }
      }

      for (final day in bundle.collapsedDays) {
        await into(collapsedDays).insert(
          CollapsedDaysCompanion.insert(tripId: tripId, day: day),
          mode: InsertMode.insertOrIgnore,
        );
      }

      for (final name in bundle.participants) {
        await into(tripParticipants).insert(
          TripParticipantsCompanion.insert(
            tripId: tripId,
            personId: personIds[name]!,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }

      return tripId;
    });
  }

  /// Resolves a person by their unique [name], creating the roster row if it
  /// doesn't exist yet. The `isMe` flag is never imported.
  Future<int> _ensurePerson(String name) async {
    await into(people).insert(
      PeopleCompanion.insert(name: name),
      mode: InsertMode.insertOrIgnore,
    );
    final person = await (select(
      people,
    )..where((p) => p.name.equals(name))).getSingle();
    return person.id;
  }

  /// Ensures a [CostReasons] row exists for every reason used by the bundle's
  /// costs. A new reason adopts the bundle's icon; an existing one keeps the
  /// icon the importer already chose.
  Future<void> _ensureReasons(TripBundle bundle) async {
    final labels = {for (final c in bundle.costs) c.reason};
    if (labels.isEmpty) return;
    final existing = await (select(
      costReasons,
    )..where((r) => r.label.isIn(labels.toList()))).get();
    final existingLabels = {for (final r in existing) r.label};
    for (final label in labels) {
      if (existingLabels.contains(label)) continue;
      await into(costReasons).insert(
        CostReasonsCompanion.insert(
          label: label,
          iconId: Value(bundle.reasonIcons[label]),
        ),
      );
    }
  }

  /// Resolves a bundle mode [key] to a local `TransportModes` row id, creating
  /// the row if needed: a built-in whose key isn't present is seeded (the user
  /// may have deleted it), and an unknown key is taken as a custom mode and
  /// created with its shared icon. Results are cached in [cache] for the import.
  Future<int?> _ensureMode(
    String? key,
    TripBundle bundle,
    Map<String, int> cache,
  ) async {
    if (key == null) return null;
    final cached = cache[key];
    if (cached != null) return cached;

    final isBuiltin = TransportMode.values.any((m) => m.name == key);
    final match =
        await (select(transportModes)..where(
              (m) => isBuiltin ? m.builtinKey.equals(key) : m.name.equals(key),
            ))
            .getSingleOrNull();
    final id =
        match?.id ??
        await into(transportModes).insert(
          TransportModesCompanion.insert(
            builtinKey: Value(isBuiltin ? key : null),
            name: Value(isBuiltin ? null : key),
            iconId: Value(isBuiltin ? null : bundle.modeIcons[key]),
            sortOrder: Value(await _nextModeSortOrder()),
          ),
        );
    cache[key] = id;
    return id;
  }

  /// The next free `sortOrder` for a mode created during import (appended).
  Future<int> _nextModeSortOrder() async {
    final maxOrder = transportModes.sortOrder.max();
    final row = await (selectOnly(
      transportModes,
    )..addColumns([maxOrder])).getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }

  /// Maps a bundle-local key to its freshly-inserted id, or null when the key is
  /// null. Assumes the referenced row was inserted earlier in the same import.
  int? _mapId(Map<int, int> ids, int? localId) =>
      localId == null ? null : ids[localId];

  /// All costs belonging to the trip, whichever way they are attached (to an
  /// item, a group, or the trip directly). Mirrors `CostDao.watchCostsForTrip`.
  Future<List<Cost>> _costsForTrip(int tripId) {
    final query =
        select(costs).join([
            leftOuterJoin(
              itineraryItems,
              itineraryItems.id.equalsExp(costs.itemId),
            ),
            leftOuterJoin(itemGroups, itemGroups.id.equalsExp(costs.groupId)),
          ])
          ..where(
            itineraryItems.tripId.equals(tripId) |
                itemGroups.tripId.equals(tripId) |
                costs.tripId.equals(tripId),
          )
          ..orderBy([OrderingTerm(expression: costs.createdAt)]);
    return query.map((row) => row.readTable(costs)).get();
  }

  /// Beneficiary person names for every cost in the trip, keyed by cost id.
  Future<Map<int, List<String>>> _beneficiaryNamesByCost(int tripId) async {
    final query =
        select(costBeneficiaries).join([
            innerJoin(costs, costs.id.equalsExp(costBeneficiaries.costId)),
            innerJoin(people, people.id.equalsExp(costBeneficiaries.personId)),
            leftOuterJoin(
              itineraryItems,
              itineraryItems.id.equalsExp(costs.itemId),
            ),
            leftOuterJoin(itemGroups, itemGroups.id.equalsExp(costs.groupId)),
          ])
          ..where(
            itineraryItems.tripId.equals(tripId) |
                itemGroups.tripId.equals(tripId) |
                costs.tripId.equals(tripId),
          )
          ..orderBy([OrderingTerm(expression: people.name)]);
    final rows = await query.get();
    final byCost = <int, List<String>>{};
    for (final row in rows) {
      final costId = row.readTable(costBeneficiaries).costId;
      byCost.putIfAbsent(costId, () => []).add(row.readTable(people).name);
    }
    return byCost;
  }

  /// Names of the trip's participants, alphabetical.
  Future<List<String>> _participantNames(int tripId) {
    final query =
        select(people).join([
            innerJoin(
              tripParticipants,
              tripParticipants.personId.equalsExp(people.id),
            ),
          ])
          ..where(tripParticipants.tripId.equals(tripId))
          ..orderBy([OrderingTerm(expression: people.name)]);
    return query.map((row) => row.readTable(people).name).get();
  }

  /// Icon id for each of [labels] that names a reason with a non-null icon, so
  /// shared reasons keep their icon on import.
  Future<Map<String, int>> _reasonIconsFor(Set<String> labels) async {
    if (labels.isEmpty) return const {};
    final rows =
        await (select(costReasons)..where(
              (r) => r.label.isIn(labels.toList()) & r.iconId.isNotNull(),
            ))
            .get();
    return {for (final r in rows) r.label: r.iconId!};
  }
}
