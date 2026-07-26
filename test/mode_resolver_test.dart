import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/transport_search/data/journey_mapper.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';

void main() {
  late AppDatabase db;

  // A fresh database seeds the built-in modes in enum order, so a row's id is its
  // TransportMode index + 1 (see the v20 migration relying on the same fact).
  int builtinId(TransportMode m) => m.index + 1;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('resolves each routing mode onto its built-in row id', () async {
    final modes = await db.transportModeDao.watchModes().first;
    final resolve = modeResolver(modes);

    expect(resolve(TransitMode.highSpeedRail), builtinId(TransportMode.train));
    expect(resolve(TransitMode.nightRail), builtinId(TransportMode.train));
    expect(resolve(TransitMode.coach), builtinId(TransportMode.bus));
    expect(resolve(TransitMode.subway), builtinId(TransportMode.subway));
    expect(resolve(TransitMode.walk), builtinId(TransportMode.walk));
  });

  test('a routing mode with no built-in resolves to null', () async {
    final modes = await db.transportModeDao.watchModes().first;
    final resolve = modeResolver(modes);
    expect(resolve(TransitMode.funicular), isNull);
    expect(resolve(TransitMode.other), isNull);
  });

  test('a deleted built-in resolves to null, not a resurrected row', () async {
    // Delete the seeded 'train' mode, then rail should no longer resolve.
    final trainId = builtinId(TransportMode.train);
    await db.transportModeDao.deleteMode(trainId);

    final modes = await db.transportModeDao.watchModes().first;
    final resolve = modeResolver(modes);

    expect(resolve(TransitMode.highSpeedRail), isNull);
    // Other modes still resolve.
    expect(resolve(TransitMode.subway), builtinId(TransportMode.subway));
  });

  test('restoring a deleted built-in makes its mode resolve again', () async {
    await db.transportModeDao.deleteMode(builtinId(TransportMode.train));
    await db.transportModeDao.restoreBuiltinMode(TransportMode.train);

    final modes = await db.transportModeDao.watchModes().first;
    final resolve = modeResolver(modes);

    final id = resolve(TransitMode.highSpeedRail);
    expect(id, isNotNull);
    // The restored row carries the built-in's key again (its identity), even if
    // its id differs from the deleted one.
    final row = modes.firstWhere((m) => m.id == id);
    expect(row.builtinKey, TransportMode.train.name);
  });

  test('a renamed built-in still resolves (identity is builtinKey)', () async {
    final busId = builtinId(TransportMode.bus);
    await db.transportModeDao.renameMode(busId, 'Autobus');

    final modes = await db.transportModeDao.watchModes().first;
    final resolve = modeResolver(modes);

    expect(resolve(TransitMode.coach), busId);
  });
}
