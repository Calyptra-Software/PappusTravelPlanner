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
/// * **Nothing starts unasked.** The sensor is switched on by the button and by
///   nothing else, and closing the last map that shows the mark stops the
///   stream (`autoDispose`): a map that quietly holds a GPS receiver open is a
///   map that costs battery for a picture nobody is looking at. What the button
///   *said* is remembered, though, and a map opened later puts the mark back on
///   by itself — because the alternative is saying the same thing again on
///   every screen, and somebody switching between a timeline and its map says
///   it a dozen times an hour. Resuming is deliberately the quiet half of a
///   press: it never brings up a permission dialog (a grant already given is
///   used, a missing one simply ends it), it says nothing when it comes to
///   nothing, and it leaves the camera where the screen framed it. So nothing
///   is asked for that was not asked for once, and no screen turns a receiver
///   on for a picture the user never chose to see.
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

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;

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
    this.startedByHand = true,
    this.fix,
    this.problem,
  });

  /// Whether the user has switched the mark on. Stays true while [fix] is still
  /// null — the first reading can take several seconds, and a button that snaps
  /// back off in the meantime reads as a failure.
  final bool on;

  /// On, but nothing received yet.
  final bool locating;

  /// Whether this session began with a press, rather than with the remembered
  /// switch being put back on because a map was opened.
  ///
  /// What reads it is `listenForFirstFix`, and the distinction it draws is the
  /// whole difference between the two: a press is a question — *where am I?* —
  /// and its first answer is worth moving the camera for, while a resumed
  /// session is only the mark being there, and a screen that has just framed
  /// itself on a trip must not be pulled off it by a receiver nobody asked
  /// anything of.
  final bool startedByHand;

  /// The last reading, or null while there is none. Cleared when switched off,
  /// which is what lets a listener recognize the *first* fix of a session by a
  /// null-to-non-null transition and center the map on it exactly once.
  final DeviceFix? fix;

  /// Why the last attempt produced nothing. Cleared as soon as another is made.
  final LocationProblem? problem;

  static const off = DeviceLocationState();
}

/// The device's position, off until somebody asks for it — and on again, by
/// itself, once somebody has.
///
/// `autoDispose`: the subscription ends with the last screen watching it, so
/// leaving the map switches the receiver off. No *reading* survives that — the
/// mark is never a stale dot left behind by an earlier map, it is always this
/// map showing the user live. What survives is the answer to the question, in
/// the preferences, which is why opening the next map costs a fresh fix and not
/// a fresh decision.
final deviceLocationProvider =
    NotifierProvider.autoDispose<DeviceLocationController, DeviceLocationState>(
      DeviceLocationController.new,
    );

class DeviceLocationController extends Notifier<DeviceLocationState> {
  /// The remembered switch. A bool and not an enum because there are two
  /// states: a fresh install has never said anything, which is off.
  static const _key = 'map_show_my_location';

  StreamSubscription<Position>? _subscription;

  /// Which start is the current one. Every [_cancel] invalidates the one in
  /// flight, and a start that has been overtaken must do nothing at all: the
  /// checks it waits on are seconds wide — a permission dialog can be minutes —
  /// and the mark can be switched off in the middle of them. Without this, the
  /// answer arriving afterwards opens a receiver nobody is watching, with the
  /// button reading *off* above it. Rare while a start took a press; now one is
  /// in flight for the first seconds of every map that opens.
  int _generation = 0;

  @override
  DeviceLocationState build() {
    ref.onDispose(_cancel);
    if (ref.read(sharedPreferencesProvider).getBool(_key) ?? false) {
      // Not from inside `build`: the first thing a start does is write state,
      // and a notifier has none until this returns. A microtask is the earliest
      // moment after it.
      Future.microtask(_resume);
    }
    return DeviceLocationState.off;
  }

