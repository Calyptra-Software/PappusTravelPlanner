import '../../core/format/money_format.dart';
import '../../data/database/app_database.dart';

/// Statistics derived from a trip's expenses, split out as pure functions so the
/// splitting and settle-up maths can be unit-tested without a database. All
/// amounts stay in minor units (cents). Costs can be in several currencies and
/// nothing here ever converts between them — everything is computed per
/// currency (see [TripStats.byCurrency]), and the exchange rates the user can
/// set in settings only ever add a converted figure *beside* these, never
/// inside them.

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
/// expenses they benefit from, what they have settled directly with the others,
/// and the resulting balance.
class PersonStat {
  const PersonStat({
    required this.name,
    required this.paidMinor,
    required this.shareMinor,
    this.settledMinor = 0,
  });

  final String name;

  /// What the person paid for the trip's *expenses*. Transfers are not in here
  /// — see [settledMinor].
  final int paidMinor;
  final int shareMinor;

  /// Net of the person-to-person transfers ([Costs.isTransfer]): money handed
  /// over minus money received. Positive when they have paid others back, so it
  /// adds to their balance exactly as paying an expense would; negative when
  /// they have been paid back. Kept apart from [paidMinor] so "paid" still
  /// means "spent on the trip" and still sums to the trip's total.
  final int settledMinor;

  /// Positive when the person is owed money, negative when they owe.
  int get netMinor => paidMinor - shareMinor + settledMinor;
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

  /// The currency's code (`Currencies.code`) — its identity outside the
  /// database, so a merged or shared trip's stats key the same way.
  final String currency;

  /// What the trip cost in this currency. Expenses only: transfers between
  /// people are not spending and stay out of it (see [computeTripStats]).
  final int totalMinor;

  /// Portion of [totalMinor] from expenses already marked paid.
  final int paidMinor;

  /// Portion of [totalMinor] still outstanding (`totalMinor - paidMinor`).
  int get openMinor => totalMinor - paidMinor;

  /// How many expenses make up [totalMinor] — transfers not counted.
  final int count;

  /// Reasons, largest spend first.
  final List<CategoryStat> byCategory;

  /// Everyone who paid or benefited, sorted by name.
  final List<PersonStat> byPerson;

  /// Minimal set of payments that settle the balances.
  final List<Transfer> settlements;
}

/// Per-currency statistics for a whole trip, in the [CurrencyBook]'s display
/// order and only for currencies that actually occur.
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
///
/// **Transfers** ([Costs.isTransfer]) are the one kind of row that is not
/// spending: one person hands money to another to settle up. Such a row moves
/// only the two people's balances — into [PersonStat.settledMinor], never into
/// the total, the paid/open split, the expense count or the categories, because
/// no money left the group. It also never falls back to the participants: a
/// transfer with no receiver recorded moves nobody's balance rather than
/// quietly spreading itself over everyone.
TripStats computeTripStats(
  List<Cost> costs,
  Map<int, List<Person>> beneficiariesByCost,
  List<String> participantNames,
  CurrencyBook book,
) {
  final byCurrency = <String, List<Cost>>{};
  for (final cost in costs) {
    final code = book.byId(cost.currency)?.code;
    if (code == null) continue;
    byCurrency.putIfAbsent(code, () => []).add(cost);
  }

  final result = <CurrencyStats>[];
  for (final code in book.ordered(byCurrency.keys)) {
    final group = byCurrency[code];
    if (group == null || group.isEmpty) continue;
    result.add(
      _statsForCurrency(code, group, beneficiariesByCost, participantNames),
    );
  }
  return TripStats(result);
}

/// Merges several trips' [TripStats] into one, as if their costs were pooled —
/// the all-trips overview. Per currency the category amounts and per-person
/// paid/share are summed and the settle-up recomputed, so it reads exactly like
/// a single trip's stats. Each trip must be computed on its own first (via
/// [computeTripStats]) so a cost still falls back to *its* trip's participants;
/// this only adds the pieces up. [book] fixes the order the currencies come out
/// in, exactly as in [computeTripStats].
TripStats mergeTripStats(Iterable<TripStats> perTrip, CurrencyBook book) {
  final byCurrency = <String, List<CurrencyStats>>{};
  for (final stats in perTrip) {
    for (final c in stats.byCurrency) {
      byCurrency.putIfAbsent(c.currency, () => []).add(c);
    }
  }

  final result = <CurrencyStats>[];
  for (final code in book.ordered(byCurrency.keys)) {
    final group = byCurrency[code];
    if (group == null || group.isEmpty) continue;
    result.add(_mergeCurrency(code, group));
  }
  return TripStats(result);
}

