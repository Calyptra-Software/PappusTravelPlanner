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
const String kAppName = 'TravelPlanner';

/// How to reach the maintainer about this client's traffic.
///
/// The policy accepts an e-mail address *or* a website URL; this is the former
/// while the repository is still private. When it goes public the URL is the
/// friendlier of the two — but one of them must always be here, since it is
/// how Transitous would tell us about a breaking change or a request pattern
/// that is costing them too much.
const String kAppContact = 'lampert.joshua@protonmail.com';

/// Where this app's own source lives.
///
/// Not decoration: being an open-source, non-commercial client is a *condition*
/// of using the Transitous API, so the link that proves it belongs in the app
/// and not only in the README.
const String kAppRepositoryUrl =
    'https://github.com/JoshuaLampert/TravelPlanner';

/// Where a user reports something that went wrong. The same repository, one
/// level in — kept beside it so the two cannot drift apart.
const String kAppIssuesUrl = '$kAppRepositoryUrl/issues';

/// The copyright line shown above the bundled licenses.
///
/// Deliberately untranslated: a copyright notice and a license name are the
/// legal text they are, in the language they were granted in.
const String kAppLegalese =
    'MIT License · © 2026-present Joshua Lampert and contributors';

/// The `User-Agent` sent with every connection-search request, e.g.
/// `TravelPlanner/1.0.0+1 (lampert.joshua@protonmail.com)`.
///
/// Pure, so the format is testable without a platform channel.
String buildUserAgent(String version) => '$kAppName/$version ($kAppContact)';
