import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/format/date_format.dart';
import '../../core/providers.dart';
import '../../core/settings/locale_provider.dart';
import '../../data/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../itinerary/application/itinerary_providers.dart';
import '../trips/application/trip_providers.dart';
import 'widget_payload.dart';

/// Native provider class name (matches the Kotlin `AppWidgetProvider`).
const String _androidWidgetName = 'TravelPlannerWidgetProvider';

/// Whether the home widget feature is available on this platform.
bool get _widgetSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Reads current trip data, builds the payload, and pushes it to the native
/// Android widget. No-op on unsupported platforms.
Future<void> updateHomeWidget(WidgetRef ref) async {
  if (!_widgetSupported) return;
  try {
    final repo = ref.read(repositoryProvider);
    final trips = await repo.watchTrips().first;

    final now = DateTime.now();
    final featured = pickFeaturedTrip(trips, now);

    var todayItems = <ItineraryItem>[];
    if (featured != null && isTripOngoing(featured, now)) {
      final today = normalizeDay(now);
      final items = await repo.watchItems(featured.id).first;
      todayItems =
          items.where((i) => normalizeDay(i.date) == today).toList();
    }

    final locale = _resolveLocale(ref);
    final l10n = await AppLocalizations.delegate.load(locale);
    final payload = buildWidgetPayload(
      trips,
      todayItems,
      now,
      l10n,
      locale.languageCode,
    );

    await _save(payload);
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  } catch (error, stack) {
    debugPrint('Home widget update failed: $error\n$stack');
  }
}

/// Clamps the active locale to one the app actually ships (en/de), defaulting
/// to English, so [AppLocalizations.delegate.load] always succeeds.
Locale _resolveLocale(WidgetRef ref) {
  final chosen = ref.read(localeProvider) ??
      WidgetsBinding.instance.platformDispatcher.locale;
  return AppLocalizations.supportedLocales
          .any((l) => l.languageCode == chosen.languageCode)
      ? Locale(chosen.languageCode)
      : const Locale('en');
}

Future<void> _save(WidgetPayload p) async {
  Future<void> s<T>(String key, T value) =>
      HomeWidget.saveWidgetData<T>(key, value).then((_) {});

  await Future.wait([
    s<bool>('has_trip', p.hasTrip),
    s<int>('trip_id', p.tripId ?? -1),
    s<String>('title', p.title),
    s<String>('destination', p.destination),
    s<String>('dates', p.dates),
    s<String>('countdown', p.countdown),
    s<bool>('is_ongoing', p.isOngoing),
    s<String>('today_header', p.todayHeader),
    s<int>('item_count', p.rows.length),
    for (var i = 0; i < 3; i++) ...[
      s<String>('item${i}_time', i < p.rows.length ? p.rows[i].time : ''),
      s<String>('item${i}_text', i < p.rows.length ? p.rows[i].text : ''),
      s<String>('item${i}_note', i < p.rows.length ? p.rows[i].note : ''),
    ],
    s<String>('more_text', p.moreCount > 0 ? '+${p.moreCount}' : ''),
    s<String>('empty_title', p.emptyTitle),
    s<String>('empty_body', p.emptyBody),
  ]);
}

// --- deep-link click handling ---

/// Routes a widget-launch [uri] (`travelplanner://trip?id=N`) into the app.
void _navigate(GoRouter router, Uri? uri) {
  if (uri == null) return;
  final id = uri.queryParameters['id'];
  if (uri.host == 'trip' && id != null && id != '-1') {
    router.go('/trip/$id');
  } else {
    router.go('/');
  }
}

/// Handles a cold start triggered by tapping the widget.
Future<void> handleInitialWidgetLaunch(GoRouter router) async {
  if (!_widgetSupported) return;
  final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  _navigate(router, uri);
}

/// Listens for widget taps while the app is running.
StreamSubscription<Uri?> listenWidgetClicks(GoRouter router) {
  return HomeWidget.widgetClicked.listen((uri) => _navigate(router, uri));
}

/// Keeps the widget in sync: re-pushes whenever trips (or the ongoing trip's
/// itinerary) change. Wrap the app content with this.
class HomeWidgetSync extends ConsumerStatefulWidget {
  const HomeWidgetSync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<HomeWidgetSync> createState() => _HomeWidgetSyncState();
}

class _HomeWidgetSyncState extends ConsumerState<HomeWidgetSync> {
  String _lastSignature = '';

  @override
  Widget build(BuildContext context) {
    if (_widgetSupported) {
      final trips = ref.watch(tripListProvider).value ?? const [];
      final featured = pickFeaturedTrip(trips, DateTime.now());
      final ongoing = featured != null && isTripOngoing(featured, DateTime.now());
      // Watch the ongoing trip's items so edits to today's plan re-sync too.
      final items = ongoing
          ? ref.watch(itineraryProvider(featured.id)).value
          : null;

      final signature = [
        for (final t in trips)
          '${t.id}:${t.title}:${t.destination}:${t.startDate}:${t.endDate}',
        // Include the fields the widget actually renders (time, the text-driving
        // columns, and notes) so editing an existing item re-pushes — item ids
        // alone would miss in-place edits.
        'items:${items?.length ?? 0}:'
            '${items?.map((i) => '${i.id}/${i.startMinutes}/${i.kind.index}/'
                '${i.title}/${i.location}/${i.mode?.index}/'
                '${i.fromLocation}/${i.toLocation}/${i.notes}').join(',') ?? ''}',
      ].join('|');

      if (signature != _lastSignature) {
        _lastSignature = signature;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) updateHomeWidget(ref);
        });
      }
    }
    return widget.child;
  }
}
