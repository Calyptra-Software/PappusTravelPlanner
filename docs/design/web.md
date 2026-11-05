# Web build

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the web build: database assets, the drift worker, downloads, fonts, self-hosting.

The database layer is split by platform via conditional imports in
`lib/core/database/database_location.dart`: native (`_io.dart`) opens a `NativeDatabase` over
a file path exactly as before; web (`_web.dart`) opens a
`WasmDatabase` (via `drift_flutter`'s `driftDatabase`) backed by browser storage (OPFS,
falling back to IndexedDB) under a name in place of a path (`defaultDatabaseFile`).
`dart:io`/`path_provider` live only in the `_io.dart` branch. Two prebuilt assets in `web/`
are **required** for web, and `tool/build_web_assets.sh` regenerates both from the versions
`pubspec.lock` resolves:

- `web/sqlite3.wasm` — the release asset of the resolved `sqlite3` version from
  `github.com/simolus3/sqlite3.dart/releases` (`sqlite3-<version>/sqlite3.wasm`), unchanged.
- `web/drift_worker.js` — `dart compile js -O4 --no-source-maps` of a one-line entrypoint
  calling `WasmDatabase.workerMainForOpen()` from `package:drift/wasm.dart`, compiled against
  this project's package config so it resolves the drift the app is built with.

The `Build web app` job in CI runs the script and fails on any difference, the rule the
generated Dart sources are held to — a stale pair otherwise keeps working until a protocol
change makes it not, which is how both once fell a release behind unnoticed. The worker is
dart2js output, so a **Flutter upgrade** can fail that check with no package having moved;
the answer is the same, run the script. Measured when it was written: the script reproduced
both committed files byte for byte.

**The web has a side-by-side build too, and its switch is a define.** Browser storage
belongs to the *origin*, so two builds served at one address — the same `localhost` port, a
CI artifact where a release was tried before — share their database, and a schema bump on a
branch migrates it out of the other's reach. `--dart-define=PAPPUS_SIDE_BY_SIDE=true` makes
`nativeApplicationId` (`application_id_web.dart`) report a `.ci` id, so `isCiBuild` holds and
`defaultDatabaseFile` names the store `pappus-ci` (measured in OPFS: `drift_db/pappus-ci`).
That is the second switch `isCiBuild` refuses elsewhere, taken here because there is nothing
for it to disagree with: a web app is registered under no id at all. Different origins never
need it; one origin is the case it is for. The preferences are per origin as well and are
*not* separated, which costs a shared filter or two and no data.

**`-O4`, the level drift compiles its own released worker at, and not a lower one.** drift
reads `navigator.locks` through `LockManager? get locks => _navigator.locks`, while
`package:web` declares that getter non-nullable. At `-O2` dart2js checks the value against
the declared type, which throws where the API is absent, and then removes the `null` check
behind it as dead code. `navigator.locks` is absent in every insecure context, which is any
page served over plain HTTP from anywhere but `localhost` — a phone opening a laptop's
`http://192.168.…:8000`, say. The shared worker then failed to serve the database, reported
it on a port nobody was listening to, and the app waited on a spinner with nothing in the
console. `-O4` omits that check and keeps the `null` test, which is also why `main.dart.js`
(compiled by Flutter at `-O4`) never showed it. Measured in Firefox over a LAN address:
`-O2` hangs before `sqlite3.wasm` is ever fetched, `-O4` opens on IndexedDB. The source
stays fragile at any level that checks interop types; a `has('locks')` test in drift, as
it already does for `storage`, would remove the dependence on the flag.

The web has no filesystem, so the settings screen hides the desktop open/create actions
there, but import/export **are** supported: `DatabaseController.exportBytes` /
`importFromBytes` close the live connection and go through `WasmDatabase.probe` (OPFS grants
exclusive single-handle access, so nothing else may be open). Export reads the stored bytes
via `probe.exportDatabase`; import deletes the store, queues the picked file's bytes via
`webSetPendingImport`, and reopens — drift's `initializeDatabase` hook seeds the fresh store.
`file_picker` yields no path on web, so `_import` reads the picked file through
`PlatformFile.readAsBytes()` rather than off `path` (the older `withData:` flag that used to
pre-load them is deprecated).

