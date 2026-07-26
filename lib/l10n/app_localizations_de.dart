// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Reiseplaner';

  @override
  String get tripsTitle => 'Meine Reisen';

  @override
  String get newTrip => 'Neue Reise';

  @override
  String get noTripsTitle => 'Noch keine Reisen';

  @override
  String get noTripsBody =>
      'Tippe auf „Neue Reise“, um dein erstes Abenteuer zu planen.';

  @override
  String get searchTrips => 'Reisen suchen';

  @override
  String get searchTripsHint => 'Titel, Reiseziel oder Notizen';

  @override
  String get filterTrips => 'Filtern und sortieren';

  @override
  String get filterAndSort => 'Filtern & sortieren';

  @override
  String get clearFilters => 'Zurücksetzen';

  @override
  String get statusLabel => 'Status';

  @override
  String get tripStatusUpcoming => 'Bevorstehend';

  @override
  String get tripStatusOngoing => 'Laufend';

  @override
  String get tripStatusPast => 'Vergangen';

  @override
  String get tripStatusUndated => 'Ohne Datum';

  @override
  String get sortLabel => 'Sortierung';

  @override
  String get sortDateAsc => 'Datum (nächste zuerst)';

  @override
  String get sortDateDesc => 'Datum (späteste zuerst)';

  @override
  String get sortNameAsc => 'Name (A–Z)';

  @override
  String get sortCreatedDesc => 'Zuletzt hinzugefügt';

  @override
  String get sortExpenseDesc => 'Ausgaben (höchste)';

  @override
  String get sortExpenseAsc => 'Ausgaben (niedrigste)';

  @override
  String get anyDate => 'Beliebig';

  @override
  String get noTripsFoundTitle => 'Keine passenden Reisen';

  @override
  String noTripsFoundBody(String query) {
    return 'Keine Reisen passen zu „$query“.';
  }

  @override
  String genericError(String error) {
    return 'Etwas ist schiefgelaufen:\n$error';
  }

  @override
  String days(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String entries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get datesNotSet => 'Kein Zeitraum festgelegt';

  @override
  String until(String date) {
    return 'Bis $date';
  }

  @override
  String get editTrip => 'Reise bearbeiten';

  @override
  String get shareTrip => 'Reise teilen';

  @override
  String get shareTripSaved => 'Reisedatei gespeichert.';

  @override
  String get shareTripFailed => 'Diese Reise konnte nicht geteilt werden.';

  @override
  String get exportPdf => 'Als PDF exportieren';

  @override
  String get exportPdfFailed =>
      'Diese Reise konnte nicht als PDF exportiert werden.';

  @override
  String get exportIcs => 'In Kalender exportieren';

  @override
  String get exportIcsFailed =>
      'Diese Reise konnte nicht in einen Kalender exportiert werden.';

  @override
  String get exportAction => 'Exportieren';

  @override
  String get pdfSectionsTitle => 'Was ins PDF kommt';

  @override
  String get pdfSectionsSubtitle =>
      'Name, Zeitraum und Teilnehmer der Reise sind immer dabei.';

  @override
  String get pdfSectionEmpty => 'Nichts erfasst';

  @override
  String get pdfInclSettlements => 'Ausgleichszahlungen enthalten';

  @override
  String pdfLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Listen',
      one: '1 Liste',
    );
    return '$_temp0';
  }

  @override
  String pdfItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String pdfOtherOptions(String options) {
    return 'Weitere Optionen: $options';
  }

  @override
  String pdfExportedOn(String date) {
    return 'Exportiert am $date';
  }

  @override
  String get importTrip => 'Reise importieren';

  @override
  String get importTripSuccess => 'Reise importiert.';

  @override
  String get importTripInvalid =>
      'Diese Datei ist keine gültige geteilte Reise.';

  @override
  String get importTripTooNew =>
      'Diese Reise wurde mit einer neueren Version der App geteilt. Bitte aktualisiere die App, um sie zu importieren.';

  @override
  String get importTripFailed => 'Diese Reise konnte nicht importiert werden.';

  @override
  String get fieldTitle => 'Titel';

  @override
  String get titleHint => 'z. B. Sommer in Italien';

  @override
  String get titleValidator => 'Bitte einen Titel eingeben';

  @override
  String get fieldDestination => 'Reiseziel';

  @override
  String get destinationHint => 'z. B. Rom, Florenz';

  @override
  String get fieldDates => 'Zeitraum';

  @override
  String get fieldNotes => 'Notizen';

  @override
  String get accentColour => 'Akzentfarbe';

  @override
  String get customColour => 'Eigene Farbe';

  @override
  String get pickColour => 'Farbe auswählen';

  @override
  String get hexColour => 'Hex';

  @override
  String get invalidHexColour => 'Gültige Hex-Farbe eingeben, z. B. 1565C0';

  @override
  String get createTrip => 'Reise erstellen';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get itineraryTitle => 'Reiseverlauf';

  @override
  String get deleteTrip => 'Reise löschen';

  @override
  String get deleteTripQuestion => 'Reise löschen?';

  @override
  String get deleteTripBody =>
      'Dadurch werden die Reise und der gesamte Reiseverlauf dauerhaft entfernt.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get nothingPlanned => 'Noch nichts geplant.';

  @override
  String get now => 'Jetzt';

  @override
  String get today => 'Heute';

  @override
  String get addPlace => 'Ort hinzufügen';

  @override
  String addArrival(String place) {
    return '$place hinzufügen';
  }

  @override
  String get addTransport => 'Transport hinzufügen';

  @override
  String get hideEntries => 'Einträge ausblenden';

  @override
  String get showEntries => 'Einträge anzeigen';

  @override
  String get editPlace => 'Ort bearbeiten';

  @override
  String get editTransport => 'Transport bearbeiten';

  @override
  String get fieldMode => 'Verkehrsmittel';

  @override
  String get fieldFrom => 'Von';

  @override
  String get fieldTo => 'Nach';

  @override
  String get fieldPlace => 'Ort';

  @override
  String get placeHint => 'z. B. Kolosseum';

  @override
  String get placeValidator => 'Bitte einen Ort eingeben';

  @override
  String get fromToValidator => 'Bitte mindestens Start- oder Zielort eingeben';

  @override
  String get transportLabelOptional => 'Bezeichnung (optional)';

  @override
  String get noteTitleOptional => 'Notiztitel (optional)';

  @override
  String get fieldDay => 'Tag';

  @override
  String get timeDeparts => 'Abfahrt';

  @override
  String get timeArrives => 'Ankunft';

  @override
  String get timeStart => 'Beginn';

  @override
  String get timeEnd => 'Ende';

  @override
  String get setTime => 'Zeit wählen';

  @override
  String get plannedTimes => 'Geplant';

  @override
  String get actualTimes => 'Tatsächlich';

  @override
  String get actualTimesHint =>
      'Was wirklich passiert ist. Die Zeitleiste zeigt die Abweichung vom Plan.';

  @override
  String get notesOptional => 'Notizen (optional)';

  @override
  String get save => 'Speichern';

  @override
  String get add => 'Hinzufügen';

  @override
  String get search => 'Suchen';

  @override
  String get searchNoMatches => 'Keine Treffer';

  @override
  String searchAdd(String query) {
    return '„$query“ hinzufügen';
  }

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get databaseSection => 'Datenbank';

  @override
  String get currentDatabase => 'Aktuelle Datenbank';

  @override
  String get dbOpen => 'Datenbank öffnen…';

  @override
  String get dbOpenSubtitle => 'Eine vorhandene .sqlite-Datei öffnen';

  @override
  String get dbNew => 'Neue Datenbank…';

  @override
  String get dbNewSubtitle =>
      'Leere Datenbank an einem gewählten Ort erstellen';

  @override
  String get dbNewEmpty => 'Neue leere Datenbank';

  @override
  String get dbNewEmptySubtitle => 'Ohne Reisen neu beginnen';

  @override
  String get dbNewEmptyConfirmTitle => 'Neue Datenbank beginnen?';

  @override
  String get dbNewEmptyConfirmBody =>
      'Dadurch werden alle aktuellen Reisen gelöscht und es wird mit einer leeren Datenbank begonnen. Dies kann nicht rückgängig gemacht werden — exportiere vorher eine Kopie, wenn du die Daten behalten möchtest.';

  @override
  String get dbNewEmptyAction => 'Neu beginnen';

  @override
  String get dbNewEmptyDone => 'Neue leere Datenbank begonnen';

  @override
  String get dbImport => 'Datenbank importieren…';

  @override
  String get dbImportSubtitle =>
      'Aktuelle Daten durch eine .sqlite-Datei ersetzen';

  @override
  String get dbExport => 'Datenbank exportieren…';

  @override
  String get dbExportSubtitle => 'Kopie der aktuellen Datenbank speichern';

  @override
  String get dbReset => 'Auf Standard zurücksetzen';

  @override
  String get dbResetSubtitle => 'Standard-Speicherort der App verwenden';

  @override
  String get dbImportConfirmTitle => 'Datenbank importieren?';

  @override
  String get dbImportConfirmBody =>
      'Dadurch werden alle aktuellen Reisen durch den Inhalt der ausgewählten Datei ersetzt. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get dbImportAction => 'Importieren';

  @override
  String get dbOpened => 'Datenbank geöffnet';

  @override
  String get dbCreated => 'Neue Datenbank erstellt';

  @override
  String get dbImported => 'Datenbank importiert';

  @override
  String get dbExported => 'Datenbank exportiert';

  @override
  String get dbResetDone => 'Zur Standarddatenbank gewechselt';

  @override
  String dbError(String error) {
    return 'Vorgang konnte nicht abgeschlossen werden: $error';
  }

  @override
  String get modeWalk => 'Zu Fuß';

  @override
  String get modeBike => 'Fahrrad';

  @override
  String get modeCar => 'Auto';

  @override
  String get modeTaxi => 'Taxi';

  @override
  String get modeBus => 'Bus';

  @override
  String get modeTrain => 'Zug';

  @override
  String get modeTram => 'Straßenbahn';

  @override
  String get modeSubway => 'U-Bahn';

  @override
  String get modeFerry => 'Fähre';

  @override
  String get modeFlight => 'Flug';

  @override
  String get modeOther => 'Sonstiges';

  @override
  String get modeSki => 'Ski';

  @override
  String get widgetNoTripsTitle => 'Noch keine Reisen';

  @override
  String get widgetNoTripsBody =>
      'Tippen, um dein nächstes Abenteuer zu planen';

  @override
  String widgetInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Tagen',
      one: 'in 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get widgetTomorrow => 'Beginnt morgen';

  @override
  String get widgetEndedYesterday => 'Gestern beendet';

  @override
  String widgetEndedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Tagen beendet',
      one: 'Vor 1 Tag beendet',
    );
    return '$_temp0';
  }

  @override
  String widgetDayXofY(int current, int total) {
    return 'Tag $current von $total';
  }

  @override
  String get widgetTodayHeader => 'Heute';

  @override
  String widgetMoreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count weitere',
      one: '+1 weiterer',
    );
    return '$_temp0';
  }

  @override
  String get addCost => 'Ausgabe hinzufügen';

  @override
  String get editCost => 'Ausgabe bearbeiten';

  @override
  String get costAmount => 'Betrag';

  @override
  String get costCurrency => 'Währung';

  @override
  String get costReason => 'Kategorie';

  @override
  String get costReasonHint => 'z. B. Hotel, Abendessen, Zugticket';

  @override
  String get costReasonLabel => 'Kategoriename';

  @override
  String get costAmountInvalid => 'Bitte einen gültigen Betrag eingeben';

  @override
  String get costReasonRequired => 'Bitte eine Kategorie eingeben';

  @override
  String get costsTotal => 'Gesamt';

  @override
  String get costs => 'Ausgaben';

  @override
  String get generalCosts => 'Allgemeine Ausgaben';

  @override
  String get costReasonsSection => 'Ausgabenkategorien';

  @override
  String get costReasonDisplay => 'Auf Ausgaben-Chips anzeigen';

  @override
  String get costReasonDisplayIcon => 'Symbol';

  @override
  String get costReasonDisplayText => 'Text';

  @override
  String get costReasonDisplayBoth => 'Beides';

  @override
  String get costReasonDisplayHelp =>
      'Wie Kategorien auf Ausgaben-Chips erscheinen – Symbol: nur das Symbol; Text: nur der Name; Beides: Symbol und Name. Der Betrag wird immer angezeigt.';

  @override
  String get costReasonAdd => 'Kategorie hinzufügen';

  @override
  String get costReasonAddTitle => 'Neue Kategorie';

  @override
  String get costReasonRenameTitle => 'Kategorie umbenennen';

  @override
  String get costReasonChooseIcon => 'Symbol auswählen';

  @override
  String get costReasonDeleteConfirmTitle => 'Kategorie löschen?';

  @override
  String costReasonDeleteConfirmBody(String reason) {
    return '„$reason“ wird aus der Liste der Kategorien entfernt. Bestehende Ausgaben behalten ihren Text.';
  }

  @override
  String get noCostReasons => 'Noch keine gespeicherten Kategorien';

  @override
  String get transportModesSection => 'Verkehrsmittel';

  @override
  String get transportModeAdd => 'Verkehrsmittel hinzufügen';

  @override
  String get transportModeAddTitle => 'Neues Verkehrsmittel';

  @override
  String get transportModeRenameTitle => 'Verkehrsmittel umbenennen';

  @override
  String get transportModeLabel => 'Name';

  @override
  String get transportModeHint => 'z. B. Gondel';

  @override
  String get transportModeChooseIcon => 'Symbol wählen';

  @override
  String get transportModeDeleteConfirmTitle => 'Verkehrsmittel löschen?';

  @override
  String transportModeDeleteConfirmBody(String mode) {
    return '\"$mode\" wird aus der Liste entfernt. Vorhandene Transportabschnitte behalten ihre Route, verlieren aber ihr Verkehrsmittel.';
  }

  @override
  String get noTransportModes => 'Noch keine Verkehrsmittel';

  @override
  String get costPaidBy => 'Bezahlt von';

  @override
  String get costPaid => 'Bereits bezahlt';

  @override
  String get costPaidFor => 'Bezahlt für';

  @override
  String get costPaidByNone => 'Nicht zugewiesen';

  @override
  String costPaidByName(String name) {
    return 'Bezahlt von $name';
  }

  @override
  String get addTransfer => 'Ausgleich erfassen';

  @override
  String get editTransfer => 'Ausgleich bearbeiten';

  @override
  String get transfer => 'Ausgleich';

  @override
  String get transfers => 'Ausgleichszahlungen';

  @override
  String get transferFrom => 'Von';

  @override
  String get transferTo => 'An';

  @override
  String get transferPersonRequired => 'Person wählen';

  @override
  String get transferSamePerson => 'Zwei verschiedene Personen wählen';

  @override
  String get transferAmountPositive => 'Betrag muss größer als null sein';

  @override
  String transferBetween(String from, String to) {
    return '$from → $to';
  }

  @override
  String get transferHint =>
      'Ausgleichszahlungen verschieben Geld zwischen Personen. Sie ändern nur die Salden — nie die Gesamtsumme der Reise.';

  @override
  String get currenciesSection => 'Währungen';

  @override
  String get currencyAdd => 'Währung hinzufügen';

  @override
  String get currencyAddTitle => 'Neue Währung';

  @override
  String get currencyEditTitle => 'Währung bearbeiten';

  @override
  String get currencyCode => 'Code';

  @override
  String get currencyCodeHint => 'z. B. JPY';

  @override
  String get currencyCodeRequired => 'Code eingeben';

  @override
  String get currencySymbol => 'Symbol';

  @override
  String get currencySymbolHint => 'z. B. ¥';

  @override
  String get currencyRate => 'Wechselkurs';

  @override
  String get currencyRateInvalid => 'Zahl größer als null eingeben';

  @override
  String get currencyRateNone => 'Kein Kurs hinterlegt';

  @override
  String currencyRateExplains(String code, String rate, String base) {
    return '1 $code = $rate $base';
  }

  @override
  String currencyRateHelp(String code, String base) {
    return 'Wie viel ein $code in $base wert ist. Leer lassen, wenn nicht umgerechnet werden soll.';
  }

  @override
  String get currencyBase => 'Basiswährung';

  @override
  String get currencyBaseHelp =>
      'Alle Kurse beziehen sich auf die Basiswährung, und neue Ausgaben starten in ihr. Summen über mehrere Währungen werden in sie umgerechnet — neben den genauen Beträgen je Währung, nicht an ihrer Stelle.';

  @override
  String get currencyMakeBase => 'Als Basiswährung festlegen';

  @override
  String get currencyRebaseWarnTitle => 'Basiswährung wechseln?';

  @override
  String currencyRebaseWarnBody(String code) {
    return 'Für \"$code\" ist kein Wechselkurs hinterlegt. Die Kurse der anderen Währungen lassen sich deshalb nicht darauf umrechnen und werden gelöscht. Du kannst sie danach neu eingeben.';
  }

  @override
  String currencyInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ausgaben',
      one: '1 Ausgabe',
    );
    return 'Verwendet von $_temp0';
  }

  @override
  String get currencyDeleteConfirmTitle => 'Währung löschen?';

  @override
  String currencyDeleteConfirmBody(String code) {
    return '\"$code\" wird aus der Währungsliste entfernt.';
  }

  @override
  String currencyDeleteBlockedInUse(String code, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ausgaben',
      one: '1 Ausgabe',
    );
    return '\"$code\" wird noch von $_temp0 verwendet. Ein Betrag kann nicht ohne Währung bleiben.';
  }

  @override
  String get currencyDeleteBlockedBase =>
      'Die Basiswährung kann nicht gelöscht werden. Lege zuerst eine andere als Basis fest.';

  @override
  String get currencyCodeTaken => 'Dieser Code ist bereits in der Liste';

  @override
  String get noCurrencies => 'Noch keine Währungen';

  @override
  String get peopleSection => 'Personen';

  @override
  String get noPeople => 'Noch keine gespeicherten Personen';

  @override
  String get personAdd => 'Person hinzufügen';

  @override
  String get personAddTitle => 'Neue Person';

  @override
  String get personRenameTitle => 'Person umbenennen';

  @override
  String get personLabel => 'Name';

  @override
  String get personHint => 'z. B. Alex';

  @override
  String get personDeleteConfirmTitle => 'Person löschen?';

  @override
  String personDeleteConfirmBody(String name) {
    return '„$name“ wird aus der Personenliste entfernt. Bestehende Ausgaben behalten ihren Zahler.';
  }

  @override
  String get personMarkAsMe => 'Als mich markieren';

  @override
  String get personIsMe => 'Das bin ich';

  @override
  String get myCostsTotal => 'Meine Ausgaben';

  @override
  String get expenseScopeAll => 'Alle';

  @override
  String get expenseScopeMine => 'Meine';

  @override
  String get participants => 'Teilnehmer';

  @override
  String get addParticipant => 'Teilnehmer hinzufügen';

  @override
  String get statsTitle => 'Statistik';

  @override
  String get statsAllTripsTitle => 'Gesamtstatistik';

  @override
  String get statsOpen => 'Statistik';

  @override
  String get statsAllTripsOpen => 'Gesamtstatistik';

  @override
  String get statsTabExpenses => 'Ausgaben';

  @override
  String get statsTabTransport => 'Transport';

  @override
  String get statsNoData => 'Noch keine Ausgaben zum Auswerten';

  @override
  String get statsNoTransport => 'Noch keine Strecken zum Auswerten';

  @override
  String get statsByCategory => 'Nach Kategorie';

  @override
  String get statsByMode => 'Nach Verkehrsmittel';

  @override
  String get statsScopeLegs => 'Strecken';

  @override
  String get statsScopeTime => 'Zeit';

  @override
  String statsLegs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Strecken',
      one: '1 Strecke',
    );
    return '$_temp0';
  }

  @override
  String statsTotalTime(String duration) {
    return '$duration gesamt';
  }

  @override
  String get statsByPerson => 'Nach Person';

  @override
  String get statsScopePaid => 'Bezahlt';

  @override
  String get statsScopeShare => 'Anteil';

  @override
  String get statsScopeBalances => 'Salden';

  @override
  String get statsPaidShort => 'Bezahlt';

  @override
  String get statsShareShort => 'Anteil';

  @override
  String get statsSettleUp => 'Ausgleichen';

  @override
  String get statsSettledUp => 'Alle sind ausgeglichen — nichts zu begleichen.';

  @override
  String get statsGetsBack => 'bekommt zurück';

  @override
  String get statsOwes => 'schuldet';

  @override
  String get statsEven => 'ausgeglichen';

  @override
  String statsExpenses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ausgaben',
      one: '1 Ausgabe',
    );
    return '$_temp0';
  }

  @override
  String statsPaidAmount(String amount, int percent) {
    return '$amount bezahlt ($percent%)';
  }

  @override
  String statsOpenAmount(String amount, int percent) {
    return '$amount offen ($percent%)';
  }

  @override
  String statsTransfer(String from, String to) {
    return '$from zahlt an $to';
  }

  @override
  String get statsRecordSettlement => 'Erfassen';

  @override
  String statsSettlementSent(String amount) {
    return '$amount zurückgezahlt';
  }

  @override
  String statsSettlementReceived(String amount) {
    return '$amount erhalten';
  }

  @override
  String get checklist => 'Checkliste';

  @override
  String get checklistAddHint => 'Eintrag hinzufügen…';

  @override
  String get checklistEditTitle => 'Eintrag bearbeiten';

  @override
  String get checklistRenameTitle => 'Checkliste umbenennen';

  @override
  String get checklistNewTitle => 'Neue Checkliste';

  @override
  String get checklistAdd => 'Checkliste hinzufügen';

  @override
  String get checklistDeleteTitle => 'Checkliste löschen?';

  @override
  String checklistDeleteBody(String name) {
    return '„$name“ und alle ihre Einträge werden entfernt.';
  }

  @override
  String get checklistActions => 'Aktionen für die Checkliste';

  @override
  String get checklistDelete => 'Checkliste löschen';

  @override
  String get checklistDuplicate => 'Duplizieren';

  @override
  String checklistCopyTitle(String name) {
    return '$name (Kopie)';
  }

  @override
  String get checklistCopyToTrip => 'In Reise kopieren…';

  @override
  String get checklistMoveToTrip => 'In Reise verschieben…';

  @override
  String get checklistPickTrip => 'In welche Reise?';

  @override
  String get checklistNoOtherTrips => 'Es gibt noch keine andere Reise dafür.';

  @override
  String checklistCopiedTo(String trip) {
    return 'Nach „$trip“ kopiert. Häkchen werden nicht kopiert – eine Liste ist nur leer wiederverwendbar.';
  }

  @override
  String checklistMovedTo(String trip) {
    return 'Nach „$trip“ verschoben.';
  }

  @override
  String get moveOrCopy => 'Verschieben oder kopieren';

  @override
  String get moveOrCopyHint =>
      'Nimm diesen Eintrag auf und lege dann fest, wo er landen soll – an einem anderen Tag oder in einer Option einer Wahl.';

  @override
  String get moveToDots => 'Verschieben nach…';

  @override
  String get copyToDots => 'Kopieren nach…';

  @override
  String get duplicateEntry => 'Duplizieren';

  @override
  String get moveHere => 'Hierher verschieben';

  @override
  String get copyHere => 'Hierher kopieren';

  @override
  String holdingMove(String entry) {
    return 'Wird verschoben: $entry';
  }

  @override
  String holdingCopy(String entry) {
    return 'Wird kopiert: $entry';
  }

  @override
  String get holdingHint =>
      'Tippe an einem Tag oder in einer Option auf „Hierher verschieben“ bzw. „Hierher kopieren“.';

  @override
  String get untitledEntry => 'Eintrag ohne Titel';

  @override
  String get copiedWithoutCosts =>
      'Kopiert. Kosten werden nicht kopiert – eine Zahlung gab es nur einmal.';

  @override
  String putIntoUnchosenOption(String option) {
    return 'In $option eingefügt – zählt nicht zur Reise, solange eine andere Option gewählt ist.';
  }

  @override
  String get alternatives => 'Alternativen';

  @override
  String get planAlternatives => 'Alternativen planen';

  @override
  String get planAlternativesHint =>
      'Mache aus diesem Eintrag eine Wahl: Plane mehrere Optionen und lege fest, welche es wird.';

  @override
  String get itemInOptionHint =>
      'Teil einer Option – zählt nur zur Reise, solange diese Option gewählt ist.';

  @override
  String get decisionDefaultLabel => 'Wahl';

  @override
  String get decisionActions => 'Aktionen für die Wahl';

  @override
  String get decisionRename => 'Wahl umbenennen';

  @override
  String get decisionNameLabel => 'Name der Wahl (optional)';

  @override
  String get decisionNameHint => 'z. B. Samstagnachmittag';

  @override
  String get decisionDelete => 'Wahl löschen';

  @override
  String get decisionDeleteQuestion => 'Diese Wahl löschen?';

  @override
  String get decisionDeleteBody =>
      'Alle Optionen mit ihren Einträgen und Ausgaben werden gelöscht.';

  @override
  String optionLetter(String letter) {
    return 'Option $letter';
  }

  @override
  String get optionChosen => 'Gewählt';

  @override
  String get optionChoose => 'Diese Option wählen';

  @override
  String get optionEmpty => 'In dieser Option ist noch nichts geplant.';

  @override
  String get optionAdd => 'Option hinzufügen';

  @override
  String get optionDuplicate => 'Option duplizieren';

  @override
  String get optionRename => 'Option umbenennen';

  @override
  String get optionNameLabel => 'Name der Option (optional)';

  @override
  String get optionNameHint => 'z. B. Museumstag';

  @override
  String get optionDelete => 'Option löschen';

  @override
  String get optionDeleteQuestion => 'Diese Option löschen?';

  @override
  String get optionDeleteBody =>
      'Ihre Einträge und deren Ausgaben werden mitgelöscht. Die anderen Optionen bleiben erhalten.';

  @override
  String get optionKeepOnly => 'Nur diese Option behalten';

  @override
  String get optionKeepOnlyQuestion => 'Nur diese Option behalten?';

  @override
  String get optionKeepOnlyBody =>
      'Ihre Einträge wandern zurück in den Tag, die anderen Optionen werden gelöscht.';

  @override
  String get optionPrevious => 'Vorherige Option';

  @override
  String get optionNext => 'Nächste Option';

  @override
  String get grouping => 'Gruppierung';

  @override
  String get groupWithNext => 'Mit nächstem Element gruppieren';

  @override
  String get groupMoveTo => 'Gruppe verschieben nach…';

  @override
  String get groupCopyTo => 'Gruppe kopieren nach…';

  @override
  String get groupRemoveItem => 'Aus Gruppe entfernen';

  @override
  String get groupUngroup => 'Gruppierung aufheben';

  @override
  String get groupNameLabel => 'Gruppenname (optional)';

  @override
  String get groupNameHint => 'z. B. Zug nach Rom';

  @override
  String get groupDefaultLabel => 'Gruppe';

  @override
  String get groupSharedExpenses => 'Gemeinsame Ausgaben';

  @override
  String get groupMemberHint =>
      'Teil einer Gruppe – die gemeinsamen Ausgaben werden auf alle Elemente angewendet.';

  @override
  String get calendarView => 'Kalenderansicht';

  @override
  String get listView => 'Listenansicht';

  @override
  String get calendarToday => 'Heute';

  @override
  String get calendarPreviousMonth => 'Voriger Monat';

  @override
  String get calendarNextMonth => 'Nächster Monat';

  @override
  String get calendarUndatedTitle => 'Reisen ohne Datum';

  @override
  String get calendarUndatedTooltip => 'Reisen ohne Datum anzeigen';

  @override
  String get connectionSearch => 'Verbindung suchen';

  @override
  String get connectionSearchOnline => 'Online suchen';

  @override
  String get connectionFrom => 'Von';

  @override
  String get connectionTo => 'Nach';

  @override
  String get connectionPickPlace => 'Bahnhof oder Ort suchen';

  @override
  String get connectionDepart => 'Abfahrt um';

  @override
  String get connectionArrive => 'Ankunft bis';

  @override
  String get connectionSearchNoResults => 'Keine Verbindungen gefunden';

  @override
  String get connectionSearchError => 'Verbindungsdienst nicht erreichbar';

  @override
  String get connectionRetry => 'Erneut versuchen';

  @override
  String connectionChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Umstiege',
      one: '1 Umstieg',
      zero: 'Direkt',
    );
    return '$_temp0';
  }

  @override
  String get connectionModesTitle => 'Verkehrsmittel';

  @override
  String get connectionModesSubtitle =>
      'Nur diese werden für die Verbindung genutzt.';

  @override
  String get connectionModesAll => 'Alle Verkehrsmittel';

  @override
  String get connectionModesNone => 'Keine Verkehrsmittel';

  @override
  String get connectionModeLongDistance => 'Fernverkehr';

  @override
  String get connectionModeRegional => 'Regionalverkehr';

  @override
  String get connectionModeCity => 'U-Bahn & Straßenbahn';

  @override
  String get connectionModeBus => 'Bus & Fernbus';

  @override
  String get connectionModeFerry => 'Fähre';

  @override
  String get connectionModeAir => 'Flüge';

  @override
  String get connectionModeOther => 'Seilbahn & Sonstiges';

  @override
  String get connectionAddToDay => 'Zum Tag hinzufügen';

  @override
  String get connectionAdded => 'Verbindung hinzugefügt';

  @override
  String get connectionAttribution =>
      'Daten © OpenStreetMap-Mitwirkende, über Transitous';

  @override
  String get transportModeRestoreBuiltin => 'Standard wiederherstellen';

  @override
  String platformShort(String track) {
    return 'Gl. $track';
  }

  @override
  String directionTo(String destination) {
    return 'Richtung $destination';
  }

  @override
  String get liveTimesRefresh => 'Echtzeit aktualisieren';

  @override
  String get liveTimesNone => 'Keine Echtzeitdaten zu aktualisieren';

  @override
  String get liveTimesError => 'Echtzeitdaten konnten nicht geladen werden';
}
