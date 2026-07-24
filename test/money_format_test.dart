import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travelplanner/core/format/money_format.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

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

  group('formatMoney', () {
    test('is locale-aware with the currency symbol', () {
      expect(norm(formatMoney(4990, Currency.eur, 'en')), '€49.90');
      expect(norm(formatMoney(4990, Currency.eur, 'de')), '49,90 €');
      expect(norm(formatMoney(5000, Currency.gbp, 'en')), '£50.00');
    });
  });

  group('sumByCurrency / formatTotals', () {
    Cost cost(int minor, Currency c, {bool isTransfer = false}) => Cost(
      id: 0,
      itemId: 1,
      amountMinor: minor,
      currency: c,
      reason: 'x',
      paid: false,
      isTransfer: isTransfer,
      createdAt: DateTime(2026),
    );

    test('groups amounts per currency', () {
      final totals = sumByCurrency([
        cost(1000, Currency.eur),
        cost(500, Currency.eur),
        cost(2000, Currency.usd),
      ]);
      expect(totals[Currency.eur], 1500);
      expect(totals[Currency.usd], 2000);
      expect(totals.containsKey(Currency.gbp), isFalse);
    });

    test('leaves settlements between people out of the total', () {
      final totals = sumByCurrency([
        cost(1000, Currency.eur),
        cost(2500, Currency.eur, isTransfer: true),
      ]);
      expect(totals[Currency.eur], 1000);
    });

    test('formats totals in stable currency order', () {
      final totals = {Currency.usd: 5000, Currency.eur: 34990};
      expect(norm(formatTotals(totals, 'en')), '€349.90 · US\$50.00');
    });
  });
}
