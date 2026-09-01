# geolocator_android — vendored, without Google Play Services

A copy of [`geolocator_android`](https://pub.dev/packages/geolocator_android)
**5.0.3** with the Google Play Services code removed, used by this app in place
of the published package (see `dependency_overrides` in the root
`pubspec.yaml`).

## Why

`geolocator_android` declares `com.google.android.gms:play-services-location`
unconditionally and two of its Java sources import it, so every APK built from
the published package carries proprietary Google code. F-Droid rejects that on
two independent counts: its source scanner matches the Gradle line against a
list of non-free dependencies, and its APK scanner runs `dexdump` and matches
`com/google/android/gms` against the *whole* output — which is why merely
excluding the Gradle group is not enough. That removes the class definitions
but leaves dangling references in the dex constant pool, and those are what
gets flagged.

The upstream escape hatch documented on `AndroidSettings.forceLocationManager`
(`configurations.implementation { exclude group: 'com.google.android.gms' }`)
therefore produces a working APK but not an admissible one, and upstream
declines to make the Play-Services-free path the default — reasonably, since
that would silently change accuracy, battery behaviour and the availability of
the in-app "enable location services" dialog for every app depending on it.
See https://github.com/Baseflow/flutter-geolocator/issues/1481 and /841.

Nothing here is used to avoid a licence: the package is MIT, and `LICENSE` and
`AUTHORS` travel with the copy.

## What was changed

Exactly three edits against the published 5.0.3, and nothing else — no
tidying, no renaming — so the copy stays a readable diff that can be rebased
onto a new release, turned into a fork, or offered upstream. All three are in
Java and Gradle, which `dart format .` never touches; it does cover the five
Dart files under `lib/`, and currently changes nothing in them:

1. `android/build.gradle` — the `com.google.android.gms:play-services-location`
   dependency is gone.
2. `android/src/main/java/.../location/FusedLocationClient.java` — deleted.
3. `android/src/main/java/.../location/GeolocationManager.java` — the two GMS
   imports and `isGooglePlayServicesAvailable` are gone, and
   `createLocationClient` now always returns `LocationManagerClient`. The
   `forceAndroidLocationManager` parameter is kept, because it is what the
   method channel passes; it simply no longer selects anything.

`example/`, `test/` (the Dart tests) and upstream's `analysis_options.yaml` are
not copied: the first two are not part of what a path dependency builds, and the
third is a lint configuration for a package this repository does not lint —
`analysis_options.yaml` at the root excludes `third_party/**`. Leaving it out
also keeps `flutter pub get` from rewriting it, which it does to any package
whose analyzer section has no `exclude:` of its own. The Dart side under `lib/`
is untouched, as is `android/src/test/`.

## What this costs

`LocationManagerClient` is upstream's own code and needs no Play Services: it
prefers `LocationManager.FUSED_PROVIDER` on Android 12 and later, then
`GPS_PROVIDER`, then `NETWORK_PROVIDER`, and requests updates through
`androidx.core.location.LocationManagerCompat`. Below Android 12 there is no
fused provider on a device without Play Services, so a first fix can be slower
and costs more battery. The foreground-service machinery
(`GeolocatorLocationService`, `BackgroundNotification`) is untouched and works
on this path, so recording a track later needs nothing from Google either.

The one feature genuinely lost is the Play Services dialog that switches
location on without leaving the app (`ResolvableApiException`). This app never
used it: `lib/features/map/location/device_location.dart` distinguishes the
three answers itself and offers a button that opens the system screen for the
two that have one.

## Updating

Fetch the new upstream release, diff it against this directory, and re-apply
the three edits above. Most upstream churn is in the half that is missing here,
so this is usually cheap. Keep the version in `pubspec.yaml` equal to the
upstream release the copy is taken from.
