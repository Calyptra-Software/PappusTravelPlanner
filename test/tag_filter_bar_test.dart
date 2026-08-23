import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/widgets/tag_chip.dart';
import 'package:travelplanner/features/trips/widgets/tag_filter_bar.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The tag roster above the overview.
///
/// It is in the open rather than inside the filter sheet because a filter two
/// taps deep stops being used, and then the filing that fed it stops too — so
/// what it does with a tap is the whole of it: tags match **any-of**, and *All*
/// is the way back out.
void main() {
  Tag tag(int id, String name) =>
      Tag(id: id, name: name, colorValue: 0xFF4CAF50, sortOrder: id);

  Set<int>? changed;
  var managed = 0;

  setUp(() {
    changed = null;
    managed = 0;
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    required List<Tag> tags,
    Set<int> selected = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagListProvider.overrideWith((ref) => Stream.value(tags))],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TagFilterBar(
              selected: selected,
              onChanged: (next) => changed = next,
              onManage: () => managed++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a database with no tags shows no bar at all', (tester) async {
    await pumpBar(tester, tags: const []);

    // An empty roster would be a permanent strip of blank above every list,
    // teaching nothing.
    expect(find.byType(TagChip), findsNothing);
    expect(find.text('All'), findsNothing);
  });

  testWidgets('lists every tag beside the way back out', (tester) async {
    await pumpBar(tester, tags: [tag(1, 'walks'), tag(2, 'commute')]);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('walks'), findsOneWidget);
    expect(find.text('commute'), findsOneWidget);
  });

  testWidgets('tapping a tag selects it', (tester) async {
    await pumpBar(tester, tags: [tag(1, 'walks'), tag(2, 'commute')]);

    await tester.tap(find.text('walks'));
    await tester.pumpAndSettle();

    expect(changed, {1});
  });

  testWidgets('a second tag widens the view rather than narrowing it', (
    tester,
  ) async {
    await pumpBar(
      tester,
      tags: [tag(1, 'walks'), tag(2, 'commute')],
      selected: const {1},
    );

    await tester.tap(find.text('commute'));
    await tester.pumpAndSettle();

    // Any-of: tapping "walks" and "commute" shows both, which is why a row of
    // two does not read as narrowing to nothing.
    expect(changed, {1, 2});
  });

  testWidgets('tapping a selected tag turns it off again', (tester) async {
    await pumpBar(
      tester,
      tags: [tag(1, 'walks'), tag(2, 'commute')],
      selected: const {1, 2},
    );

    await tester.tap(find.text('walks'));
    await tester.pumpAndSettle();

    expect(changed, {2});
  });

  testWidgets('All clears the selection', (tester) async {
    await pumpBar(tester, tags: [tag(1, 'walks')], selected: const {1});

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // A chip rather than a cleared selection, so turning the filter off is as
    // visible as turning it on.
    expect(changed, isEmpty);
  });

  testWidgets('the roster is edited from its own button', (tester) async {
    await pumpBar(tester, tags: [tag(1, 'walks')]);

    await tester.tap(find.byTooltip('Manage tags'));
    await tester.pumpAndSettle();

    expect(managed, 1);
    expect(changed, isNull, reason: 'managing is not filtering');
  });
}
