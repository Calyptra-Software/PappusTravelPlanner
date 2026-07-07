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
  String get notesOptional => 'Notizen (optional)';

  @override
  String get save => 'Speichern';

  @override
  String get add => 'Hinzufügen';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageGerman => 'Deutsch';

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
  String get widgetToday => 'Beginnt heute';

  @override
  String get widgetTomorrow => 'Beginnt morgen';

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
  String get costReasonNew => 'Neue Kategorie…';

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
  String get costPaidBy => 'Bezahlt von';

  @override
  String get costPaidByNone => 'Nicht zugewiesen';

  @override
  String get costPaidByNew => 'Neue Person…';

  @override
  String costPaidByName(String name) {
    return 'Bezahlt von $name';
  }

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
  String get participants => 'Teilnehmer';

  @override
  String get addParticipant => 'Teilnehmer hinzufügen';

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
}
