import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/itinerary_timeline.dart';
import 'package:travelplanner/features/itinerary/widgets/now_line.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_rail.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// Covers the rail down the left of a day: one line, at one position, with no
/// gap, however the day is built.
///
/// A run's band and a decision's card each used to break it twice over. Their
/// borders were drawn as a `decoration`, which insets the child by the border's
/// width, so the entries inside drew their rail 3px (a run) or 1px (a decision)
/// off the line of the entries around them; and only the entries drew a rail at
/// all, so the line stopped at every label, shared ticket, option header and
/// row of option pills. Every piece is a [TimelineRail] now, which is what this
/// test measures: they all sit at the same x, and together they cover the day
/// from its first block to its last without a hole.
void main() {
  final day = DateTime(2026, 7, 5);

  ItineraryItem entry(
    int id,
    int sortOrder,
    ItemKind kind, {
    int? groupId,
    int? alternativeId,
    int? startMinutes,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: day,
    sortOrder: sortOrder,
    kind: kind,
    spansNextDay: false,
    chordDisplay: TrackDisplay.auto,
    title: 'Entry $id',
    fromLocation: kind == ItemKind.transport ? 'A' : null,
    toLocation: kind == ItemKind.transport ? 'B' : null,
    mode: kind == ItemKind.transport ? 6 : null,
    groupId: groupId,
    alternativeId: alternativeId,
    startMinutes: startMinutes,
  );

  testWidgets('the rail is one unbroken line through runs and decisions', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(420, 1600);
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // A place, a run of two legs with a shared ticket, a place, a decision,
    // and a leg and a place after it — every kind of block a day has, and
    // every seam between a loose entry and one that is not.
    final items = [
      entry(1, 0, ItemKind.place),
      entry(2, 1, ItemKind.transport, groupId: 7),
      entry(3, 2, ItemKind.transport, groupId: 7),
      entry(4, 3, ItemKind.place),
      entry(10, 0, ItemKind.place, alternativeId: 20),
      entry(11, 1, ItemKind.transport, alternativeId: 20),
      entry(12, 0, ItemKind.place, alternativeId: 21),
      entry(5, 5, ItemKind.transport),
      // Timed, so that at 23:00 the whole day is behind us and the now-line
      // closes it off: that line is part of the rail as well.
      entry(6, 6, ItemKind.place, startMinutes: 600),
    ];
    final ticket = Cost(
      id: 1,
      groupId: 7,
      amountMinor: 1500,
      currency: eurId,
      reason: 'Ticket',
      paid: false,
      isTransfer: false,
      isReimbursement: false,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...currencyOverrides,
          repositoryProvider.overrideWithValue(TripRepository(db)),
          ...attachmentTestOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
          reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
          transportModesProvider.overrideWith(
            (ref) => Stream.value([
              TransportModeRow(id: 6, builtinKey: 'train', sortOrder: 0),
            ]),
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryTimeline(
                items: items,
                accent: Colors.teal,
                tripStart: day,
                tripEnd: day,
                onTapItem: (_) {},
                onAddPlace: (_, {alternativeId}) {},
                onQuickAddPlace: (_, _, {alternativeId}) {},
                onAddTransport: (_, _, {alternativeId}) {},
                onReorder: (_, _, _) {},
                onReorderBranch: (_, _, _) {},
                onReorderRun: (_, _, _) {},
                costsByItem: const {},
                groups: {7: ItemGroup(id: 7, tripId: 1, collapsed: false)},
                costsByGroup: {
                  7: [ticket],
                },
                sets: {
                  30: AlternativeSet(
                    id: 30,
                    tripId: 1,
                    date: day,
                    sortOrder: 4,
                  ),
                },
                branches: const {
                  30: [
                    Alternative(id: 20, setId: 30, sortOrder: 0, chosen: true),
                    Alternative(id: 21, setId: 30, sortOrder: 1, chosen: false),
                  ],
                },
                localeName: 'en',
                onTapCost: (_) {},
                collapsedDays: const {},
                onToggleDayCollapsed: (_, _) {},
                now: DateTime(2026, 7, 5, 23),
                held: null,
                onPutDown: (_, {alternativeId}) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The option not on screen is laid out a page to the right; it is not part
    // of the line anyone sees.
    final width = tester.view.physicalSize.width;
    final rails = [
      // By render box, not by widget: the card's two margins are one const
      // widget, which a widget finder cannot tell apart.
      for (final element in find.byType(TimelineRail).evaluate())
        if (element.renderObject case final RenderBox box)
          box.localToGlobal(Offset.zero) & box.size,
    ].where((r) => r.left < width).toList();
    expect(find.byType(NowLine), findsOneWidget);
    expect(rails, isNotEmpty);

    // One position: every piece's rail is at its own left + half the gutter,
    // and every piece starts at the day's left edge.
    expect({for (final r in rails) r.left}, {0});

    // No gap: the pieces, merged, are a single stretch.
    rails.sort((a, b) => a.top.compareTo(b.top));
    var bottom = rails.first.bottom;
    for (final r in rails.skip(1)) {
      expect(
        r.top,
        lessThanOrEqualTo(bottom + 0.01),
        reason: 'the rail breaks between $bottom and ${r.top}',
      );
      if (r.bottom > bottom) bottom = r.bottom;
    }
  });
}
