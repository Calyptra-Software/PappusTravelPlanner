import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// Statistics derived from a trip's expenses, split out as pure functions so the
/// splitting and settle-up maths can be unit-tested without a database. All
/// amounts stay in minor units (cents). Because costs can be in several
/// currencies and the app never converts between them, everything is computed
/// per currency — see [TripStats.byCurrency].

/// One reason's slice of a currency's spending.
class CategoryStat {
  const CategoryStat({
    required this.reason,
    required this.amountMinor,
    required this.count,
    required this.fraction,
  });

  final String reason;
  final int amountMinor;
  final int count;

  /// Share of the currency's total, in `0..1`.
  final double fraction;
}

/// One person's standing in a currency: what they paid, their fair share of the
/// expenses they benefit from, and the resulting balance.
class PersonStat {
  const PersonStat({
    required this.name,
    required this.paidMinor,
    required this.shareMinor,
  });

  final String name;
  final int paidMinor;
  final int shareMinor;

  /// Positive when the person is owed money, negative when they owe.
  int get netMinor => paidMinor - shareMinor;
}

/// A suggested payment that settles part of the balances: [from] pays [to].
class Transfer {
  const Transfer({
    required this.from,
    required this.to,
    required this.amountMinor,
  });

  final String from;
  final String to;
  final int amountMinor;
}

/// All statistics for a single currency.
class CurrencyStats {
  const CurrencyStats({
    required this.currency,
    required this.totalMinor,
    required this.paidMinor,
    required this.count,
    required this.byCategory,
    required this.byPerson,
    required this.settlements,
  });

  final Currency currency;
  final int totalMinor;

  /// Portion of [totalMinor] from expenses already marked paid.
  final int paidMinor;

  /// Portion of [totalMinor] still outstanding (`totalMinor - paidMinor`).
  int get openMinor => totalMinor - paidMinor;

  final int count;

  /// Reasons, largest spend first.
  final List<CategoryStat> byCategory;

  /// Everyone who paid or benefited, sorted by name.
  final List<PersonStat> byPerson;

  /// Minimal set of payments that settle the balances.
  final List<Transfer> settlements;
}

/// Per-currency statistics for a whole trip, in the stable [Currency] order and
/// only for currencies that actually occur.
class TripStats {
  const TripStats(this.byCurrency);

  final List<CurrencyStats> byCurrency;

  bool get isEmpty => byCurrency.isEmpty;
}

/// Computes [TripStats] from a trip's [costs], the beneficiary split for each
/// cost (keyed by cost id, as [CostDao.watchBeneficiariesForTrip] returns), and
/// the trip's [participantNames].
///
/// A cost's amount is shared among its listed beneficiaries; a cost with none
/// falls back to being split across all [participantNames], and if there are no
/// participants either it counts toward totals and categories but toward no
/// one's share. Splits are integer-exact: the remainder cents go to the first
/// beneficiaries in name order so every person's shares still sum to the total.
TripStats computeTripStats(
  List<Cost> costs,
  Map<int, List<Person>> beneficiariesByCost,
  List<String> participantNames,
) {
  final byCurrency = <Currency, List<Cost>>{};
  for (final cost in costs) {
    byCurrency.putIfAbsent(cost.currency, () => []).add(cost);
  }

  final result = <CurrencyStats>[];
  for (final currency in Currency.values) {
    final group = byCurrency[currency];
    if (group == null || group.isEmpty) continue;
    result.add(
      _statsForCurrency(currency, group, beneficiariesByCost, participantNames),
    );
  }
  return TripStats(result);
}

