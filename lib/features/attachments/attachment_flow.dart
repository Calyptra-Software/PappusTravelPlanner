/// Attaching a file, from wherever it was asked for.
///
/// One flow with three doors, like `startTrackImport`: an entry's own form, the
/// label above a run, and the trip's own section. The door decides only *what
/// the file hangs on* — an item, a group or the trip, never two of them (see
/// [Attachments]) — and everything after the picking is the same.
///
/// The reading itself happens off the platform thread. `prepareAttachment`
/// decodes, scales twice and encodes twice, which on a phone-sized photo is long
/// enough to drop frames, and picking several at once multiplies it.
library;

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format/byte_format.dart';
import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';
import '../../l10n/app_localizations.dart';
import 'application/media_location.dart';
import 'attachment_import.dart';

/// A file as it comes back from a picker: the bytes, the name it had, and — on
/// Android alone — the URI it was handed over as.
///
/// A class and not a record because [mediaUri] is absent for almost everything
/// (every desktop pick, every file that did not come from the shared
/// collection) and a record has no optional field to leave out.
final class PickedAttachment {
  const PickedAttachment({required this.bytes, this.name, this.mediaUri});

  final Uint8List bytes;
  final String? name;

  /// What the Storage Access Framework called this file, kept only long enough
  /// to ask the platform where the photograph was taken — the picker's own copy
  /// of the bytes has that zeroed out. See `media_location.dart`. Null
  /// everywhere the question cannot be asked.
  final String? mediaUri;
}

