// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Pappus Travel Planner';

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
  String get exportGpx => 'Linien exportieren (GPX)…';

  @override
  String get exportGpxEmpty => 'Diese Reise hat keine Linien zum Exportieren';

  @override
  String get exportGpxFailed => 'Die Linien konnten nicht exportiert werden';

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
  String get mapTitle => 'Karte';

  @override
  String get mapOpen => 'Auf Karte zeigen';

  @override
  String get mapNothingToShow => 'Noch nichts zu verorten';

  @override
  String get mapNothingToShowHint =>
      'Orte und Abschnitte erscheinen hier, sobald sie Koordinaten haben — importierte Verbindungen bringen ihre mit.';

  @override
  String mapTripsHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reisen hier',
      one: '1 Reise hier',
    );
    return '$_temp0';
  }

  @override
  String mapEntriesHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge hier',
      one: '1 Eintrag hier',
    );
    return '$_temp0';
  }

  @override
  String get mapColor => 'Farbe auf der Karte';

  @override
  String get mapColorHint =>
      'Färbt die Linie bzw. den Marker dieses Eintrags. Alles andere an der Reise bleibt unberührt.';

  @override
  String get mapColorTrip => 'Reisefarbe';

  @override
  String get trackSection => 'Aufgezeichnete Linie';

  @override
  String get trackImport => 'GPX importieren…';

  @override
  String get trackRemove => 'Entfernen';

  @override
  String get trackShow => 'Auf der Karte zeichnen';

  @override
  String get trackHide => 'Nicht zeichnen';

  @override
  String get trackRemoveAll => 'Alle entfernen';

  @override
  String get trackSourceRecorded => 'Aufgezeichnet';

  @override
  String get trackSourceImported => 'Importiert';

  @override
  String get trackSourceRouted => 'Berechnete Route';

  @override
  String get trackNotDrawable => 'Nichts zu zeichnen';

  @override
  String get trackNone =>
      'Keine — die Karte zeichnet die Luftlinie zwischen den Enden.';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Linien',
      one: '1 Linie',
    );
    return '$_temp0';
  }

  @override
  String get trackImportTitle => 'Aufgezeichnete Linie importieren';

  @override
  String get trackPickEntries => 'Welche Einträge deckt sie ab?';

  @override
  String get trackPickEntriesHint =>
      'Wähle einen zusammenhängenden Lauf — die Linie wird darauf aufgeteilt.';

  @override
  String get trackPickOptionHint =>
      'Wo sich der Plan gabelt: wähle die Option, der die Linie gefolgt ist.';

  @override
  String get trackPickOption => 'Welcher Option ist die Linie gefolgt?';

  @override
  String get trackOptionNotChosen => 'Nicht die Option, der die Reise folgt';

  @override
  String trackTapBoundary(String before, String after) {
    return 'Antippen, wo „$before“ an „$after“ übergibt';
  }

  @override
  String get trackBoundaryMove =>
      'Ein Tipp verschiebt den nächsten Übergabepunkt';

  @override
  String get trackImportConfirm => 'Importieren';

  @override
  String trackImportSummary(int legs, int ends) {
    String _temp0 = intl.Intl.pluralLogic(
      legs,
      locale: localeName,
      other: '$legs Einträge',
      one: '1 Eintrag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      ends,
      locale: localeName,
      other: '$ends Koordinaten gesetzt',
      one: '1 Koordinate gesetzt',
      zero: 'keine Koordinaten gesetzt',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get trackNoLegsPicked => 'Mindestens einen Transport-Eintrag wählen';

  @override
  String get trackImported => 'Linie importiert';

  @override
  String get trackNothingInFile => 'Keine Linie in dieser Datei';

  @override
  String get trackInvalidFile => 'Diese Datei ist kein lesbares GPX';

  @override
  String get mapZoomIn => 'Vergrößern';

  @override
  String get mapZoomOut => 'Verkleinern';

  @override
  String get mapFullscreen => 'Karte im Vollbild';

  @override
  String get mapExitFullscreen => 'Vollbild beenden';

  @override
  String get mapMyLocationShow => 'Meine Position anzeigen';

  @override
  String get mapMyLocationHide => 'Meine Position ausblenden';

  @override
  String get mapUseMyLocation => 'Meine Position übernehmen';

  @override
  String get mapLocationDenied => 'Standortzugriff wurde abgelehnt';

  @override
  String get mapLocationBlocked => 'Standortzugriff ist für diese App gesperrt';

  @override
  String get mapLocationServiceOff =>
      'Die Ortung ist auf diesem Gerät ausgeschaltet';

  @override
  String get mapLocationFailed => 'Position konnte nicht bestimmt werden';

  @override
  String get mapLocationOpenSettings => 'Einstellungen';

  @override
  String get mapPickConfirm => 'Punkt übernehmen';

  @override
  String get mapPickTitlePlace => 'Ort wählen';

  @override
  String get mapPickTitleFrom => 'Startpunkt wählen';

  @override
  String get mapPickTitleTo => 'Zielpunkt wählen';

  @override
  String get coordinatesLabel => 'Koordinaten';

  @override
  String get coordinatesFrom => 'Koordinaten des Startpunkts';

  @override
  String get coordinatesTo => 'Koordinaten des Ziels';

  @override
  String get coordinatesNone => 'Nicht gesetzt';

  @override
  String get coordinatesPick => 'Auf Karte wählen';

  @override
  String get coordinatesClear => 'Position entfernen';

  @override
  String get mapPickHint => 'Auf die Karte tippen, um einen Punkt zu setzen';

  @override
  String get connectionPickOnMap => 'Auf Karte wählen';

  @override
  String get mapView => 'Karte';

  @override
  String get statsOpen => 'Statistik';

  @override
  String get statsAllTripsOpen => 'Gesamtstatistik';

  @override
  String get statsTabExpenses => 'Ausgaben';

  @override
  String countriesRatio(int visited, int total, int percent) {
    return '$visited von $total · $percent %';
  }

  @override
  String get countriesWorld => 'Weltweit';

  @override
  String get regionAfrica => 'Afrika';

  @override
  String get regionAsia => 'Asien';

  @override
  String get regionEurope => 'Europa';

  @override
  String get regionNorthAmerica => 'Nordamerika';

  @override
  String get regionSouthAmerica => 'Südamerika';

  @override
  String get regionOceania => 'Australien und Ozeanien';

  @override
  String get regionAntarctica => 'Antarktis';

  @override
  String get statsTabCountries => 'Länder';

  @override
  String countriesVisited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Länder',
      one: '1 Land',
      zero: 'Noch kein Land',
    );
    return '$_temp0';
  }

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
  String get tripPickerTitle => 'In welche Reise?';

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
  String get groupActions => 'Aktionen für die Gruppe';

  @override
  String get groupWithNext => 'Mit nächstem Element gruppieren';

  @override
  String get groupRename => 'Gruppe umbenennen';

  @override
  String get groupMoveTo => 'Gruppe verschieben nach…';

  @override
  String get groupCopyTo => 'Gruppe kopieren nach…';

  @override
  String get groupRemoveItem => 'Aus Gruppe entfernen';

  @override
  String get groupUngroup => 'Gruppierung aufheben';

  @override
  String get groupDelete => 'Gruppe löschen';

  @override
  String get groupDeleteQuestion => 'Diese Gruppe löschen?';

  @override
  String get groupDeleteBody =>
      'Ihre Einträge und alle zugehörigen Ausgaben werden mitgelöscht, auch die gemeinsamen. Um die Einträge zu behalten, hebe stattdessen die Gruppierung auf.';

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
  String get connectionVia => 'Zwischenhalt';

  @override
  String get connectionViaAdd => 'Zwischenhalt hinzufügen';

  @override
  String get connectionViaRemove => 'Zwischenhalt entfernen';

  @override
  String get connectionViaHint =>
      'Als Zwischenhalt sind nur Haltestellen möglich.';

  @override
  String get connectionViaStay => 'Mindestens bleiben';

  @override
  String get connectionViaStayNone => 'Kein Minimum';

  @override
  String get connectionPickPlace => 'Bahnhof oder Ort suchen';

  @override
  String get connectionPickStop => 'Bahnhof oder Haltestelle suchen';

  @override
  String get connectionDepart => 'Abfahrt um';

  @override
  String get connectionArrive => 'Ankunft bis';

  @override
  String get connectionBudgetsTitle => 'Zeit zu und von Haltestellen';

  @override
  String get connectionBudgetsHint =>
      'Der erste und letzte Abschnitt gelten nur, wenn du von einer Adresse statt einer Haltestelle suchst.';

  @override
  String get connectionBudgetAuto => 'Automatisch';

  @override
  String get connectionBudgetPre => 'Zur ersten Haltestelle';

  @override
  String get connectionBudgetPost => 'Von der letzten Haltestelle';

  @override
  String get connectionBudgetDirect =>
      'Ganze Strecke ohne öffentliche Verkehrsmittel';

  @override
  String connectionSummaryToStop(int minutes) {
    return '≤$minutes Min. zur Haltestelle';
  }

  @override
  String connectionSummaryFromStop(int minutes) {
    return '≤$minutes Min. ab Haltestelle';
  }

  @override
  String connectionSummaryOwnWay(int minutes) {
    return '≤$minutes Min. aus eigener Kraft';
  }

  @override
  String get connectionWheelchair => 'Barrierefrei';

  @override
  String get connectionWheelchairHint =>
      'Stufenlose Fuß- und Umsteigewege, nur als barrierefrei gekennzeichnete Verbindungen. Viele Netze veröffentlichen dazu nichts — dann wird wenig oder nichts gefunden.';

  @override
  String get connectionNoAccessibleConnections =>
      'Keine barrierefreien Verbindungen gefunden';

  @override
  String get connectionByBike => 'Mit dem Fahrrad';

  @override
  String get connectionByBikeHint =>
      'Die ganze Strecke fahren oder bis zur ersten Haltestelle.';

  @override
  String get connectionBikeOnBoard => 'Fahrrad kommt mit';

  @override
  String get connectionBikeOnBoardHint =>
      'Nur Verbindungen mit Fahrradmitnahme. Viele Netze veröffentlichen dazu nichts — dann wird nichts gefunden.';

  @override
  String get connectionCyclingSpeed => 'Fahrgeschwindigkeit';

  @override
  String get connectionCyclingSpeedHint =>
      'Gilt für die Abschnitte, die du fährst.';

  @override
  String get connectionNoBikeConnections =>
      'Keine Verbindungen mit Fahrradmitnahme';

  @override
  String get connectionCancelled => 'Fällt aus';

  @override
  String get connectionWithoutTransit => 'Ohne öffentliche Verkehrsmittel';

  @override
  String get connectionSearchNoResults => 'Keine Verbindungen gefunden';

  @override
  String get connectionEarlier => 'Früher';

  @override
  String get connectionLater => 'Später';

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
  String connectionChangeIn(int minutes, String place) {
    return '$minutes Min. Umstieg in $place';
  }

  @override
  String connectionChangeBetween(int minutes, String from, String to) {
    return '$minutes Min. Umstieg: $from → $to';
  }

  @override
  String connectionChangeNow(int minutes) {
    return 'aktuell $minutes Min.';
  }

  @override
  String get connectionOptionsTitle => 'Sucheinstellungen';

  @override
  String get connectionOptionsReset => 'Zurücksetzen';

  @override
  String get connectionMinTransfer => 'Kürzester Umstieg';

  @override
  String get connectionMinTransferHint =>
      'Keine Verbindung mit weniger Zeit zwischen Ankunft und Weiterfahrt.';

  @override
  String get connectionMinTransferAny => 'Beliebig';

  @override
  String connectionMinutesShort(int minutes) {
    return '$minutes Min.';
  }

  @override
  String connectionHoursShort(int hours) {
    return '$hours Std.';
  }

  @override
  String connectionHoursMinutesShort(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String get connectionWalkingSpeed => 'Gehgeschwindigkeit';

  @override
  String get connectionWalkingSpeedHint =>
      'Gilt für Wege zu, von und zwischen Haltestellen.';

  @override
  String connectionSpeedValue(String speed) {
    return '$speed km/h';
  }

  @override
  String get connectionSpeedNormal => 'normal';

  @override
  String get connectionMaxTransfers => 'Maximale Umstiege';

  @override
  String get connectionMaxTransfersAny => 'Beliebig';

  @override
  String get connectionMaxTransfersDirect => 'Direkt';

  @override
  String connectionMaxTransfersAtMost(int count) {
    return '≤$count';
  }

  @override
  String connectionSummaryMinTransfer(int minutes) {
    return 'Umstieg ≥ $minutes Min.';
  }

  @override
  String connectionSummaryMaxChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'max. $count Umstiege',
      one: 'max. 1 Umstieg',
      zero: 'nur direkt',
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
  String get connectionSaveToTrip => 'In Reise speichern…';

  @override
  String connectionSavedTo(String trip) {
    return 'Zu „$trip“ hinzugefügt';
  }

  @override
  String get attributionOsm => '© OpenStreetMap-Mitwirkende';

  @override
  String get attributionTransitous => 'Fahrplandaten über Transitous';

  @override
  String get dataSourcesSection => 'Datenquellen';

  @override
  String get dataSourcesNote =>
      'Die Verbindungssuche nutzt frei lizenzierte Fahrplan- und Kartendaten:';

  @override
  String linkOpenFailed(String url) {
    return '$url konnte nicht geöffnet werden';
  }

  @override
  String get transportModeRestoreBuiltin => 'Standard wiederherstellen';

  @override
  String platformShort(String track) {
    return 'Gl. $track';
  }

  @override
  String platformFromShort(String track) {
    return 'von Gl. $track';
  }

  @override
  String platformToShort(String track) {
    return 'nach Gl. $track';
  }

  @override
  String directionTo(String destination) {
    return 'Richtung $destination';
  }

  @override
  String connectionStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Halte',
      one: '1 Halt',
    );
    return '$_temp0';
  }

  @override
  String connectionStopsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Halte entfallen',
      one: '1 Halt entfällt',
    );
    return '$_temp0';
  }

  @override
  String connectionChangePlace(String place) {
    return 'Umstieg in $place';
  }

  @override
  String connectionChangePlaces(String from, String to) {
    return 'Umstieg: $from → $to';
  }

  @override
  String get journeyDetails => 'Reise anzeigen';

  @override
  String get liveTimesRefresh => 'Echtzeit aktualisieren';

  @override
  String get liveTimesNone => 'Keine Echtzeitdaten zu aktualisieren';

  @override
  String get liveTimesCancelled => 'Diese Verbindung fällt aus';

  @override
  String get liveTimesError => 'Echtzeitdaten konnten nicht geladen werden';

  @override
  String get tripKindTrip => 'Reise';

  @override
  String get tripKindRoutine => 'Routine';

  @override
  String get tripKindTripBody => 'Eine Reise im Kalender — ein Tag oder viele.';

  @override
  String get tripKindRoutineBody =>
      'Ein wiederverwendbarer Plan ohne Datum. Erzeuge daraus eine echte Reise, wann immer du sie machst.';

  @override
  String get newRoutine => 'Neue Routine';

  @override
  String get editRoutine => 'Routine bearbeiten';

  @override
  String get routinesTitle => 'Routinen';

  @override
  String get noRoutinesTitle => 'Noch keine Routinen';

  @override
  String get noRoutinesBody =>
      'Eine Routine ist ein Plan, den du immer wieder nimmst — der Arbeitsweg, die Samstagsrunde. Lege eine an und erzeuge daraus eine Reise, wann immer du sie fährst.';

  @override
  String get noRoutinesFoundTitle => 'Keine passenden Routinen';

  @override
  String noRoutinesFoundBody(String query) {
    return 'Keine Routinen passen zu „$query“.';
  }

  @override
  String get searchRoutines => 'Routinen suchen';

  @override
  String get searchRoutinesHint => 'Titel, Ziel oder Notizen';

  @override
  String get filterRoutines => 'Filtern und sortieren';

  @override
  String get routineNoDates => 'Kein Datum';

  @override
  String get routineFromRoutine => 'Aus Routine…';

  @override
  String get routineCreateTrip => 'Reise erzeugen';

  @override
  String get routineCreateTripFor => 'Reise erzeugen für';

  @override
  String get routineStartDate => 'Startdatum';

  @override
  String get routineLookUpConnections => 'Aktuelle Verbindungen suchen';

  @override
  String get routineLookUpConnectionsBody =>
      'Sucht die Verbindungen dieses Plans für die gewählten Tage, damit ihre Echtzeitdaten aktualisiert werden können.';

  @override
  String get routineCreated => 'Reise erzeugt.';

  @override
  String get routineCreatedOpen => 'Öffnen';

  @override
  String get routineDuplicateReversed => 'Umgekehrt duplizieren';

  @override
  String routineReversedSuffix(String title) {
    return '$title (Rückweg)';
  }

  @override
  String get routineAlreadyRecordedTitle => 'Bereits erfasst';

  @override
  String routineAlreadyRecordedBody(String title, String date) {
    return '„$title“ hat bereits eine Reise ab $date. Noch eine erzeugen?';
  }

  @override
  String get routineCreateAnyway => 'Trotzdem erzeugen';

  @override
  String routineNewDay(int number) {
    return 'Tag $number (neu)';
  }

  @override
  String get routineAddDay => 'Tag hinzufügen';

  @override
  String routineDayNumber(int number) {
    return 'Tag $number';
  }

  @override
  String get connectionsNotFound =>
      'Keine Verbindung gefunden — der Plan wurde unverändert übernommen.';

  @override
  String get connectionsNotTaken =>
      'Eine Verbindung konnte nicht übernommen werden — der Plan bleibt bestehen.';

  @override
  String get connectionsOffline =>
      'Der Routing-Dienst war nicht erreichbar. Der Plan wurde unverändert übernommen.';

  @override
  String get connectionsKeepPlan => 'Plan behalten';

  @override
  String get connectionsUseThis => 'Diese übernehmen';

  @override
  String get connectionsSearching => 'Verbindungen werden gesucht…';

  @override
  String get connectionsFindForLeg => 'Verbindung suchen';

  @override
  String get filterRoutineLabel => 'Aus Routine';

  @override
  String get filterRoutineAny => 'Beliebige Routine';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get tagsManage => 'Tags verwalten';

  @override
  String get tagsNone => 'Noch keine Tags';

  @override
  String get tagsAddHint => 'Neues Tag';

  @override
  String get tagsAdd => 'Tag hinzufügen';

  @override
  String get tagsFilterLabel => 'Getaggt';

  @override
  String get tagsAll => 'Alle';

  @override
  String get tagDeleteQuestion => 'Dieses Tag löschen?';

  @override
  String get tagDeleteBody =>
      'Es wird von allen Reisen entfernt, die es tragen. Die Reisen selbst bleiben unverändert.';

  @override
  String get tagRename => 'Tag umbenennen';

  @override
  String get tagNameLabel => 'Name';

  @override
  String get tagDuplicate => 'Ein Tag mit diesem Namen existiert bereits.';

  @override
  String get aboutSection => 'Über die App';

  @override
  String get aboutCiBuild => 'CI-Testversion';

  @override
  String get aboutCiBuildSubtitle =>
      'Läuft neben der veröffentlichten App und hat eine eigene Datenbank. Nicht für echte Reisen.';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutVersionCopied => 'Version kopiert';

  @override
  String get aboutSourceCode => 'Quellcode';

  @override
  String get aboutReportIssue => 'Problem melden';

  @override
  String get aboutContact => 'Kontakt';

  @override
  String get aboutLicenses => 'Open-Source-Lizenzen';

  @override
  String get aboutLicensesSubtitle =>
      'Die Bibliotheken und Schriften, aus denen diese App besteht';

  @override
  String get attachmentsLabel => 'Anhänge';

  @override
  String get attachmentsAddPhoto => 'Foto hinzufügen';

  @override
  String get attachmentsAddFile => 'Datei hinzufügen';

  @override
  String get attachmentsAdding => 'Datei wird gelesen …';

  @override
  String get attachmentsAddedOne => 'Angehängt.';

  @override
  String attachmentsAddedMany(int count) {
    return '$count Dateien angehängt.';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anhänge',
      one: '1 Anhang',
    );
    return '$_temp0';
  }

  @override
  String attachmentTooLarge(String size, String limit) {
    return 'Die Datei ist $size groß — erlaubt sind $limit. Beim Export wird die gesamte Datenbank kopiert; eine große Datei kann sie unbeweglich machen.';
  }

  @override
  String attachmentUnreadableImage(String format) {
    return 'Dieses Bildformat ($format) kann hier nicht gelesen werden. Speichere es zuerst als JPEG oder PNG.';
  }

  @override
  String attachmentLocationRedacted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Android hat den Aufnahmeort dieser Fotos zurückgehalten. Du kannst die Positionen von Hand setzen.',
      one:
          'Android hat den Aufnahmeort dieses Fotos zurückgehalten. Du kannst die Position von Hand setzen.',
    );
    return '$_temp0';
  }

  @override
  String get attachmentUnreadable => 'Die Datei konnte nicht gelesen werden.';

  @override
  String get attachmentRename => 'Umbenennen';

  @override
  String get attachmentNameLabel => 'Name';

  @override
  String get attachmentOpen => 'Öffnen';

  @override
  String get attachmentShare => 'Teilen';

  @override
  String get attachmentDelete => 'Löschen';

  @override
  String get attachmentDeleteQuestion => 'Diesen Anhang löschen?';

  @override
  String get attachmentDeleteBody =>
      'Die Datei liegt in dieser Datenbank und sonst nirgends. Wer sie hier löscht, löscht sie endgültig.';

  @override
  String get attachmentPositionExif => 'Position aus dem Foto übernommen';

  @override
  String get attachmentPositionPicked => 'Position auf der Karte gewählt';

  @override
  String get attachmentPositionNone => 'Keine Position';

  @override
  String get attachmentPositionSet => 'Auf Karte setzen';

  @override
  String get attachmentPositionClear => 'Position entfernen';

  @override
  String get photosSection => 'Fotos';

  @override
  String get photoLocationTitle => 'Aufnahmeort von Fotos lesen';

  @override
  String get photoLocationSubtitle =>
      'Android verbirgt den Aufnahmeort eines Fotos, solange du es nicht erlaubst. Beim Einschalten fragt Pappus nach dieser Berechtigung; ausgeschaltet wird ein Foto ohne Ort angehängt, auch wenn Android ihn herausgeben würde.';

  @override
  String get photoLocationStillGranted =>
      'Fotos werden ohne Ort angehängt. Android behält die Berechtigung, bis du sie in den Systemeinstellungen entziehst.';

  @override
  String get photoLocationDenied =>
      'Android hat es nicht erlaubt. Fotos werden ohne Ort angehängt; du kannst die Position von Hand setzen.';

  @override
  String get photoLocationBlocked =>
      'Android fragt nicht noch einmal. In den Systemeinstellungen kann es auf der Seite dieser App weiterhin erlaubt werden.';

  @override
  String get photoLocationOpenSettings => 'Einstellungen öffnen';

  @override
  String get attachmentPhotoOpenFailed =>
      'Die Datei konnte nicht geöffnet werden.';

  @override
  String get pdfSectionPhotos => 'Fotos';

  @override
  String pdfPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '1 Foto',
    );
    return '$_temp0';
  }

  @override
  String get pdfPhotoUnnamed => 'Foto';

  @override
  String get attachmentSaved => 'Datei gespeichert.';

  @override
  String get attachmentsTripTitle => 'Reiseunterlagen';

  @override
  String get attachmentsTripAdd => 'Reiseunterlage hinzufügen';

  @override
  String get galleryTitle => 'Fotos';

  @override
  String get coverSet => 'Als Titelbild verwenden';

  @override
  String get coverRemove => 'Titelbild entfernen';

  @override
  String photosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '1 Foto',
    );
    return '$_temp0';
  }

  @override
  String documentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dokumente',
      one: '1 Dokument',
    );
    return '$_temp0';
  }

  @override
  String get documentsTitle => 'Dokumente';

  @override
  String get photosTitle => 'Fotos';
}
