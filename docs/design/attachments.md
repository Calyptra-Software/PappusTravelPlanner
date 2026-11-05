# Attachments, photos and the gallery

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for attachments, EXIF and media location, photos on the map, the gallery, cover photos, documents.

- **An attachment's bytes live in the database, and that is the whole design.**
  `Attachments` + `AttachmentBlobs` (v32, trip level v33) hold a photo or a file hung on
  part of a plan.
  Not a sidecar directory: one portable SQLite file is what the app *is*, and an
  attachment kept beside it would mean every copy, backup and export that has ever
  worked silently stops carrying everything — the file would go on claiming to be the
  whole trip, and on Android and the web there is no second path to point at anyway.
  The price is paid on the way in: `attachment_import.dart` (pure) re-encodes a photo to
  `kMaxPhotoEdge`/`kPhotoQuality` with a thumbnail beside it, and caps a document at
  `kMaxAttachmentBytes`. The ceiling being defended is not disk space — it is that
  `readDatabaseBytes` reads the *whole* database into memory to export it, so an
  unbounded photo library costs the user the ability to move their trips off the device.
  The payload is a **second table** because drift selects every column of the table it
  is given: listing what a day carries must not be reading it.
- **It hangs on exactly one of an item, a group, or the trip**, the way a `Costs` row does
  and for the same reason — a ticket covers the run and not one leg of it, and a passport
  scan belongs to the journey and not to Tuesday's train. Both cascade (unlike
  `ItineraryItems.groupId`, nulled on dissolve: an item outlives its group, an
  attachment of that group does not), and the invariant lives in `AttachmentDao._owner`
  since SQL cannot state it. The run's are reached from the ⋮ menu on the group band,
  where everything whose unit is the run already is; an entry's from its own form, below
  the note, and — like `TrackField` — only on an entry that **already exists**, since a
  file hangs off a row. The trip's are a **section on the trip screen**
  (`TripAttachmentsSection`, above the checklists), and that placement is the decision:
  an entry's and a run's announce themselves with a badge on the timeline row they hang
  on, the trip has no row, so a file filed at that level appears nowhere unless the screen
  shows it — behind a menu it would be the insurance nobody can find in the one situation
  it exists for. It collapses to a single button while there is nothing, since there is
  nothing to say about no files.
- **The trip level is the one that travels when a routine is stamped out.**
  `AttachmentDao.copyTripAttachments`, called from `materializeRoutine` and the reversed
  duplicate and — like `copyItemTracks` — from nowhere else. Everywhere else a copy takes
  the plan and not the record, which is why an entry's photograph of last Tuesday's
  platform stays behind; a file on the *trip* of a routine is the template's own paperwork
  (the season ticket, the pass), and one that had to be re-attached every morning would be
  missing by Thursday — the reasoning that already sends the checklist, the tags and the
  fare across. The rule is by **level, not by kind**: a scanned receipt and a season ticket
  are both documents and the app cannot tell them apart, while where the user *put* the
  file is a decision they made and reads as one. On the map a trip-level photo is always
  drawn (no option it could sit in, nothing that could stop being chosen) and wears the
  trip's accent, having no entry to take a color from. `watchAttachmentCountsForTrip`
  deliberately leaves it out: those two maps feed the badges on entries and runs, and there
  is no timeline row to put one on. `replaceJourneyLegs` **rescues** them exactly as it rescues the
  fare: parked owner-less for the length of the transaction, then re-homed onto the
  surviving group or the replacement's first leg. Looking a connection up again is not a
  reason to lose the photo of the ticket. **Dissolving** a group rescues them the same way
  (`GroupDao._preserveSharedThings`, which the degenerate-group tidy-up goes through too):
  ungrouping is advertised as the harmless half of deleting, so the entries stay and what
  they paid for stays with them — the fare and the ticket are the same thing said twice,
  and for a while only one of them was kept. `deleteGroup` is the other way round and
  deliberately so: nothing survives to carry them.
