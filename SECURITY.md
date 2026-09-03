# Security Policy

## Reporting a vulnerability

Please don't open a public issue for something that could be used against people
before there is a fix. Two private routes:

- **GitHub** — the *Report a vulnerability* button on this repository's
  *Advisories* page, under the security tab.
- **E-mail** — calyptra-software@proton.me.

Either is fine; the first keeps the discussion attached to the repository. Say
what you did, what happened, and what you expected instead — a crafted file, a
link, or a request that triggers it is worth more than a description of it.

This is a spare-time project, not a company with an on-call rotation. You should
have an acknowledgement within a week. If you don't, assume the mail went astray
and try the other route rather than assuming you are being ignored.

## Supported versions

The most recent release, and only that one. There is a single line of releases
and no maintenance branch behind it: a fix ships as a new version rather than as
a patch to an old one. The version string is on the *About* screen — it is the
first thing worth putting in a report, because it names the build exactly
(e.g., `1.4.0+5`, build number included).

## What this app actually exposes

Worth stating plainly, because the attack surface of an offline app is small but
not empty:

**It reads files it did not write.** Through a file picker or the share sheet:

* A `.tpt` trip bundle, parsed by `TripBundle.fromJson`
  (`lib/features/sharing/trip_bundle.dart`).
* A `.gpx` track, parsed by `parseGpx` (`lib/features/map/gpx.dart`) using the
  `xml` package, and stored as packed coordinates — the file's markup is never
  kept and never re-read. A bundle may also carry an already-packed line, which
  `decodeTrackPoints` (`lib/data/database/track_points.dart`) reads back and
  which is therefore held to the same standard as the file it came from.
* **Images**, attached to part of a trip: decoded, scaled and re-encoded to JPEG
  by the `image` package (`lib/features/attachments/attachment_import.dart`).
  Identifying the format means offering the bytes to every decoder that package
  has, which is the widest piece of foreign-format parsing in the app.
* **Any other file**, attached the same way and stored byte for byte, up to a
  size limit. It is never parsed — the app has no reading for it and hands it
  back to the operating system unchanged when it is opened or shared.

A malformed file of any kind should produce a clean refusal and nothing else.
Anything beyond that — a crash that leaves the database inconsistent, an import
that writes outside the trip it was told to create, a value that ends up
somewhere it is not escaped — is worth reporting.

**It keeps attached files inside the database**, not beside it, so everything
already true of that file is true of them: see *The database is not encrypted*
below.

**It reads one thing out of a photo, and drops the rest.** A picture attached
through *Add photo* has its EXIF searched for the position the camera recorded,
which is lifted into a field of its own — visible in the attachment's sheet, and
clearable there. Everything else EXIF can hold (the camera body, the serial
number, the moment it was taken) does not survive the re-encoding and is not
stored anywhere. That is a deliberate reduction and not an accident of the
format: `attachment_import.dart` clears the metadata before writing, and there is
a test standing on it. Such a photo leaving the app again — through the share
sheet — carries the position only in the sense that the app knows it; the bytes
handed out are the stripped ones.

On **Android** there is usually nothing to read, and putting it back is a switch
the user throws. Since Android 10 the system zeroes the coordinates in a
photograph before handing it to an app that does not hold
`ACCESS_MEDIA_LOCATION`. That permission is now declared, and *Read where a photo
was taken* in settings is the only thing that ever asks for it — off on a fresh
install, and off is exactly the behavior described above: the photograph is
attached without a position, and the app says so rather than leaving it
unexplained.

With the switch on, the position the file carries is kept — and a photograph
that arrives without one is asked about a second time, by the URI the picker
handed over, against the original the system will serve to a process holding the
permission (`MediaStore.setRequireOriginal`, in `MediaLocationBridge.kt`). Two
numbers come back across that channel and nothing else: the picture that is
stored is still the re-encoded, EXIF-stripped copy, and the position still lands
in the column it has always landed in, visible in the attachment's sheet and
clearable there. The file chooser is the same one either way.

**Switching it off again is enforced by the app, because it cannot be enforced
by the system.** An Android permission cannot be handed back from inside an app:
once granted it stays granted until it is revoked in the system settings, and
the system goes on handing over unredacted photographs in the meantime. So with
the switch off the app **drops** whatever position the bytes turn out to carry,
rather than merely declining to ask for it — otherwise the control would read
"off" while the coordinates went on being stored. Switching off says this, and
offers the system screen where the grant itself can be taken away.

What the permission is **not** used for is worth saying, because its name is
broader than this use of it. The app does not enumerate the shared collection —
that would be `READ_MEDIA_IMAGES`, which is deliberately not declared — and asks
only about a file the user has just picked, one at a time, while the import is
running. The grant taken on that file is transient and never persisted, so the
app holds no standing access to anyone's photo library.

**A file attached through *Add file* is kept exactly as it arrived, metadata and
all** — including one that happens to be a picture, which is a thing people do
deliberately with a ticket sent as a `.png`. Nothing is re-encoded there and so
nothing is stripped: whatever EXIF the file carries stays in it, is stored, and
travels in a `.tpt` bundle. That is what filing something as a document means,
and it is the user's choice which of the two doors a file comes through. Such a
file is never given a position of its own and never appears on the map.

**It opens databases it did not create.** On desktop the settings screen will
point the app at any `.sqlite` a file picker hands back, and the app writes to
it. The header check (`kApplicationId`) is a sanity check, not a security
boundary.

**It parses replies from two network services.** The connection search talks to
`https://api.transitous.org` (`lib/features/transport_search/data/motis_client.dart`),
and the map fetches tile images from `https://tile.openstreetmap.org`
(`lib/features/map/basemap.dart`). A hostile or compromised reply should not be
able to do more than produce a wrong or empty result, or a wrong picture.