/// Picks files and hangs them on [itemId], [groupId] or [tripId] — exactly one
/// of the three.
///
/// [kind] is which door this is, and it decides two things: the chooser is
/// narrowed to pictures for *Add photo*, and — the part that matters — the file
/// is stored as that kind. The decoder no longer rules on it, so a `.png` ticket
/// filed through *Add file* stays a document. [pickFiles] exists so the flow
/// can be driven without a native dialog: the refusals and what is written are
/// worth a test, and a file chooser in the middle would put them out of reach.
///
/// Returns how many were attached. A file that is turned away does not stop the
/// others — a refusal is about one file — and the first refusal's reason is what
/// gets said, since three snack bars in a row say nothing.
///
/// **On Android the photo door has two shapes, and the switch in settings picks
/// between them** (see `media_location.dart`). Off — the default — is exactly
/// what it always was. On, two things change together, because neither is any
/// use alone: the chooser becomes the file browser rather than the system's
/// photo picker, which strips a picture's coordinates whatever permission the
/// app holds; and every photograph that still arrives without a position is
/// asked about again, by URI, against the original the picker only ever handed
/// over a redacted copy of. Nothing more of the file crosses back — the picture
/// that is stored is still the re-encoded, EXIF-stripped one.
Future<int> addAttachments(
  BuildContext context,
  WidgetRef ref, {
  int? itemId,
  int? groupId,
  int? tripId,
  AttachmentKind kind = AttachmentKind.document,
  Future<List<PickedAttachment>?> Function()? pickFiles,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  // Asked before the chooser opens, because it decides which chooser opens.
  // Freshly checked rather than read off the switch: the permission can be
  // taken away in the system settings between one photograph and the next.
  final locator = ref.read(mediaLocationProvider);
  final withLocation =
      kind == AttachmentKind.photo &&
      await ref.read(photoLocationProvider.notifier).activeNow();
  if (!context.mounted) return 0;

  final picked =
      await (pickFiles ??
          () => _pick(
            photosOnly: kind == AttachmentKind.photo,
            withLocation: withLocation,
          ))();
  if (picked == null || picked.isEmpty) return 0;

  // Said before the work starts. Picking eight photos takes a moment on any
  // platform, and the snack bar is dismissed again below whatever happens.
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.attachmentsAdding),
      duration: const Duration(minutes: 1),
    ),
  );
  // On the **web** only, wait for it to actually be painted. `compute` is a
  // real isolate everywhere else — the interface stays live and this message
  // appears by itself — but in a browser it runs the callback inline and blocks
  // the one thread there is, so without yielding a frame first the app looks
  // frozen instead of busy: the snack bar would be scheduled behind the very
  // work it is announcing. Guarded rather than unconditional because awaiting a
  // frame from inside a callback is a thing that can deadlock a widget test,
  // and there is nothing to gain from it where the work is off-thread anyway.
  if (kIsWeb) await WidgetsBinding.instance.endOfFrame;

  final repo = ref.read(repositoryProvider);
  var added = 0;
  var redacted = 0;
  String? refusal;
  for (final file in picked) {
    PreparedAttachment prepared;
    try {
      prepared = await compute(_prepare, (file: file, kind: kind));
    } on AttachmentTooLargeException catch (e) {
      refusal ??= l10n.attachmentTooLarge(
        formatBytes(e.byteSize),
        formatBytes(e.limit),
      );
      continue;
    } on UnreadableImageException catch (e) {
      refusal ??= l10n.attachmentUnreadableImage(
        e.extension?.toUpperCase() ?? '?',
      );
      continue;
    } catch (_) {
      // A file from outside that nothing here could make sense of. A clean
      // refusal and nothing else is what it is owed.
      refusal ??= l10n.attachmentUnreadable;
      continue;
    }
    // The second reading, and the only one that can answer: what came back
    // from the picker is a copy Android made with a plain stream, and its GPS
    // tags are zeroed in that copy however much this process is allowed to
    // know. Asked only when the first reading found nothing — a photograph that
    // arrived with its place needs no second opinion, and one that never had a
    // fix costs a header read to say so.
    final mediaUri = file.mediaUri;
    if (withLocation && prepared.position == null && mediaUri != null) {
      final position = await locator.readLocation(mediaUri);
      if (position != null) prepared = prepared.withExifPosition(position);
    }
    if (prepared.locationRedacted) redacted++;
    await repo.addAttachment(
      prepared,
      itemId: itemId,
      groupId: groupId,
      tripId: tripId,
    );
    added++;
  }

  // Whatever replaces it, the "reading" message goes: it described work that
  // has finished, and a queue behind it would leave it on screen after the fact.
  messenger.hideCurrentSnackBar();
  // One message, in order of what the user most needs to hear. A refusal beats
  // everything, because a file is missing. A photograph whose place the system
  // withheld comes next: it is the only one of the three that reports something
  // the app did not choose and the user can still act on, and saying "3 files
  // attached" over it would leave a picture sitting on the map's doorstep with
  // no explanation. The plain count is what is left.
  if (refusal != null) {
    messenger.showSnackBar(SnackBar(content: Text(refusal)));
  } else if (redacted > 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.attachmentLocationRedacted(redacted))),
    );
  } else if (added > 1) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.attachmentsAddedMany(added))),
    );
  }
  return added;
}

/// Runs in an isolate — hence top-level, and taking one argument.
PreparedAttachment _prepare(({PickedAttachment file, AttachmentKind kind}) a) =>
    prepareAttachment(a.file.bytes, name: a.file.name, kind: a.kind);

/// Hands one attachment out of the app: to the share sheet, or to a file the
/// user chooses on desktop, which has no share sheet.
///
/// The same split `trip_detail_screen.dart` makes for a `.tpt`, and the reason
/// this exists at all: the bytes live in the database, so the only way to open a
/// ticket in a PDF reader is to give it a copy.
Future<void> shareAttachment(
  BuildContext context,
  WidgetRef ref,
  Attachment attachment,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final bytes = await ref
      .read(repositoryProvider)
      .readAttachmentBytes(attachment.id);
  if (bytes == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.attachmentPhotoOpenFailed)),
    );
    return;
  }
  final fileName = attachment.name ?? _defaultFileName(attachment);
  if (_isDesktop) {
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return;
    await XFile.fromData(bytes).saveTo(location.path);
    // Saying so, as the `.tpt` export does: a share sheet is its own
    // confirmation — the file visibly goes somewhere — while a desktop save
    // closes a dialog and leaves the screen exactly as it was.
    messenger.showSnackBar(SnackBar(content: Text(l10n.attachmentSaved)));
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, name: fileName, mimeType: attachment.mimeType),
      ],
      fileNameOverrides: [fileName],
    ),
  );
}