- **A photo keeps one thing out of its EXIF and loses the rest.** The position is lifted
  into `Attachments.lat`/`lon` with an `AttachmentPositionSource` beside it, and the
  re-encoding drops everything else — deliberately, with `full.exif = ExifData()` doing
  it and a test standing on it, because the resize *copies* the metadata and without that
  line the camera body and serial number would ride into every `.tpt` and PDF. Reading
  EXIF is not a breach of *a position is pointed at, never derived*: that rule is about
  turning a **name** into a place, and nothing is inferred here — the file says where the
  camera stood. But a camera's fix and a user's tap are not the same claim, so the
  provenance is stored and shown, `0,0` is refused (a camera with no fix writes zeros),
  and the position is never inherited from the entry it hangs on — that entry already has
  a pin, and a second one would be the app claiming to know where a picture was taken.
- **On Android there is usually no position to read, and the app says so rather than
  going quiet.** Since Android 10 the system removes `GPSLatitude` and `GPSLongitude`
  from a photograph handed to an app that does not hold `ACCESS_MEDIA_LOCATION` — which
  this one does not. `file_picker` asks with `ACTION_GET_CONTENT` and copies the answer
  through a plain `contentResolver.openInputStream`, so what reaches `prepareAttachment`
  is already stripped: the same file read on Linux yields a position and on Android
  yields none, which is exactly how this was found. Nothing in the Dart is wrong, and no
  amount of testing it would have shown this.
  What the app can do is tell the two silences apart, and **how** is worth writing down
  because two plausible guesses about it were both wrong before the bytes were looked at.
  Android does not rewrite the file and does not remove the tags: measured on a real
  photograph, the copy that comes back is byte-for-byte the same length as the original
  and differs in exactly **32 bytes**. Every GPS tag survives with its value overwritten
  by zeros. So the state to recognize is not an absence but a zero that is too complete —
  coordinates that are present and read as `0, 0`, beside hemisphere refs that are present
  and say nothing. `exifLocationRedacted` tests exactly that pair, and `addAttachments`
  reports it, ahead of the plain "N files attached" and behind a refusal.
  The **ref** is what carries the signature, not the coordinates, and that is forced
  rather than chosen: zeroed bytes read back as rationals of `0/0`, which would say it
  directly against a camera's `0/1` — but the decoder hands GPS coordinates back as
  `IfdValueSRational`, which does not override `toRational`, so the base class answers a
  flat `0/1` for every part and the distinction is gone before any of our code sees it.
  `toDouble` flattens it the same way. The letter a camera always writes, and the zeroing
  always takes, is what survives intact. A camera that genuinely stood on Null Island is
  therefore still not redaction: `exifPosition` refuses its `0, 0` on its own account,
  and its refs still say `N` and `E`.
  Both doors redact, so no *picker* fixes this by itself: *Add photo* goes out as
  `ACTION_GET_CONTENT` and *Add file* as `ACTION_OPEN_DOCUMENT`, and the round trip
  through the second is how the bytes above were obtained — SAF returned them zeroed
  too. What lifts it is the permission below, and the choice of door then matters for a
  different reason.
