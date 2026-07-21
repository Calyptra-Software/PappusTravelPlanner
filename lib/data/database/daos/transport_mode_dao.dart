import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'transport_mode_dao.g.dart';

/// The display order the built-in modes are seeded in (their `sortOrder`).
/// Insertion order, however, always follows [TransportMode.values] so a fresh
/// row's id equals its enum index + 1 — the fact the v20 migration relies on to
/// repoint each leg's old enum index onto its new row (see `AppDatabase`).
const List<TransportMode> _seedOrder = [
  TransportMode.walk,
  TransportMode.bike,
  TransportMode.ski,
  TransportMode.car,
  TransportMode.taxi,
  TransportMode.bus,
  TransportMode.train,
  TransportMode.tram,
  TransportMode.subway,
  TransportMode.ferry,
  TransportMode.flight,
  TransportMode.other,
];

/// Manages the reusable list of transport modes: the built-ins the database is
/// seeded with plus any the user adds, and the add/rename/re-icon/reorder/delete
/// operations behind the settings screen. The transport counterpart to the
/// reason management in [CostDao].
@DriftAccessor(tables: [TransportModes])
class TransportModeDao extends DatabaseAccessor<AppDatabase>
    with _$TransportModeDaoMixin {
  TransportModeDao(super.db);

  /// All modes in display order (then by id, so ties are stable). Feeds the
  /// item form's dropdown and the settings list.
  Stream<List<TransportModeRow>> watchModes() {
    return (select(transportModes)..orderBy([
          (m) => OrderingTerm(expression: m.sortOrder),
          (m) => OrderingTerm(expression: m.id),
        ]))
        .watch();
  }

  /// Adds a user-defined mode with [name] (optionally an icon), appended after
  /// the current modes. Returns its new id.
  Future<int> addMode(String name, {int? iconId}) async {
    final order = await _nextSortOrder();
    return into(transportModes).insert(
      TransportModesCompanion.insert(
        name: Value(name),
        iconId: Value(iconId),
        sortOrder: Value(order),
      ),
    );
  }

  /// Renames a mode. A built-in keeps its `builtinKey` (and so its identity) but
  /// gains a [name] that overrides its localized label; a custom mode's label is
  /// simply changed.
  Future<void> renameMode(int id, String name) {
    return (update(transportModes)..where((m) => m.id.equals(id))).write(
      TransportModesCompanion(name: Value(name)),
    );
  }

  /// Sets a mode's icon (null = the built-in default, or the generic default for
  /// a custom mode).
  Future<void> setModeIcon(int id, int? iconId) {
    return (update(transportModes)..where((m) => m.id.equals(id))).write(
      TransportModesCompanion(iconId: Value(iconId)),
    );
  }

  /// Deletes a mode. Legs that used it keep their route but lose their mode
  /// (`ItineraryItems.mode` is set null; see the table).
  Future<int> deleteMode(int id) =>
      (delete(transportModes)..where((m) => m.id.equals(id))).go();

  /// Writes a new order, given the mode ids top-to-bottom.
  Future<void> reorderModes(List<int> orderedIds) {
    return transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(transportModes)..where((m) => m.id.equals(orderedIds[i])))
            .write(TransportModesCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// Seeds one row per built-in [TransportMode], skipping any already present
  /// (matched by `builtinKey`). Inserted in enum order so a fresh row's id is
  /// its enum index + 1; a built-in's icon is left to derive from its key, so
  /// `iconId` stays null until the user picks one. Run on database creation and
  /// on the v20 upgrade.
  Future<void> seedBuiltinModes() async {
    for (final mode in TransportMode.values) {
      await into(transportModes).insert(
        TransportModesCompanion.insert(
          builtinKey: Value(mode.name),
          sortOrder: Value(_seedOrder.indexOf(mode)),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<int> _nextSortOrder() async {
    final maxOrder = transportModes.sortOrder.max();
    final row = await (selectOnly(
      transportModes,
    )..addColumns([maxOrder])).getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }
}
