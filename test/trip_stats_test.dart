import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/costs/trip_stats.dart';

import 'currency_fixture.dart';

void main() {
  var nextId = 0;
  Cost cost(
    int minor, {
    int currency = eurId,
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
    isTransfer: false,
    isReimbursement: false,
    createdAt: DateTime(2026),
  );

  /// A settlement: [from] hands [minor] to someone (the receiver is the row's
  /// beneficiary, wired up by each test).
  ///
  /// With [reimbursement] the money came from outside the group instead.
  Cost transfer(
    int minor, {
    int currency = eurId,
    required String? from,
    bool reimbursement = false,
  }) => Cost(
    id: ++nextId,
    tripId: 1,
    amountMinor: minor,
    currency: currency,
    reason: '',
    paidBy: from,
    paid: true,
    isTransfer: true,
    isReimbursement: reimbursement,
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
        seededBook,
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
        seededBook,
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
          computeTripStats([cost(2500)], const {}, const [], seededBook),
        );
        expect(cur.paidMinor, 0);
        expect(cur.openMinor, 2500);
      },
    );

    test('tracks paid/open per currency', () {
      final stats = computeTripStats(
        [
          cost(1000, paid: true),
          cost(500, currency: usdId, paid: true),
          cost(500, currency: usdId),
        ],
        const {},
        const [],
        seededBook,
      );
      final eur = stats.byCurrency.firstWhere((c) => c.currency == 'EUR');
      final usd = stats.byCurrency.firstWhere((c) => c.currency == 'USD');
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
          seededBook,
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
        seededBook,
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
        seededBook,
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
        seededBook,
      );
      expect(onlyCurrency(stats).settlements, isEmpty);
    });
  });

  group('settlements between people', () {
    test('a settlement clears the debt it repays', () {
      // Ann pays 60 for the three of them: Bo and Cy owe her 20 each.
      final dinner = cost(6000, paidBy: 'Ann');
      // Bo hands Ann his 20 back.
      final repayment = transfer(2000, from: 'Bo');
      final stats = computeTripStats(
        [dinner, repayment],
        {
          dinner.id: [person('Ann'), person('Bo'), person('Cy')],
          repayment.id: [person('Ann')],
        },
        const [],
        seededBook,
      );
      final cur = onlyCurrency(stats);
      final byPerson = {for (final p in cur.byPerson) p.name: p};

      // Bo is square; Ann is owed only Cy's share now.
      expect(byPerson['Bo']!.netMinor, 0);
      expect(byPerson['Ann']!.netMinor, 2000);
      expect(byPerson['Cy']!.netMinor, -2000);
      expect(cur.settlements, hasLength(1));
      expect(cur.settlements.single.from, 'Cy');
      expect(cur.settlements.single.to, 'Ann');
      expect(cur.settlements.single.amountMinor, 2000);
    });

    test('the repayment is not spending: total, count and categories', () {
      final dinner = cost(6000, reason: 'Dinner', paidBy: 'Ann');
      final repayment = transfer(2000, from: 'Bo');
      final stats = computeTripStats(
        [dinner, repayment],
        {
          dinner.id: [person('Ann'), person('Bo')],
          repayment.id: [person('Ann')],
        },
        const [],
        seededBook,
      );
      final cur = onlyCurrency(stats);

      expect(cur.totalMinor, 6000);
      expect(cur.count, 1);
      expect(cur.byCategory.map((c) => c.reason), ['Dinner']);
      expect(cur.byCategory.single.fraction, 1.0);
      // Nor does it move the paid/open split, though it is itself settled.
      expect(cur.paidMinor, 0);
      expect(cur.openMinor, 6000);
    });

    test('keeps "paid" meaning spent, reporting the settlement apart', () {
      final dinner = cost(6000, paidBy: 'Ann');
      final repayment = transfer(2000, from: 'Bo');
      final stats = computeTripStats(
        [dinner, repayment],
        {
          dinner.id: [person('Ann'), person('Bo'), person('Cy')],
          repayment.id: [person('Ann')],
        },
        const [],
        seededBook,
      );
      final byPerson = {
        for (final p in onlyCurrency(stats).byPerson) p.name: p,
      };

      // Bo spent nothing on the trip; he settled 20 with Ann.
      expect(byPerson['Bo']!.paidMinor, 0);
      expect(byPerson['Bo']!.settledMinor, 2000);
      // Ann's "paid" is still the dinner alone; the 20 she got back is settled.
      expect(byPerson['Ann']!.paidMinor, 6000);
      expect(byPerson['Ann']!.settledMinor, -2000);
      // The per-person paid figures still sum to the trip's total.
      expect(
        byPerson.values.fold<int>(0, (s, p) => s + p.paidMinor),
        onlyCurrency(stats).totalMinor,
      );
    });

    test('a settlement with no receiver moves nobody but the sender', () {
      // No beneficiary recorded: it must not spread over the participants the
      // way an expense would.
      final stats = computeTripStats(
        [transfer(2000, from: 'Bo')],
        const {},
        const ['Ann', 'Bo', 'Cy'],
        seededBook,
      );
      final byPerson = {
        for (final p in onlyCurrency(stats).byPerson) p.name: p,
      };
      expect(byPerson.keys, ['Bo']);
      expect(byPerson['Bo']!.settledMinor, 2000);
    });

    test('settles in its own currency only', () {
      final dinner = cost(6000, paidBy: 'Ann');
      final repayment = transfer(3000, currency: usdId, from: 'Bo');
      final stats = computeTripStats(
        [dinner, repayment],
        {
          dinner.id: [person('Ann'), person('Bo')],
          repayment.id: [person('Ann')],
        },
        const [],
        seededBook,
      );
      final eur = stats.byCurrency.firstWhere((c) => c.currency == 'EUR');
      final usd = stats.byCurrency.firstWhere((c) => c.currency == 'USD');

      // The euro debt stands — dollars don't pay it off.
      expect(eur.settlements.single.from, 'Bo');
      expect(eur.settlements.single.amountMinor, 3000);
      // The dollar side is a currency with no spending at all, just a balance.
      expect(usd.totalMinor, 0);
      expect(usd.count, 0);
      expect(usd.byCategory, isEmpty);
      expect(usd.settlements.single.from, 'Ann');
      expect(usd.settlements.single.amountMinor, 3000);
    });

    test('merged across trips, settlements travel with the balances', () {
      final dinner = cost(6000, paidBy: 'Ann');
      final trip1 = computeTripStats(
        [dinner],
        {
          dinner.id: [person('Ann'), person('Bo')],
        },
        const [],
        seededBook,
      );
      final repayment = transfer(3000, from: 'Bo');
      final trip2 = computeTripStats(
        [repayment],
        {
          repayment.id: [person('Ann')],
        },
        const [],
        seededBook,
      );

      final cur = onlyCurrency(mergeTripStats([trip1, trip2], seededBook));
      expect(cur.totalMinor, 6000);
      expect(cur.count, 1);
      final byPerson = {for (final p in cur.byPerson) p.name: p};
      expect(byPerson['Bo']!.settledMinor, 3000);
      expect(byPerson['Bo']!.netMinor, 0);
      expect(cur.settlements, isEmpty);
    });
  });

  group('reimbursements from outside the group', () {
    test('an allowance leaves its receiver owing nobody', () {
      // Ann pays her own hotel and her employer pays her a flat allowance.
      // Booked as an ordinary settlement it would put her 280 in the
      // employer's debt; as a reimbursement it moves nothing.
      final hotel = cost(30000, reason: 'Hotel', paidBy: 'Ann');
      final allowance = transfer(28000, from: 'Employer', reimbursement: true);
      final stats = computeTripStats(
        [hotel, allowance],
        {
          hotel.id: [person('Ann')],
          allowance.id: [person('Ann')],
        },
        const [],
        seededBook,
      );
      final cur = onlyCurrency(stats);
      final ann = cur.byPerson.single;

      expect(ann.name, 'Ann');
      expect(ann.netMinor, 0);
      expect(ann.settledMinor, 0);
      expect(ann.reimbursedMinor, 28000);
      expect(cur.settlements, isEmpty);
      // The source is nobody on the trip, so it has no balance to show.
      expect(cur.byPerson.map((p) => p.name), isNot(contains('Employer')));
    });

    test(
      'is not spending: total, count, categories and paid are unchanged',
      () {
        final hotel = cost(30000, reason: 'Hotel', paidBy: 'Ann', paid: true);
        final allowance = transfer(
          28000,
          from: 'Employer',
          reimbursement: true,
        );
        final cur = onlyCurrency(
          computeTripStats(
            [hotel, allowance],
            {
              hotel.id: [person('Ann')],
              allowance.id: [person('Ann')],
            },
            const [],
            seededBook,
          ),
        );

        expect(cur.totalMinor, 30000);
        expect(cur.count, 1);
        expect(cur.byCategory.map((c) => c.reason), ['Hotel']);
        expect(cur.paidMinor, 30000);
        expect(cur.byPerson.single.paidMinor, 30000);
      },
    );

    test('is reported per source, largest first', () {
      final a = transfer(5000, from: 'Employer', reimbursement: true);
      final b = transfer(3000, from: 'Insurer', reimbursement: true);
      final c = transfer(4000, from: 'Employer', reimbursement: true);
      final cur = onlyCurrency(
        computeTripStats(
          [a, b, c],
          {
            a.id: [person('Ann')],
            b.id: [person('Bo')],
            c.id: [person('Bo')],
          },
          const [],
          seededBook,
        ),
      );

      expect(cur.reimbursementsBySource.map((s) => s.name), [
        'Employer',
        'Insurer',
      ]);
      expect(cur.reimbursementsBySource.map((s) => s.amountMinor), [
        9000,
        3000,
      ]);
      expect(cur.reimbursedMinor, 12000);
      final byPerson = {for (final p in cur.byPerson) p.name: p};
      expect(byPerson['Ann']!.reimbursedMinor, 5000);
      expect(byPerson['Bo']!.reimbursedMinor, 7000);
    });

    test('belongs to its receiver: a debt to them still stands', () {
      // Ann pays 60 for herself and Bo, and her allowance covers all of it —
      // Bo still owes her his 30, since the allowance is hers.
      final dinner = cost(6000, paidBy: 'Ann');
      final allowance = transfer(6000, from: 'Employer', reimbursement: true);
      final cur = onlyCurrency(
        computeTripStats(
          [dinner, allowance],
          {
            dinner.id: [person('Ann'), person('Bo')],
            allowance.id: [person('Ann')],
          },
          const [],
          seededBook,
        ),
      );

      expect(cur.settlements, hasLength(1));
      expect(cur.settlements.single.from, 'Bo');
      expect(cur.settlements.single.to, 'Ann');
      expect(cur.settlements.single.amountMinor, 3000);
    });

    test('lists a reimbursement with no source under the empty name', () {
      final allowance = transfer(1000, from: null, reimbursement: true);
      final cur = onlyCurrency(
        computeTripStats(
          [allowance],
          {
            allowance.id: [person('Ann')],
          },
          const [],
          seededBook,
        ),
      );
      expect(cur.reimbursementsBySource.single.name, '');
      expect(cur.byPerson.single.netMinor, 0);
    });

    test('is pooled across trips by source and by receiver', () {
      Map<int, List<Person>> toAnn(Cost c) => {
        c.id: [person('Ann')],
      };
      final first = transfer(28000, from: 'Employer', reimbursement: true);
      final second = transfer(14000, from: 'Employer', reimbursement: true);
      final cur = onlyCurrency(
        mergeTripStats([
          computeTripStats([first], toAnn(first), const [], seededBook),
          computeTripStats([second], toAnn(second), const [], seededBook),
        ], seededBook),
      );

      expect(cur.reimbursementsBySource.single.name, 'Employer');
      expect(cur.reimbursementsBySource.single.amountMinor, 42000);
      expect(cur.byPerson.single.reimbursedMinor, 42000);
      expect(cur.byPerson.single.netMinor, 0);
      expect(cur.settlements, isEmpty);
    });
  });

  test('keeps currencies separate, in the book order', () {
    final stats = computeTripStats(
      [cost(2000, currency: usdId), cost(1000, currency: eurId)],
      const {},
      const [],
      seededBook,
    );
    expect(stats.byCurrency.map((c) => c.currency), ['EUR', 'USD']);
    expect(stats.byCurrency.first.totalMinor, 1000);
  });

  test('empty when there are no costs', () {
    expect(
      computeTripStats(const [], const {}, const [], seededBook).isEmpty,
      isTrue,
    );
  });

  group('invitations', () {
    Map<String, PersonStat> byName(CurrencyStats cur) => {
      for (final p in cur.byPerson) p.name: p,
    };

    test('a guest owes nothing and the payer carries the share', () {
      // Ann pays 90 for Ann, Bo and Cy; Bo is invited, Cy repays.
      final dinner = cost(9000, paidBy: 'Ann');
      final cur = onlyCurrency(
        computeTripStats(
          [dinner],
          {
            dinner.id: [person('Ann'), person('Bo'), person('Cy')],
          },
          const [],
          seededBook,
          invitedByCost: {
            dinner.id: {'Bo'},
          },
        ),
      );
      final people = byName(cur);

      // What was spent, and on whom, is unchanged.
      expect(cur.totalMinor, 9000);
      expect(cur.byCategory.single.amountMinor, 9000);
      expect(people.values.map((p) => p.shareMinor), [3000, 3000, 3000]);

      expect(people['Bo']!.invitedMinor, 3000);
      expect(people['Bo']!.borneMinor, 0);
      expect(people['Bo']!.netMinor, 0);
      expect(people['Ann']!.hostedMinor, 3000);
      expect(people['Ann']!.borneMinor, 6000);
      expect(people['Ann']!.netMinor, 3000);
      expect(people['Cy']!.netMinor, -3000);

      expect(cur.settlements, hasLength(1));
      expect(cur.settlements.single.from, 'Cy');
      expect(cur.settlements.single.to, 'Ann');
      expect(cur.settlements.single.amountMinor, 3000);
    });

    test('inviting everyone leaves nobody owing anything', () {
      final dinner = cost(9001, paidBy: 'Ann');
      final cur = onlyCurrency(
        computeTripStats(
          [dinner],
          {
            dinner.id: [person('Ann'), person('Bo'), person('Cy')],
          },
          const [],
          seededBook,
          invitedByCost: {
            dinner.id: {'Bo', 'Cy'},
          },
        ),
      );
      final people = byName(cur);
      // The odd cent is Ann's own share, so all of it stays with her.
      expect(people['Ann']!.borneMinor, 9001);
      expect(people.values.map((p) => p.netMinor), everyElement(0));
      expect(cur.settlements, isEmpty);
    });

    test('is ignored without a payer, on the payer, and on the fallback', () {
      final unpaid = cost(6000);
      final ownShare = cost(6000, paidBy: 'Ann');
      final fallback = cost(6000, paidBy: 'Ann');
      final cur = onlyCurrency(
        computeTripStats(
          [unpaid, ownShare, fallback],
          {
            unpaid.id: [person('Ann'), person('Bo')],
            ownShare.id: [person('Ann'), person('Bo')],
          },
          const ['Ann', 'Bo'],
          seededBook,
          invitedByCost: {
            unpaid.id: {'Bo'},
            ownShare.id: {'Ann'},
            // An invitation only ever names an explicit beneficiary.
            fallback.id: {'Bo'},
          },
        ),
      );
      for (final p in cur.byPerson) {
        expect(p.invitedMinor, 0, reason: p.name);
        expect(p.hostedMinor, 0, reason: p.name);
      }
    });

    test('pools across trips', () {
      final first = cost(4000, paidBy: 'Ann');
      final second = cost(2000, paidBy: 'Bo');
      final merged = onlyCurrency(
        mergeTripStats([
          computeTripStats(
            [first],
            {
              first.id: [person('Ann'), person('Bo')],
            },
            const [],
            seededBook,
            invitedByCost: {
              first.id: {'Bo'},
            },
          ),
          computeTripStats(
            [second],
            {
              second.id: [person('Ann'), person('Bo')],
            },
            const [],
            seededBook,
            invitedByCost: {
              second.id: {'Ann'},
            },
          ),
        ], seededBook),
      );
      final people = byName(merged);
      expect(people['Ann']!.invitedMinor, 1000);
      expect(people['Ann']!.hostedMinor, 2000);
      expect(people['Bo']!.invitedMinor, 2000);
      expect(people['Bo']!.hostedMinor, 1000);
      // Each invited the other and paid for it: nothing to settle.
      expect(merged.settlements, isEmpty);
    });
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
          seededBook,
        );
        // Trip 2: Bob pays 40 for Food shared by Ann and Bob.
        final trip2 = computeTripStats(
          [cost(4000, reason: 'Food', paidBy: 'Bob')],
          const {},
          const ['Ann', 'Bob'],
          seededBook,
        );

        final merged = mergeTripStats([trip1, trip2], seededBook);
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
          [cost(2000, currency: usdId)],
          const {},
          const [],
          seededBook,
        ),
        computeTripStats(
          [cost(1000, currency: eurId)],
          const {},
          const [],
          seededBook,
        ),
      ], seededBook);
      expect(merged.byCurrency.map((c) => c.currency), ['EUR', 'USD']);
      expect(mergeTripStats(const [], seededBook).isEmpty, isTrue);
    });
  });
}