- **Lifting the redaction is a switch, and it costs the picker people know.**
  `ACCESS_MEDIA_LOCATION` is declared and asked for at exactly one moment — *Read where a
  photo was taken* in settings — which is the arrangement `device_location.dart` already
  has for the locate button. Two facts are deliberately kept apart in
  `media_location.dart`: the **permission**, which is the system's to grant and to take
  back, and the **switch**, which is persisted and is the whole of the opt-in. Neither
  alone is the answer — a grant cannot be handed back from inside an app, so a control
  reading only the platform would have no off position short of the system settings; and a
  stored bool alone would go on claiming the feature runs after the permission was revoked,
  which is why the tile shows `active` (both halves) and why `activeNow()` re-asks the
  platform before every import rather than trusting what was stored.
  **Off is enforced on what is kept, not on what is asked for**, and that is the part that
  is not obvious. A permission cannot be handed back from inside an app: once granted it
  stays granted, Android goes on handing over unredacted photographs, and the switch would
  read "off" while the coordinates went on arriving — measured on a phone, which is how it
  was found. So `useForImport` answers with three states rather than a bool
  (`PhotoPlaceUse`): `allowed` keeps the position and asks for one that is missing,
  `withheld` **drops** whatever the bytes turn out to carry, and `unguarded` is every
  platform where nothing was taken out of the file in the first place and the switch that
  does not exist may not withhold anything either. `PreparedAttachment.withoutPosition` is
  where the user's "no" actually lands. The tile says as much in its subtitle, and switching
  off offers the system screen, since the grant itself can only be revoked there.
  The **chooser does not change**, and the history is worth keeping because the reasoning
  was good and the fact was wrong. `FileType.image` goes out as `ACTION_GET_CONTENT`, which
  Android has taken over with its own photo picker, and that picker was reported to strip a
  picture's coordinates unconditionally; the door therefore switched to `FileType.custom`
  over `_photoExtensions` (`ACTION_OPEN_DOCUMENT`, the file browser) whenever a position was
  wanted. On a real device with the permission granted, a photograph picked through the
  *photo picker* arrives with its place on it — so that trade gave up the familiar chooser
  for nothing, and is not made. A report is not a measurement. Where a device does redact
  anyway, the second reading answers: the picker's copy of the bytes carries no coordinates,
  so the URI is asked about again — `MediaStore.getMediaUri` (a SAF document URI) else the
  URI itself (the photo picker's own, already MediaProvider's), then `setRequireOriginal`,
  in `MediaLocationBridge.kt`. Where that fails too, the app says the position was withheld,
  which is the honest end of it.
  Three boundaries hold the second reading to the one file: the URI reaches Dart only as
  `AndroidPlatformFile.safHandle` (hence `android_file_picker` as a direct dependency, and
  hence `PickedAttachment` being a class — a record has no field to leave out), the grant
  is `transient` and never persisted, and **only two numbers come back** — the stored
  picture is still the re-encoded, EXIF-stripped one, so what the permission changes is
  what the app *knows* and not what it keeps. `READ_MEDIA_IMAGES` is deliberately not
  declared: the app has never enumerated a gallery and this does not start. The second
  reading is asked only when the first found nothing, which also means a photograph that
  genuinely never had a fix costs one header read to say so. Everything about this is off
  on a fresh install and absent entirely below Android 10 (`PhotoLocationState.supported`),
  where nothing was taken out of the file in the first place — a switch offering to turn on
  what is already on is a control that does nothing. That last answer is resolved in `main`
  and overridden in (`bootstrapMediaLocationProvider`), beside the database path and the
  version, and here the reason is visible rather than merely tidy: it decides whether a
  whole **section** of the settings list is drawn, so fetching it a few frames in inserts
  that section into a list somebody is already scrolling and everything below it jumps. A
  `checkSelfPermission` before the first frame costs nothing anyone can see. `activeNow()`
  still re-asks the platform before every import, because a grant can be taken away while
  the app is running — what is bootstrapped is the *first* answer, not the only one.
- **A photo is on the map when it carries a position, and never otherwise.**
  `MapPhoto` (`map_features.dart`) draws the stored **thumbnail**, framed in the owning
  entry's color — which is why one is kept beside every picture. Falling back to the
  entry's own coordinates was never on: the entry already has a pin there, and a second
  one would be the app claiming to know where the picture was taken, the same rule that
  keeps a one-ended leg off the map. Which photos may be drawn is decided in **Dart**, by
  `_photoMarkers`, and deliberately *not* in SQL as `TrackDao` does it: the answer is "is
  its owner part of the plan", which `live_items.dart` already owns, and
  `watchPositionedPhotosForTrip` would only be a second copy of it. It does not own that
  answer either — it asks `tripGallery` and keeps what has a position, so the **order** and
  the live rule arrive together from the one place that decides them. Walking the rows as
  the query returned them (by their own sort order, which is the order they were attached)
  put a different picture at the front of a cluster than the one the gallery opens on, and
  those two are meant to be the same photograph — the third time that ordering had been
  rebuilt elsewhere and drifted. A run's photo rides on any live member (a group lies
  wholly inside one option or wholly outside every one) and takes no color, since a group
  has none. Photos are framed
  with everything else by `allPoints` — one taken a valley over is exactly what a viewport
  fitted to the plan would cut off. They sit in a layer **above** the plan and below the
  device's mark, and never wear the reserved red: a photograph records a moment that has
  passed, so it is never "under way". The all-trips map does not draw them.
