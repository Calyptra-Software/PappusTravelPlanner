import 'app_info.dart';

/// Whether this web build is the side-by-side CI one, set at compile time with
/// `--dart-define=PAPPUS_SIDE_BY_SIDE=true`.
///
/// The one platform where the switch is a define rather than an id: a web app
/// is registered under nothing at all — `PackageInfo` reports the pubspec name
/// from `version.json` — so there is no second fact for the define to
/// disagree with, which is the reason [isCiBuild] avoids one elsewhere.
const bool _sideBySide = bool.fromEnvironment('PAPPUS_SIDE_BY_SIDE');

/// The id the web build answers to: the suffixed one for the side-by-side
/// build, otherwise none, so the caller falls back to `PackageInfo`. See
/// `application_id.dart`.
String? nativeApplicationId() =>
    _sideBySide ? 'pappus$kCiApplicationIdSuffix' : null;
