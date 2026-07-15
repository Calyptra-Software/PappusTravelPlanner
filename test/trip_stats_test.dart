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
    bool paid = false,
  }) => Cost(
    id: ++nextId,
    tripId: 1,
    amountMinor: minor,
    currency: currency,
    reason: reason,
    paidBy: paidBy,
    paid: paid,
    createdAt: DateTime(2026),
  );

  Person person(String name) =>
      Person(id: name.hashCode, name: name, isMe: false);

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

  group('paid vs open', () {
    test('sums paid expenses into paidMinor, leaving the rest open', () {
      final stats = computeTripStats(
        [cost(3000, paid: true), cost(1000, paid: true), cost(6000)],
        const {},
        const [],
      );
      final cur = onlyCurrency(stats);
      expect(cur.totalMinor, 10000);
      expect(cur.paidMinor, 4000);
      expect(cur.openMinor, 6000);
    });

    test(
      'paidMinor is zero and openMinor is the total when nothing is paid',
      () {
        final cur = onlyCurrency(
          computeTripStats([cost(2500)], const {}, const []),
        );
        expect(cur.paidMinor, 0);
        expect(cur.openMinor, 2500);
      },
    );

    test('tracks paid/open per currency', () {
      final stats = computeTripStats(
        [
          cost(1000, paid: true),
          cost(500, currency: Currency.usd, paid: true),
          cost(500, currency: Currency.usd),
        ],
        const {},
        const [],
      );
      final eur = stats.byCurrency.firstWhere(
        (c) => c.currency == Currency.eur,
      );
      final usd = stats.byCurrency.firstWhere(
        (c) => c.currency == Currency.usd,
      );
      expect(eur.paidMinor, 1000);
      expect(eur.openMinor, 0);
      expect(usd.paidMinor, 500);
      expect(usd.openMinor, 500);
    });
  });

  group('splits and balances', () {
    test(
      'splits a cost across its beneficiaries, remainder to first names',
      () {
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
        expect(byPerson.values.fold<int>(0, (s, p) => s + p.shareMinor), 1000);
        expect(byPerson['Ann']!.paidMinor, 1000);
        expect(byPerson['Ann']!.netMinor, 1000 - 334);
      },
    );

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
      [cost(2000, currency: Currency.usd), cost(1000, currency: Currency.eur)],
      const {},
      const [],
    );
    expect(stats.byCurrency.map((c) => c.currency), [
      Currency.eur,
      Currency.usd,
    ]);
    expect(stats.byCurrency.first.totalMinor, 1000);
  });

  test('empty when there are no costs', () {
    expect(computeTripStats(const [], const {}, const []).isEmpty, isTrue);
  });

  group('mergeTripStats', () {
    test(
      'pools categories, per-person paid/share and settle-up per currency',
      () {
        // Trip 1: Ann pays 100 shared by Ann and Bob.
        final trip1 = computeTripStats(
          [cost(10000, reason: 'Hotel', paidBy: 'Ann')],
          const {},
          const ['Ann', 'Bob'],
        );
        // Trip 2: Bob pays 40 for Food shared by Ann and Bob.
        final trip2 = computeTripStats(
          [cost(4000, reason: 'Food', paidBy: 'Bob')],
          const {},
          const ['Ann', 'Bob'],
        );

        final merged = mergeTripStats([trip1, trip2]);
        final cur = onlyCurrency(merged);

        expect(cur.totalMinor, 14000);
        expect(cur.count, 2);
        // Categories summed and sorted by amount.
        expect(cur.byCategory.map((c) => c.reason), ['Hotel', 'Food']);

        // Ann paid 100, share 50+20 = 70 → +30; Bob paid 40, share 70 → −30.
        final ann = cur.byPerson.firstWhere((p) => p.name == 'Ann');
        final bob = cur.byPerson.firstWhere((p) => p.name == 'Bob');
        expect(ann.paidMinor, 10000);
        expect(ann.shareMinor, 7000);
        expect(bob.netMinor, -3000);

        // Settle-up recomputed from the pooled balances.
        expect(cur.settlements, hasLength(1));
        expect(cur.settlements.single.from, 'Bob');
        expect(cur.settlements.single.to, 'Ann');
        expect(cur.settlements.single.amountMinor, 3000);
      },
    );

    test('keeps currencies separate and is empty with no data', () {
      final merged = mergeTripStats([
        computeTripStats(
          [cost(2000, currency: Currency.usd)],
          const {},
          const [],
        ),
        computeTripStats(
          [cost(1000, currency: Currency.eur)],
          const {},
          const [],
        ),
      ]);
      expect(merged.byCurrency.map((c) => c.currency), [
        Currency.eur,
        Currency.usd,
      ]);
      expect(mergeTripStats(const []).isEmpty, isTrue);
    });
  });
}
