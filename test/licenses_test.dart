import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/licenses.dart';

/// Flutter's license page knows the packages' LICENSE files and nothing else;
/// what ships inside the binary beyond them is registered by hand, from copies
/// in assets/ that have to stay what they were copied from.
void main() {
  // package_config.json says where pub put each package, to compare the copies
  // in assets/ with their sources, which Dependabot or a Flutter upgrade may
  // have updated since.
  final config = File('.dart_tool/package_config.json').absolute;
  final roots = {
    for (final p
        in (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List)
      p['name'] as String: config.uri.resolve('${p['rootUri']}/'),
  };
  String read(Uri uri) => File.fromUri(uri).readAsStringSync();
  // The text without the whitespace at line ends and the blank lines at the
  // end, which an editor trims on save and which change nothing in a license.
  String text(Uri uri) => read(
    uri,
  ).split('\n').map((line) => line.trimRight()).join('\n').trimRight();
  final materialFonts = roots['flutter']!.resolve(
    '../../bin/cache/artifacts/material_fonts/',
  );

  // For rootBundle, which registerLicenses reads from.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
  tearDown(() {
    LicenseRegistry.reset();
    debugDefaultTargetPlatformOverride = null;
  });

  test('the copied license texts match their sources', () {
    for (final MapEntry(key: package, value: file)
        in packagesWithOtherLicenses.entries) {
      expect(
        text(Uri.file(otherLicenseAsset(package))),
        text(roots[package]!.resolve(file)),
        reason: package,
      );
    }
    expect(
      text(Uri.file('assets/licenses/MaterialIcons_LICENSE.txt')),
      text(materialFonts.resolve('MaterialIcons_LICENSE.txt')),
    );
    expect(
      text(Uri.file('assets/fonts/Roboto-LICENSE.txt')),
      text(materialFonts.resolve('Roboto_LICENSE.txt')),
    );
  });

  test('the Android list holds Maven coordinates only', () {
    final libraries = androidLibraries(
      File('assets/licenses/android_libraries.txt').readAsStringSync(),
    );
    expect(libraries, contains('androidx.glance:glance-appwidget'));
    expect(libraries, everyElement(matches(r'^[\w.-]+:[\w.-]+$')));
    // Not Apache-2.0, so registered on their own with their BSD license.
    for (final protobuf in androidProtobufLibraries) {
      expect(libraries, isNot(contains(protobuf)));
    }
  });

  Future<Set<String>> registeredPackages() async {
    registerLicenses();
    return {
      await for (final entry in LicenseRegistry.licenses) ...entry.packages,
    };
  }

  test('the license page lists what Flutter misses', () async {
    // Tests run as Android by default.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final packages = await registeredPackages();
    expect(
      packages,
      containsAll([
        'Roboto',
        'Material Icons',
        'Natural Earth',
        'TransportGlyphs',
        'Material Icons (PDF export)',
        ...packagesWithOtherLicenses.keys,
      ]),
    );
    expect(packages, isNot(contains('androidx.glance:glance-appwidget')));
  });

  test('on Android it also lists the Gradle libraries', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final packages = await registeredPackages();
    expect(
      packages,
      containsAll([
        'androidx.glance:glance-appwidget',
        ...androidProtobufLibraries,
      ]),
    );
  });
}
