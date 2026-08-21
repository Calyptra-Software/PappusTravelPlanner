import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app.dart';
import 'core/database/database_location.dart';
import 'core/licenses.dart';
import 'core/app_info.dart';
import 'core/providers.dart';
import 'core/settings/locale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the IANA timezone database so an imported connection's UTC times can
  // be turned into each stop's local wall-clock (see journey_mapper).
  tzdata.initializeTimeZones();
  // The bundled fonts' terms, for the license page reachable from About.
  registerBundledFontLicenses();
  final prefs = await SharedPreferences.getInstance();
  // Resolve the database path once at startup: the user's saved choice, or the
  // default app location.
  final activePath =
      prefs.getString(kDbPathPrefKey) ?? await defaultDatabaseFile();
  // This build's version, sent to the connection-search service as its usage
  // policy requires. Read here, once, so the request that needs it can read it
  // synchronously (see [appVersionProvider]).
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapDbPathProvider.overrideWithValue(activePath),
        appVersionProvider.overrideWithValue(
          '${packageInfo.version}+${packageInfo.buildNumber}',
        ),
        isCiBuildProvider.overrideWithValue(isCiBuild(packageInfo.packageName)),
      ],
      child: const PappusApp(),
    ),
  );
}
