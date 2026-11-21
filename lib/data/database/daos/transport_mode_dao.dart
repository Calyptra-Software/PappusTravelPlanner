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
  TransportMode.gondola,
  TransportMode.chairLift,
  TransportMode.dragLift,
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

/// The lift built-ins and the curated icon a custom mode for each wears: keys of
/// `kTransportModeIcons` (the TransportGlyphs gondola, chairlift and T-bar),
/// repeated here because the database layer does not import the UI. A test
/// holds the two together.
const Map<TransportMode, int> kLiftModeIconIds = {
  TransportMode.gondola: 30,
  TransportMode.chairLift: 31,
  TransportMode.dragLift: 32,
};

/// Manages the reusable list of transport modes: the built-ins the database is
/// seeded with plus any the user adds, and the add/rename/re-icon/reorder/delete
/// operations behind the settings screen. The transport counterpart to the
/// reason management in [CostDao].
@DriftAccessor(tables: [TransportModes, ItineraryItems])
class TransportModeDao extends DatabaseAccessor<AppDatabase>
    with _$TransportModeDaoMixin {
  TransportModeDao(super.db);

  /// All modes in display order (then by id, so ties are stable). Feeds the
  /// item form's dropdown and the settings list.
  Stream<List<TransportModeRow>> watchModes() => _ordered().watch();

  /// The same list, read once — for a caller that needs the modes to *finish* a
  /// piece of work rather than to keep a screen up to date.
  ///
  /// The connection import is that caller: it maps the router's vocabulary onto
  /// these rows and must not depend on whether some widget happens to be
  /// watching them at the time (see `TransportSearchController`).
  Future<List<TransportModeRow>> modes() => _ordered().get();

  SimpleSelectStatement<$TransportModesTable, TransportModeRow> _ordered() =>
      select(transportModes)..orderBy([
        (m) => OrderingTerm(expression: m.sortOrder),
        (m) => OrderingTerm(expression: m.id),
      ]);

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

  /// Re-adds a single built-in the user deleted, restoring its stable
  /// `builtinKey` — and with it the mode's identity across sharing and the
  /// connection-search mapping. Appended to the end of the list; a no-op if the
  /// built-in is already present. This is the deliberate way back for an
  /// accidental delete, as opposed to adding a same-named custom mode (which has
  /// no `builtinKey` and so would not restore either).
  Future<void> restoreBuiltinMode(TransportMode mode) async {
    await into(transportModes).insert(
      TransportModesCompanion.insert(
        builtinKey: Value(mode.name),
        sortOrder: Value(await _nextSortOrder()),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Gives this database the built-ins in [byIconId] that it lacks, each
  /// keyed by the curated icon a custom mode for it would wear.
  ///
  /// A custom mode wearing that icon **becomes** the built-in rather than
  /// standing beside a new one: the row gains the `builtinKey`, and keeps its
  /// id, its name and its icon, so every leg already filed under it is filed
  /// under the built-in and nothing has to be moved or merged. Of several
  /// wearing the same icon, the one most legs use is taken (the first in the
  /// list on a tie); the others stay custom. A built-in no custom mode stands
  /// for is appended at the end of the list, as [restoreBuiltinMode] does. One
  /// already present is left alone.
  ///
  /// Reading identity off an icon is an inference, made only for icons that
  /// name exactly one built-in (the lift glyphs); a name is never read.
  Future<void> adoptOrAddBuiltins(Map<TransportMode, int> byIconId) async {
    for (final MapEntry(key: mode, value: iconId) in byIconId.entries) {
      final present = await (select(
        transportModes,
      )..where((m) => m.builtinKey.equals(mode.name))).getSingleOrNull();
      if (present != null) continue;
      final candidates =
          await (select(transportModes)
                ..where((m) => m.builtinKey.isNull() & m.iconId.equals(iconId))
                ..orderBy([(m) => OrderingTerm(expression: m.sortOrder)]))
              .get();
      TransportModeRow? chosen;
      var mostLegs = -1;
      for (final candidate in candidates) {
        final legs = itineraryItems.id.count();
        final row =
            await (selectOnly(itineraryItems)
                  ..addColumns([legs])
                  ..where(itineraryItems.mode.equals(candidate.id)))
                .getSingle();
        final count = row.read(legs) ?? 0;
        if (count > mostLegs) {
          mostLegs = count;
          chosen = candidate;
        }
      }
      if (chosen == null) {
        await restoreBuiltinMode(mode);
        continue;
      }
      await (update(transportModes)..where((m) => m.id.equals(chosen!.id)))
          .write(TransportModesCompanion(builtinKey: Value(mode.name)));
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
