# Database file, storage and schema changes

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the database file itself: auto-vacuum, the storage tile, switching/importing/exporting, migrations.

## Storage

- **Deleted space comes back by itself, because a user must not have to ask for it.**
  `AppDatabase._enableAutoVacuum` puts every file on `auto_vacuum = FULL`. SQLite otherwise
  keeps freed pages on a free list forever, which is the right trade for a database of text
  and the wrong one once a row can be a photograph: measured, 10 MB of blobs deleted leaves
  a 10 MB file by default and a 12 KB one with this. `FULL` rather than `INCREMENTAL`
  precisely because it needs **no call site** — an attachment dies in half a dozen places
  (its own delete, its entry's, its group's, its trip's, a journey replaced) and an
  `incremental_vacuum` at each is the shape of rule that rots. The usual objection, the
  per-commit cost, does not appear at this write volume: 6000 small writes against a file
  holding 16 MB of blobs measured 5.6 s with it and 6.1 s without, which is the `fsync`.
  It sits in `beforeOpen` beside `_stampApplicationId` for that function's own stated
  reason — the setting is in the file header, not the schema, so no `onUpgrade` branch would
  ever reach the databases that already exist. The `VACUUM` is what makes the pragma stick
  (alone it is silently ignored once there are tables) and is why doing this *now* was
  cheap: no released database can hold an attachment yet, so every one is small (14 ms at
  1 MB, 554 ms at 100 MB). It cannot run inside a transaction, which is a second reason it
  is not in a migration. Consequently there is no "reclaim space" button, and there should
  not be one.
- **The settings screen says what the database weighs**, in the tile that already says
  where it is (`_DatabaseTile`) — the path and the size are one question about one file.
  Two numbers, the file's own and what the attachments account for
  (`AttachmentDao.attachmentStorage`, reading the denormalised `byteSize` so no payload is
  touched): the file size alone leaves open where it came from, the attachment total alone
  says nothing about the thing anyone copies. The file size is null on the web, where the
  bytes could only be counted through `WasmDatabase.probe`, which wants the connection
  closed — far too much for a settings row. It is read **once**, not watched: nothing on
  that screen moves it, and a drift stream in a widget tree is one more thing every test
  that pumps it has to stub.

## Database portability & schema changes

- Data is one SQLite file. Desktop can open/create a DB at any path; Android imports/exports.
  `DatabaseController` (`lib/features/settings/application/database_providers.dart`) coordinates
  switching/importing/exporting. Where the app can't choose a path — Android (scoped storage
  hands back a `content://` URI, not a file it may hold a WAL handle on) and the web — the DB
  always lives at the fixed default location, so **"new database" can only mean "emptied in
  place"**: `createEmpty` is the import flow with nothing to copy in. "Reset to default" is
  desktop-only for the same reason — only a platform that can be pointed *away* from the
  default path can be sent back to it; elsewhere it would be a no-op wearing a destructive
  label. WAL mode writes `-wal`/`-shm` sidecars; call `checkpoint()`
  before copying and `deleteSidecars()` before replacing a file (see `core/database/database_location.dart`).
- Bump `AppDatabase.schemaVersion` (currently 41) and add an `onUpgrade` branch for **any**
  table/column change — real user databases are migrated in place, not recreated.
