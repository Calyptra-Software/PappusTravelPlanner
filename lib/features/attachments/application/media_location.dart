/// Whether the app may know where a photograph was taken, and whether the user
/// has said it should.
///
/// Two facts, deliberately kept apart, because either alone is the wrong answer:
///
/// * **The platform's** — Android has zeroed a picture's GPS tags on the way to
///   an app without `ACCESS_MEDIA_LOCATION` since version 10, which is why
///   `exifLocationRedacted` exists at all. That is a permission, so it is the
///   system's to grant and to take away again.
/// * **The user's** — a persisted switch, off on a fresh install, which is the
///   whole of the feature's opt-in. It is not derivable from the permission: a
///   grant cannot be handed back from inside the app, so a switch that only read
///   the platform would have no off position short of the system settings.
///
/// The permission is requested on that switch and at **no other moment**, which
/// is the arrangement `device_location.dart` already has for the map's locate
/// button. Nothing here reads the shared collection: the app never enumerates a
/// gallery — that is `READ_MEDIA_IMAGES`, which is deliberately not declared —
/// and asks only about the one file the picker has just handed over.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;

/// What one import may do with the place a photograph carries.
///
/// Three answers and not a bool, because "the switch is off" and "there is no
/// switch" are different states that must behave differently — and because the
/// switch has to be able to say *no* to a position the file is carrying, which
/// is the one thing a bool named "should we try harder" could not express.
enum PhotoPlaceUse {
  /// Nothing on this platform takes a photograph's place out of it and nothing
  /// has to be allowed to read one: the desktop, the web, Android 9 and older.
  /// Whatever the file says is kept, as it always was.
  unguarded,

  /// Allowed and asked for. The position in the file is kept, and one the
  /// picker's copy came without is asked for again by URI.
  allowed,

  /// The switch is off where the switch exists, so **any** position the bytes
  /// turn out to carry is dropped.
  ///
  /// This is the whole of the opt-in, and it has to live here rather than in
  /// what the app asks the platform for. A permission cannot be handed back
  /// from inside an app: once granted it stays granted, and Android then hands
  /// over an unredacted photograph whether or not this app still wants one. So
  /// the switch that reads "off" and a picture that arrives with its place on
  /// it are perfectly compatible — and the only place the user's "no" can be
  /// honoured is the moment the app decides what to keep.
  withheld,
}

/// Where the permission stands, as the platform sees it.
enum MediaLocationAccess {
  /// Not Android, or Android 9 and older: nothing is redacted, so there is
  /// nothing to ask for and no switch worth showing.
  notNeeded,

  /// Granted. Photographs arrive with their position, and one that does not can
  /// be asked about again through [MediaLocationChannel.readLocation].
  granted,

  /// Not granted, and the system will still show the dialog if asked.
  denied,

  /// Refused in a way the system will not ask about again. The only way back is
  /// the app's own page in the system settings, which is why
  /// [MediaLocationChannel.openSettings] exists.
  deniedForever,

  /// There is no bridge on this platform — the desktop and the web, where
  /// nothing was ever taken out of the file.
  unsupported,
}

/// The Android side of the question. See `MediaLocationBridge.kt`.
///
/// A class rather than three loose functions so a test can stand in for the
/// platform (`mediaLocationProvider`), which is the only way any of this is
/// exercised off a phone.
class MediaLocationChannel {
  const MediaLocationChannel([
    this._channel = const MethodChannel('dev.calyptra.pappus/media_location'),
  ]);

  final MethodChannel _channel;

  /// Whether there is a bridge to talk to at all. Checked before every call
  /// rather than caught afterwards: a `MissingPluginException` on the desktop
  /// is a normal state, not an error worth logging on every launch.
  bool get _onAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<MediaLocationAccess> status() => _ask('status');

  /// Shows the system dialog and answers with what the user said.
  ///
  /// Answers immediately with the current state when there is nothing to ask —
  /// already granted, or refused for good.
  Future<MediaLocationAccess> request() => _ask('request');

  /// Opens this app's page in the system settings, the only way out of
  /// [MediaLocationAccess.deniedForever].
  Future<void> openSettings() async {
    if (!_onAndroid) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on PlatformException {
      // A device with no app-details screen. Nothing to do and nothing to say.
    }
  }

