import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/presentation/routine_list_screen.dart';
import 'package:travelplanner/features/trips/widgets/tag_filter_bar.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The routine list read the way the overview is: searched, filtered by tag and
/// by participant, sorted — and telling "nothing matches" apart from "you have
/// not made one yet".
///
/// Every DB-backed provider the screen watches is overridden with a plain
/// stream: drift's `.watch()` does not resolve under fake-async, and a live one
/// leaves a pending timer behind when the tree is disposed.
Future<void> pumpRoutines(
  WidgetTester tester,
  List<Trip> routines, {
  List<Tag> tags = const [],
  Map<int, List<Tag>> tagsByTrip = const {},
  Map<int, List<Person>> participants = const {},
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        routineListProvider.overrideWith((ref) => Stream.value(routines)),
        tagListProvider.overrideWith((ref) => Stream.value(tags)),
        tagsByTripProvider.overrideWith((ref) => Stream.value(tagsByTrip)),
        allParticipantsProvider.overrideWith(
          (ref) => Stream.value(participants),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RoutineListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Trip _routine({
  required int id,
  required String title,
  String destination = '',
  DateTime? createdAt,
}) {
  return Trip(
    id: id,
    title: title,
    destination: destination,
    kind: TripKind.routine,
    colorValue: 0xFF00695C,
    coverHidden: false,
    photosCollapsed: false,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

Tag _tag({required int id, required String name}) =>
    Tag(id: id, name: name, colorValue: 0xFF00695C, sortOrder: id);

void main() {
  testWidgets('shows the empty state when there are no routines', (
    tester,
  ) async {
    await pumpRoutines(tester, const []);

    expect(find.text('No routines yet'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('searching narrows the list to what matches', (tester) async {
    await pumpRoutines(tester, [
      _routine(id: 1, title: 'Morning commute', destination: 'Office'),
      _routine(id: 2, title: 'Saturday ride'),
    ]);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ride');
    await tester.pumpAndSettle();

    expect(find.text('Saturday ride'), findsOneWidget);
    expect(find.text('Morning commute'), findsNothing);
  });

  testWidgets(
    'a search matching nothing is not the "no routines yet" message',
    (tester) async {
      await pumpRoutines(tester, [_routine(id: 1, title: 'Morning commute')]);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zeppelin');
      await tester.pumpAndSettle();

      expect(find.text('No matching routines'), findsOneWidget);
      expect(find.text('No routines yet'), findsNothing);
    },
  );

  testWidgets('closing the search puts the whole list back', (tester) async {
    await pumpRoutines(tester, [
      _routine(id: 1, title: 'Morning commute'),
      _routine(id: 2, title: 'Saturday ride'),
    ]);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ride');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Morning commute'), findsOneWidget);
    expect(find.text('Saturday ride'), findsOneWidget);
  });

  testWidgets('the tag bar filters, and the chip says which is on', (
    tester,
  ) async {
    final commute = _tag(id: 10, name: 'commute');
    await pumpRoutines(
      tester,
      [
        _routine(id: 1, title: 'Morning commute'),
        _routine(id: 2, title: 'Saturday ride'),
      ],
      tags: [commute],
      tagsByTrip: {
        1: [commute],
      },
    );

    // The routine's own tag row plus the bar's chip.
    expect(find.text('commute'), findsNWidgets(2));

    await tester.tap(
      find.descendant(
        of: find.byType(TagFilterBar),
        matching: find.text('commute'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morning commute'), findsOneWidget);
    expect(find.text('Saturday ride'), findsNothing);
  });

  testWidgets('a stored filter is on when the screen opens, and clears', (
    tester,
  ) async {
    final commute = _tag(id: 10, name: 'commute');
    await pumpRoutines(
      tester,
      [
        _routine(id: 1, title: 'Morning commute'),
        _routine(id: 2, title: 'Saturday ride'),
      ],
      tags: [commute],
      tagsByTrip: {
        1: [commute],
      },
      prefs: {
        'routines_filter_tag_ids': ['10'],
      },
    );

    expect(find.text('Saturday ride'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.tune),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Saturday ride'), findsOneWidget);
  });

  testWidgets('sorting by name is the default; recently added is offered', (
    tester,
  ) async {
    await pumpRoutines(tester, [
      _routine(id: 1, title: 'Shopping', createdAt: DateTime(2026, 1, 1)),
      _routine(id: 2, title: 'Commute', createdAt: DateTime(2026, 6, 1)),
    ]);

    final byName = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((byName.first.title! as Text).data, 'Commute');

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.tune),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recently added'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final byDate = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((byDate.first.title! as Text).data, 'Commute');
    expect((byDate.last.title! as Text).data, 'Shopping');
  });

  testWidgets('only people on a routine are offered as a filter', (
    tester,
  ) async {
    await pumpRoutines(
      tester,
      [_routine(id: 1, title: 'Morning commute')],
      participants: {
        1: [Person(id: 5, name: 'Ada', isMe: false)],
        // A trip that is not in this list — its participant is no candidate.
        99: [Person(id: 6, name: 'Grace', isMe: false)],
      },
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.tune),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsNothing);
  });
}
