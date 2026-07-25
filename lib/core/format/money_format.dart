import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';

/// One currency as the app prints and converts with it: a plain value type, so
/// the formatting below stays pure and works equally off a database row
/// ([CurrencyInfo.fromRow]) and off a shared trip bundle, which carries the same
/// four fields but no row ids.
class CurrencyInfo {
  const CurrencyInfo({
    this.id,
    required this.code,
    required this.symbol,
    this.rateMicros,
    this.isBase = false,
  });

  CurrencyInfo.fromRow(CurrencyRow row)
    : id = row.id,
      code = row.code,
      symbol = row.symbol,
      rateMicros = row.rateMicros,
      isBase = row.isBase;

  /// The `Currencies` row id, or null for a currency read out of a bundle
  /// (whose ids belong to the sender's database and mean nothing here).
  final int? id;
  final String code;
  final String symbol;

  /// What one unit is worth in the base currency, in millionths ([kRateOne]),
  /// or null when the user hasn't said.
  final int? rateMicros;
  final bool isBase;

  /// [rateMicros], with the base currency's own rate — 1, by definition —
  /// filled in.
  int? get effectiveRateMicros => isBase ? kRateOne : rateMicros;

  /// Whether an amount in this currency can be expressed in the base one.
  bool get hasRate => effectiveRateMicros != null;
}

/// The app's currencies: what each is called, what it is worth, and the order
/// they are shown in. Everything that prints or converts money reads one, so a
/// cost — which stores only a `Currencies` row id — can be rendered anywhere.
///
/// Pure and constructible from a plain list, so the PDF and `.ics` exports build
/// one from the bundle they were handed rather than reaching for a database.
class CurrencyBook {
  CurrencyBook(this.currencies)
    : _byId = {
        for (final c in currencies)
          if (c.id != null) c.id!: c,
      },
      _byCode = {for (final c in currencies) c.code: c};

  /// A book built from database rows, in the order they are to be shown.
  CurrencyBook.fromRows(List<CurrencyRow> rows)
    : this([for (final row in rows) CurrencyInfo.fromRow(row)]);

  /// The book to use before the currencies have loaded: it formats amounts
  /// without a symbol rather than throwing.
  static final CurrencyBook empty = CurrencyBook(const []);

  /// Every currency, in display order — which is also the order per-currency
  /// totals are printed in.
  final List<CurrencyInfo> currencies;

  final Map<int, CurrencyInfo> _byId;
  final Map<String, CurrencyInfo> _byCode;

  bool get isEmpty => currencies.isEmpty;

  CurrencyInfo? byId(int? id) => id == null ? null : _byId[id];

  CurrencyInfo? byCode(String? code) => code == null ? null : _byCode[code];

  /// The currency every rate is expressed in, or null if none is marked.
  CurrencyInfo? get base {
    for (final c in currencies) {
      if (c.isBase) return c;
    }
    return null;
  }

  /// [amountMinor], held in the currency [code], expressed in the base
  /// currency's minor units. Null when the currency is unknown to the book, has
  /// no rate, or there is no base at all — the app declines to convert rather
  /// than guess a rate.
  int? toBase(int amountMinor, String code) {
    if (base == null) return null;
    final rate = byCode(code)?.effectiveRateMicros;
    if (rate == null) return null;
    return (amountMinor * rate / kRateOne).round();
  }

  /// The order [codes] should be printed in: the book's own order, with any
  /// code it doesn't know appended (alphabetically) rather than dropped.
  List<String> ordered(Iterable<String> codes) {
    final remaining = codes.toSet();
    final result = <String>[];
    for (final c in currencies) {
      if (remaining.remove(c.code)) result.add(c.code);
    }
    return result..addAll(remaining.toList()..sort());
  }
}

/// Formats an amount held in minor units (cents) with the currency's symbol,
/// using the locale's number conventions. e.g. de: "49,90 €", en: "€49.90".
/// A null [currency] — one the book doesn't know — prints the bare number.
String formatMoney(int amountMinor, CurrencyInfo? currency, String localeName) {
  final format = NumberFormat.currency(
    locale: localeName,
    symbol: currency?.symbol ?? '',
    decimalDigits: 2,
  );
  return format.format(amountMinor / 100).trim();
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

/// Parses an exchange rate ("0.92", "1,08") into the fixed-point millionths
/// [Currencies.rateMicros] holds. Returns null for anything that isn't a
/// positive finite number — a rate of zero or less converts nothing.
int? parseRateToMicros(String input) {
  final cleaned = input.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return null;
  }
  return (value * kRateOne).round();
}

/// Renders a rate as the plain decimal the input above accepts, trimming the
/// trailing zeros a fixed-point number would otherwise show ("0.920000").
String formatRate(int rateMicros) {
  final text = (rateMicros / kRateOne).toStringAsFixed(6);
  final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

/// Totals a set of costs per currency **code** (amounts stay in minor units).
/// Codes, not row ids: the same map shape then serves a shared trip, whose
/// costs name their currency rather than pointing at a row.
///
/// Transfers ([Costs.isTransfer]) are left out: settling up moves money between
/// people, it does not spend any, so it belongs in no "total" the app prints.
/// A cost in a currency [book] doesn't know is skipped — there would be nothing
/// to label its total with.
Map<String, int> sumByCurrency(Iterable<Cost> costs, CurrencyBook book) {
  final totals = <String, int>{};
  for (final cost in costs.where((c) => !c.isTransfer)) {
    final code = book.byId(cost.currency)?.code;
    if (code == null) continue;
    totals.update(
      code,
      (value) => value + cost.amountMinor,
      ifAbsent: () => cost.amountMinor,
    );
  }
  return totals;
}

/// The sum of [totals] expressed in the base currency's minor units, or null
/// when there is no base currency, only one currency is involved (converting it
/// would just restate it), or any currency present has no rate — a partial
/// conversion would read as a total while leaving money out.
int? totalInBase(Map<String, int> totals, CurrencyBook book) {
  final base = book.base;
  if (base == null || totals.length < 2) return null;
  var sum = 0;
  for (final entry in totals.entries) {
    final converted = book.toBase(entry.value, entry.key);
    if (converted == null) return null;
    sum += converted;
  }
  return sum;
}

/// Renders per-currency totals as one string, e.g. "€349.90 · US$50.00", in the
/// book's display order.
///
/// When several currencies are involved and the user has set a rate for each,
/// the base-currency equivalent is appended — "≈ €395.90". It is deliberately an
/// addition rather than a replacement: the per-currency figures are what was
/// actually spent, and the converted one is only as good as the rates typed into
/// settings. Pass [withBaseTotal] false where the space for it isn't there.
String formatTotals(
  Map<String, int> totals,
  CurrencyBook book,
  String localeName, {
  bool withBaseTotal = true,
}) {
  final parts = [
    for (final code in book.ordered(totals.keys))
      formatMoney(totals[code]!, book.byCode(code), localeName),
  ];
  final text = parts.join(' · ');
  if (!withBaseTotal) return text;
  final inBase = totalInBase(totals, book);
  if (inBase == null) return text;
  return '$text ≈ ${formatMoney(inBase, book.base, localeName)}';
}