- **Photographs that would hide each other are gathered, and gathered in pixels.**
  `clusterPhotos` / `PhotoCluster` (`features/map/photo_clusters.dart`, pure like everything
  else the map draws from) groups the markers within `kPhotoClusterRadius` of each other and
  draws one thumbnail with a count. The distance is measured on the **screen**, through the
  camera's own projection handed in as a function — not in degrees and not in metres: two
  pictures taken in the same square metre overlap at every zoom until the map is scaled
  enough to separate them, so a threshold in metres would either group them forever or never,
  while this one comes apart as you zoom in. The radius is a little wider than a marker, on
  the grounds that a picture half behind another is worse than a count.
  Two properties are load-bearing. The grouping is **greedy from the first photograph
  onwards** and each candidate is measured against the one that *started* the cluster rather
  than against whatever joined it last, because chaining would let a line of pictures a
  screen wide collapse into a single mark. And because the answer depends only on the order
  it is given, and that order is the gallery's, a cluster keeps the **same face** while the
  camera moves instead of changing which picture it shows every time the map shifts by a
  pixel — which is also what makes the front of a cluster the picture the gallery opens on.
  The mark sits on the representative's **own** position, never the middle of the group:
  this app does not put a mark where nothing is, and the others are a thumb's width away in
  any case. A tap opens the **gallery**, however many pictures the mark holds. It used to
  answer by size — one picture opened `AttachmentSheet`, several the gallery — but what a
  mark holds is a matter of zoom, so the same photograph opened two different things
  depending on how far out the map was, and a lone picture was stuck at a third of the
  screen when seeing it was what the tap was for. The sheet, with the position controls,
  is still one tap away behind the gallery's ⋮.
- **A `.tpt` carries the bytes, Base64-encoded, and does not bump the format version.**
  It has to carry them: an attachment exists only inside the database, so naming one
  without it would hand the recipient a reference to a file on somebody else's phone, and
  `.tpt` is the one lossless export. The version stays where it was by the rule already
  stated for coordinates and tracks — a version marks a shape an importer must *branch* on,
  and an older app that ignores `attachments` imports exactly the trip it would have anyway.
  The thumbnail travels too rather than being rebuilt: the importer would otherwise decode
  and rescale every picture of the trip on a device that has just been handed a file.
  `byteSize` is **measured on arrival**, never read from the file — a number the sender
  could contradict is a number not to trust — and a row whose Base64 will not decode is
  skipped rather than failing the import, the trade the unreadable track already makes.
- **Photos are a PDF section, and the one a fresh install leaves off.** Hence
  `kDefaultPdfSections` beside `kAllPdfSections`: every other section costs a few kilobytes
  of text and this one can turn a two-page itinerary into a document too large to mail, so
  it is asked for rather than assumed. The picker names the **size** next to the count for
  exactly that reason — "12 photos" invites a tick, "12 photos · 4.1 MB" invites a decision.
  Each picture is embedded at the size the app stored it: making a third size at export time
  would mean decoding and rescaling every one on a phone, to save megabytes in a document
  whose cost the user has already been shown and accepted. Documents are not printed at all —
  a PDF cannot hold a PDF, and printing a ticket's *name* would be a list of files the
  reader does not have.
- **A picture the decoder cannot read is refused, not stored raw.** HEIC/HEIF is the case
  that matters, and keeping it as an opaque document would break all three rules above at
  once — unbounded size, no thumbnail, EXIF intact — silently. The probe itself is wrapped
  in a catch-all: identifying a format means offering the bytes to every decoder in turn,
  and four bytes of nothing is enough to walk one off the end of its buffer.