  void _cancel() {
    _generation++;
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _remember(bool wanted) =>
      ref.read(sharedPreferencesProvider).setBool(_key, wanted);

  /// Switch the mark on because somebody pressed for it.
  ///
  /// The permission is requested **here**, on that press, and nowhere else.
  /// Every failure is turned into a [LocationProblem] rather than thrown: the
  /// caller is a map with a button on it, and there is nothing it could do with
  /// an exception that it cannot do with a sentence.
  Future<void> start() => _run(mayAsk: true, announce: true, byHand: true);

  /// Switch it off, and stop putting it back on.
  ///
  /// Both halves, which is what makes this the opposite of leaving the map:
  /// `autoDispose` stops the receiver either way, and only this says that the
  /// next map should open without the mark.
  Future<void> stop() async {
    _cancel();
    state = DeviceLocationState.off;
    await _remember(false);
  }

  /// Put the remembered switch back on when a map starts watching this.
  ///
  /// Three things a press does that this does not, and together they are the
  /// reason a screen may do it at all: it shows no permission dialog, it says
  /// nothing when it comes to nothing, and it moves no camera. A map that was
  /// opened is not a question; it is a screen somebody happens to be looking
  /// at.
  Future<void> _resume() async {
    // The map may be gone again before the microtask runs — a tap that bounced
    // straight back off the screen, a test that disposed its container.
    if (!ref.mounted) return;
    await _run(mayAsk: false, announce: false, byHand: false);
  }

  Future<void> _run({
    required bool mayAsk,
    required bool announce,
    required bool byHand,
  }) async {
    _cancel();
    final generation = _generation;
    // Switched off, or replaced by a later start, while this one was waiting.
    // Either way it has nothing left to say and nothing left to open.
    bool superseded() => !ref.mounted || generation != _generation;

    state = DeviceLocationState(
      on: true,
      locating: true,
      startedByHand: byHand,
    );
    // Written before the answer is known, failure included: what is stored is
    // that the user wants the mark, and that stays true when the receiver
    // happened to be switched off at the time — which is exactly the case where
    // the next map should try again rather than ask again.
    if (byHand) await _remember(true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (superseded()) return;
        return _fail(LocationProblem.serviceOff, announce: announce);
      }
      var permission = await Geolocator.checkPermission();
      if (superseded()) return;
      if (permission == LocationPermission.denied) {
        // A dialog belongs to the press that asked for it. A resume ends here
        // instead, leaving the button — off, and saying nothing — as the way to
        // bring one up.
        if (!mayAsk) return _fail(LocationProblem.denied, announce: announce);
        permission = await Geolocator.requestPermission();
      }
      // The permission dialog is a screen of its own and the user may well leave
      // the map behind it, which disposes this provider. Writing state — or
      // starting a receiver — after that is both an error and a leak. The mark
      // may equally have been switched off behind it, which `superseded` covers
      // in the same breath.
      if (superseded()) return;
      switch (permission) {
        case LocationPermission.denied:
          return _fail(LocationProblem.denied, announce: announce);
        case LocationPermission.deniedForever:
          return _fail(LocationProblem.deniedForever, announce: announce);
        case LocationPermission.always:
        case LocationPermission.whileInUse:
        case LocationPermission.unableToDetermine:
          break;
      }
      _subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              // Metres of movement before the next reading is delivered. A receiver
              // standing still emits a jittering fix several times a second, and
              // every one of them would redraw a marker layer over a moving map.
              distanceFilter: 5,
            ),
          ).listen(
            _received,
            onError: (_) => _fail(LocationProblem.failed, announce: announce),
          );
    } on Exception {
      _fail(LocationProblem.failed, announce: announce);
    }
  }

  void _received(Position position) {
    // A stream that starts delivering after the user switched the mark off (or
    // after the screen went away) must not turn it back on.
    if (!state.on) return;
    state = DeviceLocationState(
      on: true,
      startedByHand: state.startedByHand,
      fix: DeviceFix(
        position: LatLng(position.latitude, position.longitude),
        accuracyMeters: position.accuracy.abs(),
      ),
    );
  }

  /// Nothing came of it. [announce] is what tells the two callers apart: a
  /// press is owed an explanation, while a resume the user did not make on this
  /// screen has to fail as quietly as it started — a snackbar on every map
  /// opened with location switched off is the sort of help that gets a feature
  /// switched back off.
  void _fail(LocationProblem problem, {required bool announce}) {
    _cancel();
    if (!ref.mounted) return;
    state = announce
        ? DeviceLocationState(problem: problem)
        : DeviceLocationState.off;
  }
}
