import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travelplanner/core/format/date_format.dart';
import 'package:travelplanner/l10n/app_localizations_en.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn(); // only used for the null-date branches
  setUpAll(() async => initializeDateFormatting());

  final d5 = DateTime(2026, 7, 5);
  final d4 = DateTime(2026, 7, 4);
  final d9 = DateTime(2026, 7, 9);

  group('how far an actual time missed its plan', () {
    test('late reads as a plus, early as a minus, on time as neither', () {
      expect(formatSignedMinutes(15), '+15');
      expect(formatSignedMinutes(-5), '−5');
      expect(formatSignedMinutes(0), '±0');
    });

    test('an hour or more reads as h:mm, not as a minute count', () {
      expect(formatSignedMinutes(90), '+1:30');
      expect(formatSignedMinutes(60), '+1:00');
      expect(formatSignedMinutes(-125), '−2:05');
    });
  });

  group('locale-aware date formatting', () {
    test('German uses the day-period convention', () {
      expect(formatFullDate(d5, 'de'), '5. Juli 2026');
      expect(formatDateRange(l10n, 'de', d4, d9), '4. Juli – 9. Juli 2026');
    });

    test('English uses month-first convention', () {
      expect(formatFullDate(d5, 'en'), 'July 5, 2026');
      expect(formatDateRange(l10n, 'en', d4, d9), 'July 4 – July 9, 2026');
    });

    test('cross-year range keeps both years', () {
      expect(
        formatDateRange(
          l10n,
          'de',
          DateTime(2026, 12, 30),
          DateTime(2027, 1, 2),
        ),
        '30. Dezember 2026 – 2. Januar 2027',
      );
    });
  });
}
