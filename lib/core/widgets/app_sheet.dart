import 'package:flutter/material.dart';

/// The strip of scrim a sheet always leaves above itself.
///
/// What is left over is not margin: it is the scrim, and tapping it is the way
/// back out. A sheet allowed to fill the screen has only its drag handle left
/// to close it — and on Android that handle then sits in the strip the
/// notification shade is pulled down from, so the gesture meant to shrink the
/// sheet opens the system's own panel instead and the back button is all that
/// remains.
///
/// A height rather than a fraction of the screen, and measured below the status
/// bar rather than from the top of the display, because what it has to be is a
/// **touch target** — 48 is Material's smallest — and a fraction of a short
/// screen is not one.
const double kSheetScrimStrip = 48;

/// The width Material 3 caps a bottom sheet at, restated because it has to be.
///
/// Passing `constraints` to [showModalBottomSheet] replaces the theme's own
/// wholesale rather than adding to them, and the M3 defaults are exactly
/// `BoxConstraints(maxWidth: 640)` — so a sheet that named only a height would
/// silently lose the width cap and run edge to edge on a tablet.
const double kSheetMaxWidth = 640;

/// Opens a modal bottom sheet the way this app opens every one of them.
///
/// Four settings that belong together, in one place because they had drifted
/// apart: nine call sites passed [showModalBottomSheet.useSafeArea] and twelve
/// did not, which is not a decision anyone made about those twelve.
///
/// * `useSafeArea` keeps the sheet, and with it the drag handle, clear of the
///   status bar. Its default of false does more than leave out a [SafeArea]:
///   Flutter then applies `MediaQuery.removePadding(removeTop: true)`, so a
///   `SafeArea` *inside* the sheet cannot make up for it either. What Flutter
///   wraps is `SafeArea(bottom: false)`, so a body that pads itself against the
///   gesture bar — as most here do — goes on doing so.
/// * `constraints` leaves the strip of scrim described above.
/// * `isScrollControlled` lets a sheet grow past the default nine-sixteenths of
///   the screen; every body here scrolls, and the cap is what stops the growth.
/// * `showDragHandle` draws the handle all of this is about.
///
/// A sheet that wants to be smaller still constrains its own body — several do,
/// and the stricter of the two constraints is the one that governs.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final media = MediaQuery.of(context);
  final theme = Theme.of(context);
  // What the sheet has to sit in, the status bar already taken off it by
  // `useSafeArea`. A MediaQuery can report no height at all — a test that
  // substitutes its own data, a window not yet laid out — and the honest answer
  // there is no cap rather than a negative one, which is not a constraint but a
  // crash.
  final available = media.size.height - media.padding.top;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxWidth: theme.bottomSheetTheme.constraints?.maxWidth ?? kSheetMaxWidth,
      maxHeight: available > kSheetScrimStrip
          ? available - kSheetScrimStrip
          : double.infinity,
    ),
    builder: builder,
  );
}
