import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/daos/currency_dao.dart';
import 'package:travelplanner/data/database/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Map<String, CurrencyRow>> byCode() async {
    final rows = await db.currencyDao.watchCurrencies().first;
    return {for (final r in rows) r.code: r};
  }

  Future<int> addCost(int currencyId) async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'Trip'),
    );
    return db.costDao.addCost(
      CostsCompanion.insert(
        tripId: Value(tripId),
        amountMinor: 1000,
        currency: currencyId,
        reason: 'Food',
      ),
    );
  }

  group('seeding', () {
    test('a fresh database holds the built-ins, EUR the base', () async {
      final rows = await db.currencyDao.watchCurrencies().first;
      expect(rows.map((c) => c.code), ['EUR', 'USD', 'GBP', 'CHF']);
      // Ids follow the enum order, which is what the v23 migration relies on.
      expect(rows.map((c) => c.id), [1, 2, 3, 4]);
      expect(rows.where((c) => c.isBase).map((c) => c.code), ['EUR']);
      expect(rows.first.rateMicros, kRateOne);
      // Nothing else has a rate: the app has no way to know one, and a made-up
      // rate would be worse than none.
      expect(rows.skip(1).map((c) => c.rateMicros), everyElement(isNull));
    });

    test('seeding again adds nothing', () async {
      await db.currencyDao.seedBuiltinCurrencies();
      expect(await db.currencyDao.watchCurrencies().first, hasLength(4));
    });
  });

  group('add / edit / rate', () {
    test('adds a currency at the end of the list', () async {
      final id = await db.currencyDao.addCurrency(
        code: 'JPY',
        symbol: '¥',
        rateMicros: 6000,
      );
      final rows = await db.currencyDao.watchCurrencies().first;
      expect(rows.last.id, id);
      expect(rows.last.code, 'JPY');
      expect(rows.last.rateMicros, 6000);
    });

    test('edits code and symbol without touching the rate', () async {
      final usd = (await byCode())['USD']!;
      await db.currencyDao.setRate(usd.id, 920000);
      await db.currencyDao.editCurrency(usd.id, code: 'USX', symbol: r'$');
      final rows = await db.currencyDao.watchCurrencies().first;
      final edited = rows.firstWhere((c) => c.id == usd.id);
      expect(edited.code, 'USX');
      expect(edited.symbol, r'$');
      expect(edited.rateMicros, 920000);
    });

    test('a null rate means "not known"', () async {
      final usd = (await byCode())['USD']!;
      await db.currencyDao.setRate(usd.id, 920000);
      await db.currencyDao.setRate(usd.id, null);
      expect((await byCode())['USD']!.rateMicros, isNull);
    });

    test("the base's own rate cannot be set away from 1", () async {
      final eur = (await byCode())['EUR']!;
      await db.currencyDao.setRate(eur.id, 500000);
      expect((await byCode())['EUR']!.rateMicros, kRateOne);
    });

    test('reorders by the given ids', () async {
      final all = await db.currencyDao.watchCurrencies().first;
      await db.currencyDao.reorderCurrencies([
        for (final c in all.reversed) c.id,
      ]);
      final rows = await db.currencyDao.watchCurrencies().first;
      expect(rows.map((c) => c.code), ['CHF', 'GBP', 'USD', 'EUR']);
    });
  });

  group('setBase', () {
    test('re-expresses every rate against the new base', () async {
      final codes = await byCode();
      // 1 USD = €0.90, 1 GBP = €1.20.
      await db.currencyDao.setRate(codes['USD']!.id, 900000);
      await db.currencyDao.setRate(codes['GBP']!.id, 1200000);

      await db.currencyDao.setBase(codes['USD']!.id);

      final after = await byCode();
      expect(after['USD']!.isBase, isTrue);
      expect(after['USD']!.rateMicros, kRateOne);
      expect(after['EUR']!.isBase, isFalse);
      // €1 is now worth 1/0.9 = 1.111… USD, and £1 is 1.2/0.9 = 1.333… USD.
      expect(after['EUR']!.rateMicros, 1111111);
      expect(after['GBP']!.rateMicros, 1333333);
      // CHF still has no rate — a base change cannot invent one.
      expect(after['CHF']!.rateMicros, isNull);
    });

    test('clears the rates when the new base has none to divide by', () async {
      final codes = await byCode();
      await db.currencyDao.setRate(codes['USD']!.id, 900000);

      expect(await db.currencyDao.rebaseClearsRates(codes['GBP']!.id), isTrue);
      await db.currencyDao.setBase(codes['GBP']!.id);

      final after = await byCode();
      expect(after['GBP']!.isBase, isTrue);
      expect(after['GBP']!.rateMicros, kRateOne);
      expect(after['USD']!.rateMicros, isNull);
      expect(after['EUR']!.rateMicros, isNull);
    });

    test('rebaseClearsRates is false when nothing would be lost', () async {
      final codes = await byCode();
      // Nothing but the base has a rate, so moving to a rateless currency
      // discards nothing.
      expect(await db.currencyDao.rebaseClearsRates(codes['GBP']!.id), isFalse);
      // And a target with a rate can always be divided by.
      await db.currencyDao.setRate(codes['USD']!.id, 900000);
      expect(await db.currencyDao.rebaseClearsRates(codes['USD']!.id), isFalse);
    });
  });

  group('delete', () {
    test('deletes a currency nothing uses', () async {
      final chf = (await byCode())['CHF']!;
      await db.currencyDao.deleteCurrency(chf.id);
      expect((await byCode()).keys, ['EUR', 'USD', 'GBP']);
    });

    test('refuses to delete a currency an expense is recorded in', () async {
      final usd = (await byCode())['USD']!;
      await addCost(usd.id);
      await expectLater(
        db.currencyDao.deleteCurrency(usd.id),
        throwsA(
          isA<CurrencyInUseException>()
              .having((e) => e.costCount, 'costCount', 1)
              .having((e) => e.isBase, 'isBase', isFalse),
        ),
      );
      expect((await byCode()).containsKey('USD'), isTrue);
    });

    test('refuses to delete the base currency', () async {
      final eur = (await byCode())['EUR']!;
      await expectLater(
        db.currencyDao.deleteCurrency(eur.id),
        throwsA(
          isA<CurrencyInUseException>().having(
            (e) => e.isBase,
            'isBase',
            isTrue,
          ),
        ),
      );
    });
  });

  test('counts the expenses recorded in each currency', () async {
    final codes = await byCode();
    await addCost(codes['EUR']!.id);
    await addCost(codes['EUR']!.id);
    await addCost(codes['USD']!.id);

    expect(await db.currencyDao.countCosts(codes['EUR']!.id), 2);
    final counts = await db.currencyDao.watchCostCounts().first;
    expect(counts[codes['EUR']!.id], 2);
    expect(counts[codes['USD']!.id], 1);
    expect(counts.containsKey(codes['GBP']!.id), isFalse);
  });
}