- **A trip's photographs are also a set, and the set is read as a gallery.**
  `tripGallery` (`features/attachments/trip_gallery.dart`, pure — the sibling of
  `map_features.dart`) orders them: the **trip's own first**, since the insurance and the
  printed map are about the journey rather than a day of it, which is the order the PDF
  already prints in, then everything else in timeline order, with a run's own sitting at
  its first member. The live rule is applied here in Dart against the entries the screen
  holds, for the reason `_photoMarkers` does it there: `live_items.dart` owns that
  definition and a query would hold a second copy. Each page carries the **label of the
  entry it hangs on** — the one thing a single picture never needs and twenty in a row
  cannot do without, or they are a pile of photographs with a trip somewhere behind them.
- **The way in is a thumbnail strip, not an app-bar icon.** That bar is three icons and an
  overflow and says in its own comment that a fourth leaves no room for the title, and the
  overflow is for what a trip is *done to* rather than a way of looking at it. `TripPhotoStrip`
  costs no bar space, is visibly there, and hands the gallery the picture that was tapped;
  it is absent when the trip has none. It **collapses**, and remembers, the way a checklist
  and a day do — a band of thumbnails is the heaviest thing on that screen and a trip with
  two hundred photographs should not have to be scrolled past to read the plan. The state
  is a column on the trip's own row (`Trips.photosCollapsed`, v34) rather than a table:
  `CollapsedDays` is one because a trip has many days, and this is one per trip. In the
  database rather than in preferences, because it is per-trip state and belongs to the file
  the trip lives in — so it travels in a `.tpt` too, as a checklist's collapsed state and
  the collapsed days already do. The count stays in the header while folded: a collapsed
  section that says nothing about what is inside it is a row with no reason to be tapped. This is not the rule against thumbnails *in the
  timeline*: there a picture would displace the entry it hangs on, here the photographs are
  the subject. Elsewhere the rule is **a photo opens the gallery, a document opens the
  sheet**, the map included.
- **The gallery is a reading.** Swiping browses and writes nothing (the `AlternativeCard`
  rule), and the four acts stay in `AttachmentSheet` behind the ⋮ — two places holding the
  delete confirmation means one of them going stale, the same reason `MapItemSheet` hands
  editing back to the item form. Pages decode through the `autoDispose`
  `attachmentBytesProvider` and a `PageView` builds lazily, so two hundred photographs cost
  three in memory. Zoom and page-turn are one gesture, so the page is **locked while
  magnified** (`_zoomed`, compared against `> 1.01` because a pinch back out settles on
  1.0000001 and an equality test would lock the page for good).
- **A swipe is a finger's way of turning a page, and a desk has neither.** A trackpad's
  two-finger swipe reaches a `PageView` as a scroll of whatever distance the fingers
  travelled, and a page settles on the next one only past half a screen or on enough
  velocity — so on a laptop it lands back where it started more often than not. That is
  Flutter's behaviour, not something this screen can repair, so the gallery offers the two
  controls a desk does have: the **arrow keys** (a `CallbackShortcuts` over an autofocused
  `Focus`, which works wherever there is a keyboard and shows nothing), and two **chevrons
  a mouse reveals**. `MouseRegion`'s hover is the honest way to ask whether there is a
  pointer, rather than reading the platform and guessing at it: a finger cannot hover, so
  on a phone they never appear, over a gesture that already works there. Both obey the
  rules the swipe obeys — nothing turns while a picture is magnified — and neither is
  offered where it would lead nowhere: no way back from the first picture, none on from the
  last, the rule the journey preview's confirm button follows. Drawn ink-on-scrim like the
  map's marker and for the same reason: what they sit on is a photograph, and a control
  tinted by the scheme is invisible over half of them.

