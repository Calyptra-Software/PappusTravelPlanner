/// The id the running application is registered under, where that is not what
/// `PackageInfo` reports.
///
/// On Android `PackageInfo.packageName` *is* the applicationId, so [isCiBuild]
/// reads it from there. On Linux it is not: `package_info_plus` answers with
/// the pubspec's `name` (`travelplanner`), while the id the side-by-side build
/// changes is the GTK application id set in `linux/CMakeLists.txt`. That id is
/// also what `path_provider` and `shared_preferences` key the app's data
/// directory by, so reading it — rather than a second switch beside it — is
/// reading the one fact that actually keeps the two builds apart.
///
/// `nativeApplicationId()` returns that id on Linux and null everywhere else,
/// where the caller falls back to `PackageInfo`.
library;

export 'application_id_io.dart'
    if (dart.library.js_interop) 'application_id_web.dart';
