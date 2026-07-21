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
import '../itinerary/day_blocks.dart';
import '../itinerary/widgets/transport_mode.dart';
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
      // Assemble today exactly as the timeline does — as blocks — so a decision
      // keeps the slot it occupies in the day. Only the plan as it stands
      // reaches the home screen: an option that was considered but not chosen
      // is not on today's agenda.
      todayItems = itemsInDayOrder(
        buildDayBlocks(
          day: today,
          items: await repo.watchItems(featured.id).first,
          sets: await repo.watchAlternativeSets(featured.id).first,
          branchesBySet: await repo.watchAlternativeBranches(featured.id).first,
        ),
      );
    }

    final locale = _resolveLocale(ref);
    final l10n = await AppLocalizations.delegate.load(locale);
    // Pre-resolve every mode's localized label so the payload (which the native
    // side only displays) carries plain text, not row ids.
    final modes = await repo.watchTransportModes().first;
    final modeLabels = {for (final m in modes) m.id: m.label(l10n)};
    final payload = buildWidgetPayload(
      trips,
      todayItems,
      now,
      l10n,
      locale.languageCode,
      modeLabels: modeLabels,
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
  final chosen =
      ref.read(localeProvider) ??
      WidgetsBinding.instance.platformDispatcher.locale;
  return AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == chosen.languageCode,
      )
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
    // Save every row; the native side reads item_count and renders as many as
    // fit the widget's current height.
    s<int>('item_count', p.rows.length),
    for (var i = 0; i < p.rows.length; i++) ...[
      s<int>('item${i}_id', p.rows[i].id),
      s<String>('item${i}_time', p.rows[i].time),
      s<String>('item${i}_text', p.rows[i].text),
      s<String>('item${i}_note', p.rows[i].note),
    ],
    s<String>('empty_title', p.emptyTitle),
    s<String>('empty_body', p.emptyBody),
  ]);
}

// --- deep-link click handling ---

/// Routes a widget-launch [uri] into the app. The whole widget links to the
/// trip (`travelplanner://trip?id=N`); a tapped item row adds `&item=M` to open
/// that item's editor.
void _navigate(GoRouter router, Uri? uri) {
  if (uri == null) return;
  final id = uri.queryParameters['id'];
  if (uri.host == 'trip' && id != null && id != '-1') {
    final item = uri.queryParameters['item'];
    if (item != null && item.isNotEmpty && item != '-1') {
      router.go('/trip/$id?item=$item');
    } else {
      router.go('/trip/$id');
    }
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
      final ongoing =
          featured != null && isTripOngoing(featured, DateTime.now());
      // Watch the ongoing trip's items so edits to today's plan re-sync too.
      final items = ongoing
          ? ref.watch(itineraryProvider(featured.id)).value
          : null;
      // Switching to another branch changes what today's plan *is* without
      // touching any item, and dragging a decision moves its whole option
      // without touching one either, so the branches and the sets belong in the
      // signature too.
      final branches = ongoing
          ? ref.watch(alternativeBranchesProvider(featured.id)).value
          : null;
      final sets = ongoing
          ? ref.watch(alternativeSetsProvider(featured.id)).value
          : null;

      // Use each row's full toString (Drift data classes include every column)
      // so any in-place edit re-pushes — enumerating fields by hand has twice
      // missed one (e.g. notes, then endMinutes).
      final signature = [
        for (final t in trips) t.toString(),
        'items:${items?.map((i) => i.toString()).join('|') ?? ''}',
        'branches:${branches?.values.expand((b) => b).join('|') ?? ''}',
        'sets:${sets?.values.join('|') ?? ''}',
      ].join('~');

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