CurrencyStats _statsForCurrency(
  Currency currency,
  List<Cost> costs,
  Map<int, List<Person>> beneficiariesByCost,
  List<String> participantNames,
) {
  final total = costs.fold<int>(0, (sum, c) => sum + c.amountMinor);
  final paidTotal = costs
      .where((c) => c.paid)
      .fold<int>(0, (sum, c) => sum + c.amountMinor);

  // By category (reason).
  final categoryAmounts = <String, int>{};
  final categoryCounts = <String, int>{};
  for (final cost in costs) {
    categoryAmounts.update(
      cost.reason,
      (v) => v + cost.amountMinor,
      ifAbsent: () => cost.amountMinor,
    );
    categoryCounts.update(cost.reason, (v) => v + 1, ifAbsent: () => 1);
  }
  final byCategory =
      categoryAmounts.entries
          .map(
            (e) => CategoryStat(
              reason: e.key,
              amountMinor: e.value,
              count: categoryCounts[e.key]!,
              fraction: total == 0 ? 0 : e.value / total,
            ),
          )
          .toList()
        ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

  // Paid and share, per person.
  final paid = <String, int>{};
  final share = <String, int>{};
  for (final cost in costs) {
    final payer = cost.paidBy;
    if (payer != null && payer.isNotEmpty) {
      paid.update(
        payer,
        (v) => v + cost.amountMinor,
        ifAbsent: () => cost.amountMinor,
      );
    }
    final beneficiaries =
        beneficiariesByCost[cost.id]?.map((p) => p.name).toList() ??
        participantNames;
    for (final entry in _splitEvenly(cost.amountMinor, beneficiaries).entries) {
      share.update(
        entry.key,
        (v) => v + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }

  final names = {...paid.keys, ...share.keys}.toList()..sort();
  final byPerson = names
      .map(
        (name) => PersonStat(
          name: name,
          paidMinor: paid[name] ?? 0,
          shareMinor: share[name] ?? 0,
        ),
      )
      .toList();

  return CurrencyStats(
    currency: currency,
    totalMinor: total,
    paidMinor: paidTotal,
    count: costs.length,
    byCategory: byCategory,
    byPerson: byPerson,
    settlements: _settle(byPerson),
  );
}

/// Splits [amountMinor] evenly across [names], handing the remainder cents to
/// the first names (in the given order) so the parts sum back to [amountMinor]
/// exactly. Returns an empty map when there is no one to split among.
Map<String, int> _splitEvenly(int amountMinor, List<String> names) {
  if (names.isEmpty) return const {};
  final ordered = [...names]..sort();
  final base = amountMinor ~/ ordered.length;
  final remainder = amountMinor % ordered.length;
  final result = <String, int>{};
  for (var i = 0; i < ordered.length; i++) {
    // A name can repeat if it appears twice; accumulate rather than overwrite.
    result.update(
      ordered[i],
      (v) => v + base + (i < remainder ? 1 : 0),
      ifAbsent: () => base + (i < remainder ? 1 : 0),
    );
  }
  return result;
}

/// Greedily reduces balances to a minimal-ish set of transfers: repeatedly the
/// largest debtor pays the largest creditor. Balances need not sum to zero
/// (costs with a payer but no split, or vice-versa, leave a remainder); the pass
/// settles as much as it can and stops.
List<Transfer> _settle(List<PersonStat> people) {
  final creditors =
      people
          .where((p) => p.netMinor > 0)
          .map((p) => _Bal(p.name, p.netMinor))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
  final debtors =
      people
          .where((p) => p.netMinor < 0)
          .map((p) => _Bal(p.name, -p.netMinor))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  final transfers = <Transfer>[];
  var i = 0;
  var j = 0;
  while (i < creditors.length && j < debtors.length) {
    final amount = creditors[i].amount < debtors[j].amount
        ? creditors[i].amount
        : debtors[j].amount;
    if (amount > 0) {
      transfers.add(
        Transfer(
          from: debtors[j].name,
          to: creditors[i].name,
          amountMinor: amount,
        ),
      );
    }
    creditors[i].amount -= amount;
    debtors[j].amount -= amount;
    if (creditors[i].amount == 0) i++;
    if (debtors[j].amount == 0) j++;
  }
  return transfers;
}

class _Bal {
  _Bal(this.name, this.amount);
  final String name;
  int amount;
}
