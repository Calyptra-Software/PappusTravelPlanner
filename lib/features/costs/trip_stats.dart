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
    this.reimbursedMinor = 0,
    this.invitedMinor = 0,
    this.hostedMinor = 0,
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

  /// What the person received in reimbursements ([Costs.isReimbursement]) —
  /// money from outside the group. Deliberately **not** in [netMinor]: nobody
  /// on the trip owes the source anything, so it is reported beside the
  /// balance, as what [borneMinor] came to once it came back.
  final int reimbursedMinor;

  /// The part of [shareMinor] somebody else invited the person to
  /// ([CostBeneficiaries.invited]): theirs to have had, not theirs to repay.
  final int invitedMinor;

  /// The shares of others the person invited them to, as the payer — carried
  /// by them instead of being owed back.
  final int hostedMinor;

  /// What the person's expenses came to in the end: their [shareMinor], less
  /// what they were invited to, plus what they invited others to. Before any
  /// reimbursement, which [reimbursedMinor] reports beside it.
  int get borneMinor => shareMinor - invitedMinor + hostedMinor;

  /// Positive when the person is owed money, negative when they owe.
  int get netMinor => paidMinor - borneMinor + settledMinor;
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
    this.reimbursementsBySource = const [],
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

  /// What came back from outside the group, per source — largest first. A
  /// source is named by the reimbursement's [Costs.paidBy]; one recorded with
  /// none is listed under the empty name.
  final List<SourceStat> reimbursementsBySource;

  /// Everything reimbursed in this currency.
  int get reimbursedMinor =>
      reimbursementsBySource.fold(0, (sum, s) => sum + s.amountMinor);
}

/// One source's reimbursements in a currency — an employer, an insurer.
class SourceStat {
  const SourceStat({required this.name, required this.amountMinor});

