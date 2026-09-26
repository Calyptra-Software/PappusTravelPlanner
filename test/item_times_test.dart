import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/widgets/item_times.dart';

/// Covers [ItemTimes]: an entry's planned times, each carrying how far the
/// actual time missed it — in red when late, green when early. The actual time
/// itself is left implied: the plan plus the delta already says it.
void main() {
  final theme = ThemeData(useMaterial3: true);

  ItineraryItem item({
    int? start,
    int? end,
    int? actualStart,
    int? actualEnd,
    int endDayOffset = 0,
  }) => ItineraryItem(
    id: 1,
    tripId: 1,
    date: DateTime(2026, 7, 5),
    sortOrder: 0,
    kind: ItemKind.place,
    title: 'Colosseum',
    startMinutes: start,
    endMinutes: end,
    actualStartMinutes: actualStart,
    actualEndMinutes: actualEnd,
    endDayOffset: endDayOffset,
    chordDisplay: TrackDisplay.auto,
  );

  Future<void> pump(WidgetTester tester, ItineraryItem it) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: ItemTimes(item: it)),
    ),
  );

  /// The whole line as it reads on screen.
  String line(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).textSpan!.toPlainText();

  /// The colour the piece of the line containing [text] is drawn in.
  Color? colorOf(WidgetTester tester, String text) {
    Color? found;
    tester.widget<Text>(find.byType(Text)).textSpan!.visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').contains(text)) {
        found = span.style?.color;
        return false;
      }
      return true;
    });
    return found;
  }

  testWidgets('with no actual times, only the plan is shown', (tester) async {
    await pump(tester, item(start: 9 * 60, end: 10 * 60 + 30));

    expect(line(tester), '09:00 – 10:30');
  });

  testWidgets('a late start reads as a red plus on the planned time', (
    tester,
  ) async {
    await pump(
      tester,
      item(start: 9 * 60, end: 10 * 60 + 30, actualStart: 9 * 60 + 15),
    );

    // The 09:15 it really started is left to the reader: 09:00 plus 15 minutes.
    expect(line(tester), '09:00 (+15) – 10:30');
    expect(colorOf(tester, '+15'), theme.colorScheme.error);
  });

  testWidgets('an early end reads as a green minus', (tester) async {
    await pump(
      tester,
      item(start: 9 * 60, end: 10 * 60 + 30, actualEnd: 10 * 60 + 25),
    );

    expect(line(tester), '09:00 – 10:30 (−5)');
    final color = colorOf(tester, '−5')!;
    expect(color, isNot(theme.colorScheme.error));
    expect(color.g > color.r && color.g > color.b, isTrue);
  });

  testWidgets('each end compares against its own planned time', (tester) async {
    await pump(
      tester,
      item(
        start: 9 * 60,
        end: 10 * 60 + 30,
        actualStart: 9 * 60 + 15,
        actualEnd: 10 * 60 + 25,
      ),
    );

    expect(line(tester), '09:00 (+15) – 10:30 (−5)');
    expect(colorOf(tester, '+15'), theme.colorScheme.error);
    expect(colorOf(tester, '−5'), isNot(theme.colorScheme.error));
  });

  testWidgets('an actual time with nothing to compare against stands alone', (
    tester,
  ) async {
    await pump(tester, item(actualStart: 9 * 60 + 15));

    // No plan to be late for, so the time is simply what happened — no delta.
    expect(line(tester), '09:15');
  });

  testWidgets('an entry with no times at all renders nothing', (tester) async {
    await pump(tester, item());

    expect(find.byType(Text), findsNothing);
    expect(ItemTimes.hasAny(item()), isFalse);
  });

  testWidgets('an end on a later day carries that day', (tester) async {
    await pump(
      tester,
      item(start: 22 * 60 + 14, end: 7 * 60 + 12, endDayOffset: 1),
    );

    expect(line(tester), '22:14 – 07:12 +1');
    expect(colorOf(tester, '+1'), theme.colorScheme.primary);
  });

  testWidgets('and says how many days later', (tester) async {
    await pump(
      tester,
      item(start: 22 * 60 + 14, end: 7 * 60 + 12, endDayOffset: 2),
    );

    expect(line(tester), '22:14 – 07:12 +2');
  });

  testWidgets('the day mark sits before the delay it is not part of', (
    tester,
  ) async {
    await pump(
      tester,
      item(
        start: 22 * 60 + 14,
        end: 7 * 60 + 12,
        actualEnd: 7 * 60 + 27,
        endDayOffset: 1,
      ),
    );

    expect(line(tester), '22:14 – 07:12 +1 (+15)');
  });

  testWidgets('a departure a few minutes over midnight is late, not early', (
    tester,
  ) async {
    await pump(
      tester,
      item(start: 23 * 60 + 55, end: 6 * 60, actualStart: 10, endDayOffset: 1),
    );

    // Fifteen minutes late — not "−23:45", which a subtraction of the two
    // bare minute counts would print.
    expect(line(tester), '23:55 (+15) – 06:00 +1');
  });

  testWidgets('an arrival that slips past midnight is late too', (
    tester,
  ) async {
    await pump(tester, item(start: 22 * 60, end: 23 * 60 + 50, actualEnd: 5));

    expect(line(tester), '22:00 – 23:50 (+15)');
  });
}
