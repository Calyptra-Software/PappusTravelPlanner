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

  testWidgets('the day count stays at the right of the text block', (
    tester,
  ) async {
    await pumpCard(
      tester,
      // A title far longer than the date line, so the two rows disagree about
      // how wide they want to be — which is the only case where this shows.
      data: trip(
        'A trip with a title much longer than its dates',
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 3),
      ),
      cover: png(),
    );

    // The day count, drawn as a pill at the end of the date line.
    final pill = tester.getRect(find.text('3 days'));
    final image = tester.getRect(find.byType(Image));
    final title = tester.getRect(
      find.text('A trip with a title much longer than its dates'),
    );

    // At the end of the block whose width the title sets, not tucked in behind
    // the date text. Measured on the label rather than the pill around it, so
    // the pill's own padding is the whole of the slack allowed here.
    expect(pill.right, lessThanOrEqualTo(title.right));
    expect(pill.right, greaterThan(title.right - 16));
    // And still left of the picture.
    expect(pill.right, lessThan(image.left));
  });
}
