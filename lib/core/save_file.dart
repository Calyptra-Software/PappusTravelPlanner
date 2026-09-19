/// Handing bytes to the platform's own "save a file" flow.
///
/// Native platforms open a save dialog — or, on Android, the document picker —
/// through `file_picker`, and answer whether a file was written. The web has no
/// such dialog to wait for: the bytes are handed to the browser's download
/// machinery and the browser takes it from there, which is why the two answers
/// below mean slightly different things and why the web's is documented where
/// it is made (`save_file_web.dart`).
///
/// The split exists at all because `FilePicker.saveFile` is not usable on the
/// web: its web implementation returns `null` whether it worked or not, so its
/// caller cannot tell a save from a cancellation — and the download it starts
/// does not arrive in Firefox.
library;

export 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart';