  /// Where the camera stood, read from the *original* of the file the picker
  /// handed back under [uri] — the copy it made is redacted whatever this
  /// process holds, so this is the only read that can answer.
  ///
  /// Null for every ordinary failure: a picture with no MediaStore row behind
  /// it, a provider that will not serve the original, a photograph that never
  /// had a fix. The caller already has a sentence for a photo with no position.
  Future<LatLng?> readLocation(String uri) async {
    if (!_onAndroid) return null;
    final Map<Object?, Object?>? answer;
    try {
      answer = await _channel.invokeMapMethod<Object?, Object?>(
        'readLocation',
        {'uri': uri},
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
    if (answer == null) return null;
    final lat = answer['lat'];
    final lon = answer['lon'];
    if (lat is! double || lon is! double) return null;
    // The same two readings `exifPosition` refuses, and refused here for the
    // same reasons: one outside the world, and exactly 0,0 — which is what a
    // camera with no fix writes, and also what a *redaction* leaves behind, so
    // taking it would put every withheld photograph in the Gulf of Guinea.
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    if (lat == 0 && lon == 0) return null;
    return LatLng(lat, lon);
  }

  Future<MediaLocationAccess> _ask(String method) async {
    if (!_onAndroid) return MediaLocationAccess.notNeeded;
    try {
      final answer = await _channel.invokeMethod<String>(method);
      return switch (answer) {
        'granted' => MediaLocationAccess.granted,
        'denied' => MediaLocationAccess.denied,
        'deniedForever' => MediaLocationAccess.deniedForever,
        'notNeeded' => MediaLocationAccess.notNeeded,
        _ => MediaLocationAccess.unsupported,
      };
    } on PlatformException {
      return MediaLocationAccess.unsupported;
    } on MissingPluginException {
      return MediaLocationAccess.unsupported;
    }
  }
}

/// The platform, so a test can be something else.
final mediaLocationProvider = Provider<MediaLocationChannel>(
  (ref) => const MediaLocationChannel(),
);

/// What the platform said at startup.
///
/// Resolved once in `main` and overridden into the scope, the arrangement
/// `bootstrapDbPathProvider` and `appVersionProvider` already have — and here it
/// is not a convenience but the difference between a settings screen that stands
/// still and one that does not. The answer decides whether a whole section is
/// drawn, so fetching it *after* the first frame inserts a section into a list
/// somebody may already be scrolling, and everything below it jumps. A
/// `checkSelfPermission` is a microsecond of work behind one channel hop; paying
/// it before the first frame costs nothing anybody can see.
///
/// Defaults to [MediaLocationAccess.unsupported] rather than throwing, unlike
/// `bootstrapDbPathProvider`: a scope that never said otherwise gets no switch,
/// which is the right answer for every test that merely pumps a settings screen
/// on its way to something else.
final bootstrapMediaLocationProvider = Provider<MediaLocationAccess>(
  (ref) => MediaLocationAccess.unsupported,
);

/// The switch and the permission, side by side.
final class PhotoLocationState {
  const PhotoLocationState({required this.enabled, required this.access});

  /// What the user asked for, remembered across launches.
  final bool enabled;

  /// What the platform says. Known from the first frame — see
  /// [bootstrapMediaLocationProvider] — and re-read whenever it matters, since
  /// a permission can be taken away while the app is running.
  final MediaLocationAccess access;

  /// Whether this platform has the question at all, so the settings screen knows
  /// whether to draw a switch. False on the desktop, on the web, and on Android
  /// 9 and older, where a photograph arrives intact and always did.
  bool get supported =>
      access != MediaLocationAccess.notNeeded &&
      access != MediaLocationAccess.unsupported;

  /// Both halves true: the user wants it and the system allows it. Everything
  /// downstream reads this one flag.
  bool get active => enabled && access == MediaLocationAccess.granted;

  PhotoLocationState _with({bool? enabled, MediaLocationAccess? access}) =>
      PhotoLocationState(
        enabled: enabled ?? this.enabled,
        access: access ?? this.access,
      );
}

/// Whether photographs are attached with the place they were taken.
final photoLocationProvider =
    NotifierProvider<PhotoLocationController, PhotoLocationState>(
      PhotoLocationController.new,
    );

class PhotoLocationController extends Notifier<PhotoLocationState> {
  static const _key = 'photo_location_enabled';

  @override
  PhotoLocationState build() {
    // Both halves synchronously: the switch is ours, and the permission was
    // asked about before the first frame. Nothing about this control arrives
    // late, which is what keeps the settings list from growing a section under
    // a finger already scrolling it.
    return PhotoLocationState(
      enabled: ref.read(sharedPreferencesProvider).getBool(_key) ?? false,
      access: ref.read(bootstrapMediaLocationProvider),
    );
  }

  /// Re-reads the permission. Worth doing before it matters as well as on
  /// build: it can be taken away in the system settings while the app is open,
  /// and Android revokes it by itself on an app that has gone unused.
  Future<MediaLocationAccess> refresh() async {
    final access = await ref.read(mediaLocationProvider).status();
    if (!ref.mounted) return access;
    state = state._with(access: access);
    return access;
  }

  /// Turns it on: asks for the permission, and remembers the switch **only if
  /// it was given**. A switch left on over a refusal would be a control saying
  /// the feature is running when nothing can come of it.
  ///
  /// Returns what the platform answered, so the caller can say the right thing
  /// — and, for [MediaLocationAccess.deniedForever], offer the way out.
  Future<MediaLocationAccess> enable() async {
    final access = await ref.read(mediaLocationProvider).request();
    if (!ref.mounted) return access;
    final granted = access == MediaLocationAccess.granted;
    if (granted) await ref.read(sharedPreferencesProvider).setBool(_key, true);
    if (!ref.mounted) return access;
    state = state._with(enabled: granted, access: access);
    return access;
  }

  /// Turns it off. The permission itself stays granted — an app cannot hand one
  /// back without killing its own process — so this is the switch alone, and it
  /// is what stops the app asking about a photograph's place.
  Future<void> disable() async {
    await ref.read(sharedPreferencesProvider).setBool(_key, false);
    if (!ref.mounted) return;
    state = state._with(enabled: false);
  }

  /// The answer the attachment flow needs, freshly checked.
  ///
  /// Not read straight off the state: the permission may have been revoked in
  /// the system settings since the last look, and an import is about to start.
  /// The platform is asked again unless the answer cannot depend on it.
  Future<PhotoPlaceUse> useForImport() async {
    if (!state.supported) return PhotoPlaceUse.unguarded;
    if (!state.enabled) return PhotoPlaceUse.withheld;
    return await refresh() == MediaLocationAccess.granted
        ? PhotoPlaceUse.allowed
        : PhotoPlaceUse.withheld;
  }
}
