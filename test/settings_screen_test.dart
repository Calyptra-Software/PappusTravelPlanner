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
import 'package:travelplanner/features/attachments/application/media_location.dart';
import 'package:travelplanner/features/attachments/widgets/photo_location_setting.dart';
import 'package:travelplanner/features/costs/application/currency_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/settings/presentation/settings_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The settings screen: the section that is only there on Android, and a list
/// that does not change height while it is being scrolled.
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

  /// The screen, with every section's stream handed to it.
  Future<void> pumpSettings(
    WidgetTester tester, {
    Stream<List<Person>> people = const Stream.empty(),
    Stream<List<TransportModeRow>> modes = const Stream.empty(),
    Stream<List<CostReason>> reasons = const Stream.empty(),
    Stream<List<CurrencyRow>> currencies = const Stream.empty(),
    Stream<Map<int, int>> counts = const Stream.empty(),
    MediaLocationAccess mediaLocation = MediaLocationAccess.unsupported,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bootstrapDbPathProvider.overrideWithValue('/tmp/pappus.sqlite'),
          appVersionProvider.overrideWithValue('1.0.0+1'),
          isCiBuildProvider.overrideWithValue(false),
          bootstrapMediaLocationProvider.overrideWithValue(mediaLocation),
          peopleRowsProvider.overrideWith((ref) => people),
          transportModesProvider.overrideWith((ref) => modes),
          reasonRowsProvider.overrideWith((ref) => reasons),
          currenciesProvider.overrideWith((ref) => currencies),
          currencyCostCountsProvider.overrideWith((ref) => counts),
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
    await pumpSettings(
      tester,
      people: people.stream,
      modes: modes.stream,
      reasons: reasons.stream,
      currencies: currencies.stream,
      counts: counts.stream,
    );

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

  group('the photos section', () {
    testWidgets('is there once the platform has the question', (tester) async {
      await pumpSettings(tester, mediaLocation: MediaLocationAccess.denied);

      // Denied, not granted: the switch is drawn wherever the question exists,
      // which is what makes it a way *in* to the permission rather than a
      // readout of one already held.
      await tester.scrollUntilVisible(
        find.text('Read where a photo was taken'),
        200,
        scrollable: null,
      );
      expect(find.byType(PhotoLocationSetting), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
    });

    testWidgets('and nowhere a photograph arrives intact', (tester) async {
      await pumpSettings(tester, mediaLocation: MediaLocationAccess.notNeeded);

      // Android 9 and older, the desktop and the web: nothing was taken out of
      // the file, so a switch offering to turn on what is already on would be a
      // control that does nothing — header and all.
      expect(find.byType(PhotoLocationSetting), findsNothing);
      expect(find.text('Photos'), findsNothing);
    });
  });
}
