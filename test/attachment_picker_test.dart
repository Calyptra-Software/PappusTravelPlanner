import 'package:android_file_picker/android_file_picker.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/attachments/application/media_location.dart';
import 'package:travelplanner/features/attachments/attachment_flow.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'support/fake_media_location.dart';

/// Which chooser the photo door opens, and what it asks it for.
///
/// `attachment_flow_test.dart` injects the picked files and tests everything
/// after the picking; this is the half before it, which is where the one
/// decision on that path that is not a detail lives. `FileType.image` goes out
/// as `ACTION_GET_CONTENT`, which Android has taken over with its own photo
/// picker — and that picker strips a photograph's coordinates whatever
/// permission the app holds, so it is the one chooser that can never answer the
/// question this feature exists to ask. With the switch on the door therefore
/// becomes a list of extensions, which goes out as `ACTION_OPEN_DOCUMENT`.
///
/// None of that is visible from outside except in what the picker is *asked*,
/// which is what these assert, against a chooser standing in for the platform.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late int itemId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Rome',
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 1)),
      ),
    );
    itemId = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
        title: const Value('Colosseum'),
      ),
    );
  });
  tearDown(() => db.close());

  Uint8List jpeg() {
    final image = img.Image(width: 24, height: 18);
    img.fill(image, color: img.ColorRgb8(90, 140, 190));
    return img.encodeJpg(image);
  }

  /// Puts [picker] in front of the plugin for the length of one test.
  _FakeFilePicker useFilePicker(_FakeFilePicker picker) {
    final previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = previous);
    return picker;
  }

  _FakeFileSelector useFileSelector(_FakeFileSelector selector) {
    final previous = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = selector;
    addTearDown(() => FileSelectorPlatform.instance = previous);
    return selector;
  }

  /// The flow started by the last tap. `compute` runs on a real isolate, which
  /// the fake clock does not drive — see `attachment_flow_test.dart`.
  Future<int>? pending;

  Future<void> pumpAdder(
    WidgetTester tester, {
    required FakeMediaLocation platform,
    MediaLocationAccess startup = MediaLocationAccess.granted,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          bootstrapMediaLocationProvider.overrideWithValue(startup),
          mediaLocationProvider.overrideWithValue(platform),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  // No `pickFiles`: the chooser is what is under test here.
                  onPressed: () => pending = addAttachments(
                    context,
                    ref,
                    itemId: itemId,
                    kind: AttachmentKind.photo,
                  ),
                  child: const Text('attach'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapAttach(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('attach'));
      await pending!;
    });
    await tester.pumpAndSettle();
  }

  Future<List<Attachment>> stored() =>
      (db.select(db.attachments)..where((a) => a.itemId.equals(itemId))).get();

  testWidgets('with the switch off it is the photo picker, and nothing else', (
    tester,
  ) async {
    final picker = useFilePicker(_FakeFilePicker([_androidFile(jpeg())]));
    final platform = FakeMediaLocation(position: const LatLng(53.55, 10.0));
    await pumpAdder(tester, platform: platform);
    await tapAttach(tester);

    // The chooser people know, asked for pictures and for nothing more: no
    // extension list, so no `ACTION_OPEN_DOCUMENT`, and no SAF options, so no
    // URI to ask about. Off is exactly what it always was.
    expect(picker.type, FileType.image);
    expect(picker.allowedExtensions, isNull);
    expect(picker.androidOptions, isNot(isA<FilePickerAndroidOptions>()));
    expect(platform.asked, isEmpty);
    expect((await stored()).single.lat, isNull);
  });

  testWidgets('with it on it is the file browser, and the URI comes back', (
    tester,
  ) async {
    await prefs.setBool('photo_location_enabled', true);
    final picker = useFilePicker(
      _FakeFilePicker([
        _androidFile(jpeg(), uri: 'content://media/external/images/media/7'),
      ]),
    );
    final platform = FakeMediaLocation(position: const LatLng(53.55, 10.0));
    await pumpAdder(tester, platform: platform);
    await tapAttach(tester);

    // A list of extensions rather than a media type, which is what makes this
    // the file browser and not the picker that always redacts.
    expect(picker.type, FileType.custom);
    expect(picker.allowedExtensions, contains('jpg'));
    // The SAF handle is the only route the URI has into Dart, and the grant
    // taken on it lasts this import and no longer.
    final options = picker.androidOptions;
    expect(options, isA<FilePickerAndroidOptions>());
    expect(
      (options! as FilePickerAndroidOptions).safOptions.grant,
      AndroidSAFGrant.transient,
    );

    expect(platform.asked, ['content://media/external/images/media/7']);
    final photo = (await stored()).single;
    expect(photo.lat, closeTo(53.55, 0.0001));
    expect(photo.positionSource, AttachmentPositionSource.exif);
  });

  testWidgets('a file with no handle behind it is simply attached', (
    tester,
  ) async {
    await prefs.setBool('photo_location_enabled', true);
    // A chooser that answered from somewhere with no MediaStore row behind it —
    // a cloud provider, a file manager of its own. There is nothing to ask.
    useFilePicker(_FakeFilePicker([_androidFile(jpeg())]));
    final platform = FakeMediaLocation(position: const LatLng(53.55, 10.0));
    await pumpAdder(tester, platform: platform);
    await tapAttach(tester);

    expect(platform.asked, isEmpty);
    expect((await stored()).single.lat, isNull);
  });

  testWidgets('a dismissed chooser attaches nothing and says nothing', (
    tester,
  ) async {
    useFilePicker(_FakeFilePicker(const []));
    await pumpAdder(tester, platform: FakeMediaLocation());
    await tapAttach(tester);

    expect(await stored(), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('on the desktop it is the other chooser, narrowed to pictures', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    // `file_selector` and not `file_picker` here, for the reason the database
    // export gives: its native chooser parents to the app window on Linux
    // instead of opening behind it.
    final selector = useFileSelector(
      _FakeFileSelector([XFile.fromData(jpeg(), name: 'view.jpg')]),
    );
    final platform = FakeMediaLocation(position: const LatLng(53.55, 10.0));
    await pumpAdder(tester, platform: platform);
    await tapAttach(tester);
    // Put back inside the body, not in a tear-down: the binding checks the
    // foundation's debug variables before tear-downs run, and reports a test
    // that left one set as a failure of its own.
    debugDefaultTargetPlatformOverride = null;

    expect(selector.acceptedTypeGroups?.single.extensions, contains('jpg'));
    // Nothing was ever taken out of the file here, so there is no second
    // reading to ask for — the position, if the picture has one, comes out of
    // the bytes like it always did.
    expect(platform.asked, isEmpty);
    expect(await stored(), hasLength(1));
  });
}

/// One picked file, as Android's picker hands it over: bytes for the app, and a
/// SAF handle only when the chooser was asked for one.
AndroidPlatformFile _androidFile(Uint8List bytes, {String? uri}) =>
    AndroidPlatformFile(
      name: 'view.jpg',
      uri: Uri.parse(uri ?? 'file:///cache/view.jpg'),
      safHandle: uri == null
          ? null
          : AndroidSAFHandle(
              accessMode: AndroidSAFAccessMode.readOnly,
              uri: Uri.parse(uri),
            ),
      xFile: XFile.fromData(bytes, name: 'view.jpg'),
    );

/// The chooser, standing still, recording what it was asked for.
class _FakeFilePicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  _FakeFilePicker(this.answer);

  final List<PlatformFile> answer;

  FileType? type;
  List<String>? allowedExtensions;
  AndroidOptions? androidOptions;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    this.androidOptions = androidOptions;
    return answer;
  }
}

/// The desktop chooser, likewise.
class _FakeFileSelector extends FileSelectorPlatform
    with MockPlatformInterfaceMixin {
  _FakeFileSelector(this.answer);

  final List<XFile> answer;

  List<XTypeGroup>? acceptedTypeGroups;

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    this.acceptedTypeGroups = acceptedTypeGroups;
    return answer;
  }
}
