import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/home_widget/home_widget_service.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The push to the Android home-screen widget, with the plugin's channel
/// answered here: what reaches the native side, and in which language.
void main() {
  const channel = MethodChannel('home_widget');
  late Map<String, Object?> saved;
  late List<String> calls;

  setUp(() {
    saved = {};
    calls = [];
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'saveWidgetData') {
            final args = call.arguments as Map<Object?, Object?>;
            saved[args['id']! as String] = args['data'];
          }
          return true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> push(WidgetTester tester, {String? language}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // Real futures, so outside the test's fake clock.
    final prefs = (await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'locale_code': ?language});
      return SharedPreferences.getInstance();
    }))!;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // Drift's streams answer on the real event loop, not the test's clock.
    await tester.runAsync(() => updateHomeWidget(widgetRef));
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('pushes the payload, then asks the widget to redraw', (
    tester,
  ) async {
    await push(tester);
    expect(saved['has_trip'], isFalse);
    expect(calls.last, 'updateWidget');
  });

  testWidgets('in the language the app is set to', (tester) async {
    await push(tester, language: 'de');
    final german = lookupAppLocalizations(const Locale('de'));
    expect(saved['empty_title'], german.widgetNoTripsTitle);
  });

  testWidgets('elsewhere than Android, nothing is pushed', (tester) async {
    // No database either: it returns before it would read one.
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    // `flutter test` builds for Android unless told otherwise.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await updateHomeWidget(widgetRef);
    debugDefaultTargetPlatformOverride = null;
    expect(calls, isEmpty);
  });
}