- **A trip's overview card shows one photograph, and which one is three states.**
  `coverPhoto` (in `trip_gallery.dart`, pure) answers: **none** when the trip says it wants
  none, the **named** one when it named one and that one is still in the gallery, and
  otherwise the **first** in gallery order. Three states need two columns —
  `Trips.coverAttachmentId` and `Trips.coverHidden` (v35) — because null in the id means
  "nothing chosen", which is not the statement "nothing wanted": a trip whose pictures are
  all of receipts has photos and no cover, and deriving one anyway would overrule that.
  `TripDao` keeps the invariant that hiding **clears** the id rather than parking it, so no
  two columns can disagree about what the card shows and un-hiding returns to the derived
  picture rather than to a memory nothing on screen hinted at.
- **`Trips.coverAttachmentId` is deliberately not a foreign key, and this is the general
  rule: never put two tables in a reference cycle.** `Attachments` already references
  `Trips`, so declaring the reverse closes one — and **drift answers a cycle by silently
  dropping foreign keys elsewhere** until it can order its `CREATE TABLE`s again. Measured
  when it happened: `item_groups.trip_id` and `alternative_sets.trip_id` came out with no
  `REFERENCES` clause at all, `itinerary_items` lost one of four, and deleting a trip
  stopped cascading to its groups and its decisions. Nothing warns; the schema simply comes
  out weaker, and four unrelated cascade tests are what noticed. A stale id is the cheaper
  problem: `coverPhoto` looks it up in the gallery it was handed and falls back when it is
  not there, and `attachments.id` being `AUTOINCREMENT` means SQLite never reissues the
  number, so it can never come to mean a different picture. `attachment_dao_test.dart`
  stands on both halves.
- **One star does all three states.** An amber star in the **gallery's** app bar, filled
  when this picture is the one the card shows — the argument that put `ItemColorField` on
  the map rather than in a form. Starring an unstarred picture makes it the cover;
  **unstarring the cover means the trip wants none**. Deriving is never named: it is where a
  trip starts and it looks exactly like having chosen that picture, which is the point.
  Crucially the star is filled for the **derived** cover too — an earlier version lit it
  only for a named one, which left the commonest case a card showing a photograph with no
  star anywhere, reading as the app having picked one behind the user's back. Resolving
  which picture that is belongs to `tripCoverIdProvider`, so the strip and the gallery
  cannot disagree. This replaced a checkable *No cover photo* on a ⋮ in the strip's header:
  one control with one meaning beats two, and the menu is gone.
  The strip carries the same star as a **mark**, ink-on-halo like the map's own marker, and
  deliberately not as a control: a real 48dp target inside a 72dp tile takes half of it and
  steals the taps that open the gallery. Amber because red is reserved for "happening" and a
  user-chosen accent is invisible against half the photographs it would be drawn on
  (`kCoverStarColor`, defined once so the two cannot drift).
- **Which of the two a file becomes is the door it came through, never the decoder.**
  `prepareAttachment` takes an `AttachmentKind`. It used to read the answer off the bytes —
  whatever decoded was a photograph — so a train ticket saved as a `.png` could not be filed
  under documents however much its owner wanted it there. Deciding that would be the app
  ruling on what a file *means*, which it declines to do about tags, about trip length and
  about a position; and it left *Add photo* and *Add file* meaning the same thing for half
  the files people have. A picture filed as a **document** is kept byte for byte: not
  bounded like a photograph, **metadata not stripped** (`SECURITY.md` says so), no position
  and no map marker — a document is a file, not a place, whatever it is a picture of, and
  `AttachmentDao.setAttachmentPosition` passes over one rather than trusting its callers. A
  thumbnail *is* made when the bytes decode, without touching them, because a list of files
  with one blank row looks broken; `Attachment.width` records that they did, which is what
  `isViewable` reads. One consequence worth having: HEIC is refused at the photo door and
  welcome at the other, so a format nothing here can decode can still be kept and handed on.
- **An entry says "3 photos" and "2 documents", apart.** They are two acts: a photograph is
  *looked at* (the gallery, one tap) and a document is *opened* (a list, from which each
  goes on to whatever program understands it). One line saying "5 attachments" answered
  neither, and its icon had to guess which a tap would do. So `AttachmentTally` counts by
  kind, and the entry draws two `_CountChip`s. The gallery is of **that entry's**
  photographs, not the trip's — the entry is what you pointed at, and the strip on the trip
  screen is where the whole trip is walked. A run's band gets the same two acts as bare
  icons without counts: it already carries a label, the journey button, the ⋮ and the drag
  handle, and two more numbers would leave a named run nowhere to be read.
