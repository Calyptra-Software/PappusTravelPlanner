// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Travel Planner';

  @override
  String get tripsTitle => 'My Trips';

  @override
  String get newTrip => 'New trip';

  @override
  String get noTripsTitle => 'No trips yet';

  @override
  String get noTripsBody => 'Tap “New trip” to plan your first adventure.';

  @override
  String genericError(String error) {
    return 'Something went wrong:\n$error';
  }

  @override
  String days(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String entries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get datesNotSet => 'Dates not set';

  @override
  String until(String date) {
    return 'Until $date';
  }

  @override
  String get editTrip => 'Edit trip';

  @override
  String get fieldTitle => 'Title';

  @override
  String get titleHint => 'e.g. Summer in Italy';

  @override
  String get titleValidator => 'Enter a title';

  @override
  String get fieldDestination => 'Destination';

  @override
  String get destinationHint => 'e.g. Rome, Florence';

  @override
  String get fieldDates => 'Dates';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get accentColour => 'Accent colour';

  @override
  String get createTrip => 'Create trip';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get itineraryTitle => 'Itinerary';

  @override
  String get deleteTrip => 'Delete trip';

  @override
  String get deleteTripQuestion => 'Delete trip?';

  @override
  String get deleteTripBody =>
      'This will permanently remove the trip and its whole itinerary.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get nothingPlanned => 'Nothing planned yet.';

  @override
  String get addPlace => 'Add place';

  @override
  String addArrival(String place) {
    return 'Add $place';
  }

  @override
  String get addTransport => 'Add transport';

  @override
  String get hideEntries => 'Hide entries';

  @override
  String get showEntries => 'Show entries';

  @override
  String get editPlace => 'Edit place';

  @override
  String get editTransport => 'Edit transport';

  @override
  String get fieldMode => 'Mode';

  @override
  String get fieldFrom => 'From';

  @override
  String get fieldTo => 'To';

  @override
  String get fieldPlace => 'Place';

  @override
  String get placeHint => 'e.g. Colosseum';

  @override
  String get placeValidator => 'Enter a place';

  @override
  String get fromToValidator => 'Enter at least a from or to location';

  @override
  String get transportLabelOptional => 'Label (optional)';

  @override
  String get noteTitleOptional => 'Note title (optional)';

  @override
  String get fieldDay => 'Day';

  @override
  String get timeDeparts => 'Departs';

  @override
  String get timeArrives => 'Arrives';

  @override
  String get timeStart => 'Start';

  @override
  String get timeEnd => 'End';

  @override
  String get setTime => 'Set time';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'German';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get databaseSection => 'Database';

  @override
  String get currentDatabase => 'Current database';

  @override
  String get dbOpen => 'Open database…';

  @override
  String get dbOpenSubtitle => 'Point the app at an existing .sqlite file';

  @override
  String get dbNew => 'New database…';

  @override
  String get dbNewSubtitle => 'Create an empty database at a chosen location';

  @override
  String get dbImport => 'Import database…';

  @override
  String get dbImportSubtitle => 'Replace the current data with a .sqlite file';

  @override
  String get dbExport => 'Export database…';

  @override
  String get dbExportSubtitle => 'Save a copy of the current database';

  @override
  String get dbReset => 'Reset to default';

  @override
  String get dbResetSubtitle => 'Use the app\'s default database location';

  @override
  String get dbImportConfirmTitle => 'Import database?';

  @override
  String get dbImportConfirmBody =>
      'This replaces all current trips with the contents of the selected file. It can\'t be undone.';

  @override
  String get dbImportAction => 'Import';

  @override
  String get dbOpened => 'Database opened';

  @override
  String get dbCreated => 'New database created';

  @override
  String get dbImported => 'Database imported';

  @override
  String get dbExported => 'Database exported';

  @override
  String get dbResetDone => 'Switched to the default database';

  @override
  String dbError(String error) {
    return 'Couldn\'t complete the operation: $error';
  }

  @override
  String get modeWalk => 'Walk';

  @override
  String get modeBike => 'Bike';

  @override
  String get modeCar => 'Car';

  @override
  String get modeTaxi => 'Taxi';

  @override
  String get modeBus => 'Bus';

  @override
  String get modeTrain => 'Train';

  @override
  String get modeTram => 'Tram';

  @override
  String get modeSubway => 'Subway';

  @override
  String get modeFerry => 'Ferry';

  @override
  String get modeFlight => 'Flight';

  @override
  String get modeOther => 'Other';

  @override
  String get modeSki => 'Ski';

  @override
  String get widgetNoTripsTitle => 'No trips yet';

  @override
  String get widgetNoTripsBody => 'Tap to plan your next adventure';

  @override
  String widgetInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get widgetToday => 'Starts today';

  @override
  String get widgetTomorrow => 'Starts tomorrow';

  @override
  String widgetDayXofY(int current, int total) {
    return 'Day $current of $total';
  }

  @override
  String get widgetTodayHeader => 'Today';

  @override
  String widgetMoreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String get addCost => 'Add expense';

  @override
  String get editCost => 'Edit expense';

  @override
  String get costAmount => 'Amount';

  @override
  String get costCurrency => 'Currency';

  @override
  String get costReason => 'Category';

  @override
  String get costReasonNew => 'New category…';

  @override
  String get costReasonHint => 'e.g. Hotel, Dinner, Train ticket';

  @override
  String get costReasonLabel => 'Category name';

  @override
  String get costAmountInvalid => 'Enter a valid amount';

  @override
  String get costReasonRequired => 'Enter a category';

  @override
  String get costsTotal => 'Total';

  @override
  String get costs => 'Expenses';

  @override
  String get generalCosts => 'General expenses';

  @override
  String get costReasonsSection => 'Expense categories';

  @override
  String get costReasonDisplay => 'Show on expense chips';

  @override
  String get costReasonDisplayIcon => 'Icon';

  @override
  String get costReasonDisplayText => 'Text';

  @override
  String get costReasonDisplayBoth => 'Both';

  @override
  String get costReasonDisplayHelp =>
      'How categories appear on expense chips — Icon: only the symbol; Text: only the name; Both: symbol and name. The amount is always shown.';

  @override
  String get costReasonAdd => 'Add category';

  @override
  String get costReasonAddTitle => 'New category';

  @override
  String get costReasonRenameTitle => 'Rename category';

  @override
  String get costReasonChooseIcon => 'Choose an icon';

  @override
  String get costReasonDeleteConfirmTitle => 'Delete category?';

  @override
  String costReasonDeleteConfirmBody(String reason) {
    return '\"$reason\" will be removed from the category list. Existing expenses keep their text.';
  }

  @override
  String get noCostReasons => 'No saved categories yet';

  @override
  String get costPaidBy => 'Paid by';

  @override
  String get costPaidFor => 'Paid for';

  @override
  String get costPaidByNone => 'Unassigned';

  @override
  String get costPaidByNew => 'New person…';

  @override
  String costPaidByName(String name) {
    return 'Paid by $name';
  }

  @override
  String get peopleSection => 'People';

  @override
  String get noPeople => 'No saved people yet';

  @override
  String get personAdd => 'Add person';

  @override
  String get personAddTitle => 'New person';

  @override
  String get personRenameTitle => 'Rename person';

  @override
  String get personLabel => 'Name';

  @override
  String get personHint => 'e.g. Alex';

  @override
  String get personDeleteConfirmTitle => 'Delete person?';

  @override
  String personDeleteConfirmBody(String name) {
    return '\"$name\" will be removed from the people list. Existing expenses keep their payer.';
  }

  @override
  String get participants => 'Participants';

  @override
  String get addParticipant => 'Add participant';

  @override
  String get checklist => 'Checklist';

  @override
  String get checklistAddHint => 'Add an item…';

  @override
  String get checklistEditTitle => 'Edit item';

  @override
  String get checklistRenameTitle => 'Rename checklist';

  @override
  String get checklistNewTitle => 'New checklist';

  @override
  String get checklistAdd => 'Add checklist';

  @override
  String get checklistDeleteTitle => 'Delete checklist?';

  @override
  String checklistDeleteBody(String name) {
    return '\"$name\" and all its items will be removed.';
  }
}
