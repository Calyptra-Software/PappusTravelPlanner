/// The "you are here" the sensor answers for: the button that switches it on,
/// and the mark it draws.
///
/// Kept apart from `map_overlays.dart`, which is deliberately provider-free
/// furniture handed its strings from outside. This half is the opposite: it owns
/// an interaction — a permission dialog, a refusal to explain, a receiver to
/// switch off — so it reads the provider and the localizations itself, and every
/// map gets the whole behavior by placing two widgets rather than by
/// reimplementing it.
///
/// Note which "you are here" this is *not*. `now_marker.dart` answers where the
/// **plan** has got to, from the clock and the day's entries, and it is drawn in
/// the app's reserved red. This one answers where the **device** is, and says so
/// in a color of its own — see [_kLocationBlue].
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../l10n/app_localizations.dart';
import '../location/device_location.dart';
import 'map_overlays.dart';

/// The color of the device's own position, and the one color on these maps
/// that is not the app's to theme.
///
/// A trip's accent is the user's choice and a leg under way is red; a mark that
/// took either would be claiming to be part of the plan. This blue is what every
/// map application has drawn a receiver's own reading in for twenty years, so it
/// is read correctly before anything is tapped — and it stays the same in light
/// and dark, because the raster tiles under it do too.
const Color _kLocationBlue = Color(0xFF1A73E8);

/// How far in the map zooms when it is centered on a fix, unless it is already
/// closer.
///
/// Never *out*: someone who has zoomed in to read street names asked a question
/// this button was not asked, and answering it by pulling the map back out is
/// the sort of help nobody wants twice.
const double kLocationZoom = 15;

/// Reports a refusal, once, as a message with a way out of it where there is
/// one.
///
/// Call from `build`. Compares against the previous problem rather than against
/// null, so a second attempt that fails the same way still says so, while the
/// stream of fixes that follows a successful one cannot re-raise anything.
void reportLocationProblems(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  ref.listen(deviceLocationProvider, (previous, next) {
    final problem = next.problem;
    if (problem == null || problem == previous?.problem) return;

    // The two problems with a system screen behind them get an action rather
    // than a sentence telling the user to go and find it: a permission the
    // platform will not ask about again, and location switched off device-wide,
    // both sit several taps deep in places that differ per OS and per version.
    final (
      String message,
      Future<bool> Function()? settings,
    ) = switch (problem) {
      LocationProblem.denied => (l10n.mapLocationDenied, null),
      LocationProblem.deniedForever => (
        l10n.mapLocationBlocked,
        Geolocator.openAppSettings,
      ),
      LocationProblem.serviceOff => (
        l10n.mapLocationServiceOff,
        Geolocator.openLocationSettings,
      ),
      LocationProblem.failed => (l10n.mapLocationFailed, null),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: settings == null
            ? null
            : SnackBarAction(
                label: l10n.mapLocationOpenSettings,
                onPressed: () => settings(),
              ),
      ),
    );
  });
}

/// Runs [onFirstFix] with the first reading of each session, and no other.
///
/// Call from `build`. "First" is read off the null-to-fix transition rather than
/// counted, which is exactly why switching the mark off clears the fix: that is
/// what makes a second session's first reading recognizable as one. The
/// distinction is the whole of the agreed behavior — the map is put where the
/// user is *once*, and every reading after that only moves the mark, so a map
/// panned ahead to see what is coming stays where it was put.
void listenForFirstFix(WidgetRef ref, ValueChanged<DeviceFix> onFirstFix) {
  ref.listen(deviceLocationProvider, (previous, next) {
    final fix = next.fix;
    if (fix == null || previous?.fix != null) return;
    onFirstFix(fix);
  });
}

/// Puts [fix] in the middle of the map, closing in to [kLocationZoom] if the
/// camera is further out than that.
void centerOnFix(MapController controller, DeviceFix fix) {
  controller.move(
    fix.position,
    math.max(controller.camera.zoom, kLocationZoom),
  );
}

/// The button that switches the mark on and off.
///
/// One press does the whole thing: ask for the permission if it has not been
/// given, start the receiver, and — through the null-to-fix transition its
/// callers listen for — center the map on the first reading. A second press
/// switches it off again. The camera is never moved after that: a map that
/// follows you is a map you cannot look ahead on, and panning away to see what
/// comes next is the most ordinary thing to do while traveling.
class MapLocationButton extends ConsumerWidget {
  const MapLocationButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(deviceLocationProvider);

    reportLocationProblems(context, ref);

    return MapRoundButton(
      icon: state.problem != null
          ? Icons.location_disabled
          : state.on
          ? Icons.my_location
          : Icons.location_searching,
      // Highlighted while it is on, so the button says whether the receiver is
      // running even before the first fix has drawn anything.
      foreground: state.on ? _kLocationBlue : null,
      tooltip: state.on ? l10n.mapMyLocationHide : l10n.mapMyLocationShow,
      onPressed: () => ref.read(deviceLocationProvider.notifier).toggle(),
      // Something is happening, and until the first reading arrives there is
      // nothing on the map to show it.
      busy: state.locating,
    );
  }
}

/// The mark itself: the reading, and how sure it is.
///
/// A `FlutterMap` child, so it goes in `children:` alongside the tile and marker
/// layers rather than in the `Stack` over them. Draws nothing at all until there
/// is a fix, which is what keeps it out of the way of a map nobody has asked to
/// be located on.
class DeviceLocationLayer extends ConsumerWidget {
  const DeviceLocationLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fix = ref.watch(deviceLocationProvider).fix;
    if (fix == null) return const SizedBox.shrink();
    return Stack(
      children: [
        // The error, drawn to scale. A receiver indoors is routinely a hundred
        // meters out and says so; a dot alone would state a precision it does
        // not have, and the circle is the whole difference between "you are
        // here" and "you are somewhere in here". Skipped when the platform
        // reports no figure at all, rather than drawn as a hairline that would
        // mean the opposite of what it says.
        if (fix.accuracyMeters > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: fix.position,
                radius: fix.accuracyMeters,
                useRadiusInMeter: true,
                color: _kLocationBlue.withValues(alpha: 0.15),
                borderColor: _kLocationBlue.withValues(alpha: 0.5),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: fix.position,
              width: 22,
              height: 22,
              child: const _LocationDot(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Blue on a white ring — the same two-layer trick the place pin and the
/// picker's mark use, and for the same reason: raster tiles are busy, and a
/// single-color mark disappears into one of them sooner or later.
///
/// A dot and not a pin, which matters more than it looks: a pin claims the point
/// under its tip and is read as a place somebody chose, while a dot is centerd
/// on its position and is read as a measurement. This map draws both, and they
/// must not be mistaken for each other.
class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: _kLocationBlue,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 2.5),
      ),
    ),
  );
}
