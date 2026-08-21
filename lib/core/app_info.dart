/// Who this app says it is when it talks to someone else's server.
///
/// Only the connection search does that at all (`MotisTransportSearch`), and
/// the community-run Transitous instance behind it asks — in its usage policy —
/// that every request carry three things: the application's name, the version
/// of the client, and a way to get in touch. So all three live here, together,
/// rather than as a string constant next to the HTTP call that would quietly
/// go stale.
///
/// Deliberately free of any Flutter or Riverpod import: the client that sends
/// this is plain Dart (`tool/motis_smoke.dart` runs it without a Flutter
/// binding). The *live* version is a startup value, so it lives beside the
/// app's other bootstrap overrides as `appVersionProvider` in `providers.dart`.
library;

/// The application's name, as the service sees it.
///
/// A `User-Agent` product token, so it carries no space — the displayed name
/// is the localized `appTitle`, which is what the About screen shows.
const String kAppName = 'PappusTravelPlanner';

/// How to reach the maintainer, for anything that is not about this client's
/// traffic — the traffic itself is answered by [kAppRepositoryUrl], see
/// [buildUserAgent].
const String kAppContact = 'calyptra-software@proton.me';

/// Where this app's own source lives.
///
/// Not decoration: being an open-source, non-commercial client is a *condition*
/// of using the Transitous API, so the link that proves it belongs in the app
/// and not only in the README.
const String kAppRepositoryUrl =
    'https://github.com/Calyptra-Software/PappusTravelPlanner';

/// Where a user reports something that went wrong. The same repository, one
/// level in — kept beside it so the two cannot drift apart.
const String kAppIssuesUrl = '$kAppRepositoryUrl/issues';

/// What an `applicationId` gains when the build is the one meant to be
/// installed *beside* a real one (`android/app/build.gradle.kts`, the
/// `pappusSideBySide` property).
const String kCiApplicationIdSuffix = '.ci';

/// Whether [packageName] names the side-by-side CI build.
///
/// Derived from the application id rather than carried as a second switch of
/// its own: the suffix is what *makes* a build the CI one, so a `--dart-define`
/// beside it could be set when the Gradle property was not, and the app would
/// then be wrong about itself in the one field a bug report quotes. Only
/// Android has such a build, and no other platform's package name ends this
/// way, so the answer is simply false everywhere else.
///
/// Pure, so the rule is testable without a platform channel.
bool isCiBuild(String packageName) =>
    packageName.endsWith(kCiApplicationIdSuffix);

/// The copyright line shown above the bundled licenses.
///
/// Deliberately untranslated: a copyright notice and a license name are the
/// legal text they are, in the language they were granted in.
///
/// This is also the app's "Appropriate Legal Notices" in the sense of GPLv3 §5:
/// an interactive program has to state the license and the absence of warranty
/// where the user can see it, and point at the terms. The About screen shows
/// this line above the license page and beside [kAppRepositoryUrl], which is
/// where the corresponding source is.
const String kAppLegalese =
    'GNU General Public License v3 or later · no warranty\n'
    '© 2026-present Joshua Lampert and contributors';

/// The `User-Agent` sent with every connection-search request, e.g.
/// `PappusTravelPlanner/1.0.0+1 (+https://github.com/Calyptra-Software/PappusTravelPlanner)`.
///
/// The policy accepts an e-mail address *or* a website URL as the way to get in
/// touch. Now that the repository is public the URL is the better of the two: it
/// leads to the issue tracker, the README and the source that being an
/// open-source client is conditioned on — and it keeps an address out of every
/// line of somebody else's request log. The `+` prefix is the convention a
/// crawler uses for exactly this field.
///
/// Pure, so the format is testable without a platform channel.
String buildUserAgent(String version) =>
    '$kAppName/$version (+$kAppRepositoryUrl)';
