import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'currency_dao.g.dart';

/// Thrown when a currency cannot be deleted because something still depends on
/// it: an expense is recorded in it, or it is the base every rate is expressed
/// in. Carries which of the two it is so the UI can say so.
class CurrencyInUseException implements Exception {
  const CurrencyInUseException.costs(this.costCount) : isBase = false;
  const CurrencyInUseException.base() : costCount = 0, isBase = true;

  /// How many expenses still use the currency (0 when [isBase] is the reason).
  final int costCount;

  /// Whether the currency is the base one.
  final bool isBase;

  @override
  String toString() => isBase
      ? 'The base currency cannot be deleted.'
      : 'Still used by $costCount expense(s).';
}

/// Manages the reusable list of currencies: the built-ins the database is seeded
/// with plus any the user adds, which one is the **base**, and the exchange rate
/// of each of the others against it. The money counterpart to `TransportModeDao`.
///
/// Rates are stored one-per-currency against the base rather than as an N×N
/// table: a pair's rate is then always derivable (`a → b` is `a → base → b`) and
/// there is no way to enter a set of rates that contradicts itself.
@DriftAccessor(tables: [Currencies, Costs])
class CurrencyDao extends DatabaseAccessor<AppDatabase>
    with _$CurrencyDaoMixin {
  CurrencyDao(super.db);

  /// All currencies in display order (then by id, so ties are stable). Feeds the
  /// expense form's picker, the settings list, and every total's ordering.
  Stream<List<CurrencyRow>> watchCurrencies() {
    return (select(currencies)..orderBy([
          (c) => OrderingTerm(expression: c.sortOrder),
          (c) => OrderingTerm(expression: c.id),
        ]))
        .watch();
  }

  /// All currencies in display order, read once.
  Future<List<CurrencyRow>> allCurrencies() {
    return (select(currencies)..orderBy([
          (c) => OrderingTerm(expression: c.sortOrder),
          (c) => OrderingTerm(expression: c.id),
        ]))
        .get();
  }

  /// Adds a currency, appended after the current ones. [rateMicros] is what one
  /// of its units is worth in the base currency (see [Currencies.rateMicros]);
  /// leaving it null means "not known yet". Returns its new id.
  Future<int> addCurrency({
    required String code,
    required String symbol,
    int? rateMicros,
  }) async {
    final order = await _nextSortOrder();
    return into(currencies).insert(
      CurrenciesCompanion.insert(
        code: code,
        symbol: symbol,
        rateMicros: Value(rateMicros),
        sortOrder: Value(order),
      ),
    );
  }

  /// Edits a currency's code and symbol. The rate is set separately (see
  /// [setRate]) because changing what a currency *is called* and changing what
  /// it is *worth* are different edits.
  Future<void> editCurrency(int id, {String? code, String? symbol}) {
    return (update(currencies)..where((c) => c.id.equals(id))).write(
      CurrenciesCompanion(
        code: code == null ? const Value.absent() : Value(code),
        symbol: symbol == null ? const Value.absent() : Value(symbol),
      ),
    );
  }

  /// Sets what one unit of [id] is worth in the base currency, in millionths
  /// ([kRateOne] = 1). Null clears the rate back to "not known". A no-op on the
  /// base currency itself, whose rate is 1 by definition.
  Future<void> setRate(int id, int? rateMicros) async {
    final row = await (select(
      currencies,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null || row.isBase) return;
    await (update(currencies)..where((c) => c.id.equals(id))).write(
      CurrenciesCompanion(rateMicros: Value(rateMicros)),
    );
  }

  /// Makes [id] the base currency, re-expressing every rate against it.
  ///
  /// Rates are relative, so moving the base has to move them all: a currency
  /// worth `r` old-base units is worth `r / newBaseRate` new-base ones. When the
  /// new base has no rate of its own there is nothing to divide by — the other
  /// currencies' rates say nothing about it — so they are cleared rather than
  /// left pointing at a base that is gone. [rebaseClearsRates] answers that
  /// question up front so the UI can warn first.
  Future<void> setBase(int id) async {
    await transaction(() async {
      final rows = await select(currencies).get();
      final target = rows.where((c) => c.id == id).firstOrNull;
      if (target == null || target.isBase) return;
      final divisor = target.rateMicros;

      for (final row in rows) {
        final isNewBase = row.id == id;
        final rate = isNewBase
            ? kRateOne
            : _rebase(_effectiveRate(row), divisor);
        await (update(currencies)..where((c) => c.id.equals(row.id))).write(
          CurrenciesCompanion(
            isBase: Value(isNewBase),
            rateMicros: Value(rate),
          ),
        );
      }
    });
  }

  /// Whether making [id] the base would discard rates the user entered — which
  /// it does exactly when [id] has no rate to divide them by *and* some other
  /// currency has one to lose. See [setBase].
  ///
  /// The current base is not counted among those: its stored 1 is what "base"
  /// means, not a rate anyone typed, so moving away from a base nothing else is
  /// priced against loses nothing worth warning about.
  Future<bool> rebaseClearsRates(int id) async {
    final row = await (select(
      currencies,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null || row.isBase) return false;
    if (row.rateMicros != null) return false;
    final others =
        await (select(currencies)..where(
              (c) =>
                  c.rateMicros.isNotNull() &
                  c.id.equals(id).not() &
                  c.isBase.equals(false),
            ))
            .get();
    return others.isNotEmpty;
  }

  /// A row's rate against the current base, treating the base's own as 1.
  int? _effectiveRate(CurrencyRow row) =>
      row.isBase ? kRateOne : row.rateMicros;

  /// `rate / divisor` in the fixed-point encoding, or null when either side is
  /// unknown.
  int? _rebase(int? rate, int? divisor) {
    if (rate == null || divisor == null || divisor == 0) return null;
    return (rate * kRateOne / divisor).round();
  }

  /// Deletes a currency. Throws [CurrencyInUseException] if it is the base or
  /// any expense is still recorded in it — an amount cannot be left without a
  /// currency, so there is nothing sensible to do but refuse.
  Future<void> deleteCurrency(int id) async {
    final row = await (select(
      currencies,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (row.isBase) throw const CurrencyInUseException.base();
    final used = await countCosts(id);
    if (used > 0) throw CurrencyInUseException.costs(used);
    await (delete(currencies)..where((c) => c.id.equals(id))).go();
  }

  /// How many expenses are recorded in the currency [id].
  Future<int> countCosts(int id) async {
    final count = costs.id.count();
    final row =
        await (selectOnly(costs)
              ..addColumns([count])
              ..where(costs.currency.equals(id)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// How many expenses are recorded in each currency, keyed by currency id.
  /// Currencies nothing uses are absent. Lets the settings list say which rows
  /// can still be deleted without a query apiece.
  Stream<Map<int, int>> watchCostCounts() {
    final count = costs.id.count();
    final query = selectOnly(costs)
      ..addColumns([costs.currency, count])
      ..groupBy([costs.currency]);
    return query.watch().map((rows) {
      final byCurrency = <int, int>{};
      for (final row in rows) {
        final id = row.read(costs.currency);
        if (id == null) continue;
        byCurrency[id] = row.read(count) ?? 0;
      }
      return byCurrency;
    });
  }

  /// Writes a new order, given the currency ids top-to-bottom.
  Future<void> reorderCurrencies(List<int> orderedIds) {
    return transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(currencies)..where((c) => c.id.equals(orderedIds[i])))
            .write(CurrenciesCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// Seeds one row per built-in [Currency], skipping any already present
  /// (matched by `code`). Inserted in enum order so a fresh row's id is its enum
  /// index + 1 — the fact the v23 migration relies on to repoint every existing
  /// cost's stored enum index onto its new row. The first built-in becomes the
  /// base (rate 1); the rest start with no rate, because the app has no way to
  /// know one and a made-up rate is worse than none. Run on database creation
  /// and on the v23 upgrade.
  Future<void> seedBuiltinCurrencies() async {
    for (final currency in Currency.values) {
      final isBase = currency == Currency.values.first;
      await into(currencies).insert(
        CurrenciesCompanion.insert(
          code: currency.code,
          symbol: currency.symbol,
          rateMicros: Value(isBase ? kRateOne : null),
          isBase: Value(isBase),
          sortOrder: Value(currency.index),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<int> _nextSortOrder() async {
    final maxOrder = currencies.sortOrder.max();
    final row = await (selectOnly(
      currencies,
    )..addColumns([maxOrder])).getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }
}
