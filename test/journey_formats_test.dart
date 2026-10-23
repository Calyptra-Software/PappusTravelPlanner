import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_formats.dart';

/// The results list prints a leg end's miss beside its planned time; it has to
/// be the same miss the preview shows once the result is opened.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  Future<String> render(WidgetTester tester, LegPoint end) async {
    late String text;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            text = TextSpan(children: legTimeSpans(context, end)).toPlainText();
            return const SizedBox();
          },
        ),
      ),
    );
    return text;
  }

  testWidgets('a delay that carries the arrival past midnight stays a delay', (
    tester,
  ) async {
    // A night train due at 20:31 in Hamburg, running 4 h 23 m late: the live
    // time of day is 00:54, which subtracted from 20:31 reads −19:37.
    final scheduled = DateTime.utc(2026, 10, 24, 18, 31);
    final end = LegPoint(
      name: 'Hamburg-Harburg',
      scheduled: scheduled,
      actual: scheduled.add(const Duration(hours: 4, minutes: 23)),
      timeZone: 'Europe/Berlin',
    );
    expect(await render(tester, end), '8:31 PM (+4:23)');
  });

  testWidgets('an early end reads early', (tester) async {
    final scheduled = DateTime.utc(2026, 10, 24, 6);
    final end = LegPoint(
      name: 'Paris Nord',
      scheduled: scheduled,
      actual: scheduled.subtract(const Duration(minutes: 3)),
      timeZone: 'Europe/Paris',
    );
    expect(await render(tester, end), '8:00 AM (−3)');
  });
}
