/// Handing bytes to whatever program on this device opens their kind of file.
///
/// The app holds its attachments inside the database, so no other program can
/// reach one until it is given a copy. Sharing was the only way to make that
/// copy, which turned "look at the booking" into three steps through a share
/// sheet, a download and a file manager. This is the one step: a copy in the
/// app's own cache, handed to the platform's viewer.
///
/// Split by platform like `save_file.dart`: native writes a file and names it
/// to the operating system, the web hands the browser a blob to show in a tab.
library;

export 'open_file_io.dart' if (dart.library.js_interop) 'open_file_web.dart';