  final String name;
  final int amountMinor;
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
///
/// A **reimbursement** ([Costs.isReimbursement]) is a transfer whose money came
/// from outside the group. It moves no balance at all — counting it would leave
/// the receiver owing the source what the source handed over — and is collected
/// instead into the receiver's [PersonStat.reimbursedMinor] and the currency's
/// [CurrencyStats.reimbursementsBySource]. It belongs to its receiver alone: an
/// allowance covering the receiver's own share says nothing about what somebody
/// else on the trip owes them.
///
/// An **invitation** ([invitedByCost], names keyed by cost id, as
/// [CostDao.watchInvitedForTrip] returns) says that the payer carries a
/// beneficiary's share rather than being owed it. The share stays the guest's
/// in [PersonStat.shareMinor] — it is what they had — and the totals and
/// categories do not move, since the money was spent all the same; what moves
/// is the balance, the share being booked to the guest's
/// [PersonStat.invitedMinor] and the payer's [PersonStat.hostedMinor]. An
/// invitation needs a payer and a beneficiary who is not the payer, and is
/// ignored on anything else: nobody can be invited by nobody, and inviting
/// oneself changes nothing. It only ever names an explicit beneficiary, so a
/// cost split by the participant fallback invites nobody.
TripStats computeTripStats(
  List<Cost> costs,
  Map<int, List<Person>> beneficiariesByCost,
  List<String> participantNames,
  CurrencyBook book, {
  Map<int, Set<String>> invitedByCost = const {},
}) {
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
      _statsForCurrency(
        code,
        group,
        beneficiariesByCost,
        participantNames,
        invitedByCost,
      ),
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
  final reimbursedByPerson = <String, int>{};
  final invitedByPerson = <String, int>{};
  final hostedByPerson = <String, int>{};
  final bySource = <String, int>{};
  for (final part in parts) {
    for (final source in part.reimbursementsBySource) {
      bySource.update(
        source.name,
        (v) => v + source.amountMinor,
        ifAbsent: () => source.amountMinor,
      );
    }
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
      reimbursedByPerson.update(
        person.name,
        (v) => v + person.reimbursedMinor,
        ifAbsent: () => person.reimbursedMinor,
      );
      invitedByPerson.update(
        person.name,
        (v) => v + person.invitedMinor,
        ifAbsent: () => person.invitedMinor,
      );
      hostedByPerson.update(
        person.name,
        (v) => v + person.hostedMinor,
        ifAbsent: () => person.hostedMinor,
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
    ...reimbursedByPerson.keys,
    ...invitedByPerson.keys,
    ...hostedByPerson.keys,
  }.toList()..sort();
  final byPerson = names
      .map(
        (name) => PersonStat(
          name: name,
          paidMinor: paidByPerson[name] ?? 0,
          shareMinor: shareByPerson[name] ?? 0,
          settledMinor: settledByPerson[name] ?? 0,
          reimbursedMinor: reimbursedByPerson[name] ?? 0,
          invitedMinor: invitedByPerson[name] ?? 0,
          hostedMinor: hostedByPerson[name] ?? 0,
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
    reimbursementsBySource: _sources(bySource),
  );
}

CurrencyStats _statsForCurrency(
  String currency,
  List<Cost> costs,
  Map<int, List<Person>> beneficiariesByCost,
  List<String> participantNames,
  Map<int, Set<String>> invitedByCost,
) {
  // Every spend figure below is about the expenses only; the transfers are
  // settlements between people and are handled apart, on the balances.
  // Reimbursements are transfers in shape only: they came from outside the
  // group, so they are collected apart and settle nothing.
  final expenses = costs.where((c) => !c.isTransfer).toList();
  final transfers = costs.where((c) => c.isTransfer && !c.isReimbursement);
  final reimbursements = costs.where((c) => c.isTransfer && c.isReimbursement);

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

  // Paid and share, per person — and of each share, what the payer carries.
  final paid = <String, int>{};
  final share = <String, int>{};
  final invited = <String, int>{};
  final hosted = <String, int>{};
  for (final cost in expenses) {
    final payer = cost.paidBy;
    final hasPayer = payer != null && payer.isNotEmpty;
    if (hasPayer) {
      paid.update(
        payer,
        (v) => v + cost.amountMinor,
        ifAbsent: () => cost.amountMinor,
      );
    }
    final listed = beneficiariesByCost[cost.id]?.map((p) => p.name).toList();
    final guests = hasPayer && listed != null
        ? invitedByCost[cost.id] ?? const <String>{}
        : const <String>{};
    for (final entry in _splitEvenly(
      cost.amountMinor,
      listed ?? participantNames,
    ).entries) {
      share.update(
        entry.key,
        (v) => v + entry.value,
        ifAbsent: () => entry.value,
      );
      if (entry.key == payer || !guests.contains(entry.key)) continue;
      invited.update(
        entry.key,
        (v) => v + entry.value,
        ifAbsent: () => entry.value,
      );
      hosted.update(
        payer!,
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

  // Reimbursed, per receiver and per source. The source is not a person of the
  // trip's balances — it neither paid for nor benefited from anything — so it
  // is not added to [byPerson]; the receiver is, since what came back to them
  // is part of their standing.
  final reimbursed = <String, int>{};
  final bySource = <String, int>{};
  for (final cost in reimbursements) {
    bySource.update(
      cost.paidBy?.trim() ?? '',
      (v) => v + cost.amountMinor,
      ifAbsent: () => cost.amountMinor,
    );
    final receivers = beneficiariesByCost[cost.id]?.map((p) => p.name).toList();
    if (receivers == null) continue;
    for (final entry in _splitEvenly(cost.amountMinor, receivers).entries) {
      reimbursed.update(
        entry.key,
        (v) => v + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }

  final names = {
    ...paid.keys,
    ...share.keys,
    ...settled.keys,
    ...reimbursed.keys,
    ...hosted.keys,
  }.toList()..sort();
  final byPerson = names
      .map(
        (name) => PersonStat(
          name: name,
          paidMinor: paid[name] ?? 0,
          shareMinor: share[name] ?? 0,
          settledMinor: settled[name] ?? 0,
          reimbursedMinor: reimbursed[name] ?? 0,
          invitedMinor: invited[name] ?? 0,
          hostedMinor: hosted[name] ?? 0,
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
    reimbursementsBySource: _sources(bySource),
  );
}

/// [bySource] as a list, largest amount first and by name among equals, so the
/// order is stable.
List<SourceStat> _sources(Map<String, int> bySource) =>
    [
      for (final e in bySource.entries)
        SourceStat(name: e.key, amountMinor: e.value),
    ]..sort((a, b) {
      final byAmount = b.amountMinor.compareTo(a.amountMinor);
      return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
    });

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
