import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/costs/trip_stats.dart';

void main() {
  var nextId = 0;
  Cost cost(
    int minor, {
    Currency currency = Currency.eur,
    String reason = 'Food',
    String? paidBy,
  }) =>
      Cost(
        id: ++nextId,
        tripId: 1,
        amountMinor: minor,
        currency: currency,
        reason: reason,
        paidBy: paidBy,
        createdAt: DateTime(2026),
      );

  Person person(String name) => Person(id: name.hashCode, name: name, isMe: false);

  CurrencyStats onlyCurrency(TripStats stats) {
    expect(stats.byCurrency, hasLength(1));
    return stats.byCurrency.single;
  }

  setUp(() => nextId = 0);

  group('categories', () {
    test('groups by reason, sorted by amount, with fractions', () {
      final stats = computeTripStats(
        [
          cost(3000, reason: 'Food'),
          cost(1000, reason: 'Food'),
          cost(6000, reason: 'Hotel'),
        ],
        const {},
        const [],
      );
      final cur = onlyCurrency(stats);
      expect(cur.totalMinor, 10000);
      expect(cur.byCategory.map((c) => c.reason), ['Hotel', 'Food']);
      expect(cur.byCategory.first.amountMinor, 6000);
      expect(cur.byCategory.first.fraction, closeTo(0.6, 1e-9));
      expect(cur.byCategory.first.count, 1);
      expect(cur.byCategory.last.count, 2);
    });
  });

  group('splits and balances', () {
    test('splits a cost across its beneficiaries, remainder to first names', () {
      final c = cost(1000, paidBy: 'Ann'); // 10.00 across 3 people
      final stats = computeTripStats(
        [c],
        {
          c.id: [person('Ann'), person('Bo'), person('Cy')],
        },
        const [],
      );
      final byPerson = {
        for (final p in onlyCurrency(stats).byPerson) p.name: p,
      };
      // 1000 / 3 = 333 each, remainder 1 to the first name alphabetically.
      expect(byPerson['Ann']!.shareMinor, 334);
      expect(byPerson['Bo']!.shareMinor, 333);
      expect(byPerson['Cy']!.shareMinor, 333);
      // Shares sum back to the full amount exactly.
      expect(
        byPerson.values.fold<int>(0, (s, p) => s + p.shareMinor),
        1000,
      );
      expect(byPerson['Ann']!.paidMinor, 1000);
      expect(byPerson['Ann']!.netMinor, 1000 - 334);
    });

    test('falls back to participants when a cost has no beneficiaries', () {
      final stats = computeTripStats(
        [cost(1000, paidBy: 'Ann')],
        const {},
        const ['Ann', 'Bo'],
      );
      final byPerson = {
        for (final p in onlyCurrency(stats).byPerson) p.name: p,
      };
      expect(byPerson['Ann']!.shareMinor, 500);
      expect(byPerson['Bo']!.shareMinor, 500);
      expect(byPerson['Bo']!.netMinor, -500); // owes 5.00
    });

    test('settle-up nets balances into minimal transfers', () {
      // Ann pays 60 split evenly among Ann, Bo, Cy -> each owes 20.
      final c = cost(6000, paidBy: 'Ann');
      final stats = computeTripStats(
        [c],
        {
          c.id: [person('Ann'), person('Bo'), person('Cy')],
        },
        const [],
      );
      final cur = onlyCurrency(stats);
      final transfers = {for (final t in cur.settlements) t.from: t};
      expect(cur.settlements, hasLength(2));
      expect(transfers['Bo']!.to, 'Ann');
      expect(transfers['Bo']!.amountMinor, 2000);
      expect(transfers['Cy']!.to, 'Ann');
      expect(transfers['Cy']!.amountMinor, 2000);
    });

    test('no transfers when everyone is even', () {
      final c = cost(2000, paidBy: 'Ann');
      final stats = computeTripStats(
        [c],
        {
          c.id: [person('Ann')],
        },
        const [],
      );
      expect(onlyCurrency(stats).settlements, isEmpty);
    });
  });

  test('keeps currencies separate, in enum order', () {
    final stats = computeTripStats(
      [
        cost(2000, currency: Currency.usd),
        cost(1000, currency: Currency.eur),
      ],
      const {},
      const [],
    );
    expect(stats.byCurrency.map((c) => c.currency),
        [Currency.eur, Currency.usd]);
    expect(stats.byCurrency.first.totalMinor, 1000);
  });

  test('empty when there are no costs', () {
    expect(computeTripStats(const [], const {}, const []).isEmpty, isTrue);
  });
}
