import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/presentation/track_import_screen.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The screen that divides one recording among its entries.
void main() {
  ItineraryItem leg(int id, String title) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.transport,
    title: title,
    spansNextDay: false,
  );

  final line = [for (var i = 0; i < 40; i++) LatLng(53.5 + i * 0.001, 9.9)];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVersionProvider.overrideWithValue('0.0.0-test')],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrackImportScreen(
            lines: [line],
            name: 'Walk',
            selection: [leg(1, 'A → B'), leg(2, 'B → C')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  }

  testWidgets('nothing is written until the handover has been pointed at', (
    tester,
  ) async {
    await pump(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'estimating is not offered');
    expect(find.textContaining('A → B'), findsWidgets);

    await drain(tester);
  });
}
