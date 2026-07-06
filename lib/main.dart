import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/database_location.dart';
import 'core/providers.dart';
import 'core/settings/locale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Resolve the database path once at startup: the user's saved choice, or the
  // default app location.
  final activePath =
      prefs.getString(kDbPathPrefKey) ?? await defaultDatabaseFile();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapDbPathProvider.overrideWithValue(activePath),
      ],
      child: const TravelPlannerApp(),
    ),
  );
}
