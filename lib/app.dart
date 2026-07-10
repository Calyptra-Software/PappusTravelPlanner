import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/settings/locale_provider.dart';
import 'core/settings/theme_mode_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/home_widget/home_widget_service.dart';
import 'features/sharing/trip_share_channel.dart';
import 'l10n/app_localizations.dart';

class TravelPlannerApp extends ConsumerStatefulWidget {
  const TravelPlannerApp({super.key});

  @override
  ConsumerState<TravelPlannerApp> createState() => _TravelPlannerAppState();
}

class _TravelPlannerAppState extends ConsumerState<TravelPlannerApp> {
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    final router = ref.read(routerProvider);
    // Handle a launch from tapping the widget, plus taps while running.
    handleInitialWidgetLaunch(router);
    _widgetClicks = listenWidgetClicks(router);
    // Handle a shared .tpt trip file that launched the app, plus files opened
    // while it's running.
    handleInitialSharedTrip(ref);
    listenSharedTrips(ref);
    // Push an initial snapshot to the widget once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) updateHomeWidget(ref);
    });
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) =>
          HomeWidgetSync(child: child ?? const SizedBox.shrink()),
    );
  }
}
