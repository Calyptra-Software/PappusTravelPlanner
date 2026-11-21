import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:travelplanner/core/icons/transport_glyphs.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/daos/transport_mode_dao.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/widgets/transport_mode.dart'
    show kTransportModeIcons;
import 'package:travelplanner/features/transport_search/data/journey_mapper.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';

/// The three lift modes: in a new database, and in one migrated from v44 where
/// the user had made modes of their own for lifts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the lift icons the migration reads are the lift glyphs', () {
    expect(
      kTransportModeIcons[kLiftModeIconIds[TransportMode.gondola]],
      kGondolaGlyph,
    );
    expect(
      kTransportModeIcons[kLiftModeIconIds[TransportMode.chairLift]],
      kChairliftGlyph,
    );
    expect(
      kTransportModeIcons[kLiftModeIconIds[TransportMode.dragLift]],
      kTbarGlyph,
    );
  });

  test('a new database has them, after ski', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final modes = await (db.select(
      db.transportModes,
    )..orderBy([(m) => OrderingTerm(expression: m.sortOrder)])).get();
    final keys = [for (final m in modes) m.builtinKey];
    final ski = keys.indexOf('ski');
    expect(keys.sublist(ski, ski + 4), [
      'ski',
      'gondola',
      'chairLift',
      'dragLift',
    ]);
  });

  test('a timetable lift is a gondola, a funicular a train', () {
    expect(
      builtinTransportModeFor(TransitMode.aerialLift),
      TransportMode.gondola,
    );
    expect(builtinTransportModeFor(TransitMode.gondola), TransportMode.gondola);
    expect(builtinTransportModeFor(TransitMode.funicular), TransportMode.train);
  });

  group('v44 -> v45', () {
    late Directory tempDir;
    late String path;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tp_lift_modes');
      path = p.join(tempDir.path, 'v44.sqlite');
    });
    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// A v44 database where the user made "Gondel" (used twice) and
    /// "Seilbahn" (used once), both with the gondola glyph, and "Sessellift"
    /// with the chairlift glyph, and nothing for a drag lift. Written through
    /// the app, for the reason `reimbursement_migration_test.dart` gives.
    Future<Map<String, int>> seedV44Database() async {
      final db = AppDatabase.forTesting(NativeDatabase(File(path)));
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Ski'),
      );
      Future<int> custom(String name, int iconId, int sortOrder) => db
          .into(db.transportModes)
          .insert(
            TransportModesCompanion.insert(
              name: Value(name),
              iconId: Value(iconId),
              sortOrder: Value(sortOrder),
            ),
          );
      final ids = {
        'Seilbahn': await custom('Seilbahn', 30, 20),
        'Gondel': await custom('Gondel', 30, 21),
        'Sessellift': await custom('Sessellift', 31, 22),
      };
      Future<void> legOn(int modeId) => db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: tripId,
              date: DateTime(2026, 2, 1),
              kind: ItemKind.transport,
              mode: Value(modeId),
            ),
          );
      await legOn(ids['Gondel']!);
      await legOn(ids['Gondel']!);
      await legOn(ids['Seilbahn']!);
      await legOn(ids['Sessellift']!);
      await db.close();

      final raw = sqlite3.open(path);
      raw.execute(
        "DELETE FROM transport_modes WHERE builtin_key IN "
        "('gondola', 'chairLift', 'dragLift')",
      );
      raw.execute('PRAGMA user_version = 44');
      raw.close();
      return ids;
    }

    test('a mode made for a lift becomes the built-in, legs and all', () async {
      final ids = await seedV44Database();

      final db = AppDatabase.forTesting(NativeDatabase(File(path)));
      addTearDown(db.close);
      Future<TransportModeRow> mode(int id) => (db.select(
        db.transportModes,
      )..where((m) => m.id.equals(id))).getSingle();

      // The one most legs use is the gondola now, under its own name.
      final gondel = await mode(ids['Gondel']!);
      expect(gondel.builtinKey, 'gondola');
      expect(gondel.name, 'Gondel');
      expect(gondel.iconId, 30);
      // The other with the same glyph stays the user's own.
      expect((await mode(ids['Seilbahn']!)).builtinKey, isNull);
      expect((await mode(ids['Sessellift']!)).builtinKey, 'chairLift');

      // Nothing stood for a drag lift: it is added, at the end of the list.
      final modes = await (db.select(
        db.transportModes,
      )..orderBy([(m) => OrderingTerm(expression: m.sortOrder)])).get();
      expect(modes.last.builtinKey, 'dragLift');
      expect(modes.where((m) => m.builtinKey == 'gondola'), hasLength(1));

      // Every leg is where it was.
      final legs = await db.select(db.itineraryItems).get();
      expect(
        legs.map((l) => l.mode).toList()..sort(),
        [ids['Seilbahn'], ids['Gondel'], ids['Gondel'], ids['Sessellift']]
          ..sort(),
      );
    });

    test('a database without such modes gets all three, at the end', () async {
      final db0 = AppDatabase.forTesting(NativeDatabase(File(path)));
      await db0.select(db0.trips).get();
      await db0.close();
      final raw = sqlite3.open(path);
      raw.execute(
        "DELETE FROM transport_modes WHERE builtin_key IN "
        "('gondola', 'chairLift', 'dragLift')",
      );
      raw.execute('PRAGMA user_version = 44');
      raw.close();

      final db = AppDatabase.forTesting(NativeDatabase(File(path)));
      addTearDown(db.close);
      final modes = await (db.select(
        db.transportModes,
      )..orderBy([(m) => OrderingTerm(expression: m.sortOrder)])).get();

      expect(
        modes.reversed.take(3).map((m) => m.builtinKey).toList().reversed,
        ['gondola', 'chairLift', 'dragLift'],
      );
    });
  });
}