**It accepts deep links.** `pappus://trip?id=N`, used by the Android home-screen
widget to open a trip.

**It reads the device's position, on request.** A map's locate button starts the
platform's location service and stops it again when the map is closed. The
reading is held in memory for as long as it is on screen — it is not written to
the database, does not go into a `.tpt` bundle or any other export, and is not
sent anywhere. See *What is deliberately not a vulnerability* below for what the
tile server does and does not learn from it.

## Verifying a release

Every APK released here is signed, and the SHA-256 fingerprint of the signing
certificate is what identifies it as one of ours:

    1.11.0 and later      5bb5d79192cca90b847d80924e859762fc269f7e1e9fd35d5f71c398ec355fcb
    1.10.0 and earlier    a2568e7004c1c365c7dfeba050112f3ecf844de4c1973806653f3d5790d70e44

To check a file against one of them:

    apksigner verify --print-certs app-arm64-v8a-release.apk

Look for the line ending in `certificate SHA-256 digest`; what precedes it
differs between versions of the tool.

There are two fingerprints because the key was changed once, deliberately, with
1.11.0 — which is why that release had to be installed fresh rather than over
its predecessor. The older certificate is named `CN=Android Debug`, and that is
not what it looks like: it was the key Android generates for debug builds, kept
and used for release builds from the app's first day. Replacing it is what the
change was for. It says nothing about how those APKs were built, and they are
what they claim to be.

Android enforces the fingerprint by itself on every update — a build signed with
a different key is refused rather than installed — so checking it by hand is for
the *first* install, and for any copy that did not come from this repository's
releases page.

It is not the same number as the file hashes published alongside a release in
`SHA256SUMS.txt`. Those are hashes of the APK files: they differ from release to
release and answer whether a download arrived intact. The fingerprints above do
not change, and answer who signed it.

## What is deliberately not a vulnerability

**The database is not encrypted.** It is an ordinary SQLite file, and being able
to copy it, open it, back it up, and carry it to another machine is the whole
premise of the app. Anyone who has the file has the trips in it. If that matters
for your threat model, the answer is disk encryption underneath, not something
this app can add on top without giving up what it is for.

**The exports are plaintext too** — `.tpt`, `.ics` and the PDF are all meant to
be handed to other people and other programs. An attachment handed to the share
sheet is likewise a plain copy of the file, for whichever program the user picks.

**Attachments travel with a shared trip.** A `.tpt` bundle carries every photo
and file on the trip, Base64-encoded — it is the one lossless export, and an
attachment exists nowhere but in the database, so a bundle that named one
without carrying it would be handing over a broken reference. A photo's stored
*position* travels with it, which is worth knowing before sharing: the EXIF the
camera wrote is gone, but where it was taken is a column of the row, shown in
the attachment's sheet and clearable there. The PDF prints pictures only when
that section is ticked, and it is off until someone ticks it.

**There are no accounts and no server of ours.** Nothing to authenticate to,
nothing held anywhere but on your device.

**The connection search tells Transitous what it must.** A place query, a date,
and a time go to the routing service, along with a `User-Agent` naming the app
and linking this repository — its
[usage policy](https://transitous.org/api/) asks for exactly that. Searching a
connection without telling anyone where and when you want to go is not a thing
that can be built.

**The map tells OpenStreetMap which tiles it is looking at.** Opening a trip's
map requests the image tiles covering it, which means the tile server sees the
area you are looking at, along with a `User-Agent` naming the app and its
version — the [tile usage policy](https://operations.osmfoundation.org/policies/tiles/)
requires that identification. Tiles are cached, so panning back over ground
already seen asks for nothing. No coordinate of yours is ever *sent*: a tile is
addressed by a grid square, and which entries of your trip sit inside it is
something only your device knows.

**The map can show where you are, and tells nobody.** Pressing the locate button
asks the platform for the device's position; the mark it draws is the only thing
that happens with the answer. It is never stored and never transmitted — and in
particular it is not what the map is fetched with: a tile is addressed by grid
square, exactly as it is when the mark is off, so centering on yourself asks for
the same tiles as panning there by hand would. Nothing on the device is followed
in the background either: the request has no `ACCESS_BACKGROUND_LOCATION` behind
it, and the receiver is released when the map goes away.

**Attaching a file asks for no permission** — with the one exception above, and
only once it has been switched on. The picker runs in the system's own process
(the Storage Access Framework on Android, the platform file chooser elsewhere)
and hands back one file the user chose. The app never enumerates a gallery or a
directory, and there is no camera capture.

**Nothing else leaves the device.** There is no analytics, no crash reporting,
and no telemetry of any kind, and the Android build declares four permissions:
`INTERNET`; `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`, asked for only
when the locate button is pressed; and `ACCESS_MEDIA_LOCATION`, asked for only
when *Read where a photo was taken* is switched on in settings. The two location
permissions are both declared so that the system dialog can offer the choice
between an exact and an approximate position; the app works either way. The media
one is granted to nobody until it is asked for, and the app works without it — a
photograph simply attaches without the place it was taken.

The Android build also links **no Google Play Services code at all**. Positioning
goes through Android's own `LocationManager`, using a copy of the `geolocator`
Android plugin with the Play Services client removed
(`third_party/geolocator_android`). It is checkable rather than a claim: the
release APK's dex holds no reference to `com/google/android/gms`, and the
resolved Gradle runtime classpath names no `play-services` artifact.

## What happens after a report

I will confirm what you found, or explain why I think it does not hold. If it
does, the fix goes out in a release and the advisory says what was wrong and
which versions were affected. Tell me how you would like to be credited, or that
you would rather not be — either is fine, and neither is a condition.
