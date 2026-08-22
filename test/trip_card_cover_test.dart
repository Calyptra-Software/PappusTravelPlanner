import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:travelplanner/core/format/money_format.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/trips/widgets/trip_card.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Where the cover photograph sits on an overview card.
///
/// Worth a test because it is a *layout* claim and nothing else can hold it:
/// the picture hugs the text, which only works while every row inside the text
/// column shrink-wraps. One `Expanded` put back by accident would silently
/// push it to the card's edge again, and no assertion about widgets would
/// notice.
void main() {
  const width = 400.0;

  Trip trip(String title, {DateTime? start, DateTime? end}) => Trip(
    id: 1,
    title: title,
    destination: '',
    startDate: start,
    endDate: end,
    kind: TripKind.trip,
    colorValue: 0xFF00695C,
    coverHidden: false,
    photosCollapsed: false,
    createdAt: DateTime(2026, 1, 1),
  );

  Uint8List png() {
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(90, 140, 190));
    return img.encodePng(image);
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required Trip data,
    Uint8List? cover,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: TripCard(
                trip: data,
                book: CurrencyBook.empty,
                cover: cover,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('follows the text instead of standing at the card edge', (
    tester,
  ) async {
    await pumpCard(tester, data: trip('Rom'), cover: png());
    final short = tester.getRect(find.byType(Image)).left;

    await pumpCard(
      tester,
      data: trip('A trip whose title runs on well past the width available'),
      cover: png(),
    );
    final long = tester.getRect(find.byType(Image)).left;

    // The distinguishing property, and the only one that survives a change of
    // font or padding: where the picture sits *depends on the text*. Pushed to
    // the card's edge it would land in the same place both times.
    expect(short, lessThan(long));
  });

  testWidgets('a long title pushes it out to the edge, and no further', (
    tester,
  ) async {
    await pumpCard(
      tester,
      data: trip('A trip whose title runs on well past the width available'),
      cover: png(),
    );

    final card = tester.getRect(find.byType(TripCard));
    final image = tester.getRect(find.byType(Image));

    // Laid out before the text, so the text ellipsizes rather than squeezing
    // the photograph out of the card.
    expect(image.width, kTripCoverSize);
    expect(image.right, lessThanOrEqualTo(card.right));
  });

  testWidgets('a trip without one draws no picture at all', (tester) async {
    await pumpCard(tester, data: trip('Rom'));

    // No placeholder: an invented square would be something put there to fill a
    // space rather than something said.
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('the day count sits on a line of its own, under the dates', (
    tester,
  ) async {
    await pumpCard(
      tester,
      data: trip('Rom', start: DateTime(2026, 5, 1), end: DateTime(2026, 5, 3)),
      cover: png(),
    );

    final pill = tester.getRect(find.text('3 days'));
    final dates = tester.getRect(find.textContaining('2026'));
    final image = tester.getRect(find.byType(Image));

    // Below the dates rather than beside them: on a phone the chip is the first
    // thing to run out of room, and what gives way for it is the date line the
    // chip is about.
    expect(pill.top, greaterThanOrEqualTo(dates.bottom));
    expect(pill.left, closeTo(dates.left, 24));
    // And inside the text block, so the picture still follows the text.
    expect(pill.right, lessThan(image.left));
  });
}
