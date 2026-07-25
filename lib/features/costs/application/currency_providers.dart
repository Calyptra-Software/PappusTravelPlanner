import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';

/// The managed currencies in display order — the built-ins plus any the user
/// added. Feeds the expense form's picker and the settings list.
final currenciesProvider = StreamProvider.autoDispose<List<CurrencyRow>>((ref) {
  return ref.watch(repositoryProvider).watchCurrencies();
});

/// The same currencies as the pure [CurrencyBook] everything that prints or
/// converts money reads. [CurrencyBook.empty] until the stream first resolves,
/// which formats amounts without a symbol rather than throwing.
final currencyBookProvider = Provider.autoDispose<CurrencyBook>((ref) {
  final rows = ref.watch(currenciesProvider).value;
  if (rows == null) return CurrencyBook.empty;
  return CurrencyBook.fromRows(rows);
});

/// How many expenses are recorded in each currency, keyed by currency id. Lets
/// the settings list show which currencies are still in use — and so cannot be
/// deleted — without a query per row.
final currencyCostCountsProvider = StreamProvider.autoDispose<Map<int, int>>((
  ref,
) {
  return ref.watch(repositoryProvider).watchCurrencyCostCounts();
});

final currencyControllerProvider = Provider<CurrencyController>(
  (ref) => CurrencyController(ref),
);

/// Add/edit/re-rate/rebase/reorder/delete for the currencies managed in
/// settings — the money counterpart to `TransportModeController`.
class CurrencyController {
  CurrencyController(this._ref);
  final Ref _ref;

  Future<int> addCurrency({
    required String code,
    required String symbol,
    int? rateMicros,
  }) => _ref
      .read(repositoryProvider)
      .addCurrency(code: code, symbol: symbol, rateMicros: rateMicros);

  Future<void> editCurrency(int id, {String? code, String? symbol}) => _ref
      .read(repositoryProvider)
      .editCurrency(id, code: code, symbol: symbol);

  /// Sets what one unit of the currency is worth in the base one, in millionths
  /// (see `Currencies.rateMicros`); null clears it back to "not known".
  Future<void> setRate(int id, int? rateMicros) =>
      _ref.read(repositoryProvider).setCurrencyRate(id, rateMicros);

  /// Makes the currency the base, re-expressing every other rate against it.
  Future<void> setBase(int id) =>
      _ref.read(repositoryProvider).setBaseCurrency(id);

  /// Whether [setBase] would have to discard the other currencies' rates, so
  /// the user can be warned first.
  Future<bool> rebaseClearsRates(int id) =>
      _ref.read(repositoryProvider).rebaseClearsRates(id);

  /// Deletes a currency. Throws `CurrencyInUseException` when an expense still
  /// uses it, or when it is the base.
  Future<void> deleteCurrency(int id) =>
      _ref.read(repositoryProvider).deleteCurrency(id);

  Future<void> reorderCurrencies(List<int> orderedIds) =>
      _ref.read(repositoryProvider).reorderCurrencies(orderedIds);
}
