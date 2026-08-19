/// Where the device says it *is*, as opposed to where the plan says it should
/// be.
///
/// The whole app until now has drawn one kind of position: a coordinate somebody
/// wrote down — picked on the map, or brought back by the router with a
/// connection. This is the other kind, and the difference is worth keeping in
/// mind wherever the two meet: a stored coordinate is a statement, while a fix
/// is a measurement with an error bar that the map has to draw as well as the
/// point (see [DeviceFix.accuracyMeters]).
///
/// Three rules the rest of the feature leans on:
///
/// * **Nothing starts by itself.** The sensor is switched on by a button and by
///   nothing else — no screen asks for a permission because it happened to be
///   opened, and closing the last map that shows the mark stops the stream
///   (`autoDispose`). A map that quietly holds a GPS receiver open is a map that
///   costs battery for a picture nobody is looking at.
/// * **Nothing is stored.** A fix lives in this provider's state and dies with
///   it. It is never written to the database, never put in a `.tpt` bundle, and
///   never sent anywhere — the tile server is addressed by grid square, exactly
///   as it was before.
/// * **A refusal is an answer, not an error.** Declining the permission,
///   switching location off, or having no receiver at all are ordinary outcomes
///   the map must be able to say something about, which is what
///   [LocationProblem] is for. Only genuinely unexpected failures land on
///   [LocationProblem.failed].
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// One reading: where, and how sure.
///
/// The radius is carried rather than dropped because a map drawn without it
/// claims a precision no receiver has — a 300 m fix drawn as a dot is a lie
/// told in the most convincing form available, a small mark on an exact spot.
final class DeviceFix {
  const DeviceFix({required this.position, required this.accuracyMeters});

  final LatLng position;

  /// The 68 % confidence radius the platform reports, in meters. Never negative:
  /// a platform that has no figure reports one, and it is clamped rather than
  /// trusted, since it ends up as a circle's radius.
  final double accuracyMeters;
}

/// Why there is no mark on the map — each an ordinary outcome with its own
/// sentence in the UI, since "no position" alone leaves the user guessing which
/// of four quite different things to go and fix.
enum LocationProblem {
  /// Asked and declined, this once. Asking again is allowed.
  denied,

  /// Declined permanently (or blocked by policy): the platform will not show the
  /// dialog again, so the only way back is the system settings.
  deniedForever,

  /// The permission is there, but location itself is switched off on the device.
  serviceOff,

  /// Anything else — no receiver, no GeoClue on this Linux box, a web page
  /// served over plain HTTP, a timeout. Distinguishing further would mean
  /// guessing at platform error strings.
  failed,
}

/// What the map knows about the device's position right now.
final class DeviceLocationState {
  const DeviceLocationState({
    this.on = false,
    this.locating = false,
    this.fix,
    this.problem,
  });

  /// Whether the user has switched the mark on. Stays true while [fix] is still
  /// null — the first reading can take several seconds, and a button that snaps
  /// back off in the meantime reads as a failure.
  final bool on;

  /// On, but nothing received yet.
  final bool locating;

  /// The last reading, or null while there is none. Cleared when switched off,
  /// which is what lets a listener recognize the *first* fix of a session by a
  /// null-to-non-null transition and center the map on it exactly once.
  final DeviceFix? fix;

  /// Why the last attempt produced nothing. Cleared as soon as another is made.
  final LocationProblem? problem;

  static const off = DeviceLocationState();
}

/// The device's position, off until somebody asks for it.
///
/// `autoDispose`: the subscription ends with the last screen watching it, so
/// leaving the map switches the receiver off. The mark therefore does not
/// survive from one map to the next, which is the honest behavior — it says
/// "this map is showing you live" rather than leaving a stale dot behind.
final deviceLocationProvider =
    NotifierProvider.autoDispose<DeviceLocationController, DeviceLocationState>(
      DeviceLocationController.new,
    );

class DeviceLocationController extends Notifier<DeviceLocationState> {
  StreamSubscription<Position>? _subscription;

  @override
  DeviceLocationState build() {
    ref.onDispose(_cancel);
    return DeviceLocationState.off;
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// On when it is off, off when it is on — the whole of the button's behavior.
  Future<void> toggle() => state.on ? _stop() : start();

  Future<void> _stop() async {
    _cancel();
    state = DeviceLocationState.off;
  }

  /// Switch the mark on: ask for the permission if it has not been given, then
  /// keep the position up to date until it is switched off again.
  ///
  /// The permission is requested **here**, on an explicit press, and nowhere
  /// else. Every failure is turned into a [LocationProblem] rather than thrown:
  /// the caller is a map with a button on it, and there is nothing it could do
  /// with an exception that it cannot do with a sentence.
  Future<void> start() async {
    _cancel();
    state = const DeviceLocationState(on: true, locating: true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _fail(LocationProblem.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      // The permission dialog is a screen of its own and the user may well leave
      // the map behind it, which disposes this provider. Writing state — or
      // starting a receiver — after that is both an error and a leak.
      if (!ref.mounted) return;
      switch (permission) {
        case LocationPermission.denied:
          return _fail(LocationProblem.denied);
        case LocationPermission.deniedForever:
          return _fail(LocationProblem.deniedForever);
        case LocationPermission.always:
        case LocationPermission.whileInUse:
        case LocationPermission.unableToDetermine:
          break;
      }
      _subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Metres of movement before the next reading is delivered. A receiver
          // standing still emits a jittering fix several times a second, and
          // every one of them would redraw a marker layer over a moving map.
          distanceFilter: 5,
        ),
      ).listen(_received, onError: (_) => _fail(LocationProblem.failed));
    } on Exception {
      _fail(LocationProblem.failed);
    }
  }

  void _received(Position position) {
    // A stream that starts delivering after the user switched the mark off (or
    // after the screen went away) must not turn it back on.
    if (!state.on) return;
    state = DeviceLocationState(
      on: true,
      fix: DeviceFix(
        position: LatLng(position.latitude, position.longitude),
        accuracyMeters: position.accuracy.abs(),
      ),
    );
  }

  void _fail(LocationProblem problem) {
    _cancel();
    if (!ref.mounted) return;
    state = DeviceLocationState(problem: problem);
  }
}
