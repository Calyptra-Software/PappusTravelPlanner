import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/widgets/attribution.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Where the connection search's data comes from — and, the part that makes it
/// attribution rather than a credit, how to get there.
///
/// Transitous' usage policy asks that its sources page be **linked**, and the
/// OpenStreetMap data underneath carries the same condition. That makes these
/// two widgets a term of use rather than a nicety, which is the whole reason
/// they are worth a test: a refactor that turned either into plain text would
/// break an agreement, silently and invisibly.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('under the search, where the data is used', () {
    testWidgets('names both sources', (tester) async {
      await pump(tester, const AttributionFooter());

      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('Timetable data via Transitous'), findsOneWidget);
    });

    testWidgets('and both are links, not captions', (tester) async {
      await pump(tester, const AttributionFooter());

      // Two tappable things, underlined so they read as links.
      expect(find.byType(InkWell), findsNWidgets(2));
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.decoration, TextDecoration.underline);
      }
    });
  });

  group('in settings, where they outlive the sheet', () {
    testWidgets('both sources are rows carrying their address', (tester) async {
      await pump(tester, const DataSourcesSettings());

      // The URL is on the row itself: an imported connection stays in the
      // trip, the PDF and the `.ics` long after the search that found it, so
      // the attribution has to be reachable when no search is open.
      expect(find.text(kOsmCopyrightUrl), findsOneWidget);
      expect(find.text(kTransitousSourcesUrl), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(2));
    });

    testWidgets('under a line saying what the data is for', (tester) async {
      await pump(tester, const DataSourcesSettings());

      expect(
        find.textContaining('openly licensed timetable and map data'),
        findsOneWidget,
      );
    });

    testWidgets('and each row opens its own address', (tester) async {
      await pump(tester, const DataSourcesSettings());

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
      expect(tiles, hasLength(2));
      for (final tile in tiles) {
        expect(tile.onTap, isNotNull);
      }
    });
  });

  test('the two addresses are the pages the policies name', () {
    // Hard-coded on purpose: these are the pages the licences point at, not a
    // preference, and changing one is changing what the app credits.
    expect(kOsmCopyrightUrl, 'https://www.openstreetmap.org/copyright');
    expect(kTransitousSourcesUrl, 'https://transitous.org/sources/');
  });
}
