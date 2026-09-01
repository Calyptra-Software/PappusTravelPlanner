import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/attachments/application/storage_providers.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/costs/application/currency_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/settings/presentation/settings_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// A settings screen that does not change height while it is being scrolled.
///
/// Every section there reads an `autoDispose` stream, and a `ListView` unmounts
/// a child once it has scrolled far enough past it — which drops the last
/// listener and disposes the stream. Coming back, the section rebuilds from
/// `AsyncLoading` and draws its "nothing here" row, then grows to its real
/// height a frame later. Below the viewport nobody sees that; *above* it, the
/// content over the scroll offset gets taller and the same offset now points
/// half a screen further up the list, which is exactly what was reported from a
/// phone: a jump, only ever when scrolling upwards, and always in the same
/// place.
///
/// So what is asserted is the subscription, not the pixels: a section's stream
/// is still listened to after the screen has been scrolled to the bottom and
/// back, because the screen holds it for as long as it is on display.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// A stream that hands over [initial] and then stays open, counting who is
  /// listening. The count is the whole assertion: 1 while the screen is up,
  /// 0 the moment nothing needs it any more.
  ///
  /// `Stream.multi` rather than a controller, so that a *second* subscription is
  /// legal. Without it a regression here reports "stream has already been
  /// listened to" from inside a provider — an exception about the harness,
  /// where what the reader needs is the count.
  ({Stream<T> stream, int Function() listeners}) counted<T>(T initial) {
    var listeners = 0;
    final stream = Stream<T>.multi((controller) {
      listeners++;
      controller.add(initial);
      controller.onCancel = () => listeners--;
    });
    return (stream: stream, listeners: () => listeners);
  }

  testWidgets('a section scrolled past and back is still subscribed', (
    tester,
  ) async {
    // Enough of them that the section is taller than a screen either way — a
    // list of six collapsing to one "no people" row is the half-screen jump.
    final people = counted<List<Person>>([
      for (var i = 1; i <= 6; i++)
        Person(id: i, name: 'Person $i', isMe: false),
    ]);
    final modes = counted<List<TransportModeRow>>(const []);
    final reasons = counted<List<CostReason>>(const []);
    final currencies = counted<List<CurrencyRow>>(const []);
    final counts = counted<Map<int, int>>(const {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bootstrapDbPathProvider.overrideWithValue('/tmp/pappus.sqlite'),
          appVersionProvider.overrideWithValue('1.0.0+1'),
          isCiBuildProvider.overrideWithValue(false),
          peopleRowsProvider.overrideWith((ref) => people.stream),
          transportModesProvider.overrideWith((ref) => modes.stream),
          reasonRowsProvider.overrideWith((ref) => reasons.stream),
          currenciesProvider.overrideWith((ref) => currencies.stream),
          currencyCostCountsProvider.overrideWith((ref) => counts.stream),
          // Reads the database file and counts its attachments; neither exists
          // here, and neither is what this test is about.
          databaseStorageProvider.overrideWith(
            (ref) async =>
                (fileBytes: 1024, attachmentCount: 0, attachmentBytes: 0),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Subscribed from the first build — the screen asks for them itself, not
    // through whichever section happens to be on screen.
    expect(people.listeners(), 1);

    final list = find.byType(ListView);
    await tester.scrollUntilVisible(
      find.text('Person 6'),
      200,
      scrollable: null,
    );
    expect(find.text('Person 6'), findsOneWidget);

    // On to the far end of the list. This is the half of the gesture nobody
    // sees anything wrong in — and the half that used to throw the section
    // away.
    for (var i = 0; i < 12; i++) {
      await tester.drag(list, const Offset(0, -600));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Person 6'), findsNothing);
    expect(people.listeners(), 1);
    expect(modes.listeners(), 1);
    expect(reasons.listeners(), 1);
    expect(currencies.listeners(), 1);
    expect(counts.listeners(), 1);

    // And back up, which is where the jump was felt. The section is drawn from
    // the value it never lost, so there is no loading frame and no height to
    // grow back into.
    for (var i = 0; i < 12; i++) {
      await tester.drag(list, const Offset(0, 600));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Person 6'),
      200,
      scrollable: null,
    );

    expect(find.text('Person 6'), findsOneWidget);
    expect(people.listeners(), 1);
  });
}
