/// The licenses of the things that ship *inside* the binary but are not Dart
/// packages — the two bundled fonts.
///
/// Flutter's license page is built from `LicenseRegistry`, which knows every
/// package's `LICENSE` file and nothing else. Roboto is bundled here as a real
/// asset (the PDF export needs a font that can draw a €), and Apache-2.0 asks
/// that its terms travel with the copy; the transport glyphs carry their own
/// per-icon provenance. Both are already in the repository as text files, so
/// registering them is the difference between the license page listing what the
/// app actually contains and listing only its dependencies.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled fonts' license texts to the registry Flutter's license page
/// reads. Called once from `main`; the callback itself is lazy, so the asset is
/// only loaded if someone opens that page.
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Roboto',
    ], await rootBundle.loadString('assets/fonts/Roboto-LICENSE.txt'));
    yield LicenseEntryWithLineBreaks(
      const ['TransportGlyphs'],
      await rootBundle.loadString(
        'assets/fonts/TransportGlyphs-ATTRIBUTION.txt',
      ),
    );
  });
}
