import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/settings/application/database_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tp_db_test');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer containerAt(String path) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapDbPathProvider.overrideWithValue(path),
      ],
    );
  }

  Future<List<String>> titles(ProviderContainer c) async {
    final trips = await c.read(repositoryProvider).watchTrips().first;
    return trips.map((t) => t.title).toList();
  }

  test(
    'data written to a file persists when reopened (portability core)',
    () async {
      final path = p.join(tempDir.path, 'trip.sqlite');

      final c1 = containerAt(path);
      await c1
          .read(repositoryProvider)
          .createTrip(TripsCompanion.insert(title: 'Portable trip'));
      final db1 = c1.read(databaseProvider);
      await db1.checkpoint();
      await db1.close();
      c1.dispose();

      // Reopening the same file (as a fresh app launch would) sees the data.
      final c2 = containerAt(path);
      expect(await titles(c2), ['Portable trip']);
      c2.dispose();
    },
  );

  test('switching the active path swaps which database is shown', () async {
    final pathA = p.join(tempDir.path, 'a.sqlite');
    final pathB = p.join(tempDir.path, 'b.sqlite');

    final c = containerAt(pathA);
    await c
        .read(repositoryProvider)
        .createTrip(TripsCompanion.insert(title: 'In A'));
    expect(await titles(c), ['In A']);

    // Switch to an empty database B.
    await c.read(databaseControllerProvider).openExisting(pathB);
    expect(await titles(c), isEmpty);

    // Switch back to A — its data is intact.
    await c.read(databaseControllerProvider).openExisting(pathA);
    expect(await titles(c), ['In A']);

    // The chosen path was persisted.
    expect(prefs.getString(kDbPathPrefKey), pathA);
    c.dispose();
  });

  test('importFrom replaces the active database contents in place', () async {
    // Build a source database with its own trip.
    final sourcePath = p.join(tempDir.path, 'source.sqlite');
    final source = AppDatabase.atPath(sourcePath);
    await source.tripDao.createTrip(
      TripsCompanion.insert(title: 'Imported trip'),
    );
    await source.checkpoint();
    await source.close();

    // Active database starts with different data.
    final activePath = p.join(tempDir.path, 'active.sqlite');
    final c = containerAt(activePath);
    await c
        .read(repositoryProvider)
        .createTrip(
          TripsCompanion.insert(
            title: 'Original',
            destination: const Value('to be replaced'),
          ),
        );
    expect(await titles(c), ['Original']);

    await c.read(databaseControllerProvider).importFrom(sourcePath);

    // The active path is unchanged, but its contents are now the source's.
    expect(c.read(activeDbPathProvider), activePath);
    expect(await titles(c), ['Imported trip']);
    c.dispose();
  });
}
