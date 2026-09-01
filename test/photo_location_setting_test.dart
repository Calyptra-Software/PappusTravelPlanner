import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/features/attachments/application/media_location.dart';
import 'package:travelplanner/features/attachments/widgets/photo_location_setting.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'support/fake_media_location.dart';

/// The one control the feature has.
///
/// What it shows is [PhotoLocationState.active] — both halves, the switch and
/// the permission — and what it says is the rest: a refusal springs the switch
/// back, which needs a sentence; a *permanent* refusal needs the way out with
/// it, since the app can no longer show the dialog itself; and switching **off**
/// needs one too, because the grant outlives it and only the system screen can
/// take it away.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpTile(
    WidgetTester tester,
    FakeMediaLocation platform, {
    MediaLocationAccess startup = MediaLocationAccess.denied,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bootstrapMediaLocationProvider.overrideWithValue(startup),
          mediaLocationProvider.overrideWithValue(platform),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PhotoLocationSetting()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchIsOn(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  testWidgets('is off, and says what off means', (tester) async {
    await pumpTile(tester, FakeMediaLocation());

    expect(switchIsOn(tester), isFalse);
    // Not belt and braces: a granted permission cannot be handed back from
    // inside an app, so off has to be a statement about what is kept rather
    // than about what is asked for — and the tile says so.
    expect(
      find.textContaining('even where Android would hand it over'),
      findsOneWidget,
    );
  });

  testWidgets('turning it on and being allowed leaves it on, quietly', (
    tester,
  ) async {
    await pumpTile(tester, FakeMediaLocation());

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // Silence on success: the switch has moved, which is the whole answer.
    expect(switchIsOn(tester), isTrue);
    expect(prefs.getBool('photo_location_enabled'), isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a refusal springs the switch back and is explained', (
    tester,
  ) async {
    await pumpTile(
      tester,
      FakeMediaLocation(access: MediaLocationAccess.denied),
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(switchIsOn(tester), isFalse);
    expect(find.textContaining('did not allow'), findsOneWidget);
  });

  testWidgets('a permanent refusal comes with the way out', (tester) async {
    final platform = FakeMediaLocation(
      access: MediaLocationAccess.deniedForever,
    );
    await pumpTile(tester, platform);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // The app can no longer show the dialog itself, so the sentence carries the
    // system screen with it rather than leaving the user to find it.
    expect(find.textContaining('will not ask again'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(platform.settingsOpened, 1);
  });

  testWidgets('turning it off says what it does and does not do', (
    tester,
  ) async {
    await prefs.setBool('photo_location_enabled', true);
    final platform = FakeMediaLocation();
    await pumpTile(tester, platform, startup: MediaLocationAccess.granted);
    expect(switchIsOn(tester), isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(switchIsOn(tester), isFalse);
    expect(prefs.getBool('photo_location_enabled'), isFalse);
    // The grant outlives the switch — an app cannot hand one back without
    // killing its own process — which is surprising enough to be worth saying,
    // with the one screen that can undo it beside the sentence.
    expect(find.textContaining('keeps the permission'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(platform.settingsOpened, 1);
  });

  testWidgets('and says nothing when there was no grant to outlive it', (
    tester,
  ) async {
    await prefs.setBool('photo_location_enabled', true);
    // Switched on once and refused, or revoked since: nothing is standing, so
    // a sentence about revoking it would be noise.
    await pumpTile(
      tester,
      FakeMediaLocation(access: MediaLocationAccess.denied),
      startup: MediaLocationAccess.denied,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.textContaining('keeps the permission'), findsNothing);
  });

  testWidgets('a permission revoked since reads as off, and can be re-asked', (
    tester,
  ) async {
    await prefs.setBool('photo_location_enabled', true);
    // The switch was set, and the permission has gone since.
    await pumpTile(
      tester,
      FakeMediaLocation(),
      startup: MediaLocationAccess.denied,
    );

    // The app's own word must not stand against the system's.
    expect(switchIsOn(tester), isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(switchIsOn(tester), isTrue);
  });
}