**Where those bytes go is a seam of its own** (`core/save_file.dart`, the same conditional
import the database location uses), because `FilePicker.saveFile` cannot be used on the web.
Its web implementation hands the browser a blob and then loses the download two ways: the
anchor it clicks is never in the document, which Firefox does not act on, and the object URL
is revoked in the same turn as the click, before the browser has read the blob. It also
returns `null` whether it worked or not — so the caller cannot tell a save from a
cancellation, and the export said nothing even when it had worked. `save_file_web.dart`
therefore does the download itself: append, click, remove, and free the URL a minute later,
which it must do at all because the blob is a second copy of the whole database in memory.
The answer is a `bool` rather than the `Uri` the native side gets, since the web has no
dialog to wait for and no path to come back with: on the web `true` means *handed over*,
which is everything a page is told. Verifying it needs a browser — `flutter run -d
web-server` — because this file is never compiled by `flutter test`.

**Closing the database is a request on the web, and the answer may never come**, which is
why `DatabaseController._closeLiveDatabase` bounds the wait there and only there. drift
answers a close by shutting the worker down — `server_impl.dart`'s `terminateAll` calls
`shutdown()`, closing the channels the reply would travel on — and `client_impl.dart`
covers that by catching the `ConnectionClosedException` the closing channel is expected to
raise on the pending request. Where none is raised either, the wait never ends: measured
in Firefox, where the export stopped dead with no file, no message and no error, since
every one of `createEmpty`, `importFromBytes` and `exportBytes` closes before it does
anything. What those callers need is not the acknowledgement but that nothing holds the
storage, and probing or deleting it establishes that for itself — so carrying on is safe
and a silent forever becomes a pause. Native keeps waiting, where carrying on early would
mean copying a file that is still open. The trigger was never identified, only the
mechanism and the place; the same export succeeded on a later run with `close()` returning
normally, so this is insurance rather than a cure.

Two things about that browser worth knowing before chasing the next web problem.
`flutter run -d web-server` serves **without** cross-origin isolation, so
`SharedArrayBuffer` is missing and drift picks `opfsShared` (the database in a *shared*
worker) where a deployment sending `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp` would get `opfsLocks`. Development and
production therefore run different storage implementations, and this hang appeared in the
development one. And drift prints the choice itself (`Using … due to missing browser
features: …`) whenever anything is missing, which is the first line to look for.

**The web build talks to a host the others never do: `fonts.gstatic.com`.** CanvasKit
cannot reach the fonts installed on the machine, so for any character the bundled fonts
lack it downloads a Noto slice from Google — measured: the Chinese interface fetches
Noto Sans SC at startup, the English one nothing until an emoji or another script turns
up in the data. `--no-web-resources-cdn` keeps CanvasKit itself local but does **not**
cover this; the URL is `fontFallbackBaseUrl` in the engine's configuration. The native
engines contain no such URL (checked in `libflutter.so` and `libflutter_linux_gtk.so`)
and fall back to the system's fonts. `SECURITY.md` states this as a fact of the web
build, so serving the fonts locally is the change that would have to edit it.

**Roboto is a `fonts:` family, not only a PDF asset, and that keeps the web build off
Google at startup.** Apart from any fallback, the engine adds Roboto from
`fonts.gstatic.com` to every start whose font manifest has no family called exactly
`Roboto` (`if (!hasRoboto) …push("Roboto", fontFallbackBaseUrl + "roboto/v32/…")` in the
engine's font loading, read in `main.dart.js`). Up to 1.14.0 Roboto was bundled only as
raw bytes for the PDF, so by that code every web start, in any language, fetched it; the
"English fetches nothing" measurement above holds only since the family exists. The family in
`pubspec.yaml` (Regular, Medium, Bold, the SDK's files; a test compares them) is what
`SECURITY.md`'s "when text needs them" depends on: renaming it, or moving it into a
package (where it becomes `packages/<name>/Roboto`), brings the request back.

**A release carries the web app for anyone to host** (`pappus-<version>-web.zip`, the
`web` job of `release.yml`), built without the side-by-side define so it keeps the
database name every web install has used. Anyone could already build and host it; the zip
only makes that easy, and `docs/self-hosting.md` is the price of making it easy: what a
host must set up and what they take on. One consequence lands here rather than with the
host: Firefox delivers the app's `User-Agent` to Transitous, so a stranger's instance
searches under this project's name and repository URL. Its `Referer` tells the two apart,
and the policy asks that host for contact details of their own, which is why the docs say
so. The two instructions in those docs were measured before they were written, not taken
from Flutter's documentation: editing `<base href>` alone serves the app from a path
(everything, `sqlite3.wasm` and the worker included, loaded under `/pappus/`), and
`config: { fontFallbackBaseUrl: … }` in `flutter_bootstrap.js` moves every fallback-font
request off Google. With nothing at that path the requests 404, the characters draw as
boxes, and the engine gives up retrying after a handful of failures. Neither edit survives
a rebuild, so if the docs ever promise more than a hand edit, they have to say which build
flag does it.
