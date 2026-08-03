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
  String get exportAction => 'Export';

  @override
  String get pdfSectionsTitle => 'What goes into the PDF';

  @override
  String get pdfSectionsSubtitle =>
      'The trip\'s name, dates and participants are always included.';

  @override
  String get pdfSectionEmpty => 'Nothing recorded';

  @override
  String get pdfInclSettlements => 'Settlements included';

  @override
  String pdfLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists',
      one: '1 list',
    );
    return '$_temp0';
  }

  @override
  String pdfItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

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
  String get currenciesSection => 'Currencies';

  @override
  String get currencyAdd => 'Add currency';

  @override
  String get currencyAddTitle => 'New currency';

  @override
  String get currencyEditTitle => 'Edit currency';

  @override
  String get currencyCode => 'Code';

  @override
  String get currencyCodeHint => 'e.g. JPY';

  @override
  String get currencyCodeRequired => 'Enter a code';

  @override
  String get currencySymbol => 'Symbol';

  @override
  String get currencySymbolHint => 'e.g. ¥';

  @override
  String get currencyRate => 'Exchange rate';

  @override
  String get currencyRateInvalid => 'Enter a number above zero';

  @override
  String get currencyRateNone => 'No rate set';

  @override
  String currencyRateExplains(String code, String rate, String base) {
    return '1 $code = $rate $base';
  }

  @override
  String currencyRateHelp(String code, String base) {
    return 'What one $code is worth in $base. Leave empty if you would rather not convert.';
  }

  @override
  String get currencyBase => 'Base currency';

  @override
  String get currencyBaseHelp =>
      'Every rate is expressed in the base currency, and it is the one new expenses start in. Totals across several currencies are converted into it — beside the exact per-currency figures, never instead of them.';

  @override
  String get currencyMakeBase => 'Make base currency';

  @override
  String get currencyRebaseWarnTitle => 'Change the base currency?';

  @override
  String currencyRebaseWarnBody(String code) {
    return '\"$code\" has no exchange rate, so the other currencies\' rates cannot be re-expressed against it and will be cleared. You can enter them again afterwards.';
  }

  @override
  String currencyInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return 'Used by $_temp0';
  }

  @override
  String get currencyDeleteConfirmTitle => 'Delete currency?';

  @override
  String currencyDeleteConfirmBody(String code) {
    return '\"$code\" will be removed from the currency list.';
  }

  @override
  String currencyDeleteBlockedInUse(String code, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '\"$code\" is still used by $_temp0. An amount cannot be left without a currency.';
  }

  @override
  String get currencyDeleteBlockedBase =>
      'The base currency cannot be deleted. Make another one the base first.';

  @override
  String get currencyCodeTaken => 'That code is already in the list';

  @override
  String get noCurrencies => 'No currencies yet';

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

  @override
  String get connectionSearch => 'Search connection';

  @override
  String get connectionSearchOnline => 'Search online';

  @override
  String get connectionFrom => 'From';

  @override
  String get connectionTo => 'To';

  @override
  String get connectionVia => 'Via stop';

  @override
  String get connectionViaAdd => 'Add via stop';

  @override
  String get connectionViaRemove => 'Remove via stop';

  @override
  String get connectionViaHint => 'Only stations can be a via stop.';

  @override
  String get connectionViaStay => 'Stay at least';

  @override
  String get connectionViaStayNone => 'No minimum';

  @override
  String get connectionPickPlace => 'Search station or place';

  @override
  String get connectionPickStop => 'Search station';

  @override
  String get connectionDepart => 'Depart at';

  @override
  String get connectionArrive => 'Arrive by';

  @override
  String get connectionBudgetsTitle => 'Time to and from stops';

  @override
  String get connectionBudgetsHint =>
      'The first and last stretch only apply when you search from an address rather than a station.';

  @override
  String get connectionBudgetAuto => 'Auto';

  @override
  String get connectionBudgetPre => 'To the first stop';

  @override
  String get connectionBudgetPost => 'From the last stop';

  @override
  String get connectionBudgetDirect => 'Whole way without public transport';

  @override
  String connectionSummaryToStop(int minutes) {
    return '≤$minutes min to stop';
  }

  @override
  String connectionSummaryFromStop(int minutes) {
    return '≤$minutes min from stop';
  }

  @override
  String connectionSummaryOwnWay(int minutes) {
    return '≤$minutes min on your own';
  }

  @override
  String get connectionWheelchair => 'Wheelchair accessible';

  @override
  String get connectionWheelchairHint =>
      'Step-free walking and changes, and only services marked as accessible. Many networks publish nothing about this, and then little or nothing is found.';

  @override
  String get connectionNoAccessibleConnections =>
      'No step-free connections found';

  @override
  String get connectionByBike => 'Travelling by bike';

  @override
  String get connectionByBikeHint =>
      'Cycle the whole way, or to the first stop.';

  @override
  String get connectionBikeOnBoard => 'Bike comes along';

  @override
  String get connectionBikeOnBoardHint =>
      'Only services that carry bikes. Many networks publish nothing about this, and then nothing is found.';

  @override
  String get connectionCyclingSpeed => 'Cycling speed';

  @override
  String get connectionCyclingSpeedHint =>
      'Used for the parts of the journey you ride.';

  @override
  String get connectionNoBikeConnections => 'No connections that take bikes';

  @override
  String get connectionCancelled => 'Cancelled';

  @override
  String get connectionWithoutTransit => 'Without public transport';

  @override
  String get connectionSearchNoResults => 'No connections found';

  @override
  String get connectionEarlier => 'Earlier';

  @override
  String get connectionLater => 'Later';

  @override
  String get connectionSearchError => 'Couldn\'t reach the connection service';

  @override
  String get connectionRetry => 'Retry';

  @override
  String connectionChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
      zero: 'Direct',
    );
    return '$_temp0';
  }

  @override
  String connectionChangeIn(int minutes, String place) {
    return '$minutes min change in $place';
  }

  @override
  String connectionChangeBetween(int minutes, String from, String to) {
    return '$minutes min change: $from → $to';
  }

  @override
  String connectionChangeNow(int minutes) {
    return 'now $minutes min';
  }

  @override
  String get connectionOptionsTitle => 'Search options';

  @override
  String get connectionOptionsReset => 'Reset';

  @override
  String get connectionMinTransfer => 'Shortest change';

  @override
  String get connectionMinTransferHint =>
      'No connection with less time than this between arriving and departing again.';

  @override
  String get connectionMinTransferAny => 'Any';

  @override
  String connectionMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String connectionHoursShort(int hours) {
    return '$hours h';
  }

  @override
  String connectionHoursMinutesShort(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get connectionWalkingSpeed => 'Walking speed';

  @override
  String get connectionWalkingSpeedHint =>
      'Used for walking to, from and between stops.';

  @override
  String connectionSpeedValue(String speed) {
    return '$speed km/h';
  }

  @override
  String get connectionSpeedNormal => 'normal';

  @override
  String get connectionMaxTransfers => 'Most changes';

  @override
  String get connectionMaxTransfersAny => 'Any';

  @override
  String get connectionMaxTransfersDirect => 'Direct';

  @override
  String connectionMaxTransfersAtMost(int count) {
    return '≤$count';
  }

  @override
  String connectionSummaryMinTransfer(int minutes) {
    return 'changes ≥ $minutes min';
  }

  @override
  String connectionSummaryMaxChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'max $count changes',
      one: 'max 1 change',
      zero: 'direct only',
    );
    return '$_temp0';
  }

  @override
  String get connectionModesTitle => 'Means of transport';

  @override
  String get connectionModesSubtitle =>
      'Only these are used when planning the connection.';

  @override
  String get connectionModesAll => 'All means of transport';

  @override
  String get connectionModesNone => 'No means of transport';

  @override
  String get connectionModeLongDistance => 'Long-distance trains';

  @override
  String get connectionModeRegional => 'Regional trains';

  @override
  String get connectionModeCity => 'Underground & tram';

  @override
  String get connectionModeBus => 'Bus & coach';

  @override
  String get connectionModeFerry => 'Ferry';

  @override
  String get connectionModeAir => 'Flights';

  @override
  String get connectionModeOther => 'Cable car & other';

  @override
  String get connectionAddToDay => 'Add to day';

  @override
  String get connectionAdded => 'Connection added';

  @override
  String get attributionOsm => '© OpenStreetMap contributors';

  @override
  String get attributionTransitous => 'Timetable data via Transitous';

  @override
  String get dataSourcesSection => 'Data sources';

  @override
  String get dataSourcesNote =>
      'Connection search uses openly licensed timetable and map data:';

  @override
  String linkOpenFailed(String url) {
    return 'Could not open $url';
  }

  @override
  String get transportModeRestoreBuiltin => 'Restore built-in';

  @override
  String platformShort(String track) {
    return 'Pl. $track';
  }

  @override
  String platformFromShort(String track) {
    return 'from Pl. $track';
  }

  @override
  String platformToShort(String track) {
    return 'to Pl. $track';
  }

  @override
  String directionTo(String destination) {
    return 'to $destination';
  }

  @override
  String connectionStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String connectionStopsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops cancelled',
      one: '1 stop cancelled',
    );
    return '$_temp0';
  }

  @override
  String connectionChangePlace(String place) {
    return 'Change in $place';
  }

  @override
  String connectionChangePlaces(String from, String to) {
    return 'Change: $from → $to';
  }

  @override
  String get journeyDetails => 'Show journey';

  @override
  String get liveTimesRefresh => 'Update live times';

  @override
  String get liveTimesNone => 'No live times to update';

  @override
  String get liveTimesCancelled => 'This service has been cancelled';

  @override
  String get liveTimesError => 'Couldn\'t fetch live times';

  @override
  String get tripKindTrip => 'Trip';

  @override
  String get tripKindRoutine => 'Routine';

  @override
  String get tripKindTripBody => 'A trip on the calendar — one day or many.';

  @override
  String get tripKindRoutineBody =>
      'A reusable plan with no dates. Stamp a real trip out of it whenever you take it.';

  @override
  String get newRoutine => 'New routine';

  @override
  String get editRoutine => 'Edit routine';

  @override
  String get routinesTitle => 'Routines';

  @override
  String get noRoutinesTitle => 'No routines yet';

  @override
  String get noRoutinesBody =>
      'A routine is a plan you take again and again — the commute, the Saturday ride. Make one, then stamp a trip out of it whenever you travel it.';

  @override
  String get routineNoDates => 'No dates';

  @override
  String get routineFromRoutine => 'From routine…';

  @override
  String get routineCreateTrip => 'Create trip';

  @override
  String get routineCreateTripFor => 'Create trip for';

  @override
  String get routineStartDate => 'Start date';

  @override
  String get routineLookUpConnections => 'Look up current connections';

  @override
  String get routineLookUpConnectionsBody =>
      'Search for the journeys in this plan on the chosen dates, so their live times can be refreshed.';

  @override
  String get routineCreated => 'Trip created.';

  @override
  String get routineCreatedOpen => 'Open';

  @override
  String get routineDuplicateReversed => 'Duplicate reversed';

  @override
  String routineReversedSuffix(String title) {
    return '$title (return)';
  }

  @override
  String get routineAlreadyRecordedTitle => 'Already recorded';

  @override
  String routineAlreadyRecordedBody(String title, String date) {
    return '“$title” already has a trip starting on $date. Create another?';
  }

  @override
  String get routineCreateAnyway => 'Create anyway';

  @override
  String routineNewDay(int number) {
    return 'Day $number (new)';
  }

  @override
  String get routineAddDay => 'Add day';

  @override
  String routineDayNumber(int number) {
    return 'Day $number';
  }

  @override
  String get connectionsNotFound =>
      'No connection found — the plan was copied as it stands.';

  @override
  String get connectionsNotTaken =>
      'A connection couldn\'t be taken over — the plan was kept.';

  @override
  String get connectionsOffline =>
      'Couldn\'t reach the routing service. The plan was copied as it stands.';

  @override
  String get connectionsKeepPlan => 'Keep the plan';

  @override
  String get connectionsUseThis => 'Use this';

  @override
  String get connectionsSearching => 'Looking up connections…';

  @override
  String get connectionsFindForLeg => 'Find connection';

  @override
  String get filterRoutineLabel => 'From routine';

  @override
  String get filterRoutineAny => 'Any routine';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get tagsManage => 'Manage tags';

  @override
  String get tagsNone => 'No tags yet';

  @override
  String get tagsAddHint => 'New tag';

  @override
  String get tagsAdd => 'Add tag';

  @override
  String get tagsFilterLabel => 'Tagged';

  @override
  String get tagsAll => 'All';

  @override
  String get tagDeleteQuestion => 'Delete this tag?';

  @override
  String get tagDeleteBody =>
      'It will be removed from every trip carrying it. The trips themselves are untouched.';

  @override
  String get tagRename => 'Rename tag';

  @override
  String get tagNameLabel => 'Name';

  @override
  String get tagDuplicate => 'A tag with that name already exists.';

  @override
  String get aboutSection => 'About';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutVersionCopied => 'Version copied';

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutReportIssue => 'Report a problem';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get aboutLicensesSubtitle =>
      'The libraries and fonts this app is built from';
}
