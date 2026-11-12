import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/trips/presentation/move_entries_dialog.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The question the trip form asks when a start date is saved as another day.
void main() {
  group('entryShiftDays', () {
    test('a new start is a move by the days between', () {
      expect(
        entryShiftDays(
          oldStart: DateTime(2026, 5, 12),
          newStart: DateTime(2026, 5, 26),
        ),
        14,
      );
      expect(
        entryShiftDays(
          oldStart: DateTime(2026, 5, 12),
          newStart: DateTime(2026, 5, 9),
        ),
        -3,
      );
    });

    test('nothing to ask without a move', () {
      // The same day (the end alone may have changed).
      expect(
        entryShiftDays(
          oldStart: DateTime(2026, 5, 12),
          newStart: DateTime(2026, 5, 12),
        ),
        isNull,
      );
      // Dates set for the first time: no old start to measure from.
      expect(
        entryShiftDays(oldStart: null, newStart: DateTime(2026, 5, 12)),
        isNull,
      );
      // Dates cleared.
      expect(
        entryShiftDays(oldStart: DateTime(2026, 5, 12), newStart: null),
        isNull,
      );
    });
  });

  group('showMoveEntriesDialog', () {
    Future<Future<MoveEntriesChoice?> Function()> open(
      WidgetTester tester, {
      int days = 14,
      bool offerLookUp = true,
      bool clearsActualTimes = false,
    }) async {
      MoveEntriesChoice? answer;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  answer = await showMoveEntriesDialog(
                    context,
                    days: days,
                    from: (
                      start: DateTime(2026, 5, 12),
                      end: DateTime(2026, 5, 19),
                    ),
                    to: (
                      start: DateTime(2026, 5, 12 + days),
                      end: DateTime(2026, 5, 19 + days),
                    ),
                    offerLookUp: offerLookUp,
                    clearsActualTimes: clearsActualTimes,
                  );
                },
                child: const Text('save'),
              ),
            ),
          ),
        ),
      );
      return () async => answer;
    }

    Future<void> show(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
    }

    testWidgets('says by how much, and moves with the lookup', (tester) async {
      final answer = await open(tester);
      await show(tester);

      expect(find.text('Move the entries too?'), findsOneWidget);
      expect(find.text('Every entry moves 14 days later.'), findsOneWidget);
      expect(find.text('Look up current connections'), findsOneWidget);
      expect(
        find.textContaining('removed'),
        findsNothing,
        reason: 'nothing recorded, nothing to lose',
      );

      await tester.tap(find.text('Move entries'));
      await tester.pumpAndSettle();
      expect(await answer(), (move: true, lookUp: true));
    });

    testWidgets('an earlier start reads as earlier', (tester) async {
      await open(tester, days: -1);
      await show(tester);
      expect(find.text('Every entry moves one day earlier.'), findsOneWidget);
    });

    testWidgets('the lookup can be left out', (tester) async {
      final answer = await open(tester);
      await show(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Move entries'));
      await tester.pumpAndSettle();
      expect(await answer(), (move: true, lookUp: false));
    });

    testWidgets('no lookup offered, none asked for', (tester) async {
      final answer = await open(tester, offerLookUp: false);
      await show(tester);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.text('Move entries'));
      await tester.pumpAndSettle();
      expect(await answer(), (move: true, lookUp: false));
    });

    testWidgets('warns when actual times would go', (tester) async {
      await open(tester, clearsActualTimes: true);
      await show(tester);
      expect(
        find.text('The actual times recorded so far are removed.'),
        findsOneWidget,
      );
    });

    testWidgets('dates only leaves the entries where they are', (tester) async {
      final answer = await open(tester);
      await show(tester);
      await tester.tap(find.text('Dates only'));
      await tester.pumpAndSettle();
      expect(await answer(), (move: false, lookUp: false));
    });

    testWidgets('cancel answers nothing, so the form stays open', (
      tester,
    ) async {
      final answer = await open(tester);
      await show(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await answer(), isNull);
    });
  });
}