/// A name for a file that arrived without one, so what leaves the app is not
/// called `null`. Its id keeps two of them apart.
String _defaultFileName(Attachment attachment) {
  final extension = switch (attachment.mimeType) {
    'image/jpeg' => 'jpg',
    'application/pdf' => 'pdf',
    'text/plain' => 'txt',
    _ => 'bin',
  };
  return 'attachment-${attachment.id}.$extension';
}

/// The file extensions the photo door offers.
///
/// One list, used by both choosers that can be narrowed by extension: the
/// desktop's type group, and — when a position is wanted — Android's document
/// browser, which takes media types derived from exactly these.
const _photoExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];

Future<List<PickedAttachment>?> _pick({
  required bool photosOnly,
  bool withLocation = false,
}) async {
  if (_isDesktop) {
    // file_selector on desktop, matching the GPX import and the database
    // export: its native chooser parents to the app window on Linux instead of
    // opening behind it.
    final files = await openFiles(
      acceptedTypeGroups: [
        if (photosOnly)
          const XTypeGroup(label: 'Images', extensions: _photoExtensions),
      ],
    );
    return [
      for (final file in files)
        PickedAttachment(bytes: await file.readAsBytes(), name: file.name),
    ];
  }
  // Read through the picked file rather than off a path, so the one branch
  // works on web and native alike.
  // `pickFiles` is the multi-file call and takes several by default. A
  // dismissed picker comes back as an empty list rather than as nothing, which
  // the caller already reads the same way it reads "none picked".
  //
  // **`FileType.custom` and not `FileType.image` when a position is wanted**,
  // which is the one thing on this path that is not a detail. `image` goes out
  // as `ACTION_GET_CONTENT`, and Android has taken that over with its own photo
  // picker, which strips a picture's coordinates *unconditionally* — the
  // permission does not reach it, so the nicer chooser is the one chooser that
  // can never answer. A list of extensions goes out as `ACTION_OPEN_DOCUMENT`
  // instead: the file browser, filtered to the same pictures, whose answer
  // still names a row the platform will serve the original of. That is why the
  // feature is a switch and not simply the behaviour — it trades the picker
  // people know for the one that knows where the photograph was taken.
  //
  // The SAF options are there for the URI alone. `transient`, because the grant
  // is wanted for the length of this import and not beyond it: what is read
  // through it is two numbers, and an app holding a lifetime grant on somebody's
  // photo library is not what was asked for.
  final files = await FilePicker.pickFiles(
    type: withLocation
        ? FileType.custom
        : (photosOnly ? FileType.image : FileType.any),
    allowedExtensions: withLocation ? _photoExtensions : null,
    androidOptions: withLocation
        ? const FilePickerAndroidOptions(
            safOptions: AndroidSAFOptions(
              grant: AndroidSAFGrant.transient,
              persistGrant: false,
            ),
          )
        : const AndroidOptions(),
  );
  return [
    for (final file in files)
      PickedAttachment(
        bytes: await file.readAsBytes(),
        name: file.name,
        mediaUri: withLocation ? _mediaUriOf(file) : null,
      ),
  ];
}

/// What the Storage Access Framework called a picked file, when this platform
/// has such a thing. Null everywhere else, which is every platform where
/// nothing was taken out of the file in the first place.
String? _mediaUriOf(PlatformFile file) =>
    file is AndroidPlatformFile ? file.safHandle?.uri.toString() : null;

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS);
