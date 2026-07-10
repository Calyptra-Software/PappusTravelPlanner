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
    Locale('de'),
    Locale('en'),
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

  /// No description provided for @widgetToday.
  ///
  /// In en, this message translates to:
  /// **'Starts today'**
  String get widgetToday;

  /// No description provided for @widgetTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Starts tomorrow'**
  String get widgetTomorrow;

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

  /// No description provided for @costReasonNew.
  ///
  /// In en, this message translates to:
  /// **'New category…'**
  String get costReasonNew;

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

  /// No description provided for @costPaidByNew.
  ///
  /// In en, this message translates to:
  /// **'New person…'**
  String get costPaidByNew;

  /// No description provided for @costPaidByName.
  ///
  /// In en, this message translates to:
  /// **'Paid by {name}'**
  String costPaidByName(String name);

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
  /// **'Expense statistics'**
  String get statsTitle;

  /// No description provided for @statsOpen.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsOpen;

  /// No description provided for @statsNoData.
  ///
  /// In en, this message translates to:
  /// **'No expenses to analyze yet'**
  String get statsNoData;

  /// No description provided for @statsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get statsByCategory;

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
