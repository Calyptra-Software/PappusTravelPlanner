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

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format/byte_format.dart';
import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'attachment_import.dart';

/// A file as it comes back from a picker: the bytes, and the name it had.
typedef PickedAttachment = ({Uint8List bytes, String? name});

/// Picks files and hangs them on [itemId], [groupId] or [tripId] — exactly one
/// of the three.
///
/// [photosOnly] narrows the chooser to pictures, which is what the *Add photo*
/// door asks for; the other door takes anything. [pickFiles] exists so the flow
/// can be driven without a native dialog: the refusals and what is written are
/// worth a test, and a file chooser in the middle would put them out of reach.
///
/// Returns how many were attached. A file that is turned away does not stop the
/// others — a refusal is about one file — and the first refusal's reason is what
/// gets said, since three snack bars in a row say nothing.
Future<int> addAttachments(
  BuildContext context,
  WidgetRef ref, {
  int? itemId,
  int? groupId,
  int? tripId,
  bool photosOnly = false,
  Future<List<PickedAttachment>?> Function()? pickFiles,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final picked = await (pickFiles ?? () => _pick(photosOnly: photosOnly))();
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
  String? refusal;
  for (final file in picked) {
    final PreparedAttachment prepared;
    try {
      prepared = await compute(_prepare, file);
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
  if (refusal != null) {
    messenger.showSnackBar(SnackBar(content: Text(refusal)));
  } else if (added > 1) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.attachmentsAddedMany(added))),
    );
  }
  return added;
}

/// Runs in an isolate — hence top-level, and taking one argument.
PreparedAttachment _prepare(PickedAttachment file) =>
    prepareAttachment(file.bytes, name: file.name);

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

Future<List<PickedAttachment>?> _pick({required bool photosOnly}) async {
  if (_isDesktop) {
    // file_selector on desktop, matching the GPX import and the database
    // export: its native chooser parents to the app window on Linux instead of
    // opening behind it.
    final files = await openFiles(
      acceptedTypeGroups: [
        if (photosOnly)
          const XTypeGroup(
            label: 'Images',
            extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
          ),
      ],
    );
    return [
      for (final file in files)
        (bytes: await file.readAsBytes(), name: file.name),
    ];
  }
  // Read through the picked file rather than off a path, so the one branch
  // works on web and native alike.
  // `pickFiles` is the multi-file call and takes several by default.
  final result = await FilePicker.pickFiles(
    type: photosOnly ? FileType.image : FileType.any,
  );
  if (result == null) return null;
  return [
    for (final file in result.files)
      (bytes: await file.readAsBytes(), name: file.name),
  ];
}

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS);
