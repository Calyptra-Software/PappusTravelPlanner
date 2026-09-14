import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app.dart';
import 'core/application_id.dart';
import 'core/database/database_location.dart';
import 'core/licenses.dart';
import 'core/app_info.dart';
import 'core/providers.dart';
import 'core/settings/locale_provider.dart';
import 'features/attachments/application/media_location.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the IANA timezone database so an imported connection's UTC times can
  // be turned into each stop's local wall-clock (see journey_mapper).
  tzdata.initializeTimeZones();
  // The bundled fonts' terms, for the license page reachable from About.
  registerBundledFontLicenses();
  final prefs = await SharedPreferences.getInstance();
  // This build's version, sent to the connection-search service as its usage
  // policy requires. Read here, once, so the request that needs it can read it
  // synchronously (see [appVersionProvider]).
  final packageInfo = await PackageInfo.fromPlatform();
  // On Linux the id that makes a build the CI one is GTK's, not PackageInfo's
  // (see core/application_id.dart). Read before the database path, whose
  // default depends on it.
  final ciBuild = isCiBuild(nativeApplicationId() ?? packageInfo.packageName);
  // Resolve the database path once at startup: the user's saved choice, or the
  // default app location.
  final activePath =
      prefs.getString(kDbPathPrefKey) ??
      await defaultDatabaseFile(ciBuild: ciBuild);
  // Whether Android will let this build read where a photograph was taken.
  // Asked here, once, for the same reason the two above are: the settings
  // screen draws a whole section on the answer, and one that arrived a few
  // frames in would insert that section into a list already being scrolled.
  // Nothing is *requested* here — this only reads what has already been
  // granted, and the dialog still belongs to the switch alone.
  final mediaLocation = await const MediaLocationChannel().status();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapDbPathProvider.overrideWithValue(activePath),
        appVersionProvider.overrideWithValue(
          '${packageInfo.version}+${packageInfo.buildNumber}',
        ),
        isCiBuildProvider.overrideWithValue(ciBuild),
        bootstrapMediaLocationProvider.overrideWithValue(mediaLocation),
      ],
      child: const PappusApp(),
    ),
  );
}