- **A form lists them under two headings, never as one pile.** `AttachmentsField` draws a
  *Photos* section and a *Documents* section, each with its own count and its own **Add**
  button — so which door a file comes through, and therefore what it becomes, is chosen
  where that kind is listed. A flat list under "Attachments" made the reader sort a ticket
  from a photograph by its icon, and it is the same split the timeline shows. An empty
  section is its heading and its button and nothing else: a "nothing here" line under each
  of two headings is noise where the point is to see at a glance what there is. Narrowed to
  one kind (`only`, which the timeline's documents sheet passes) it is one section, since
  there is then nothing to choose between.
- **A document that is a picture is under documents, and opens in a gallery of its own.**
  That is the point of having filed it there — a `.png` ticket is not one of the trip's
  photographs, does not reach the map, the PDF or the cover star (the documents gallery is
  opened with no `tripId`, so the star is absent), and is still something you can look at
  when you need to show it. `tripGalleryProvider` orders the trip's photographs **once**;
  the strip draws that list, the cover star reads which of it is the cover, and an entry's
  chip filters it. Three copies of `tripGallery(...)` would be three chances for the order
  to drift.
- **A tap on a document opens it, in somebody else's program.** A document is *opened*, and
  the app has no reading of its own for a PDF, so `openAttachment` (`attachment_flow.dart`)
  hands a copy to the platform: `core/open_file.dart`, split like `save_file.dart`. Native
  writes it to `<app cache>/opened/<id>/<name>` — the app's own cache, never a shared temp
  directory where a passport scan is readable by every account on a desktop — and names it
  to the OS: `url_launcher` on the desktops, `DocumentOpener.kt` on Android, which serves it
  through a non-exported `DocumentFileProvider` limited to that one folder and starts
  `ACTION_VIEW` with a one-URI read grant (no permission, no `<queries>`; `startActivity`
  needs neither). The web opens a blob in a tab. The copy is removed by the **next** open,
  not after this one, since a viewer reads it for as long as it is open, so at most one
  document lies outside the database. Two traps that decided the details: a file with no
  type is **not** sent (`application/octet-stream` is what this app's own `.tpt` filter
  answers, so the "viewer" would be Pappus importing it as a trip), and a desktop picks the
  program by the extension, so `attachmentFileName` puts one back on a renamed "Ticket" from
  the table `extensionForMimeType` shares with the import. Where nothing takes the file, the
  row's tap opens the sheet with the reason in it, not a snack bar: this list lives in a
  modal sheet, and a snack bar would be drawn underneath it. Since no row's tap reaches the
  sheet any more, every row carries a ⋮ to it.
- **The card reads one map, not one query per card.** `tripCoversProvider` is the
  `watchPositionedItems` rule applied again, in two steps because the thumbnail is a blob:
  `watchCoverCandidates` asks only *where* each photograph sits — no bytes — and
  `thumbnailsFor` then fetches the handful that were chosen. Fetching every thumbnail to
  pick a dozen would push megabytes through the stream on every tick. That query carries
  each photograph's **place in the plan** and applies the **live rule in SQL**, so the card
  derives the same picture the strip's star sits on. It did not once: the card ordered by
  when a photograph was *added* while the strip ordered by where the plan puts it, and the
  two only said so out loud when a named cover was deleted and both fell back — to
  different pictures. Stating the rule in SQL here is the `TrackDao._liveTracks` precedent,
  not a departure: an all-trips query has no caller holding the entries to check against. The thumbnail is `kTripCoverSize` square at
  the card's **trailing** edge, opposite the accent stripe: leading would shift the title of
  every card that has one and leave the list a ragged left edge, or force a placeholder —
  something invented to fill a space rather than something said.
