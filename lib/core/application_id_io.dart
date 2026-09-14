import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// The GTK application id on Linux, null on every other platform; see
/// `application_id.dart`.
///
/// Asked of GLib directly, the way `path_provider_linux` asks it when choosing
/// the directory the preferences are stored in — that helper is not part of
/// its public API, so this is the same two calls rather than an import of it.
/// Any failure (no libgio, no default application yet) is an unknown id, not
/// a crash: the caller then falls back to `PackageInfo`, which says "not the
/// CI build".
String? nativeApplicationId() {
  if (!Platform.isLinux) return null;
  try {
    final gio = DynamicLibrary.open('libgio-2.0.so.0');
    final getDefault = gio
        .lookupFunction<Pointer Function(), Pointer Function()>(
          'g_application_get_default',
        );
    final getId = gio
        .lookupFunction<
          Pointer<Utf8> Function(Pointer),
          Pointer<Utf8> Function(Pointer)
        >('g_application_get_application_id');
    final app = getDefault();
    if (app == nullptr) return null;
    final id = getId(app);
    return id == nullptr ? null : id.toDartString();
  } on Object {
    return null;
  }
}
