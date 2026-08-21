import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/app_info.dart';
import 'package:travelplanner/core/licenses.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/features/settings/presentation/about_settings.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The About section says which build this is — the one thing a bug report is
/// useless without — and copies it, since it is read in order to be typed
/// somewhere else. It reports the *running* version, never a literal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAbout(
    WidgetTester tester, {
    String version = '9.8.7+42',
    bool isCi = false,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWithValue(version),
          isCiBuildProvider.overrideWithValue(isCi),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AboutSettings()),
        ),
      ),
    );
  }

  testWidgets('shows the running version, not a hard-coded one', (
    tester,
  ) async {
    await pumpAbout(tester);
    await tester.pumpAndSettle();

    expect(find.text('Version'), findsOneWidget);
    expect(find.text('9.8.7+42'), findsOneWidget);
  });

  testWidgets('links to the source and the issue tracker', (tester) async {
    await pumpAbout(tester);
    await tester.pumpAndSettle();

    expect(find.text(kAppRepositoryUrl), findsOneWidget);
    expect(find.text(kAppIssuesUrl), findsOneWidget);
  });

  testWidgets('shows the address the User-Agent no longer carries', (
    tester,
  ) async {
    await pumpAbout(tester);
    await tester.pumpAndSettle();

    expect(find.text(kAppContact), findsOneWidget);
  });

  testWidgets('tapping the version copies it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpAbout(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('9.8.7+42'));
    await tester.pumpAndSettle();

    expect(copied, '9.8.7+42');
    expect(find.text('Version copied'), findsOneWidget);
  });

  testWidgets('the license page carries the bundled fonts too', (tester) async {
    // Flutter's registry knows package LICENSE files; a font ships inside the
    // binary and has to be added by hand.
    addTearDown(LicenseRegistry.reset);
    registerBundledFontLicenses();
    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }

    expect(packages, containsAll(<String>['Roboto', 'TransportGlyphs']));
  });

  testWidgets('opens the license page', (tester) async {
    await pumpAbout(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open-source licenses'));
    // Not pumpAndSettle: the page spins a progress indicator while it collects
    // the licenses, so it never settles.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text(kAppLegalese), findsOneWidget);
    // The mark sits above the title; the lockup would repeat the name that the
    // page already prints from `applicationName`.
    final icon = tester.widget<Image>(
      find.descendant(
        of: find.byType(LicensePage),
        matching: find.byType(Image),
      ),
    );
    expect((icon.image as AssetImage).assetName, 'assets/logo/pappus_mark.png');
  });

  testWidgets('says nothing about CI in an ordinary build', (tester) async {
    await pumpAbout(tester);
    await tester.pumpAndSettle();

    expect(find.text('CI test build'), findsNothing);
    expect(find.text('9.8.7+42'), findsOneWidget);
  });

  testWidgets('names the CI build and marks the version it copies', (
    tester,
  ) async {
    await pumpAbout(tester, isCi: true);
    await tester.pumpAndSettle();

    expect(find.text('CI test build'), findsOneWidget);
    // The marker rides on the string itself: the version is read in order to be
    // pasted into a bug report, which must say it came from a test build.
    expect(find.text('9.8.7+42 \u00b7 CI'), findsOneWidget);
    expect(find.text('9.8.7+42'), findsNothing);
  });
}
