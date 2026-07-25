import 'package:travelplanner/core/format/money_format.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/costs/application/currency_providers.dart';

/// The currency row ids a freshly seeded database hands out: the built-ins go in
/// in [Currency] order, so each id is its enum index + 1 (the same fact the v23
/// migration relies on). Tests that write a `Costs` row need one of these.
const int eurId = 1;
const int usdId = 2;
const int gbpId = 3;
const int chfId = 4;

/// A [CurrencyBook] matching a freshly seeded database: the four built-ins in
/// enum order, EUR the base, and no rates — the state a new database is in until
/// the user enters some.
final CurrencyBook seededBook = currencyBook();

/// The same four as plain rows, for widget tests to feed the provider with.
final List<CurrencyRow> seededCurrencyRows = [
  for (final c in Currency.values)
    CurrencyRow(
      id: c.index + 1,
      code: c.code,
      symbol: c.symbol,
      rateMicros: c == Currency.values.first ? kRateOne : null,
      isBase: c == Currency.values.first,
      sortOrder: c.index,
    ),
];

/// Stubs the currency roster for a widget test — spread into the
/// `ProviderScope` overrides.
///
/// Anything that prints money resolves its symbol through
/// `currencyBookProvider`, which reads a Drift `.watch()` stream, and those
/// never resolve under `flutter_test`'s fake-async clock (see AGENTS.md): the
/// amounts would render unlabelled and the test would leak a pending timer.
final currencyOverrides = [
  currenciesProvider.overrideWith((ref) => Stream.value(seededCurrencyRows)),
];

/// A [CurrencyBook] like [seededBook] but with the given rates against EUR, so a
/// test can exercise the converted "≈" total. Keys are currency codes; values
/// are what one unit is worth in EUR, in millionths ([kRateOne] = 1).
CurrencyBook currencyBook({Map<String, int> rates = const {}}) {
  return CurrencyBook([
    for (final c in Currency.values)
      CurrencyInfo(
        id: c.index + 1,
        code: c.code,
        symbol: c.symbol,
        rateMicros: c == Currency.values.first ? kRateOne : rates[c.code],
        isBase: c == Currency.values.first,
      ),
  ]);
}
