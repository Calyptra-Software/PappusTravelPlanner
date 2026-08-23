import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_location.dart';
import '../../../core/providers.dart';

/// What the database costs to carry: the file's own size, and what the
/// attachments inside it account for.
///
/// Two numbers rather than one, and the pair is the point. The file size alone
/// says "41 MB" and leaves open where that came from; the attachment total
/// alone says nothing about the file anyone actually copies. Side by side they
/// answer the only question asked here — whether the trips or the pictures are
/// what makes this thing large — and, when the two drift apart, that something
/// is being held that nothing needs.
///
/// [fileBytes] is null on the web, which has no file: see `databaseFileSize`.
typedef DatabaseStorage = ({
  int? fileBytes,
  int attachmentCount,
  int attachmentBytes,
});

/// Read once rather than watched. Nothing on the settings screen changes these
/// numbers, the answer is a fact about a moment rather than a live reading, and
/// a drift `.watch()` in a widget tree is a stream that has to be stubbed in
/// every test that ever pumps it.
///
/// `ref.invalidate` is the way to refresh it after something that would move
/// the numbers — importing a database, or emptying one.
final databaseStorageProvider = FutureProvider.autoDispose<DatabaseStorage>((
  ref,
) async {
  final counted = await ref.watch(repositoryProvider).attachmentStorage();
  return (
    fileBytes: databaseFileSize(ref.watch(activeDbPathProvider)),
    attachmentCount: counted.count,
    attachmentBytes: counted.bytes,
  );
});
