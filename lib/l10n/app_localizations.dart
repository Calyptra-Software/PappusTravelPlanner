import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel Planner'**
  String get appTitle;

  /// No description provided for @tripsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get tripsTitle;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get newTrip;

  /// No description provided for @noTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get noTripsTitle;

  /// No description provided for @noTripsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap “New trip” to plan your first adventure.'**
  String get noTripsBody;

  /// No description provided for @searchTrips.
  ///
  /// In en, this message translates to:
  /// **'Search trips'**
  String get searchTrips;

  /// No description provided for @searchTripsHint.
  ///
  /// In en, this message translates to:
  /// **'Title, destination or notes'**
  String get searchTripsHint;

  /// No description provided for @filterTrips.
  ///
  /// In en, this message translates to:
  /// **'Filter and sort'**
  String get filterTrips;

  /// No description provided for @filterAndSort.
  ///
  /// In en, this message translates to:
  /// **'Filter & sort'**
  String get filterAndSort;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilters;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @tripStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tripStatusUpcoming;

  /// No description provided for @tripStatusOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get tripStatusOngoing;

  /// No description provided for @tripStatusPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get tripStatusPast;

  /// No description provided for @tripStatusUndated.
  ///
  /// In en, this message translates to:
  /// **'No dates'**
  String get tripStatusUndated;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @sortDateAsc.
  ///
  /// In en, this message translates to:
  /// **'Date (soonest)'**
  String get sortDateAsc;

  /// No description provided for @sortDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Date (latest)'**
  String get sortDateDesc;

  /// No description provided for @sortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get sortNameAsc;

  /// No description provided for @sortCreatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get sortCreatedDesc;

  /// No description provided for @sortExpenseDesc.
  ///
  /// In en, this message translates to:
  /// **'Expenses (highest)'**
  String get sortExpenseDesc;

  /// No description provided for @sortExpenseAsc.
  ///
  /// In en, this message translates to:
  /// **'Expenses (lowest)'**
  String get sortExpenseAsc;

  /// No description provided for @anyDate.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get anyDate;

  /// No description provided for @noTripsFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching trips'**
  String get noTripsFoundTitle;

  /// No description provided for @noTripsFoundBody.
  ///
  /// In en, this message translates to:
  /// **'No trips match “{query}”.'**
  String noTripsFoundBody(String query);

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong:\n{error}'**
  String genericError(String error);

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String days(int count);

  /// No description provided for @entries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String entries(int count);

  /// No description provided for @datesNotSet.
  ///
  /// In en, this message translates to:
  /// **'Dates not set'**
  String get datesNotSet;

  /// No description provided for @until.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String until(String date);

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get editTrip;

  /// No description provided for @shareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share trip'**
  String get shareTrip;

  /// No description provided for @shareTripSaved.
  ///
  /// In en, this message translates to:
  /// **'Trip file saved.'**
  String get shareTripSaved;

  /// No description provided for @shareTripFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share this trip.'**
  String get shareTripFailed;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get exportPdf;

  /// No description provided for @exportPdfFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export this trip as PDF.'**
  String get exportPdfFailed;

  /// No description provided for @exportIcs.
  ///
  /// In en, this message translates to:
  /// **'Export to calendar'**
  String get exportIcs;

  /// No description provided for @exportIcsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export this trip to a calendar.'**
  String get exportIcsFailed;

  /// No description provided for @exportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportAction;

  /// No description provided for @pdfSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'What goes into the PDF'**
  String get pdfSectionsTitle;

  /// No description provided for @pdfSectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The trip\'s name, dates and participants are always included.'**
  String get pdfSectionsSubtitle;

  /// No description provided for @pdfSectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded'**
  String get pdfSectionEmpty;

  /// No description provided for @pdfInclSettlements.
  ///
  /// In en, this message translates to:
  /// **'Settlements included'**
  String get pdfInclSettlements;

  /// No description provided for @pdfLists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 list} other{{count} lists}}'**
  String pdfLists(int count);

  /// No description provided for @pdfItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String pdfItems(int count);

  /// No description provided for @pdfOtherOptions.
  ///
  /// In en, this message translates to:
  /// **'Other options: {options}'**
  String pdfOtherOptions(String options);

  /// No description provided for @pdfExportedOn.
  ///
  /// In en, this message translates to:
  /// **'Exported {date}'**
  String pdfExportedOn(String date);

  /// No description provided for @importTrip.
  ///
  /// In en, this message translates to:
  /// **'Import trip'**
  String get importTrip;

  /// No description provided for @importTripSuccess.
  ///
  /// In en, this message translates to:
  /// **'Trip imported.'**
  String get importTripSuccess;

  /// No description provided for @importTripInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a valid shared trip.'**
  String get importTripInvalid;

  /// No description provided for @importTripTooNew.
  ///
  /// In en, this message translates to:
  /// **'This trip was shared from a newer version of the app. Please update to import it.'**
  String get importTripTooNew;

  /// No description provided for @importTripFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import this trip.'**
  String get importTripFailed;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Summer in Italy'**
  String get titleHint;

  /// No description provided for @titleValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get titleValidator;

  /// No description provided for @fieldDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get fieldDestination;

  /// No description provided for @destinationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rome, Florence'**
  String get destinationHint;

  /// No description provided for @fieldDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get fieldDates;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @accentColour.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get accentColour;

  /// No description provided for @customColour.
  ///
  /// In en, this message translates to:
  /// **'Custom colour'**
  String get customColour;

  /// No description provided for @pickColour.
  ///
  /// In en, this message translates to:
  /// **'Pick a colour'**
  String get pickColour;

  /// No description provided for @hexColour.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get hexColour;

  /// No description provided for @invalidHexColour.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid hex colour, e.g. 1565C0'**
  String get invalidHexColour;

  /// No description provided for @createTrip.
  ///
  /// In en, this message translates to:
  /// **'Create trip'**
  String get createTrip;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @itineraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Itinerary'**
  String get itineraryTitle;

  /// No description provided for @deleteTrip.
  ///
  /// In en, this message translates to:
  /// **'Delete trip'**
  String get deleteTrip;

  /// No description provided for @deleteTripQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete trip?'**
  String get deleteTripQuestion;

  /// No description provided for @deleteTripBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove the trip and its whole itinerary.'**
  String get deleteTripBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @nothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned yet.'**
  String get nothingPlanned;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @addPlace.
  ///
  /// In en, this message translates to:
  /// **'Add place'**
  String get addPlace;

  /// Quick-add chip that creates a place matching the destination of the day's last transport leg.
  ///
  /// In en, this message translates to:
  /// **'Add {place}'**
  String addArrival(String place);

  /// No description provided for @addTransport.
  ///
  /// In en, this message translates to:
  /// **'Add transport'**
  String get addTransport;

  /// No description provided for @hideEntries.
  ///
  /// In en, this message translates to:
  /// **'Hide entries'**
  String get hideEntries;

  /// No description provided for @showEntries.
  ///
  /// In en, this message translates to:
  /// **'Show entries'**
  String get showEntries;

  /// No description provided for @editPlace.
  ///
  /// In en, this message translates to:
  /// **'Edit place'**
  String get editPlace;

  /// No description provided for @editTransport.
  ///
  /// In en, this message translates to:
  /// **'Edit transport'**
  String get editTransport;

  /// No description provided for @fieldMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get fieldMode;

  /// No description provided for @fieldFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fieldFrom;

  /// No description provided for @fieldTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get fieldTo;

  /// No description provided for @fieldPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get fieldPlace;

  /// No description provided for @placeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Colosseum'**
  String get placeHint;

  /// No description provided for @placeValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a place'**
  String get placeValidator;

  /// No description provided for @fromToValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter at least a from or to location'**
  String get fromToValidator;

  /// No description provided for @transportLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get transportLabelOptional;

  /// No description provided for @noteTitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Note title (optional)'**
  String get noteTitleOptional;

  /// No description provided for @fieldDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get fieldDay;

  /// No description provided for @timeDeparts.
  ///
  /// In en, this message translates to:
  /// **'Departs'**
  String get timeDeparts;

  /// No description provided for @timeArrives.
  ///
  /// In en, this message translates to:
  /// **'Arrives'**
  String get timeArrives;

  /// No description provided for @timeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get timeStart;

  /// No description provided for @timeEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get timeEnd;

  /// No description provided for @setTime.
  ///
  /// In en, this message translates to:
  /// **'Set time'**
  String get setTime;

  /// No description provided for @plannedTimes.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get plannedTimes;

  /// No description provided for @actualTimes.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get actualTimes;

  /// No description provided for @actualTimesHint.
  ///
  /// In en, this message translates to:
  /// **'What really happened. The timeline shows how late or early it ran.'**
  String get actualTimesHint;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get searchNoMatches;

  /// Row in a search picker that adds what was typed as a new entry
  ///
  /// In en, this message translates to:
  /// **'Add “{query}”'**
  String searchAdd(String query);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @databaseSection.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get databaseSection;

  /// No description provided for @currentDatabase.
  ///
  /// In en, this message translates to:
  /// **'Current database'**
  String get currentDatabase;

  /// No description provided for @dbOpen.
  ///
  /// In en, this message translates to:
  /// **'Open database…'**
  String get dbOpen;

  /// No description provided for @dbOpenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Point the app at an existing .sqlite file'**
  String get dbOpenSubtitle;

  /// No description provided for @dbNew.
  ///
  /// In en, this message translates to:
  /// **'New database…'**
  String get dbNew;

  /// No description provided for @dbNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an empty database at a chosen location'**
  String get dbNewSubtitle;

  /// No description provided for @dbNewEmpty.
  ///
  /// In en, this message translates to:
  /// **'New empty database'**
  String get dbNewEmpty;

  /// No description provided for @dbNewEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start over with no trips'**
  String get dbNewEmptySubtitle;

  /// No description provided for @dbNewEmptyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new database?'**
  String get dbNewEmptyConfirmTitle;

  /// No description provided for @dbNewEmptyConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes all current trips and starts from an empty database. It can\'t be undone — export a copy first if you want to keep the data.'**
  String get dbNewEmptyConfirmBody;

  /// No description provided for @dbNewEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Start new'**
  String get dbNewEmptyAction;

  /// No description provided for @dbNewEmptyDone.
  ///
  /// In en, this message translates to:
  /// **'Started a new empty database'**
  String get dbNewEmptyDone;

  /// No description provided for @dbImport.
  ///
  /// In en, this message translates to:
  /// **'Import database…'**
  String get dbImport;

  /// No description provided for @dbImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the current data with a .sqlite file'**
  String get dbImportSubtitle;

  /// No description provided for @dbExport.
  ///
  /// In en, this message translates to:
  /// **'Export database…'**
  String get dbExport;

  /// No description provided for @dbExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a copy of the current database'**
  String get dbExportSubtitle;

  /// No description provided for @dbReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get dbReset;

  /// No description provided for @dbResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the app\'s default database location'**
  String get dbResetSubtitle;

  /// No description provided for @dbImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import database?'**
  String get dbImportConfirmTitle;

  /// No description provided for @dbImportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This replaces all current trips with the contents of the selected file. It can\'t be undone.'**
  String get dbImportConfirmBody;

  /// No description provided for @dbImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dbImportAction;

  /// No description provided for @dbOpened.
  ///
  /// In en, this message translates to:
  /// **'Database opened'**
  String get dbOpened;

  /// No description provided for @dbCreated.
  ///
  /// In en, this message translates to:
  /// **'New database created'**
  String get dbCreated;

  /// No description provided for @dbImported.
  ///
  /// In en, this message translates to:
  /// **'Database imported'**
  String get dbImported;

  /// No description provided for @dbExported.
  ///
  /// In en, this message translates to:
  /// **'Database exported'**
  String get dbExported;

  /// No description provided for @dbResetDone.
  ///
  /// In en, this message translates to:
  /// **'Switched to the default database'**
  String get dbResetDone;

  /// No description provided for @dbError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the operation: {error}'**
  String dbError(String error);

  /// No description provided for @modeWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get modeWalk;

  /// No description provided for @modeBike.
  ///
  /// In en, this message translates to:
  /// **'Bike'**
  String get modeBike;

  /// No description provided for @modeCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get modeCar;

  /// No description provided for @modeTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get modeTaxi;

  /// No description provided for @modeBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get modeBus;

  /// No description provided for @modeTrain.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get modeTrain;

  /// No description provided for @modeTram.
  ///
  /// In en, this message translates to:
  /// **'Tram'**
  String get modeTram;

  /// No description provided for @modeSubway.
  ///
  /// In en, this message translates to:
  /// **'Subway'**
  String get modeSubway;

  /// No description provided for @modeFerry.
  ///
  /// In en, this message translates to:
  /// **'Ferry'**
  String get modeFerry;

  /// No description provided for @modeFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get modeFlight;

  /// No description provided for @modeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get modeOther;

  /// No description provided for @modeSki.
  ///
  /// In en, this message translates to:
  /// **'Ski'**
  String get modeSki;

  /// No description provided for @widgetNoTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get widgetNoTripsTitle;

  /// No description provided for @widgetNoTripsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to plan your next adventure'**
  String get widgetNoTripsBody;

  /// No description provided for @widgetInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 day} other{in {count} days}}'**
  String widgetInDays(int count);

  /// No description provided for @widgetTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Starts tomorrow'**
  String get widgetTomorrow;

  /// No description provided for @widgetEndedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Ended yesterday'**
  String get widgetEndedYesterday;

  /// No description provided for @widgetEndedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ended 1 day ago} other{Ended {count} days ago}}'**
  String widgetEndedDaysAgo(int count);

  /// No description provided for @widgetDayXofY.
  ///
  /// In en, this message translates to:
  /// **'Day {current} of {total}'**
  String widgetDayXofY(int current, int total);

  /// No description provided for @widgetTodayHeader.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get widgetTodayHeader;

  /// No description provided for @widgetMoreItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more} other{+{count} more}}'**
  String widgetMoreItems(int count);

  /// No description provided for @addCost.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addCost;

  /// No description provided for @editCost.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editCost;

  /// No description provided for @costAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get costAmount;

  /// No description provided for @costCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get costCurrency;

  /// No description provided for @costReason.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get costReason;

  /// No description provided for @costReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Hotel, Dinner, Train ticket'**
  String get costReasonHint;

  /// No description provided for @costReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get costReasonLabel;

  /// No description provided for @costAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get costAmountInvalid;

  /// No description provided for @costReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a category'**
  String get costReasonRequired;

  /// No description provided for @costsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get costsTotal;

  /// No description provided for @costs.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get costs;

  /// Heading for trip-wide expenses not tied to a specific place or transport
  ///
  /// In en, this message translates to:
  /// **'General expenses'**
  String get generalCosts;

  /// No description provided for @costReasonsSection.
  ///
  /// In en, this message translates to:
  /// **'Expense categories'**
  String get costReasonsSection;

  /// No description provided for @costReasonDisplay.
  ///
  /// In en, this message translates to:
  /// **'Show on expense chips'**
  String get costReasonDisplay;

  /// No description provided for @costReasonDisplayIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get costReasonDisplayIcon;

  /// No description provided for @costReasonDisplayText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get costReasonDisplayText;

  /// No description provided for @costReasonDisplayBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get costReasonDisplayBoth;

  /// No description provided for @costReasonDisplayHelp.
  ///
  /// In en, this message translates to:
  /// **'How categories appear on expense chips — Icon: only the symbol; Text: only the name; Both: symbol and name. The amount is always shown.'**
  String get costReasonDisplayHelp;

  /// No description provided for @costReasonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get costReasonAdd;

  /// No description provided for @costReasonAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get costReasonAddTitle;

  /// No description provided for @costReasonRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get costReasonRenameTitle;

  /// No description provided for @costReasonChooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose an icon'**
  String get costReasonChooseIcon;

  /// No description provided for @costReasonDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get costReasonDeleteConfirmTitle;

  /// No description provided for @costReasonDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{reason}\" will be removed from the category list. Existing expenses keep their text.'**
  String costReasonDeleteConfirmBody(String reason);

  /// No description provided for @noCostReasons.
  ///
  /// In en, this message translates to:
  /// **'No saved categories yet'**
  String get noCostReasons;

  /// No description provided for @transportModesSection.
  ///
  /// In en, this message translates to:
  /// **'Transport modes'**
  String get transportModesSection;

  /// No description provided for @transportModeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add mode'**
  String get transportModeAdd;

  /// No description provided for @transportModeAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New transport mode'**
  String get transportModeAddTitle;

  /// No description provided for @transportModeRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename mode'**
  String get transportModeRenameTitle;

  /// No description provided for @transportModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get transportModeLabel;

  /// No description provided for @transportModeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Gondola'**
  String get transportModeHint;

  /// No description provided for @transportModeChooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose an icon'**
  String get transportModeChooseIcon;

  /// No description provided for @transportModeDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete mode?'**
  String get transportModeDeleteConfirmTitle;

  /// No description provided for @transportModeDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{mode}\" will be removed from the mode list. Existing transport legs that used it keep their route but lose their mode.'**
  String transportModeDeleteConfirmBody(String mode);

  /// No description provided for @noTransportModes.
  ///
  /// In en, this message translates to:
  /// **'No transport modes yet'**
  String get noTransportModes;

  /// No description provided for @costPaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get costPaidBy;

  /// No description provided for @costPaid.
  ///
  /// In en, this message translates to:
  /// **'Already paid'**
  String get costPaid;

  /// No description provided for @costPaidFor.
  ///
  /// In en, this message translates to:
  /// **'Paid for'**
  String get costPaidFor;

  /// No description provided for @costPaidByNone.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get costPaidByNone;

  /// No description provided for @costPaidByName.
  ///
  /// In en, this message translates to:
  /// **'Paid by {name}'**
  String costPaidByName(String name);

  /// Records money handed from one person to another to settle a debt — not an expense
  ///
  /// In en, this message translates to:
  /// **'Record settlement'**
  String get addTransfer;

  /// No description provided for @editTransfer.
  ///
  /// In en, this message translates to:
  /// **'Edit settlement'**
  String get editTransfer;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get transfer;

  /// No description provided for @transfers.
  ///
  /// In en, this message translates to:
  /// **'Settlements'**
  String get transfers;

  /// No description provided for @transferFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transferFrom;

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transferTo;

  /// No description provided for @transferPersonRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a person'**
  String get transferPersonRequired;

  /// No description provided for @transferSamePerson.
  ///
  /// In en, this message translates to:
  /// **'Choose two different people'**
  String get transferSamePerson;

  /// No description provided for @transferAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero'**
  String get transferAmountPositive;

  /// No description provided for @transferBetween.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String transferBetween(String from, String to);

  /// No description provided for @transferHint.
  ///
  /// In en, this message translates to:
  /// **'Settlements move money between people. They change the balances only — never the trip\'s total.'**
  String get transferHint;

  /// No description provided for @currenciesSection.
  ///
  /// In en, this message translates to:
  /// **'Currencies'**
  String get currenciesSection;

  /// No description provided for @currencyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add currency'**
  String get currencyAdd;

  /// No description provided for @currencyAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New currency'**
  String get currencyAddTitle;

  /// No description provided for @currencyEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit currency'**
  String get currencyEditTitle;

  /// No description provided for @currencyCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get currencyCode;

  /// No description provided for @currencyCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. JPY'**
  String get currencyCodeHint;

  /// No description provided for @currencyCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a code'**
  String get currencyCodeRequired;

  /// No description provided for @currencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get currencySymbol;

  /// No description provided for @currencySymbolHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ¥'**
  String get currencySymbolHint;

  /// No description provided for @currencyRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get currencyRate;

  /// No description provided for @currencyRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number above zero'**
  String get currencyRateInvalid;

  /// No description provided for @currencyRateNone.
  ///
  /// In en, this message translates to:
  /// **'No rate set'**
  String get currencyRateNone;

  /// What one unit of a currency is worth in the base currency
  ///
  /// In en, this message translates to:
  /// **'1 {code} = {rate} {base}'**
  String currencyRateExplains(String code, String rate, String base);

  /// No description provided for @currencyRateHelp.
  ///
  /// In en, this message translates to:
  /// **'What one {code} is worth in {base}. Leave empty if you would rather not convert.'**
  String currencyRateHelp(String code, String base);

  /// No description provided for @currencyBase.
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get currencyBase;

  /// No description provided for @currencyBaseHelp.
  ///
  /// In en, this message translates to:
  /// **'Every rate is expressed in the base currency, and it is the one new expenses start in. Totals across several currencies are converted into it — beside the exact per-currency figures, never instead of them.'**
  String get currencyBaseHelp;

  /// No description provided for @currencyMakeBase.
  ///
  /// In en, this message translates to:
  /// **'Make base currency'**
  String get currencyMakeBase;

  /// No description provided for @currencyRebaseWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Change the base currency?'**
  String get currencyRebaseWarnTitle;

  /// No description provided for @currencyRebaseWarnBody.
  ///
  /// In en, this message translates to:
  /// **'\"{code}\" has no exchange rate, so the other currencies\' rates cannot be re-expressed against it and will be cleared. You can enter them again afterwards.'**
  String currencyRebaseWarnBody(String code);

  /// No description provided for @currencyInUse.
  ///
  /// In en, this message translates to:
  /// **'Used by {count, plural, =1{1 expense} other{{count} expenses}}'**
  String currencyInUse(int count);

  /// No description provided for @currencyDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete currency?'**
  String get currencyDeleteConfirmTitle;

  /// No description provided for @currencyDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{code}\" will be removed from the currency list.'**
  String currencyDeleteConfirmBody(String code);

  /// No description provided for @currencyDeleteBlockedInUse.
  ///
  /// In en, this message translates to:
  /// **'\"{code}\" is still used by {count, plural, =1{1 expense} other{{count} expenses}}. An amount cannot be left without a currency.'**
  String currencyDeleteBlockedInUse(String code, int count);

  /// No description provided for @currencyDeleteBlockedBase.
  ///
  /// In en, this message translates to:
  /// **'The base currency cannot be deleted. Make another one the base first.'**
  String get currencyDeleteBlockedBase;

  /// No description provided for @currencyCodeTaken.
  ///
  /// In en, this message translates to:
  /// **'That code is already in the list'**
  String get currencyCodeTaken;

  /// No description provided for @noCurrencies.
  ///
  /// In en, this message translates to:
  /// **'No currencies yet'**
  String get noCurrencies;

  /// No description provided for @peopleSection.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get peopleSection;

  /// No description provided for @noPeople.
  ///
  /// In en, this message translates to:
  /// **'No saved people yet'**
  String get noPeople;

  /// No description provided for @personAdd.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get personAdd;

  /// No description provided for @personAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New person'**
  String get personAddTitle;

  /// No description provided for @personRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename person'**
  String get personRenameTitle;

  /// No description provided for @personLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get personLabel;

  /// No description provided for @personHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Alex'**
  String get personHint;

  /// No description provided for @personDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete person?'**
  String get personDeleteConfirmTitle;

  /// No description provided for @personDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from the people list. Existing expenses keep their payer.'**
  String personDeleteConfirmBody(String name);

  /// No description provided for @personMarkAsMe.
  ///
  /// In en, this message translates to:
  /// **'Mark as me'**
  String get personMarkAsMe;

  /// No description provided for @personIsMe.
  ///
  /// In en, this message translates to:
  /// **'This is me'**
  String get personIsMe;

  /// No description provided for @myCostsTotal.
  ///
  /// In en, this message translates to:
  /// **'My expenses'**
  String get myCostsTotal;

  /// No description provided for @expenseScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get expenseScopeAll;

  /// No description provided for @expenseScopeMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get expenseScopeMine;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @addParticipant.
  ///
  /// In en, this message translates to:
  /// **'Add participant'**
  String get addParticipant;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsAllTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Overall statistics'**
  String get statsAllTripsTitle;

  /// No description provided for @statsOpen.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsOpen;

  /// No description provided for @statsAllTripsOpen.
  ///
  /// In en, this message translates to:
  /// **'Overall statistics'**
  String get statsAllTripsOpen;

  /// No description provided for @statsTabExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get statsTabExpenses;

  /// No description provided for @statsTabTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get statsTabTransport;

  /// No description provided for @statsNoData.
  ///
  /// In en, this message translates to:
  /// **'No expenses to analyze yet'**
  String get statsNoData;

  /// No description provided for @statsNoTransport.
  ///
  /// In en, this message translates to:
  /// **'No transport legs to analyze yet'**
  String get statsNoTransport;

  /// No description provided for @statsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get statsByCategory;

  /// No description provided for @statsByMode.
  ///
  /// In en, this message translates to:
  /// **'By mode'**
  String get statsByMode;

  /// No description provided for @statsScopeLegs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get statsScopeLegs;

  /// No description provided for @statsScopeTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get statsScopeTime;

  /// No description provided for @statsLegs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 leg} other{{count} legs}}'**
  String statsLegs(int count);

  /// No description provided for @statsTotalTime.
  ///
  /// In en, this message translates to:
  /// **'{duration} total'**
  String statsTotalTime(String duration);

  /// No description provided for @statsByPerson.
  ///
  /// In en, this message translates to:
  /// **'By person'**
  String get statsByPerson;

  /// No description provided for @statsScopePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statsScopePaid;

  /// No description provided for @statsScopeShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get statsScopeShare;

  /// No description provided for @statsScopeBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get statsScopeBalances;

  /// No description provided for @statsPaidShort.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statsPaidShort;

  /// No description provided for @statsShareShort.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get statsShareShort;

  /// No description provided for @statsSettleUp.
  ///
  /// In en, this message translates to:
  /// **'Settle up'**
  String get statsSettleUp;

  /// No description provided for @statsSettledUp.
  ///
  /// In en, this message translates to:
  /// **'Everyone\'s even — nothing to settle.'**
  String get statsSettledUp;

  /// No description provided for @statsGetsBack.
  ///
  /// In en, this message translates to:
  /// **'gets back'**
  String get statsGetsBack;

  /// No description provided for @statsOwes.
  ///
  /// In en, this message translates to:
  /// **'owes'**
  String get statsOwes;

  /// No description provided for @statsEven.
  ///
  /// In en, this message translates to:
  /// **'even'**
  String get statsEven;

  /// No description provided for @statsExpenses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense} other{{count} expenses}}'**
  String statsExpenses(int count);

  /// No description provided for @statsPaidAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} paid ({percent}%)'**
  String statsPaidAmount(String amount, int percent);

  /// No description provided for @statsOpenAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} open ({percent}%)'**
  String statsOpenAmount(String amount, int percent);

  /// No description provided for @statsTransfer.
  ///
  /// In en, this message translates to:
  /// **'{from} pays {to}'**
  String statsTransfer(String from, String to);

  /// Button on a suggested settle-up payment: books it as an actual settlement
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get statsRecordSettlement;

  /// No description provided for @statsSettlementSent.
  ///
  /// In en, this message translates to:
  /// **'paid back {amount}'**
  String statsSettlementSent(String amount);

  /// No description provided for @statsSettlementReceived.
  ///
  /// In en, this message translates to:
  /// **'received {amount}'**
  String statsSettlementReceived(String amount);

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @checklistAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add an item…'**
  String get checklistAddHint;

  /// No description provided for @checklistEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get checklistEditTitle;

  /// No description provided for @checklistRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename checklist'**
  String get checklistRenameTitle;

  /// No description provided for @checklistNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New checklist'**
  String get checklistNewTitle;

  /// No description provided for @checklistAdd.
  ///
  /// In en, this message translates to:
  /// **'Add checklist'**
  String get checklistAdd;

  /// No description provided for @checklistDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete checklist?'**
  String get checklistDeleteTitle;

  /// No description provided for @checklistDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" and all its items will be removed.'**
  String checklistDeleteBody(String name);

  /// No description provided for @checklistActions.
  ///
  /// In en, this message translates to:
  /// **'Checklist actions'**
  String get checklistActions;

  /// No description provided for @checklistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete checklist'**
  String get checklistDelete;

  /// No description provided for @checklistDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get checklistDuplicate;

  /// Name given to a checklist duplicated within the same trip.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String checklistCopyTitle(String name);

  /// No description provided for @checklistCopyToTrip.
  ///
  /// In en, this message translates to:
  /// **'Copy to trip…'**
  String get checklistCopyToTrip;

  /// No description provided for @checklistMoveToTrip.
  ///
  /// In en, this message translates to:
  /// **'Move to trip…'**
  String get checklistMoveToTrip;

  /// No description provided for @checklistPickTrip.
  ///
  /// In en, this message translates to:
  /// **'Which trip?'**
  String get checklistPickTrip;

  /// No description provided for @checklistNoOtherTrips.
  ///
  /// In en, this message translates to:
  /// **'There is no other trip to put it in yet.'**
  String get checklistNoOtherTrips;

  /// Confirmation after copying a checklist into another trip.
  ///
  /// In en, this message translates to:
  /// **'Copied to “{trip}”. Ticks aren\'t copied — a list is only reusable empty.'**
  String checklistCopiedTo(String trip);

  /// Confirmation after moving a checklist to another trip.
  ///
  /// In en, this message translates to:
  /// **'Moved to “{trip}”.'**
  String checklistMovedTo(String trip);

  /// No description provided for @moveOrCopy.
  ///
  /// In en, this message translates to:
  /// **'Move or copy'**
  String get moveOrCopy;

  /// No description provided for @moveOrCopyHint.
  ///
  /// In en, this message translates to:
  /// **'Pick this entry up, then choose where to put it down — another day, or one option of a choice.'**
  String get moveOrCopyHint;

  /// No description provided for @moveToDots.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get moveToDots;

  /// No description provided for @copyToDots.
  ///
  /// In en, this message translates to:
  /// **'Copy to…'**
  String get copyToDots;

  /// No description provided for @duplicateEntry.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateEntry;

  /// No description provided for @moveHere.
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get moveHere;

  /// No description provided for @copyHere.
  ///
  /// In en, this message translates to:
  /// **'Copy here'**
  String get copyHere;

  /// Bar shown while an itinerary entry is picked up and waiting to be put down.
  ///
  /// In en, this message translates to:
  /// **'Moving: {entry}'**
  String holdingMove(String entry);

  /// Bar shown while an itinerary entry is picked up to be duplicated elsewhere.
  ///
  /// In en, this message translates to:
  /// **'Copying: {entry}'**
  String holdingCopy(String entry);

  /// No description provided for @holdingHint.
  ///
  /// In en, this message translates to:
  /// **'Tap “Move here” or “Copy here” on any day or option.'**
  String get holdingHint;

  /// No description provided for @untitledEntry.
  ///
  /// In en, this message translates to:
  /// **'Untitled entry'**
  String get untitledEntry;

  /// No description provided for @copiedWithoutCosts.
  ///
  /// In en, this message translates to:
  /// **'Copied. Expenses aren\'t copied — a payment happened only once.'**
  String get copiedWithoutCosts;

  /// Warning after moving or copying an entry into an option that is not the chosen one.
  ///
  /// In en, this message translates to:
  /// **'Put into {option} — it won\'t count toward the trip while another option is chosen.'**
  String putIntoUnchosenOption(String option);

  /// No description provided for @alternatives.
  ///
  /// In en, this message translates to:
  /// **'Alternatives'**
  String get alternatives;

  /// No description provided for @planAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Plan alternatives'**
  String get planAlternatives;

  /// No description provided for @planAlternativesHint.
  ///
  /// In en, this message translates to:
  /// **'Turn this entry into a choice: plan several options and pick the one you go with.'**
  String get planAlternativesHint;

  /// No description provided for @itemInOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Part of an option — it counts toward the trip only while that option is chosen.'**
  String get itemInOptionHint;

  /// No description provided for @decisionDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Choice'**
  String get decisionDefaultLabel;

  /// No description provided for @decisionActions.
  ///
  /// In en, this message translates to:
  /// **'Decision actions'**
  String get decisionActions;

  /// No description provided for @decisionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename choice'**
  String get decisionRename;

  /// No description provided for @decisionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Choice name (optional)'**
  String get decisionNameLabel;

  /// No description provided for @decisionNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Saturday afternoon'**
  String get decisionNameHint;

  /// No description provided for @decisionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete choice'**
  String get decisionDelete;

  /// No description provided for @decisionDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this choice?'**
  String get decisionDeleteQuestion;

  /// No description provided for @decisionDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Every option and all their entries and expenses are deleted.'**
  String get decisionDeleteBody;

  /// No description provided for @optionLetter.
  ///
  /// In en, this message translates to:
  /// **'Option {letter}'**
  String optionLetter(String letter);

  /// No description provided for @optionChosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen'**
  String get optionChosen;

  /// No description provided for @optionChoose.
  ///
  /// In en, this message translates to:
  /// **'Use this option'**
  String get optionChoose;

  /// No description provided for @optionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned in this option yet.'**
  String get optionEmpty;

  /// No description provided for @optionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get optionAdd;

  /// No description provided for @optionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate option'**
  String get optionDuplicate;

  /// No description provided for @optionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename option'**
  String get optionRename;

  /// No description provided for @optionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Option name (optional)'**
  String get optionNameLabel;

  /// No description provided for @optionNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Museum day'**
  String get optionNameHint;

  /// No description provided for @optionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete option'**
  String get optionDelete;

  /// No description provided for @optionDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this option?'**
  String get optionDeleteQuestion;

  /// No description provided for @optionDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its entries and their expenses are deleted with it. The other options are kept.'**
  String get optionDeleteBody;

  /// No description provided for @optionKeepOnly.
  ///
  /// In en, this message translates to:
  /// **'Keep only this option'**
  String get optionKeepOnly;

  /// No description provided for @optionKeepOnlyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Keep only this option?'**
  String get optionKeepOnlyQuestion;

  /// No description provided for @optionKeepOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'Its entries move back into the day and the other options are deleted.'**
  String get optionKeepOnlyBody;

  /// No description provided for @optionPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous option'**
  String get optionPrevious;

  /// No description provided for @optionNext.
  ///
  /// In en, this message translates to:
  /// **'Next option'**
  String get optionNext;

  /// No description provided for @grouping.
  ///
  /// In en, this message translates to:
  /// **'Grouping'**
  String get grouping;

  /// No description provided for @groupWithNext.
  ///
  /// In en, this message translates to:
  /// **'Group with next item'**
  String get groupWithNext;

  /// No description provided for @groupMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move group to…'**
  String get groupMoveTo;

  /// No description provided for @groupCopyTo.
  ///
  /// In en, this message translates to:
  /// **'Copy group to…'**
  String get groupCopyTo;

  /// No description provided for @groupRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get groupRemoveItem;

  /// No description provided for @groupUngroup.
  ///
  /// In en, this message translates to:
  /// **'Ungroup'**
  String get groupUngroup;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name (optional)'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Train to Rome'**
  String get groupNameHint;

  /// No description provided for @groupDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Grouped'**
  String get groupDefaultLabel;

  /// No description provided for @groupSharedExpenses.
  ///
  /// In en, this message translates to:
  /// **'Shared expenses'**
  String get groupSharedExpenses;

  /// No description provided for @groupMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Part of a group — shared expenses apply to all its items.'**
  String get groupMemberHint;

  /// No description provided for @calendarView.
  ///
  /// In en, this message translates to:
  /// **'Calendar view'**
  String get calendarView;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPreviousMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// No description provided for @calendarUndatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Undated trips'**
  String get calendarUndatedTitle;

  /// No description provided for @calendarUndatedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show undated trips'**
  String get calendarUndatedTooltip;

  /// No description provided for @connectionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search connection'**
  String get connectionSearch;

  /// No description provided for @connectionSearchOnline.
  ///
  /// In en, this message translates to:
  /// **'Search online'**
  String get connectionSearchOnline;

  /// No description provided for @connectionFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get connectionFrom;

  /// No description provided for @connectionTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get connectionTo;

  /// No description provided for @connectionPickPlace.
  ///
  /// In en, this message translates to:
  /// **'Search station or place'**
  String get connectionPickPlace;

  /// No description provided for @connectionDepart.
  ///
  /// In en, this message translates to:
  /// **'Depart at'**
  String get connectionDepart;

  /// No description provided for @connectionArrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive by'**
  String get connectionArrive;

  /// No description provided for @connectionBudgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to and from stops'**
  String get connectionBudgetsTitle;

  /// No description provided for @connectionBudgetsHint.
  ///
  /// In en, this message translates to:
  /// **'The first and last stretch only apply when you search from an address rather than a station.'**
  String get connectionBudgetsHint;

  /// No description provided for @connectionBudgetAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get connectionBudgetAuto;

  /// No description provided for @connectionBudgetPre.
  ///
  /// In en, this message translates to:
  /// **'To the first stop'**
  String get connectionBudgetPre;

  /// No description provided for @connectionBudgetPost.
  ///
  /// In en, this message translates to:
  /// **'From the last stop'**
  String get connectionBudgetPost;

  /// No description provided for @connectionBudgetDirect.
  ///
  /// In en, this message translates to:
  /// **'Whole way without public transport'**
  String get connectionBudgetDirect;

  /// No description provided for @connectionSummaryToStop.
  ///
  /// In en, this message translates to:
  /// **'≤{minutes} min to stop'**
  String connectionSummaryToStop(int minutes);

  /// No description provided for @connectionSummaryFromStop.
  ///
  /// In en, this message translates to:
  /// **'≤{minutes} min from stop'**
  String connectionSummaryFromStop(int minutes);

  /// No description provided for @connectionSummaryOwnWay.
  ///
  /// In en, this message translates to:
  /// **'≤{minutes} min on your own'**
  String connectionSummaryOwnWay(int minutes);

  /// No description provided for @connectionByBike.
  ///
  /// In en, this message translates to:
  /// **'Travelling by bike'**
  String get connectionByBike;

  /// No description provided for @connectionByBikeHint.
  ///
  /// In en, this message translates to:
  /// **'Cycle the whole way, or to the first stop.'**
  String get connectionByBikeHint;

  /// No description provided for @connectionBikeOnBoard.
  ///
  /// In en, this message translates to:
  /// **'Bike comes along'**
  String get connectionBikeOnBoard;

  /// No description provided for @connectionBikeOnBoardHint.
  ///
  /// In en, this message translates to:
  /// **'Only services that carry bikes. Many networks publish nothing about this, and then nothing is found.'**
  String get connectionBikeOnBoardHint;

  /// No description provided for @connectionCyclingSpeed.
  ///
  /// In en, this message translates to:
  /// **'Cycling speed'**
  String get connectionCyclingSpeed;

  /// No description provided for @connectionCyclingSpeedHint.
  ///
  /// In en, this message translates to:
  /// **'Used for the parts of the journey you ride.'**
  String get connectionCyclingSpeedHint;

  /// No description provided for @connectionNoBikeConnections.
  ///
  /// In en, this message translates to:
  /// **'No connections that take bikes'**
  String get connectionNoBikeConnections;

  /// No description provided for @connectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get connectionCancelled;

  /// No description provided for @connectionWithoutTransit.
  ///
  /// In en, this message translates to:
  /// **'Without public transport'**
  String get connectionWithoutTransit;

  /// No description provided for @connectionSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No connections found'**
  String get connectionSearchNoResults;

  /// No description provided for @connectionEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get connectionEarlier;

  /// No description provided for @connectionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get connectionLater;

  /// No description provided for @connectionSearchError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the connection service'**
  String get connectionSearchError;

  /// No description provided for @connectionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get connectionRetry;

  /// No description provided for @connectionChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Direct} =1{1 change} other{{count} changes}}'**
  String connectionChanges(int count);

  /// No description provided for @connectionOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search options'**
  String get connectionOptionsTitle;

  /// No description provided for @connectionOptionsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get connectionOptionsReset;

  /// No description provided for @connectionMinTransfer.
  ///
  /// In en, this message translates to:
  /// **'Shortest change'**
  String get connectionMinTransfer;

  /// No description provided for @connectionMinTransferHint.
  ///
  /// In en, this message translates to:
  /// **'No connection with less time than this between arriving and departing again.'**
  String get connectionMinTransferHint;

  /// No description provided for @connectionMinTransferAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get connectionMinTransferAny;

  /// No description provided for @connectionMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String connectionMinutesShort(int minutes);

  /// No description provided for @connectionWalkingSpeed.
  ///
  /// In en, this message translates to:
  /// **'Walking speed'**
  String get connectionWalkingSpeed;

  /// No description provided for @connectionWalkingSpeedHint.
  ///
  /// In en, this message translates to:
  /// **'Used for walking to, from and between stops.'**
  String get connectionWalkingSpeedHint;

  /// No description provided for @connectionSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'{speed} km/h'**
  String connectionSpeedValue(String speed);

  /// No description provided for @connectionSpeedNormal.
  ///
  /// In en, this message translates to:
  /// **'normal'**
  String get connectionSpeedNormal;

  /// No description provided for @connectionMaxTransfers.
  ///
  /// In en, this message translates to:
  /// **'Most changes'**
  String get connectionMaxTransfers;

  /// No description provided for @connectionMaxTransfersAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get connectionMaxTransfersAny;

  /// No description provided for @connectionMaxTransfersDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get connectionMaxTransfersDirect;

  /// No description provided for @connectionMaxTransfersAtMost.
  ///
  /// In en, this message translates to:
  /// **'≤{count}'**
  String connectionMaxTransfersAtMost(int count);

  /// No description provided for @connectionSummaryMinTransfer.
  ///
  /// In en, this message translates to:
  /// **'changes ≥ {minutes} min'**
  String connectionSummaryMinTransfer(int minutes);

  /// No description provided for @connectionSummaryMaxChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{direct only} =1{max 1 change} other{max {count} changes}}'**
  String connectionSummaryMaxChanges(int count);

  /// No description provided for @connectionModesTitle.
  ///
  /// In en, this message translates to:
  /// **'Means of transport'**
  String get connectionModesTitle;

  /// No description provided for @connectionModesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only these are used when planning the connection.'**
  String get connectionModesSubtitle;

  /// No description provided for @connectionModesAll.
  ///
  /// In en, this message translates to:
  /// **'All means of transport'**
  String get connectionModesAll;

  /// No description provided for @connectionModesNone.
  ///
  /// In en, this message translates to:
  /// **'No means of transport'**
  String get connectionModesNone;

  /// No description provided for @connectionModeLongDistance.
  ///
  /// In en, this message translates to:
  /// **'Long-distance trains'**
  String get connectionModeLongDistance;

  /// No description provided for @connectionModeRegional.
  ///
  /// In en, this message translates to:
  /// **'Regional trains'**
  String get connectionModeRegional;

  /// No description provided for @connectionModeCity.
  ///
  /// In en, this message translates to:
  /// **'Underground & tram'**
  String get connectionModeCity;

  /// No description provided for @connectionModeBus.
  ///
  /// In en, this message translates to:
  /// **'Bus & coach'**
  String get connectionModeBus;

  /// No description provided for @connectionModeFerry.
  ///
  /// In en, this message translates to:
  /// **'Ferry'**
  String get connectionModeFerry;

  /// No description provided for @connectionModeAir.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get connectionModeAir;

  /// No description provided for @connectionModeOther.
  ///
  /// In en, this message translates to:
  /// **'Cable car & other'**
  String get connectionModeOther;

  /// No description provided for @connectionAddToDay.
  ///
  /// In en, this message translates to:
  /// **'Add to day'**
  String get connectionAddToDay;

  /// No description provided for @connectionAdded.
  ///
  /// In en, this message translates to:
  /// **'Connection added'**
  String get connectionAdded;

  /// No description provided for @connectionAttribution.
  ///
  /// In en, this message translates to:
  /// **'Data © OpenStreetMap contributors, via Transitous'**
  String get connectionAttribution;

  /// No description provided for @transportModeRestoreBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Restore built-in'**
  String get transportModeRestoreBuiltin;

  /// No description provided for @platformShort.
  ///
  /// In en, this message translates to:
  /// **'Pl. {track}'**
  String platformShort(String track);

  /// No description provided for @directionTo.
  ///
  /// In en, this message translates to:
  /// **'to {destination}'**
  String directionTo(String destination);

  /// No description provided for @liveTimesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Update live times'**
  String get liveTimesRefresh;

  /// No description provided for @liveTimesNone.
  ///
  /// In en, this message translates to:
  /// **'No live times to update'**
  String get liveTimesNone;

  /// No description provided for @liveTimesCancelled.
  ///
  /// In en, this message translates to:
  /// **'This service has been cancelled'**
  String get liveTimesCancelled;

  /// No description provided for @liveTimesError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch live times'**
  String get liveTimesError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
