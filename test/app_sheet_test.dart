import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/widgets/app_sheet.dart';

/// What every sheet in the app is opened by, and the two things it is for.
///
/// A sheet taller than the screen used to reach the very top of it, which put
/// its drag handle in the strip Android pulls the notification shade down from:
/// the one gesture that should have shrunk the sheet opened the system's panel
/// instead, and the back button was the only way out. So the sheet stops below
/// the status bar *and* leaves a touch target's worth of scrim above itself —
/// the handle can be reached, and tapping beside the sheet closes it.
void main() {
  /// A body far taller than any screen, so the cap is always what decides.
  Future<void> pumpTallSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (_) => const SingleChildScrollView(
                    child: SizedBox(
                      height: 4000,
                      width: double.infinity,
                      child: Text('deep'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a tall sheet stops a touch target below the status bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = const FakeViewPadding(top: 40);
    addTearDown(tester.view.reset);

    await pumpTallSheet(tester);

    final top = tester.getTopLeft(find.byType(BottomSheet)).dy;
    expect(
      top,
      40 + kSheetScrimStrip,
      reason: 'the status bar, and then a strip of scrim under it',
    );
  });

  testWidgets('the scrim left above it is what closes the sheet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = const FakeViewPadding(top: 40);
    addTearDown(tester.view.reset);

    await pumpTallSheet(tester);
    expect(find.byType(BottomSheet), findsOneWidget);

    // Between the status bar and the sheet — the strip that exists so a tap
    // there is possible at all.
    await tester.tapAt(const Offset(200, 40 + kSheetScrimStrip / 2));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('a wide window keeps the width Material caps a sheet at', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await pumpTallSheet(tester);

    // Naming a height in `constraints` replaces the theme's own constraints
    // rather than adding to them, so the width has to be restated with it. The
    // `BottomSheet` itself is laid out full width and carries the cap inside,
    // so what it is measured on is the body.
    expect(
      tester.getSize(find.byType(SingleChildScrollView)).width,
      kSheetMaxWidth,
    );
  });
}
