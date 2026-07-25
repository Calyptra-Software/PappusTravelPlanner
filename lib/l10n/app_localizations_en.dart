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
  String get searchTrips => 'Search trips';

  @override
  String get searchTripsHint => 'Title, destination or notes';

  @override
  String get filterTrips => 'Filter and sort';

  @override
  String get filterAndSort => 'Filter & sort';

  @override
  String get clearFilters => 'Clear';

  @override
  String get statusLabel => 'Status';

  @override
  String get tripStatusUpcoming => 'Upcoming';

  @override
  String get tripStatusOngoing => 'Ongoing';

  @override
  String get tripStatusPast => 'Past';

  @override
  String get tripStatusUndated => 'No dates';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortDateAsc => 'Date (soonest)';

  @override
  String get sortDateDesc => 'Date (latest)';

  @override
  String get sortNameAsc => 'Name (A–Z)';

  @override
  String get sortCreatedDesc => 'Recently added';

  @override
  String get sortExpenseDesc => 'Expenses (highest)';

  @override
  String get sortExpenseAsc => 'Expenses (lowest)';

  @override
  String get anyDate => 'Any';

  @override
  String get noTripsFoundTitle => 'No matching trips';

  @override
  String noTripsFoundBody(String query) {
    return 'No trips match “$query”.';
  }

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
  String get shareTrip => 'Share trip';

  @override
  String get shareTripSaved => 'Trip file saved.';

  @override
  String get shareTripFailed => 'Could not share this trip.';

  @override
  String get exportPdf => 'Export as PDF';

  @override
  String get exportPdfFailed => 'Could not export this trip as PDF.';

  @override
  String get exportIcs => 'Export to calendar';

  @override
  String get exportIcsFailed => 'Could not export this trip to a calendar.';

  @override
  String pdfOtherOptions(String options) {
    return 'Other options: $options';
  }

  @override
  String pdfExportedOn(String date) {
    return 'Exported $date';
  }

  @override
  String get importTrip => 'Import trip';

  @override
  String get importTripSuccess => 'Trip imported.';

  @override
  String get importTripInvalid => 'This file isn\'t a valid shared trip.';

  @override
  String get importTripTooNew =>
      'This trip was shared from a newer version of the app. Please update to import it.';

  @override
  String get importTripFailed => 'Could not import this trip.';

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
  String get customColour => 'Custom colour';

  @override
  String get pickColour => 'Pick a colour';

  @override
  String get hexColour => 'Hex';

  @override
  String get invalidHexColour => 'Enter a valid hex colour, e.g. 1565C0';

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
  String get now => 'Now';

  @override
  String get today => 'Today';

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
  String get plannedTimes => 'Planned';

  @override
  String get actualTimes => 'Actual';

  @override
  String get actualTimesHint =>
      'What really happened. The timeline shows how late or early it ran.';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get search => 'Search';

  @override
  String get searchNoMatches => 'No matches';

  @override
  String searchAdd(String query) {
    return 'Add “$query”';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'German';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

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
  String get dbNewEmpty => 'New empty database';

  @override
  String get dbNewEmptySubtitle => 'Start over with no trips';

  @override
  String get dbNewEmptyConfirmTitle => 'Start a new database?';

  @override
  String get dbNewEmptyConfirmBody =>
      'This deletes all current trips and starts from an empty database. It can\'t be undone — export a copy first if you want to keep the data.';

  @override
  String get dbNewEmptyAction => 'Start new';

  @override
  String get dbNewEmptyDone => 'Started a new empty database';

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
  String get widgetTomorrow => 'Starts tomorrow';

  @override
  String get widgetEndedYesterday => 'Ended yesterday';

  @override
  String widgetEndedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ended $count days ago',
      one: 'Ended 1 day ago',
    );
    return '$_temp0';
  }

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
  String get transportModesSection => 'Transport modes';

  @override
  String get transportModeAdd => 'Add mode';

  @override
  String get transportModeAddTitle => 'New transport mode';

  @override
  String get transportModeRenameTitle => 'Rename mode';

  @override
  String get transportModeLabel => 'Name';

  @override
  String get transportModeHint => 'e.g. Gondola';

  @override
  String get transportModeChooseIcon => 'Choose an icon';

  @override
  String get transportModeDeleteConfirmTitle => 'Delete mode?';

  @override
  String transportModeDeleteConfirmBody(String mode) {
    return '\"$mode\" will be removed from the mode list. Existing transport legs that used it keep their route but lose their mode.';
  }

  @override
  String get noTransportModes => 'No transport modes yet';

  @override
  String get costPaidBy => 'Paid by';

  @override
  String get costPaid => 'Already paid';

  @override
  String get costPaidFor => 'Paid for';

  @override
  String get costPaidByNone => 'Unassigned';

  @override
  String costPaidByName(String name) {
    return 'Paid by $name';
  }

  @override
  String get addTransfer => 'Record settlement';

  @override
  String get editTransfer => 'Edit settlement';

  @override
  String get transfer => 'Settlement';

  @override
  String get transfers => 'Settlements';

  @override
  String get transferFrom => 'From';

  @override
  String get transferTo => 'To';

  @override
  String get transferPersonRequired => 'Choose a person';

  @override
  String get transferSamePerson => 'Choose two different people';

  @override
  String get transferAmountPositive => 'Enter an amount above zero';

  @override
  String transferBetween(String from, String to) {
    return '$from → $to';
  }

  @override
  String get transferHint =>
      'Settlements move money between people. They change the balances only — never the trip\'s total.';

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
  String get personMarkAsMe => 'Mark as me';

  @override
  String get personIsMe => 'This is me';

  @override
  String get myCostsTotal => 'My expenses';

  @override
  String get expenseScopeAll => 'All';

  @override
  String get expenseScopeMine => 'Mine';

  @override
  String get participants => 'Participants';

  @override
  String get addParticipant => 'Add participant';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsAllTripsTitle => 'Overall statistics';

  @override
  String get statsOpen => 'Statistics';

  @override
  String get statsAllTripsOpen => 'Overall statistics';

  @override
  String get statsTabExpenses => 'Expenses';

  @override
  String get statsTabTransport => 'Transport';

  @override
  String get statsNoData => 'No expenses to analyze yet';

  @override
  String get statsNoTransport => 'No transport legs to analyze yet';

  @override
  String get statsByCategory => 'By category';

  @override
  String get statsByMode => 'By mode';

  @override
  String get statsScopeLegs => 'Legs';

  @override
  String get statsScopeTime => 'Time';

  @override
  String statsLegs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count legs',
      one: '1 leg',
    );
    return '$_temp0';
  }

  @override
  String statsTotalTime(String duration) {
    return '$duration total';
  }

  @override
  String get statsByPerson => 'By person';

  @override
  String get statsScopePaid => 'Paid';

  @override
  String get statsScopeShare => 'Share';

  @override
  String get statsScopeBalances => 'Balances';

  @override
  String get statsPaidShort => 'Paid';

  @override
  String get statsShareShort => 'Share';

  @override
  String get statsSettleUp => 'Settle up';

  @override
  String get statsSettledUp => 'Everyone\'s even — nothing to settle.';

  @override
  String get statsGetsBack => 'gets back';

  @override
  String get statsOwes => 'owes';

  @override
  String get statsEven => 'even';

  @override
  String statsExpenses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '$_temp0';
  }

  @override
  String statsPaidAmount(String amount, int percent) {
    return '$amount paid ($percent%)';
  }

  @override
  String statsOpenAmount(String amount, int percent) {
    return '$amount open ($percent%)';
  }

  @override
  String statsTransfer(String from, String to) {
    return '$from pays $to';
  }

  @override
  String get statsRecordSettlement => 'Record';

  @override
  String statsSettlementSent(String amount) {
    return 'paid back $amount';
  }

  @override
  String statsSettlementReceived(String amount) {
    return 'received $amount';
  }

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

  @override
  String get checklistActions => 'Checklist actions';

  @override
  String get checklistDelete => 'Delete checklist';

  @override
  String get checklistDuplicate => 'Duplicate';

  @override
  String checklistCopyTitle(String name) {
    return '$name (copy)';
  }

  @override
  String get checklistCopyToTrip => 'Copy to trip…';

  @override
  String get checklistMoveToTrip => 'Move to trip…';

  @override
  String get checklistPickTrip => 'Which trip?';

  @override
  String get checklistNoOtherTrips =>
      'There is no other trip to put it in yet.';

  @override
  String checklistCopiedTo(String trip) {
    return 'Copied to “$trip”. Ticks aren\'t copied — a list is only reusable empty.';
  }

  @override
  String checklistMovedTo(String trip) {
    return 'Moved to “$trip”.';
  }

  @override
  String get moveOrCopy => 'Move or copy';

  @override
  String get moveOrCopyHint =>
      'Pick this entry up, then choose where to put it down — another day, or one option of a choice.';

  @override
  String get moveToDots => 'Move to…';

  @override
  String get copyToDots => 'Copy to…';

  @override
  String get duplicateEntry => 'Duplicate';

  @override
  String get moveHere => 'Move here';

  @override
  String get copyHere => 'Copy here';

  @override
  String holdingMove(String entry) {
    return 'Moving: $entry';
  }

  @override
  String holdingCopy(String entry) {
    return 'Copying: $entry';
  }

  @override
  String get holdingHint =>
      'Tap “Move here” or “Copy here” on any day or option.';

  @override
  String get untitledEntry => 'Untitled entry';

  @override
  String get copiedWithoutCosts =>
      'Copied. Expenses aren\'t copied — a payment happened only once.';

  @override
  String putIntoUnchosenOption(String option) {
    return 'Put into $option — it won\'t count toward the trip while another option is chosen.';
  }

  @override
  String get alternatives => 'Alternatives';

  @override
  String get planAlternatives => 'Plan alternatives';

  @override
  String get planAlternativesHint =>
      'Turn this entry into a choice: plan several options and pick the one you go with.';

  @override
  String get itemInOptionHint =>
      'Part of an option — it counts toward the trip only while that option is chosen.';

  @override
  String get decisionDefaultLabel => 'Choice';

  @override
  String get decisionActions => 'Decision actions';

  @override
  String get decisionRename => 'Rename choice';

  @override
  String get decisionNameLabel => 'Choice name (optional)';

  @override
  String get decisionNameHint => 'e.g. Saturday afternoon';

  @override
  String get decisionDelete => 'Delete choice';

  @override
  String get decisionDeleteQuestion => 'Delete this choice?';

  @override
  String get decisionDeleteBody =>
      'Every option and all their entries and expenses are deleted.';

  @override
  String optionLetter(String letter) {
    return 'Option $letter';
  }

  @override
  String get optionChosen => 'Chosen';

  @override
  String get optionChoose => 'Use this option';

  @override
  String get optionEmpty => 'Nothing planned in this option yet.';

  @override
  String get optionAdd => 'Add option';

  @override
  String get optionDuplicate => 'Duplicate option';

  @override
  String get optionRename => 'Rename option';

  @override
  String get optionNameLabel => 'Option name (optional)';

  @override
  String get optionNameHint => 'e.g. Museum day';

  @override
  String get optionDelete => 'Delete option';

  @override
  String get optionDeleteQuestion => 'Delete this option?';

  @override
  String get optionDeleteBody =>
      'Its entries and their expenses are deleted with it. The other options are kept.';

  @override
  String get optionKeepOnly => 'Keep only this option';

  @override
  String get optionKeepOnlyQuestion => 'Keep only this option?';

  @override
  String get optionKeepOnlyBody =>
      'Its entries move back into the day and the other options are deleted.';

  @override
  String get optionPrevious => 'Previous option';

  @override
  String get optionNext => 'Next option';

  @override
  String get grouping => 'Grouping';

  @override
  String get groupWithNext => 'Group with next item';

  @override
  String get groupMoveTo => 'Move group to…';

  @override
  String get groupCopyTo => 'Copy group to…';

  @override
  String get groupRemoveItem => 'Remove from group';

  @override
  String get groupUngroup => 'Ungroup';

  @override
  String get groupNameLabel => 'Group name (optional)';

  @override
  String get groupNameHint => 'e.g. Train to Rome';

  @override
  String get groupDefaultLabel => 'Grouped';

  @override
  String get groupSharedExpenses => 'Shared expenses';

  @override
  String get groupMemberHint =>
      'Part of a group — shared expenses apply to all its items.';

  @override
  String get calendarView => 'Calendar view';

  @override
  String get listView => 'List view';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarUndatedTitle => 'Undated trips';

  @override
  String get calendarUndatedTooltip => 'Show undated trips';
}