CurrencyStats _mergeCurrency(String currency, List<CurrencyStats> parts) {
  var total = 0;
  var paid = 0;
  var count = 0;
  final categoryAmounts = <String, int>{};
  final categoryCounts = <String, int>{};
  final paidByPerson = <String, int>{};
  final shareByPerson = <String, int>{};
  final settledByPerson = <String, int>{};
  for (final part in parts) {
    total += part.totalMinor;
    paid += part.paidMinor;
    count += part.count;
    for (final cat in part.byCategory) {
      categoryAmounts.update(
        cat.reason,
        (v) => v + cat.amountMinor,
        ifAbsent: () => cat.amountMinor,
      );
      categoryCounts.update(
        cat.reason,
        (v) => v + cat.count,
        ifAbsent: () => cat.count,
      );
    }
    for (final person in part.byPerson) {
      paidByPerson.update(
        person.name,
        (v) => v + person.paidMinor,
        ifAbsent: () => person.paidMinor,
      );
      shareByPerson.update(
        person.name,
        (v) => v + person.shareMinor,
        ifAbsent: () => person.shareMinor,
      );
      settledByPerson.update(
        person.name,
        (v) => v + person.settledMinor,
        ifAbsent: () => person.settledMinor,
      );
    }
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

  final names = {
    ...paidByPerson.keys,
    ...shareByPerson.keys,
    ...settledByPerson.keys,
  }.toList()..sort();
  final byPerson = names
      .map(
        (name) => PersonStat(
          name: name,
          paidMinor: paidByPerson[name] ?? 0,
          shareMinor: shareByPerson[name] ?? 0,
          settledMinor: settledByPerson[name] ?? 0,
        ),
      )
      .toList();

  return CurrencyStats(
    currency: currency,
    totalMinor: total,
    paidMinor: paid,
    count: count,
    byCategory: byCategory,
    byPerson: byPerson,
    settlements: _settle(byPerson),
  );
}

CurrencyStats _statsForCurrency(
  String currency,
  List<Cost> costs,
  Map<int, List<Person>> beneficiariesByCost,
  List<String> participantNames,
) {
  // Every spend figure below is about the expenses only; the transfers are
  // settlements between people and are handled apart, on the balances.
  final expenses = costs.where((c) => !c.isTransfer).toList();
  final transfers = costs.where((c) => c.isTransfer);

  final total = expenses.fold<int>(0, (sum, c) => sum + c.amountMinor);
  final paidTotal = expenses
      .where((c) => c.paid)
      .fold<int>(0, (sum, c) => sum + c.amountMinor);

  // By category (reason).
  final categoryAmounts = <String, int>{};
  final categoryCounts = <String, int>{};
  for (final cost in expenses) {
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
  for (final cost in expenses) {
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

  // Settled, per person: the sender's balance rises by what they handed over,
  // each receiver's falls by what they got. No participant fallback — an
  // unaddressed transfer settles with nobody (see [computeTripStats]).
  final settled = <String, int>{};
  for (final cost in transfers) {
    final sender = cost.paidBy;
    if (sender != null && sender.isNotEmpty) {
      settled.update(
        sender,
        (v) => v + cost.amountMinor,
        ifAbsent: () => cost.amountMinor,
      );
    }
    final receivers = beneficiariesByCost[cost.id]?.map((p) => p.name).toList();
    if (receivers == null) continue;
    for (final entry in _splitEvenly(cost.amountMinor, receivers).entries) {
      settled.update(
        entry.key,
        (v) => v - entry.value,
        ifAbsent: () => -entry.value,
      );
    }
  }

  final names = {...paid.keys, ...share.keys, ...settled.keys}.toList()..sort();
  final byPerson = names
      .map(
        (name) => PersonStat(
          name: name,
          paidMinor: paid[name] ?? 0,
          shareMinor: share[name] ?? 0,
          settledMinor: settled[name] ?? 0,
        ),
      )
      .toList();

  return CurrencyStats(
    currency: currency,
    totalMinor: total,
    paidMinor: paidTotal,
    count: expenses.length,
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
