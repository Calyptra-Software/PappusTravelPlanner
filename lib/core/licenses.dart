/// The licenses of the things that ship *inside* the binary but are not a Dart
/// package's `LICENSE` file.
///
/// Flutter's license page is built from `LicenseRegistry`, which knows every
/// package's `LICENSE` file and the engine's, and nothing else. Missing from it
/// otherwise: the bundled fonts and the country outlines, the further licenses
/// that [packagesWithOtherLicenses] keep beside their `LICENSE`, and on Android
/// the libraries Gradle pulls in through the plugins. Roboto is bundled as a
/// real asset (the PDF export needs a font that can draw a €), and Apache-2.0
/// asks that its terms travel with the copy; the Material Icons font asks for
/// an attribution; the transport glyphs carry their own per-icon provenance.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart packages in the app that keep the licenses of code taken from other
/// projects in further files beside their `LICENSE`, copied to
/// assets/licenses/ as `<package>-<file name>`: image and archive (through
/// image and pdf) with code ported from other projects, characters (through
/// Flutter) with the Unicode grapheme tables, and mime (through share_plus)
/// with Apache httpd's media types.
const Map<String, String> packagesWithOtherLicenses = {
  'archive': 'LICENSE-other.md',
  'image': 'LICENSE-other.md',
  'characters': 'third_party/Unicode_Consortium/UNICODE_LICENSE.txt',
  'mime': 'third_party/httpd/LICENSE',
};

/// The asset a [packagesWithOtherLicenses] entry is copied to.
String otherLicenseAsset(String package) =>
    'assets/licenses/$package-'
    '${packagesWithOtherLicenses[package]!.split('/').last}';

/// The Android libraries not under Apache-2.0: repackaged Protocol Buffers
/// runtimes (BSD-3-Clause), from the settings store and the home-screen widget.
const List<String> androidProtobufLibraries = [
  'androidx.datastore:datastore-preferences-external-protobuf',
  'androidx.glance:glance-appwidget-external-protobuf',
];

/// Makes the license page list everything that ships inside the app. Called
/// once from `main`; the callback itself is lazy, so the assets are only loaded
/// if someone opens that page.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Roboto',
    ], await rootBundle.loadString('assets/fonts/Roboto-LICENSE.txt'));
    // The attribution that CC BY 4.0 asks for, before the license itself.
    yield LicenseEntryWithLineBreaks(
      const ['Material Icons'],
      'Material Icons by Google, https://fonts.google.com/icons. The app '
      'bundles only the icons it uses.\n\n'
      '${await rootBundle.loadString('assets/licenses/MaterialIcons_LICENSE.txt')}',
    );
    yield LicenseEntryWithLineBreaks(const [
      'Natural Earth',
    ], await rootBundle.loadString('assets/geo/countries-ATTRIBUTION.txt'));
    yield LicenseEntryWithLineBreaks(
      const ['TransportGlyphs'],
      await rootBundle.loadString(
        'assets/fonts/TransportGlyphs-ATTRIBUTION.txt',
      ),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Material Icons (PDF export)'],
      await rootBundle.loadString(
        'assets/fonts/MaterialIconsPdf-ATTRIBUTION.txt',
      ),
    );
    for (final package in packagesWithOtherLicenses.keys) {
      yield LicenseEntryWithLineBreaks([
        package,
      ], await rootBundle.loadString(otherLicenseAsset(package)));
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      yield LicenseEntryWithLineBreaks(
        androidLibraries(
          await rootBundle.loadString('assets/licenses/android_libraries.txt'),
        ),
        await rootBundle.loadString('assets/licenses/Apache-2.0.txt'),
      );
      yield LicenseEntryWithLineBreaks(
        androidProtobufLibraries,
        await rootBundle.loadString('assets/licenses/protobuf-LICENSE.txt'),
      );
    }
  });
}

/// The `group:artifact` lines of assets/licenses/android_libraries.txt.
List<String> androidLibraries(String list) => [
  for (final line in list.split('\n'))
    if (line.trim() case final l when l.isNotEmpty && !l.startsWith('#')) l,
];
