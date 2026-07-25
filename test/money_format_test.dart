import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travelplanner/core/format/money_format.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart' show kRateOne;

import 'currency_fixture.dart';

/// Currency formatting inserts non-breaking spaces (U+00A0); normalise them so
/// assertions can use plain spaces.
String norm(String s) => s.replaceAll(String.fromCharCode(0xA0), " ");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting());

  group('parseAmountToMinor', () {
    test('accepts dot and comma decimals', () {
      expect(parseAmountToMinor('49.90'), 4990);
      expect(parseAmountToMinor('49,90'), 4990);
      expect(parseAmountToMinor('7'), 700);
      expect(parseAmountToMinor(' 12.5 '), 1250);
    });

    test('accepts a leading minus as an income', () {
      expect(parseAmountToMinor('-5'), -500);
      expect(parseAmountToMinor('-49,90'), -4990);
    });

    test('rejects invalid input', () {
      expect(parseAmountToMinor(''), isNull);
      expect(parseAmountToMinor('abc'), isNull);
    });
  });

  group('parseRateToMicros / formatRate', () {
    test('accepts dot and comma decimals', () {
      expect(parseRateToMicros('0.92'), 920000);
      expect(parseRateToMicros('1,08'), 1080000);
      expect(parseRateToMicros(' 2 '), 2000000);
    });

    test('rejects anything that converts nothing', () {
      expect(parseRateToMicros(''), isNull);
      expect(parseRateToMicros('abc'), isNull);
      expect(parseRateToMicros('0'), isNull);
      expect(parseRateToMicros('-1.5'), isNull);
    });

    test('renders a rate without fixed-point padding', () {
      expect(formatRate(920000), '0.92');
      expect(formatRate(kRateOne), '1');
      expect(formatRate(1234560), '1.23456');
    });
  });

  group('formatMoney', () {
    final book = seededBook;
    test('is locale-aware with the currency symbol', () {
      expect(norm(formatMoney(4990, book.byCode('EUR'), 'en')), '€49.90');
      expect(norm(formatMoney(4990, book.byCode('EUR'), 'de')), '49,90 €');
      expect(norm(formatMoney(5000, book.byCode('GBP'), 'en')), '£50.00');
    });

    test('prints a bare number for a currency the book does not know', () {
      expect(norm(formatMoney(4990, book.byCode('JPY'), 'en')), '49.90');
    });
  });

  group('sumByCurrency / formatTotals', () {
    Cost cost(int minor, int currencyId, {bool isTransfer = false}) => Cost(
      id: 0,
      itemId: 1,
      amountMinor: minor,
      currency: currencyId,
      reason: 'x',
      paid: false,
      isTransfer: isTransfer,
      createdAt: DateTime(2026),
    );

    test('groups amounts per currency code', () {
      final totals = sumByCurrency([
        cost(1000, eurId),
        cost(500, eurId),
        cost(2000, usdId),
      ], seededBook);
      expect(totals['EUR'], 1500);
      expect(totals['USD'], 2000);
      expect(totals.containsKey('GBP'), isFalse);
    });

    test('leaves settlements between people out of the total', () {
      final totals = sumByCurrency([
        cost(1000, eurId),
        cost(2500, eurId, isTransfer: true),
      ], seededBook);
      expect(totals['EUR'], 1000);
    });

    test('formats totals in the book order', () {
      final totals = {'USD': 5000, 'EUR': 34990};
      expect(
        norm(formatTotals(totals, seededBook, 'en')),
        '€349.90 · US\$50.00',
      );
    });

    test('appends the base equivalent once every rate is known', () {
      final book = currencyBook(rates: {'USD': 900000});
      final totals = {'USD': 5000, 'EUR': 34990};
      expect(
        norm(formatTotals(totals, book, 'en')),
        '€349.90 · US\$50.00 ≈ €394.90',
      );
    });

    test('omits the equivalent when a currency has no rate', () {
      final totals = {'USD': 5000, 'EUR': 34990};
      expect(
        norm(formatTotals(totals, seededBook, 'en')),
        '€349.90 · US\$50.00',
      );
    });

    test('never converts a single currency — there is nothing to add up', () {
      final book = currencyBook(rates: {'USD': 900000});
      expect(norm(formatTotals({'USD': 5000}, book, 'en')), 'US\$50.00');
    });

    test('withBaseTotal false keeps the line to what was spent', () {
      final book = currencyBook(rates: {'USD': 900000});
      final totals = {'USD': 5000, 'EUR': 34990};
      expect(
        norm(formatTotals(totals, book, 'en', withBaseTotal: false)),
        '€349.90 · US\$50.00',
      );
    });
  });

  group('totalInBase', () {
    test('converts each currency through its rate', () {
      final book = currencyBook(rates: {'USD': 900000, 'GBP': 1200000});
      expect(totalInBase({'EUR': 1000, 'USD': 1000, 'GBP': 1000}, book), 3100);
    });

    test('is null when any currency has no rate', () {
      final book = currencyBook(rates: {'USD': 900000});
      expect(totalInBase({'USD': 1000, 'GBP': 1000}, book), isNull);
    });
  });
}
