import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// Formats an amount held in minor units (cents) with the currency's symbol,
/// using the locale's number conventions. e.g. de: "49,90 €", en: "€49.90".
String formatMoney(int amountMinor, Currency currency, String localeName) {
  final format = NumberFormat.currency(
    locale: localeName,
    symbol: currency.symbol,
    decimalDigits: 2,
  );
  return format.format(amountMinor / 100);
}

/// Parses user input into minor units (cents), accepting both ',' and '.' as
/// the decimal separator. A leading '-' yields a negative amount (an income).
/// Returns null when the input isn't a finite number.
int? parseAmountToMinor(String input) {
  final cleaned = input.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return (value * 100).round();
}

/// Totals a set of costs per currency (amounts stay in minor units).
Map<Currency, int> sumByCurrency(Iterable<Cost> costs) {
  final totals = <Currency, int>{};
  for (final cost in costs) {
    totals.update(
      cost.currency,
      (value) => value + cost.amountMinor,
      ifAbsent: () => cost.amountMinor,
    );
  }
  return totals;
}

/// Renders per-currency totals as one string, e.g. "€349.90 · $50.00".
String formatTotals(Map<Currency, int> totals, String localeName) {
  // Stable order: EUR, USD, GBP.
  final ordered = Currency.values.where(totals.containsKey);
  return ordered
      .map((c) => formatMoney(totals[c]!, c, localeName))
      .join(' · ');
}
