// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TripsTable extends Trips with TableInfo<$TripsTable, Trip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationMeta = const VerificationMeta(
    'destination',
  );
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
    'destination',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF00695C),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    destination,
    startDate,
    endDate,
    notes,
    colorValue,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('destination')) {
      context.handle(
        _destinationMeta,
        destination.isAcceptableOrUnknown(
          data['destination']!,
          _destinationMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      destination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class Trip extends DataClass implements Insertable<Trip> {
  final int id;
  final String title;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;

  /// ARGB colour used as the card accent, e.g. 0xFF00695C.
  final int colorValue;
  final DateTime createdAt;
  const Trip({
    required this.id,
    required this.title,
    required this.destination,
    this.startDate,
    this.endDate,
    this.notes,
    required this.colorValue,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['destination'] = Variable<String>(destination);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['color_value'] = Variable<int>(colorValue);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      title: Value(title),
      destination: Value(destination),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      colorValue: Value(colorValue),
      createdAt: Value(createdAt),
    );
  }

  factory Trip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      destination: serializer.fromJson<String>(json['destination']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      notes: serializer.fromJson<String?>(json['notes']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'destination': serializer.toJson<String>(destination),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'notes': serializer.toJson<String?>(notes),
      'colorValue': serializer.toJson<int>(colorValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Trip copyWith({
    int? id,
    String? title,
    String? destination,
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    int? colorValue,
    DateTime? createdAt,
  }) => Trip(
    id: id ?? this.id,
    title: title ?? this.title,
    destination: destination ?? this.destination,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    notes: notes.present ? notes.value : this.notes,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt ?? this.createdAt,
  );
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      destination: data.destination.present
          ? data.destination.value
          : this.destination,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      notes: data.notes.present ? data.notes.value : this.notes,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('destination: $destination, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('notes: $notes, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    destination,
    startDate,
    endDate,
    notes,
    colorValue,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip &&
          other.id == this.id &&
          other.title == this.title &&
          other.destination == this.destination &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.notes == this.notes &&
          other.colorValue == this.colorValue &&
          other.createdAt == this.createdAt);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> destination;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<String?> notes;
  final Value<int> colorValue;
  final Value<DateTime> createdAt;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.destination = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TripsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.destination = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<Trip> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? destination,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? notes,
    Expression<int>? colorValue,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (destination != null) 'destination': destination,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (notes != null) 'notes': notes,
      if (colorValue != null) 'color_value': colorValue,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TripsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? destination,
    Value<DateTime?>? startDate,
    Value<DateTime?>? endDate,
    Value<String?>? notes,
    Value<int>? colorValue,
    Value<DateTime>? createdAt,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('destination: $destination, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('notes: $notes, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ItineraryItemsTable extends ItineraryItems
    with TableInfo<$ItineraryItemsTable, ItineraryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItineraryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ItemKind>($ItineraryItemsTable.$converterkind);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMinutesMeta = const VerificationMeta(
    'startMinutes',
  );
  @override
  late final GeneratedColumn<int> startMinutes = GeneratedColumn<int>(
    'start_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinutesMeta = const VerificationMeta(
    'endMinutes',
  );
  @override
  late final GeneratedColumn<int> endMinutes = GeneratedColumn<int>(
    'end_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TransportMode?, int> mode =
      GeneratedColumn<int>(
        'mode',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<TransportMode?>($ItineraryItemsTable.$convertermoden);
  static const VerificationMeta _fromLocationMeta = const VerificationMeta(
    'fromLocation',
  );
  @override
  late final GeneratedColumn<String> fromLocation = GeneratedColumn<String>(
    'from_location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toLocationMeta = const VerificationMeta(
    'toLocation',
  );
  @override
  late final GeneratedColumn<String> toLocation = GeneratedColumn<String>(
    'to_location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    date,
    sortOrder,
    kind,
    title,
    startMinutes,
    endMinutes,
    notes,
    location,
    mode,
    fromLocation,
    toLocation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'itinerary_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItineraryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('start_minutes')) {
      context.handle(
        _startMinutesMeta,
        startMinutes.isAcceptableOrUnknown(
          data['start_minutes']!,
          _startMinutesMeta,
        ),
      );
    }
    if (data.containsKey('end_minutes')) {
      context.handle(
        _endMinutesMeta,
        endMinutes.isAcceptableOrUnknown(data['end_minutes']!, _endMinutesMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('from_location')) {
      context.handle(
        _fromLocationMeta,
        fromLocation.isAcceptableOrUnknown(
          data['from_location']!,
          _fromLocationMeta,
        ),
      );
    }
    if (data.containsKey('to_location')) {
      context.handle(
        _toLocationMeta,
        toLocation.isAcceptableOrUnknown(data['to_location']!, _toLocationMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItineraryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItineraryItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      kind: $ItineraryItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      startMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minutes'],
      ),
      endMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minutes'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      mode: $ItineraryItemsTable.$convertermoden.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}mode'],
        ),
      ),
      fromLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_location'],
      ),
      toLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_location'],
      ),
    );
  }

  @override
  $ItineraryItemsTable createAlias(String alias) {
    return $ItineraryItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemKind, int, int> $converterkind =
      const EnumIndexConverter<ItemKind>(ItemKind.values);
  static JsonTypeConverter2<TransportMode, int, int> $convertermode =
      const EnumIndexConverter<TransportMode>(TransportMode.values);
  static JsonTypeConverter2<TransportMode?, int?, int?> $convertermoden =
      JsonTypeConverter2.asNullable($convertermode);
}

class ItineraryItem extends DataClass implements Insertable<ItineraryItem> {
  final int id;
  final int tripId;

  /// The day this entry belongs to (time component ignored, normalised to midnight).
  final DateTime date;

  /// Manual ordering within a day, used for reordering the timeline.
  final int sortOrder;
  final ItemKind kind;
  final String? title;

  /// Times stored as minutes since midnight (0-1439), or null if unset.
  final int? startMinutes;
  final int? endMinutes;
  final String? notes;
  final String? location;
  final TransportMode? mode;
  final String? fromLocation;
  final String? toLocation;
  const ItineraryItem({
    required this.id,
    required this.tripId,
    required this.date,
    required this.sortOrder,
    required this.kind,
    this.title,
    this.startMinutes,
    this.endMinutes,
    this.notes,
    this.location,
    this.mode,
    this.fromLocation,
    this.toLocation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trip_id'] = Variable<int>(tripId);
    map['date'] = Variable<DateTime>(date);
    map['sort_order'] = Variable<int>(sortOrder);
    {
      map['kind'] = Variable<int>(
        $ItineraryItemsTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || startMinutes != null) {
      map['start_minutes'] = Variable<int>(startMinutes);
    }
    if (!nullToAbsent || endMinutes != null) {
      map['end_minutes'] = Variable<int>(endMinutes);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<int>(
        $ItineraryItemsTable.$convertermoden.toSql(mode),
      );
    }
    if (!nullToAbsent || fromLocation != null) {
      map['from_location'] = Variable<String>(fromLocation);
    }
    if (!nullToAbsent || toLocation != null) {
      map['to_location'] = Variable<String>(toLocation);
    }
    return map;
  }

  ItineraryItemsCompanion toCompanion(bool nullToAbsent) {
    return ItineraryItemsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      date: Value(date),
      sortOrder: Value(sortOrder),
      kind: Value(kind),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      startMinutes: startMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinutes),
      endMinutes: endMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinutes),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      fromLocation: fromLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLocation),
      toLocation: toLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(toLocation),
    );
  }

  factory ItineraryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItineraryItem(
      id: serializer.fromJson<int>(json['id']),
      tripId: serializer.fromJson<int>(json['tripId']),
      date: serializer.fromJson<DateTime>(json['date']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      kind: $ItineraryItemsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      title: serializer.fromJson<String?>(json['title']),
      startMinutes: serializer.fromJson<int?>(json['startMinutes']),
      endMinutes: serializer.fromJson<int?>(json['endMinutes']),
      notes: serializer.fromJson<String?>(json['notes']),
      location: serializer.fromJson<String?>(json['location']),
      mode: $ItineraryItemsTable.$convertermoden.fromJson(
        serializer.fromJson<int?>(json['mode']),
      ),
      fromLocation: serializer.fromJson<String?>(json['fromLocation']),
      toLocation: serializer.fromJson<String?>(json['toLocation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tripId': serializer.toJson<int>(tripId),
      'date': serializer.toJson<DateTime>(date),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'kind': serializer.toJson<int>(
        $ItineraryItemsTable.$converterkind.toJson(kind),
      ),
      'title': serializer.toJson<String?>(title),
      'startMinutes': serializer.toJson<int?>(startMinutes),
      'endMinutes': serializer.toJson<int?>(endMinutes),
      'notes': serializer.toJson<String?>(notes),
      'location': serializer.toJson<String?>(location),
      'mode': serializer.toJson<int?>(
        $ItineraryItemsTable.$convertermoden.toJson(mode),
      ),
      'fromLocation': serializer.toJson<String?>(fromLocation),
      'toLocation': serializer.toJson<String?>(toLocation),
    };
  }

  ItineraryItem copyWith({
    int? id,
    int? tripId,
    DateTime? date,
    int? sortOrder,
    ItemKind? kind,
    Value<String?> title = const Value.absent(),
    Value<int?> startMinutes = const Value.absent(),
    Value<int?> endMinutes = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<TransportMode?> mode = const Value.absent(),
    Value<String?> fromLocation = const Value.absent(),
    Value<String?> toLocation = const Value.absent(),
  }) => ItineraryItem(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    date: date ?? this.date,
    sortOrder: sortOrder ?? this.sortOrder,
    kind: kind ?? this.kind,
    title: title.present ? title.value : this.title,
    startMinutes: startMinutes.present ? startMinutes.value : this.startMinutes,
    endMinutes: endMinutes.present ? endMinutes.value : this.endMinutes,
    notes: notes.present ? notes.value : this.notes,
    location: location.present ? location.value : this.location,
    mode: mode.present ? mode.value : this.mode,
    fromLocation: fromLocation.present ? fromLocation.value : this.fromLocation,
    toLocation: toLocation.present ? toLocation.value : this.toLocation,
  );
  ItineraryItem copyWithCompanion(ItineraryItemsCompanion data) {
    return ItineraryItem(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      date: data.date.present ? data.date.value : this.date,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      startMinutes: data.startMinutes.present
          ? data.startMinutes.value
          : this.startMinutes,
      endMinutes: data.endMinutes.present
          ? data.endMinutes.value
          : this.endMinutes,
      notes: data.notes.present ? data.notes.value : this.notes,
      location: data.location.present ? data.location.value : this.location,
      mode: data.mode.present ? data.mode.value : this.mode,
      fromLocation: data.fromLocation.present
          ? data.fromLocation.value
          : this.fromLocation,
      toLocation: data.toLocation.present
          ? data.toLocation.value
          : this.toLocation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItineraryItem(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('date: $date, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('endMinutes: $endMinutes, ')
          ..write('notes: $notes, ')
          ..write('location: $location, ')
          ..write('mode: $mode, ')
          ..write('fromLocation: $fromLocation, ')
          ..write('toLocation: $toLocation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    date,
    sortOrder,
    kind,
    title,
    startMinutes,
    endMinutes,
    notes,
    location,
    mode,
    fromLocation,
    toLocation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItineraryItem &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.date == this.date &&
          other.sortOrder == this.sortOrder &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.startMinutes == this.startMinutes &&
          other.endMinutes == this.endMinutes &&
          other.notes == this.notes &&
          other.location == this.location &&
          other.mode == this.mode &&
          other.fromLocation == this.fromLocation &&
          other.toLocation == this.toLocation);
}

class ItineraryItemsCompanion extends UpdateCompanion<ItineraryItem> {
  final Value<int> id;
  final Value<int> tripId;
  final Value<DateTime> date;
  final Value<int> sortOrder;
  final Value<ItemKind> kind;
  final Value<String?> title;
  final Value<int?> startMinutes;
  final Value<int?> endMinutes;
  final Value<String?> notes;
  final Value<String?> location;
  final Value<TransportMode?> mode;
  final Value<String?> fromLocation;
  final Value<String?> toLocation;
  const ItineraryItemsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.date = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.startMinutes = const Value.absent(),
    this.endMinutes = const Value.absent(),
    this.notes = const Value.absent(),
    this.location = const Value.absent(),
    this.mode = const Value.absent(),
    this.fromLocation = const Value.absent(),
    this.toLocation = const Value.absent(),
  });
  ItineraryItemsCompanion.insert({
    this.id = const Value.absent(),
    required int tripId,
    required DateTime date,
    this.sortOrder = const Value.absent(),
    required ItemKind kind,
    this.title = const Value.absent(),
    this.startMinutes = const Value.absent(),
    this.endMinutes = const Value.absent(),
    this.notes = const Value.absent(),
    this.location = const Value.absent(),
    this.mode = const Value.absent(),
    this.fromLocation = const Value.absent(),
    this.toLocation = const Value.absent(),
  }) : tripId = Value(tripId),
       date = Value(date),
       kind = Value(kind);
  static Insertable<ItineraryItem> custom({
    Expression<int>? id,
    Expression<int>? tripId,
    Expression<DateTime>? date,
    Expression<int>? sortOrder,
    Expression<int>? kind,
    Expression<String>? title,
    Expression<int>? startMinutes,
    Expression<int>? endMinutes,
    Expression<String>? notes,
    Expression<String>? location,
    Expression<int>? mode,
    Expression<String>? fromLocation,
    Expression<String>? toLocation,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (date != null) 'date': date,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (startMinutes != null) 'start_minutes': startMinutes,
      if (endMinutes != null) 'end_minutes': endMinutes,
      if (notes != null) 'notes': notes,
      if (location != null) 'location': location,
      if (mode != null) 'mode': mode,
      if (fromLocation != null) 'from_location': fromLocation,
      if (toLocation != null) 'to_location': toLocation,
    });
  }

  ItineraryItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? tripId,
    Value<DateTime>? date,
    Value<int>? sortOrder,
    Value<ItemKind>? kind,
    Value<String?>? title,
    Value<int?>? startMinutes,
    Value<int?>? endMinutes,
    Value<String?>? notes,
    Value<String?>? location,
    Value<TransportMode?>? mode,
    Value<String?>? fromLocation,
    Value<String?>? toLocation,
  }) {
    return ItineraryItemsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      date: date ?? this.date,
      sortOrder: sortOrder ?? this.sortOrder,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      mode: mode ?? this.mode,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $ItineraryItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startMinutes.present) {
      map['start_minutes'] = Variable<int>(startMinutes.value);
    }
    if (endMinutes.present) {
      map['end_minutes'] = Variable<int>(endMinutes.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (mode.present) {
      map['mode'] = Variable<int>(
        $ItineraryItemsTable.$convertermoden.toSql(mode.value),
      );
    }
    if (fromLocation.present) {
      map['from_location'] = Variable<String>(fromLocation.value);
    }
    if (toLocation.present) {
      map['to_location'] = Variable<String>(toLocation.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItineraryItemsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('date: $date, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('endMinutes: $endMinutes, ')
          ..write('notes: $notes, ')
          ..write('location: $location, ')
          ..write('mode: $mode, ')
          ..write('fromLocation: $fromLocation, ')
          ..write('toLocation: $toLocation')
          ..write(')'))
        .toString();
  }
}

class $CostsTable extends Costs with TableInfo<$CostsTable, Cost> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES itinerary_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Currency, int> currency =
      GeneratedColumn<int>(
        'currency',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Currency>($CostsTable.$convertercurrency);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    tripId,
    amountMinor,
    currency,
    reason,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'costs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cost> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cost map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cost(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      ),
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: $CostsTable.$convertercurrency.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}currency'],
        )!,
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CostsTable createAlias(String alias) {
    return $CostsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Currency, int, int> $convertercurrency =
      const EnumIndexConverter<Currency>(Currency.values);
}

class Cost extends DataClass implements Insertable<Cost> {
  final int id;
  final int? itemId;

  /// Set for trip-level costs that aren't tied to a specific itinerary item.
  final int? tripId;

  /// Amount in the currency's minor unit (e.g. cents) to avoid float rounding.
  final int amountMinor;
  final Currency currency;
  final String reason;
  final DateTime createdAt;
  const Cost({
    required this.id,
    this.itemId,
    this.tripId,
    required this.amountMinor,
    required this.currency,
    required this.reason,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<int>(itemId);
    }
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<int>(tripId);
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    {
      map['currency'] = Variable<int>(
        $CostsTable.$convertercurrency.toSql(currency),
      );
    }
    map['reason'] = Variable<String>(reason);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CostsCompanion toCompanion(bool nullToAbsent) {
    return CostsCompanion(
      id: Value(id),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      reason: Value(reason),
      createdAt: Value(createdAt),
    );
  }

  factory Cost.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cost(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<int?>(json['itemId']),
      tripId: serializer.fromJson<int?>(json['tripId']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: $CostsTable.$convertercurrency.fromJson(
        serializer.fromJson<int>(json['currency']),
      ),
      reason: serializer.fromJson<String>(json['reason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<int?>(itemId),
      'tripId': serializer.toJson<int?>(tripId),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<int>(
        $CostsTable.$convertercurrency.toJson(currency),
      ),
      'reason': serializer.toJson<String>(reason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Cost copyWith({
    int? id,
    Value<int?> itemId = const Value.absent(),
    Value<int?> tripId = const Value.absent(),
    int? amountMinor,
    Currency? currency,
    String? reason,
    DateTime? createdAt,
  }) => Cost(
    id: id ?? this.id,
    itemId: itemId.present ? itemId.value : this.itemId,
    tripId: tripId.present ? tripId.value : this.tripId,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    reason: reason ?? this.reason,
    createdAt: createdAt ?? this.createdAt,
  );
  Cost copyWithCompanion(CostsCompanion data) {
    return Cost(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cost(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('tripId: $tripId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, itemId, tripId, amountMinor, currency, reason, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cost &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.tripId == this.tripId &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt);
}

class CostsCompanion extends UpdateCompanion<Cost> {
  final Value<int> id;
  final Value<int?> itemId;
  final Value<int?> tripId;
  final Value<int> amountMinor;
  final Value<Currency> currency;
  final Value<String> reason;
  final Value<DateTime> createdAt;
  const CostsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CostsCompanion.insert({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.tripId = const Value.absent(),
    required int amountMinor,
    required Currency currency,
    required String reason,
    this.createdAt = const Value.absent(),
  }) : amountMinor = Value(amountMinor),
       currency = Value(currency),
       reason = Value(reason);
  static Insertable<Cost> custom({
    Expression<int>? id,
    Expression<int>? itemId,
    Expression<int>? tripId,
    Expression<int>? amountMinor,
    Expression<int>? currency,
    Expression<String>? reason,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (tripId != null) 'trip_id': tripId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CostsCompanion copyWith({
    Value<int>? id,
    Value<int?>? itemId,
    Value<int?>? tripId,
    Value<int>? amountMinor,
    Value<Currency>? currency,
    Value<String>? reason,
    Value<DateTime>? createdAt,
  }) {
    return CostsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      tripId: tripId ?? this.tripId,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<int>(
        $CostsTable.$convertercurrency.toSql(currency.value),
      );
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CostsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('tripId: $tripId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CostReasonsTable extends CostReasons
    with TableInfo<$CostReasonsTable, CostReason> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CostReasonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cost_reasons';
  @override
  VerificationContext validateIntegrity(
    Insertable<CostReason> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CostReason map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CostReason(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
    );
  }

  @override
  $CostReasonsTable createAlias(String alias) {
    return $CostReasonsTable(attachedDatabase, alias);
  }
}

class CostReason extends DataClass implements Insertable<CostReason> {
  final int id;
  final String label;
  const CostReason({required this.id, required this.label});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    return map;
  }

  CostReasonsCompanion toCompanion(bool nullToAbsent) {
    return CostReasonsCompanion(id: Value(id), label: Value(label));
  }

  factory CostReason.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CostReason(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
    };
  }

  CostReason copyWith({int? id, String? label}) =>
      CostReason(id: id ?? this.id, label: label ?? this.label);
  CostReason copyWithCompanion(CostReasonsCompanion data) {
    return CostReason(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CostReason(')
          ..write('id: $id, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CostReason && other.id == this.id && other.label == this.label);
}

class CostReasonsCompanion extends UpdateCompanion<CostReason> {
  final Value<int> id;
  final Value<String> label;
  const CostReasonsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
  });
  CostReasonsCompanion.insert({
    this.id = const Value.absent(),
    required String label,
  }) : label = Value(label);
  static Insertable<CostReason> custom({
    Expression<int>? id,
    Expression<String>? label,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
    });
  }

  CostReasonsCompanion copyWith({Value<int>? id, Value<String>? label}) {
    return CostReasonsCompanion(id: id ?? this.id, label: label ?? this.label);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CostReasonsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $ItineraryItemsTable itineraryItems = $ItineraryItemsTable(this);
  late final $CostsTable costs = $CostsTable(this);
  late final $CostReasonsTable costReasons = $CostReasonsTable(this);
  late final TripDao tripDao = TripDao(this as AppDatabase);
  late final ItineraryDao itineraryDao = ItineraryDao(this as AppDatabase);
  late final CostDao costDao = CostDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trips,
    itineraryItems,
    costs,
    costReasons,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('itinerary_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'itinerary_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('costs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('costs', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TripsTableCreateCompanionBuilder =
    TripsCompanion Function({
      Value<int> id,
      required String title,
      Value<String> destination,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<String?> notes,
      Value<int> colorValue,
      Value<DateTime> createdAt,
    });
typedef $$TripsTableUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> destination,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<String?> notes,
      Value<int> colorValue,
      Value<DateTime> createdAt,
    });

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, Trip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItineraryItemsTable, List<ItineraryItem>>
  _itineraryItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itineraryItems,
    aliasName: 'trips__id__itinerary_items__trip_id',
  );

  $$ItineraryItemsTableProcessedTableManager get itineraryItemsRefs {
    final manager = $$ItineraryItemsTableTableManager(
      $_db,
      $_db.itineraryItems,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_itineraryItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CostsTable, List<Cost>> _costsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.costs,
    aliasName: 'trips__id__costs__trip_id',
  );

  $$CostsTableProcessedTableManager get costsRefs {
    final manager = $$CostsTableTableManager(
      $_db,
      $_db.costs,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_costsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itineraryItemsRefs(
    Expression<bool> Function($$ItineraryItemsTableFilterComposer f) f,
  ) {
    final $$ItineraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItineraryItemsTableFilterComposer(
            $db: $db,
            $table: $db.itineraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> costsRefs(
    Expression<bool> Function($$CostsTableFilterComposer f) f,
  ) {
    final $$CostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CostsTableFilterComposer(
            $db: $db,
            $table: $db.costs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> itineraryItemsRefs<T extends Object>(
    Expression<T> Function($$ItineraryItemsTableAnnotationComposer a) f,
  ) {
    final $$ItineraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItineraryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.itineraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> costsRefs<T extends Object>(
    Expression<T> Function($$CostsTableAnnotationComposer a) f,
  ) {
    final $$CostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CostsTableAnnotationComposer(
            $db: $db,
            $table: $db.costs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripsTable,
          Trip,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (Trip, $$TripsTableReferences),
          Trip,
          PrefetchHooks Function({bool itineraryItemsRefs, bool costsRefs})
        > {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> destination = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                title: title,
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                notes: notes,
                colorValue: colorValue,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String> destination = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                title: title,
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                notes: notes,
                colorValue: colorValue,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TripsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({itineraryItemsRefs = false, costsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itineraryItemsRefs) db.itineraryItems,
                    if (costsRefs) db.costs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itineraryItemsRefs)
                        await $_getPrefetchedData<
                          Trip,
                          $TripsTable,
                          ItineraryItem
                        >(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._itineraryItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).itineraryItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (costsRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, Cost>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._costsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(db, table, p0).costsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripsTable,
      Trip,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (Trip, $$TripsTableReferences),
      Trip,
      PrefetchHooks Function({bool itineraryItemsRefs, bool costsRefs})
    >;
typedef $$ItineraryItemsTableCreateCompanionBuilder =
    ItineraryItemsCompanion Function({
      Value<int> id,
      required int tripId,
      required DateTime date,
      Value<int> sortOrder,
      required ItemKind kind,
      Value<String?> title,
      Value<int?> startMinutes,
      Value<int?> endMinutes,
      Value<String?> notes,
      Value<String?> location,
      Value<TransportMode?> mode,
      Value<String?> fromLocation,
      Value<String?> toLocation,
    });
typedef $$ItineraryItemsTableUpdateCompanionBuilder =
    ItineraryItemsCompanion Function({
      Value<int> id,
      Value<int> tripId,
      Value<DateTime> date,
      Value<int> sortOrder,
      Value<ItemKind> kind,
      Value<String?> title,
      Value<int?> startMinutes,
      Value<int?> endMinutes,
      Value<String?> notes,
      Value<String?> location,
      Value<TransportMode?> mode,
      Value<String?> fromLocation,
      Value<String?> toLocation,
    });

final class $$ItineraryItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ItineraryItemsTable, ItineraryItem> {
  $$ItineraryItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('itinerary_items__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<int>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CostsTable, List<Cost>> _costsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.costs,
    aliasName: 'itinerary_items__id__costs__item_id',
  );

  $$CostsTableProcessedTableManager get costsRefs {
    final manager = $$CostsTableTableManager(
      $_db,
      $_db.costs,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_costsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItineraryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ItineraryItemsTable> {
  $$ItineraryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemKind, ItemKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TransportMode?, TransportMode, int> get mode =>
      $composableBuilder(
        column: $table.mode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get fromLocation => $composableBuilder(
    column: $table.fromLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toLocation => $composableBuilder(
    column: $table.toLocation,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> costsRefs(
    Expression<bool> Function($$CostsTableFilterComposer f) f,
  ) {
    final $$CostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CostsTableFilterComposer(
            $db: $db,
            $table: $db.costs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItineraryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItineraryItemsTable> {
  $$ItineraryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromLocation => $composableBuilder(
    column: $table.fromLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toLocation => $composableBuilder(
    column: $table.toLocation,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItineraryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItineraryItemsTable> {
  $$ItineraryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get startMinutes => $composableBuilder(
    column: $table.startMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinutes => $composableBuilder(
    column: $table.endMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransportMode?, int> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get fromLocation => $composableBuilder(
    column: $table.fromLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toLocation => $composableBuilder(
    column: $table.toLocation,
    builder: (column) => column,
  );

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> costsRefs<T extends Object>(
    Expression<T> Function($$CostsTableAnnotationComposer a) f,
  ) {
    final $$CostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CostsTableAnnotationComposer(
            $db: $db,
            $table: $db.costs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItineraryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItineraryItemsTable,
          ItineraryItem,
          $$ItineraryItemsTableFilterComposer,
          $$ItineraryItemsTableOrderingComposer,
          $$ItineraryItemsTableAnnotationComposer,
          $$ItineraryItemsTableCreateCompanionBuilder,
          $$ItineraryItemsTableUpdateCompanionBuilder,
          (ItineraryItem, $$ItineraryItemsTableReferences),
          ItineraryItem,
          PrefetchHooks Function({bool tripId, bool costsRefs})
        > {
  $$ItineraryItemsTableTableManager(
    _$AppDatabase db,
    $ItineraryItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItineraryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItineraryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItineraryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tripId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<ItemKind> kind = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> startMinutes = const Value.absent(),
                Value<int?> endMinutes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<TransportMode?> mode = const Value.absent(),
                Value<String?> fromLocation = const Value.absent(),
                Value<String?> toLocation = const Value.absent(),
              }) => ItineraryItemsCompanion(
                id: id,
                tripId: tripId,
                date: date,
                sortOrder: sortOrder,
                kind: kind,
                title: title,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                notes: notes,
                location: location,
                mode: mode,
                fromLocation: fromLocation,
                toLocation: toLocation,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tripId,
                required DateTime date,
                Value<int> sortOrder = const Value.absent(),
                required ItemKind kind,
                Value<String?> title = const Value.absent(),
                Value<int?> startMinutes = const Value.absent(),
                Value<int?> endMinutes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<TransportMode?> mode = const Value.absent(),
                Value<String?> fromLocation = const Value.absent(),
                Value<String?> toLocation = const Value.absent(),
              }) => ItineraryItemsCompanion.insert(
                id: id,
                tripId: tripId,
                date: date,
                sortOrder: sortOrder,
                kind: kind,
                title: title,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                notes: notes,
                location: location,
                mode: mode,
                fromLocation: fromLocation,
                toLocation: toLocation,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItineraryItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false, costsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (costsRefs) db.costs],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$ItineraryItemsTableReferences
                                    ._tripIdTable(db),
                                referencedColumn:
                                    $$ItineraryItemsTableReferences
                                        ._tripIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (costsRefs)
                    await $_getPrefetchedData<
                      ItineraryItem,
                      $ItineraryItemsTable,
                      Cost
                    >(
                      currentTable: table,
                      referencedTable: $$ItineraryItemsTableReferences
                          ._costsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ItineraryItemsTableReferences(
                            db,
                            table,
                            p0,
                          ).costsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.itemId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ItineraryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItineraryItemsTable,
      ItineraryItem,
      $$ItineraryItemsTableFilterComposer,
      $$ItineraryItemsTableOrderingComposer,
      $$ItineraryItemsTableAnnotationComposer,
      $$ItineraryItemsTableCreateCompanionBuilder,
      $$ItineraryItemsTableUpdateCompanionBuilder,
      (ItineraryItem, $$ItineraryItemsTableReferences),
      ItineraryItem,
      PrefetchHooks Function({bool tripId, bool costsRefs})
    >;
typedef $$CostsTableCreateCompanionBuilder =
    CostsCompanion Function({
      Value<int> id,
      Value<int?> itemId,
      Value<int?> tripId,
      required int amountMinor,
      required Currency currency,
      required String reason,
      Value<DateTime> createdAt,
    });
typedef $$CostsTableUpdateCompanionBuilder =
    CostsCompanion Function({
      Value<int> id,
      Value<int?> itemId,
      Value<int?> tripId,
      Value<int> amountMinor,
      Value<Currency> currency,
      Value<String> reason,
      Value<DateTime> createdAt,
    });

final class $$CostsTableReferences
    extends BaseReferences<_$AppDatabase, $CostsTable, Cost> {
  $$CostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItineraryItemsTable _itemIdTable(_$AppDatabase db) =>
      db.itineraryItems.createAlias('costs__item_id__itinerary_items__id');

  $$ItineraryItemsTableProcessedTableManager? get itemId {
    final $_column = $_itemColumn<int>('item_id');
    if ($_column == null) return null;
    final manager = $$ItineraryItemsTableTableManager(
      $_db,
      $_db.itineraryItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('costs__trip_id__trips__id');

  $$TripsTableProcessedTableManager? get tripId {
    final $_column = $_itemColumn<int>('trip_id');
    if ($_column == null) return null;
    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CostsTableFilterComposer extends Composer<_$AppDatabase, $CostsTable> {
  $$CostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Currency, Currency, int> get currency =>
      $composableBuilder(
        column: $table.currency,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItineraryItemsTableFilterComposer get itemId {
    final $$ItineraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItineraryItemsTableFilterComposer(
            $db: $db,
            $table: $db.itineraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CostsTableOrderingComposer
    extends Composer<_$AppDatabase, $CostsTable> {
  $$CostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItineraryItemsTableOrderingComposer get itemId {
    final $$ItineraryItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItineraryItemsTableOrderingComposer(
            $db: $db,
            $table: $db.itineraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CostsTable> {
  $$CostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Currency, int> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ItineraryItemsTableAnnotationComposer get itemId {
    final $$ItineraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItineraryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.itineraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CostsTable,
          Cost,
          $$CostsTableFilterComposer,
          $$CostsTableOrderingComposer,
          $$CostsTableAnnotationComposer,
          $$CostsTableCreateCompanionBuilder,
          $$CostsTableUpdateCompanionBuilder,
          (Cost, $$CostsTableReferences),
          Cost,
          PrefetchHooks Function({bool itemId, bool tripId})
        > {
  $$CostsTableTableManager(_$AppDatabase db, $CostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> itemId = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<Currency> currency = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CostsCompanion(
                id: id,
                itemId: itemId,
                tripId: tripId,
                amountMinor: amountMinor,
                currency: currency,
                reason: reason,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> itemId = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                required int amountMinor,
                required Currency currency,
                required String reason,
                Value<DateTime> createdAt = const Value.absent(),
              }) => CostsCompanion.insert(
                id: id,
                itemId: itemId,
                tripId: tripId,
                amountMinor: amountMinor,
                currency: currency,
                reason: reason,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CostsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false, tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$CostsTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$CostsTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$CostsTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$CostsTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CostsTable,
      Cost,
      $$CostsTableFilterComposer,
      $$CostsTableOrderingComposer,
      $$CostsTableAnnotationComposer,
      $$CostsTableCreateCompanionBuilder,
      $$CostsTableUpdateCompanionBuilder,
      (Cost, $$CostsTableReferences),
      Cost,
      PrefetchHooks Function({bool itemId, bool tripId})
    >;
typedef $$CostReasonsTableCreateCompanionBuilder =
    CostReasonsCompanion Function({Value<int> id, required String label});
typedef $$CostReasonsTableUpdateCompanionBuilder =
    CostReasonsCompanion Function({Value<int> id, Value<String> label});

class $$CostReasonsTableFilterComposer
    extends Composer<_$AppDatabase, $CostReasonsTable> {
  $$CostReasonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CostReasonsTableOrderingComposer
    extends Composer<_$AppDatabase, $CostReasonsTable> {
  $$CostReasonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CostReasonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CostReasonsTable> {
  $$CostReasonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);
}

class $$CostReasonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CostReasonsTable,
          CostReason,
          $$CostReasonsTableFilterComposer,
          $$CostReasonsTableOrderingComposer,
          $$CostReasonsTableAnnotationComposer,
          $$CostReasonsTableCreateCompanionBuilder,
          $$CostReasonsTableUpdateCompanionBuilder,
          (
            CostReason,
            BaseReferences<_$AppDatabase, $CostReasonsTable, CostReason>,
          ),
          CostReason,
          PrefetchHooks Function()
        > {
  $$CostReasonsTableTableManager(_$AppDatabase db, $CostReasonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CostReasonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CostReasonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CostReasonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
              }) => CostReasonsCompanion(id: id, label: label),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String label}) =>
                  CostReasonsCompanion.insert(id: id, label: label),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CostReasonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CostReasonsTable,
      CostReason,
      $$CostReasonsTableFilterComposer,
      $$CostReasonsTableOrderingComposer,
      $$CostReasonsTableAnnotationComposer,
      $$CostReasonsTableCreateCompanionBuilder,
      $$CostReasonsTableUpdateCompanionBuilder,
      (
        CostReason,
        BaseReferences<_$AppDatabase, $CostReasonsTable, CostReason>,
      ),
      CostReason,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$ItineraryItemsTableTableManager get itineraryItems =>
      $$ItineraryItemsTableTableManager(_db, _db.itineraryItems);
  $$CostsTableTableManager get costs =>
      $$CostsTableTableManager(_db, _db.costs);
  $$CostReasonsTableTableManager get costReasons =>
      $$CostReasonsTableTableManager(_db, _db.costReasons);
}
