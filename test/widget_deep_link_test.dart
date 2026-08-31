// The home-screen widget's deep links: which location a tap means, and whether
// the app's own route table can still read it back.
//
// This is the path people enter the app by from the home screen, and until now
// nothing here had an opinion on it — a rename of `trip/:id`, or a go_router
// release that read query parameters differently, would have broken it in a way
// only a phone could notice. It costs no database and builds no screens:
// `widgetLaunchLocation` is pure, and `GoRouter.configuration.findMatch` runs
// the real table without a widget tree, which is also what keeps it clear of
// the drift-stream hazards a `TripDetailScreen` would drag in.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travelplanner/core/router/app_router.dart';
import 'package:travelplanner/features/home_widget/widget_deep_link.dart';

Uri widgetUri(String query) => Uri.parse('pappus://trip?$query');

void main() {
  group('a widget tap means', () {
    test('the trip it names', () {
      expect(widgetLaunchLocation(widgetUri('id=7')), '/trip/7');
    });

    test('the entry too, when a row was the thing tapped', () {
      expect(
        widgetLaunchLocation(widgetUri('id=7&item=42')),
        '/trip/7?item=42',
      );
    });

    test('nothing at all when there is no uri behind the launch', () {
      // Distinct from '/': an ordinary cold start must not be redirected to the
      // overview, or it would throw away wherever the app was already going.
      expect(widgetLaunchLocation(null), isNull);
    });

    test('the overview when the widget is showing no trip', () {
      // -1 is the native side's "nothing here": an AppWidgetProvider fills its
      // RemoteViews before it knows what the app holds, so an absent id arrives
      // as a number rather than as a missing parameter.
      expect(widgetLaunchLocation(widgetUri('id=-1')), '/');
    });

    test('the trip, when only the entry is the placeholder', () {
      expect(widgetLaunchLocation(widgetUri('id=7&item=-1')), '/trip/7');
    });

    test('the trip, when the entry is empty rather than absent', () {
      expect(widgetLaunchLocation(widgetUri('id=7&item=')), '/trip/7');
    });

    test('the overview when no trip is named', () {
      expect(widgetLaunchLocation(Uri.parse('pappus://trip')), '/');
    });

    test('the overview when the link is about something else', () {
      expect(widgetLaunchLocation(Uri.parse('pappus://elsewhere?id=7')), '/');
    });
  });

  group('the route table reads back', () {
    late GoRouter router;

    setUp(() {
      // routerProvider depends on nothing, so no database is needed to build
      // the real table this app runs on.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      router = container.read(routerProvider);
    });

    RouteMatchList matchFor(Uri? widgetLaunch) {
      final location = widgetLaunchLocation(widgetLaunch);
      expect(location, isNotNull);
      return router.configuration.findMatch(Uri.parse(location!));
    }

    test('the trip id a widget tap put in the path', () {
      final match = matchFor(widgetUri('id=7'));
      expect(match.isError, isFalse);
      expect(match.pathParameters['id'], '7');
    });

    test('the entry id a row tap put in the query', () {
      final match = matchFor(widgetUri('id=7&item=42'));
      expect(match.isError, isFalse);
      // The screen reads the two halves from different places, so both are
      // asserted: `pathParameters` for the trip, `uri.queryParameters` for the
      // entry — exactly as app_router.dart does.
      expect(match.pathParameters['id'], '7');
      expect(match.uri.queryParameters['item'], '42');
    });

    test('the overview, for a widget with nothing to open', () {
      final match = matchFor(widgetUri('id=-1'));
      expect(match.isError, isFalse);
      expect(match.uri.path, '/');
    });
  });
}
