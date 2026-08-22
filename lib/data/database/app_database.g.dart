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
  @override
  late final GeneratedColumnWithTypeConverter<TripKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<TripKind>($TripsTable.$converterkind);
  static const VerificationMeta _fromRoutineIdMeta = const VerificationMeta(
    'fromRoutineId',
  );
  @override
  late final GeneratedColumn<int> fromRoutineId = GeneratedColumn<int>(
    'from_routine_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE SET NULL',
    ),
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
    kind,
    fromRoutineId,
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
    if (data.containsKey('from_routine_id')) {
      context.handle(
        _fromRoutineIdMeta,
        fromRoutineId.isAcceptableOrUnknown(
          data['from_routine_id']!,
          _fromRoutineIdMeta,
        ),
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
      kind: $TripsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      fromRoutineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_routine_id'],
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

  static JsonTypeConverter2<TripKind, int, int> $converterkind =
      const EnumIndexConverter<TripKind>(TripKind.values);
}

class Trip extends DataClass implements Insertable<Trip> {
  final int id;
  final String title;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;

  /// Whether this is a trip or a template for one. Defaults to [TripKind.trip]
  /// so every row written before the column existed keeps its behaviour.
  final TripKind kind;

  /// The [TripKind.routine] this trip was created from, when it was. Records
  /// where the plan came from — enough to warn before recording the same
  /// routine twice on one day, and to list what a routine has produced.
  /// `setNull` on delete: a trip that happened does not stop having happened
  /// because the template it came from was thrown away.
  final int? fromRoutineId;

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
    required this.kind,
    this.fromRoutineId,
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
    {
      map['kind'] = Variable<int>($TripsTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || fromRoutineId != null) {
      map['from_routine_id'] = Variable<int>(fromRoutineId);
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
      kind: Value(kind),
      fromRoutineId: fromRoutineId == null && nullToAbsent
          ? const Value.absent()
          : Value(fromRoutineId),
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
      kind: $TripsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      fromRoutineId: serializer.fromJson<int?>(json['fromRoutineId']),
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
      'kind': serializer.toJson<int>($TripsTable.$converterkind.toJson(kind)),
      'fromRoutineId': serializer.toJson<int?>(fromRoutineId),
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
    TripKind? kind,
    Value<int?> fromRoutineId = const Value.absent(),
    int? colorValue,
    DateTime? createdAt,
  }) => Trip(
    id: id ?? this.id,
    title: title ?? this.title,
    destination: destination ?? this.destination,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    notes: notes.present ? notes.value : this.notes,
    kind: kind ?? this.kind,
    fromRoutineId: fromRoutineId.present
        ? fromRoutineId.value
        : this.fromRoutineId,
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
      kind: data.kind.present ? data.kind.value : this.kind,
      fromRoutineId: data.fromRoutineId.present
          ? data.fromRoutineId.value
          : this.fromRoutineId,
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
          ..write('kind: $kind, ')
          ..write('fromRoutineId: $fromRoutineId, ')
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
    kind,
    fromRoutineId,
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
          other.kind == this.kind &&
          other.fromRoutineId == this.fromRoutineId &&
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
  final Value<TripKind> kind;
  final Value<int?> fromRoutineId;
  final Value<int> colorValue;
  final Value<DateTime> createdAt;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.destination = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.notes = const Value.absent(),
    this.kind = const Value.absent(),
    this.fromRoutineId = const Value.absent(),
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
    this.kind = const Value.absent(),
    this.fromRoutineId = const Value.absent(),
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
    Expression<int>? kind,
    Expression<int>? fromRoutineId,
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
      if (kind != null) 'kind': kind,
      if (fromRoutineId != null) 'from_routine_id': fromRoutineId,
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
    Value<TripKind>? kind,
    Value<int?>? fromRoutineId,
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
      kind: kind ?? this.kind,
      fromRoutineId: fromRoutineId ?? this.fromRoutineId,
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
    if (kind.present) {
      map['kind'] = Variable<int>($TripsTable.$converterkind.toSql(kind.value));
    }
    if (fromRoutineId.present) {
      map['from_routine_id'] = Variable<int>(fromRoutineId.value);
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
          ..write('kind: $kind, ')
          ..write('fromRoutineId: $fromRoutineId, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ItemGroupsTable extends ItemGroups
    with TableInfo<$ItemGroupsTable, ItemGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _collapsedMeta = const VerificationMeta(
    'collapsed',
  );
  @override
  late final GeneratedColumn<bool> collapsed = GeneratedColumn<bool>(
    'collapsed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collapsed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, tripId, label, collapsed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemGroup> instance, {
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
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('collapsed')) {
      context.handle(
        _collapsedMeta,
        collapsed.isAcceptableOrUnknown(data['collapsed']!, _collapsedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      collapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collapsed'],
      )!,
    );
  }

  @override
  $ItemGroupsTable createAlias(String alias) {
    return $ItemGroupsTable(attachedDatabase, alias);
  }
}

class ItemGroup extends DataClass implements Insertable<ItemGroup> {
  final int id;
  final int tripId;

  /// Optional display name (e.g. "Train to Rome"); falls back to a default label.
  final String? label;

  /// Whether the group is shown collapsed in the itinerary overview. Persisted
  /// like [Checklists.collapsed] so the state survives reopening.
  final bool collapsed;
  const ItemGroup({
    required this.id,
    required this.tripId,
    this.label,
    required this.collapsed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trip_id'] = Variable<int>(tripId);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['collapsed'] = Variable<bool>(collapsed);
    return map;
  }

  ItemGroupsCompanion toCompanion(bool nullToAbsent) {
    return ItemGroupsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      collapsed: Value(collapsed),
    );
  }

  factory ItemGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemGroup(
      id: serializer.fromJson<int>(json['id']),
      tripId: serializer.fromJson<int>(json['tripId']),
      label: serializer.fromJson<String?>(json['label']),
      collapsed: serializer.fromJson<bool>(json['collapsed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tripId': serializer.toJson<int>(tripId),
      'label': serializer.toJson<String?>(label),
      'collapsed': serializer.toJson<bool>(collapsed),
    };
  }

  ItemGroup copyWith({
    int? id,
    int? tripId,
    Value<String?> label = const Value.absent(),
    bool? collapsed,
  }) => ItemGroup(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    label: label.present ? label.value : this.label,
    collapsed: collapsed ?? this.collapsed,
  );
  ItemGroup copyWithCompanion(ItemGroupsCompanion data) {
    return ItemGroup(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      label: data.label.present ? data.label.value : this.label,
      collapsed: data.collapsed.present ? data.collapsed.value : this.collapsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemGroup(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('label: $label, ')
          ..write('collapsed: $collapsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tripId, label, collapsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemGroup &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.label == this.label &&
          other.collapsed == this.collapsed);
}

class ItemGroupsCompanion extends UpdateCompanion<ItemGroup> {
  final Value<int> id;
  final Value<int> tripId;
  final Value<String?> label;
  final Value<bool> collapsed;
  const ItemGroupsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.label = const Value.absent(),
    this.collapsed = const Value.absent(),
  });
  ItemGroupsCompanion.insert({
    this.id = const Value.absent(),
    required int tripId,
    this.label = const Value.absent(),
    this.collapsed = const Value.absent(),
  }) : tripId = Value(tripId);
  static Insertable<ItemGroup> custom({
    Expression<int>? id,
    Expression<int>? tripId,
    Expression<String>? label,
    Expression<bool>? collapsed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (label != null) 'label': label,
      if (collapsed != null) 'collapsed': collapsed,
    });
  }

  ItemGroupsCompanion copyWith({
    Value<int>? id,
    Value<int>? tripId,
    Value<String?>? label,
    Value<bool>? collapsed,
  }) {
    return ItemGroupsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      label: label ?? this.label,
      collapsed: collapsed ?? this.collapsed,
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
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (collapsed.present) {
      map['collapsed'] = Variable<bool>(collapsed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemGroupsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('label: $label, ')
          ..write('collapsed: $collapsed')
          ..write(')'))
        .toString();
  }
}

class $AlternativeSetsTable extends AlternativeSets
    with TableInfo<$AlternativeSetsTable, AlternativeSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlternativeSetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, tripId, date, sortOrder, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alternative_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlternativeSet> instance, {
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
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlternativeSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlternativeSet(
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
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
    );
  }

  @override
  $AlternativeSetsTable createAlias(String alias) {
    return $AlternativeSetsTable(attachedDatabase, alias);
  }
}

class AlternativeSet extends DataClass implements Insertable<AlternativeSet> {
  final int id;
  final int tripId;

  /// The day this decision sits on (normalized to midnight, like
  /// [ItineraryItems.date]). Branches are day-scoped: every item in every branch
  /// belongs to this day.
  final DateTime date;

  /// The set's position within its day, sharing one ordering space with that
  /// day's loose items — the whole set is a single block in the timeline.
  final int sortOrder;

  /// Optional display name (e.g. "Saturday afternoon"); falls back to a default
  /// label in the UI.
  final String? label;
  const AlternativeSet({
    required this.id,
    required this.tripId,
    required this.date,
    required this.sortOrder,
    this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trip_id'] = Variable<int>(tripId);
    map['date'] = Variable<DateTime>(date);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    return map;
  }

  AlternativeSetsCompanion toCompanion(bool nullToAbsent) {
    return AlternativeSetsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      date: Value(date),
      sortOrder: Value(sortOrder),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
    );
  }

  factory AlternativeSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlternativeSet(
      id: serializer.fromJson<int>(json['id']),
      tripId: serializer.fromJson<int>(json['tripId']),
      date: serializer.fromJson<DateTime>(json['date']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      label: serializer.fromJson<String?>(json['label']),
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
      'label': serializer.toJson<String?>(label),
    };
  }

  AlternativeSet copyWith({
    int? id,
    int? tripId,
    DateTime? date,
    int? sortOrder,
    Value<String?> label = const Value.absent(),
  }) => AlternativeSet(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    date: date ?? this.date,
    sortOrder: sortOrder ?? this.sortOrder,
    label: label.present ? label.value : this.label,
  );
  AlternativeSet copyWithCompanion(AlternativeSetsCompanion data) {
    return AlternativeSet(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      date: data.date.present ? data.date.value : this.date,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlternativeSet(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('date: $date, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tripId, date, sortOrder, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlternativeSet &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.date == this.date &&
          other.sortOrder == this.sortOrder &&
          other.label == this.label);
}

class AlternativeSetsCompanion extends UpdateCompanion<AlternativeSet> {
  final Value<int> id;
  final Value<int> tripId;
  final Value<DateTime> date;
  final Value<int> sortOrder;
  final Value<String?> label;
  const AlternativeSetsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.date = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.label = const Value.absent(),
  });
  AlternativeSetsCompanion.insert({
    this.id = const Value.absent(),
    required int tripId,
    required DateTime date,
    this.sortOrder = const Value.absent(),
    this.label = const Value.absent(),
  }) : tripId = Value(tripId),
       date = Value(date);
  static Insertable<AlternativeSet> custom({
    Expression<int>? id,
    Expression<int>? tripId,
    Expression<DateTime>? date,
    Expression<int>? sortOrder,
    Expression<String>? label,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (date != null) 'date': date,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (label != null) 'label': label,
    });
  }

  AlternativeSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? tripId,
    Value<DateTime>? date,
    Value<int>? sortOrder,
    Value<String?>? label,
  }) {
    return AlternativeSetsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      date: date ?? this.date,
      sortOrder: sortOrder ?? this.sortOrder,
      label: label ?? this.label,
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
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlternativeSetsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('date: $date, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }
}

class $AlternativesTable extends Alternatives
    with TableInfo<$AlternativesTable, Alternative> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlternativesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<int> setId = GeneratedColumn<int>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES alternative_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _chosenMeta = const VerificationMeta('chosen');
  @override
  late final GeneratedColumn<bool> chosen = GeneratedColumn<bool>(
    'chosen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("chosen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, setId, label, sortOrder, chosen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alternatives';
  @override
  VerificationContext validateIntegrity(
    Insertable<Alternative> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('chosen')) {
      context.handle(
        _chosenMeta,
        chosen.isAcceptableOrUnknown(data['chosen']!, _chosenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Alternative map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Alternative(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      chosen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}chosen'],
      )!,
    );
  }

  @override
  $AlternativesTable createAlias(String alias) {
    return $AlternativesTable(attachedDatabase, alias);
  }
}

class Alternative extends DataClass implements Insertable<Alternative> {
  final int id;
  final int setId;

  /// Optional display name (e.g. "Museum day"); falls back to "Option A/B/C".
  final String? label;

  /// Order of the branches within the set — the order they are swiped through.
  final int sortOrder;

  /// Whether this is the branch currently selected for the plan. At most one per
  /// set; see the class doc.
  final bool chosen;
  const Alternative({
    required this.id,
    required this.setId,
    this.label,
    required this.sortOrder,
    required this.chosen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['set_id'] = Variable<int>(setId);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['chosen'] = Variable<bool>(chosen);
    return map;
  }

  AlternativesCompanion toCompanion(bool nullToAbsent) {
    return AlternativesCompanion(
      id: Value(id),
      setId: Value(setId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      sortOrder: Value(sortOrder),
      chosen: Value(chosen),
    );
  }

  factory Alternative.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Alternative(
      id: serializer.fromJson<int>(json['id']),
      setId: serializer.fromJson<int>(json['setId']),
      label: serializer.fromJson<String?>(json['label']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      chosen: serializer.fromJson<bool>(json['chosen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'setId': serializer.toJson<int>(setId),
      'label': serializer.toJson<String?>(label),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'chosen': serializer.toJson<bool>(chosen),
    };
  }

  Alternative copyWith({
    int? id,
    int? setId,
    Value<String?> label = const Value.absent(),
    int? sortOrder,
    bool? chosen,
  }) => Alternative(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    label: label.present ? label.value : this.label,
    sortOrder: sortOrder ?? this.sortOrder,
    chosen: chosen ?? this.chosen,
  );
  Alternative copyWithCompanion(AlternativesCompanion data) {
    return Alternative(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      label: data.label.present ? data.label.value : this.label,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      chosen: data.chosen.present ? data.chosen.value : this.chosen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Alternative(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('label: $label, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('chosen: $chosen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, setId, label, sortOrder, chosen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Alternative &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.label == this.label &&
          other.sortOrder == this.sortOrder &&
          other.chosen == this.chosen);
}

class AlternativesCompanion extends UpdateCompanion<Alternative> {
  final Value<int> id;
  final Value<int> setId;
  final Value<String?> label;
  final Value<int> sortOrder;
  final Value<bool> chosen;
  const AlternativesCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.label = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.chosen = const Value.absent(),
  });
  AlternativesCompanion.insert({
    this.id = const Value.absent(),
    required int setId,
    this.label = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.chosen = const Value.absent(),
  }) : setId = Value(setId);
  static Insertable<Alternative> custom({
    Expression<int>? id,
    Expression<int>? setId,
    Expression<String>? label,
    Expression<int>? sortOrder,
    Expression<bool>? chosen,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (label != null) 'label': label,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (chosen != null) 'chosen': chosen,
    });
  }

  AlternativesCompanion copyWith({
    Value<int>? id,
    Value<int>? setId,
    Value<String?>? label,
    Value<int>? sortOrder,
    Value<bool>? chosen,
  }) {
    return AlternativesCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      chosen: chosen ?? this.chosen,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<int>(setId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (chosen.present) {
      map['chosen'] = Variable<bool>(chosen.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlternativesCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('label: $label, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('chosen: $chosen')
          ..write(')'))
        .toString();
  }
}

class $TransportModesTable extends TransportModes
    with TableInfo<$TransportModesTable, TransportModeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransportModesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _builtinKeyMeta = const VerificationMeta(
    'builtinKey',
  );
  @override
  late final GeneratedColumn<String> builtinKey = GeneratedColumn<String>(
    'builtin_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _iconIdMeta = const VerificationMeta('iconId');
  @override
  late final GeneratedColumn<int> iconId = GeneratedColumn<int>(
    'icon_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  List<GeneratedColumn> get $columns => [
    id,
    builtinKey,
    name,
    iconId,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transport_modes';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransportModeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('builtin_key')) {
      context.handle(
        _builtinKeyMeta,
        builtinKey.isAcceptableOrUnknown(data['builtin_key']!, _builtinKeyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('icon_id')) {
      context.handle(
        _iconIdMeta,
        iconId.isAcceptableOrUnknown(data['icon_id']!, _iconIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransportModeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransportModeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      builtinKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}builtin_key'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      iconId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TransportModesTable createAlias(String alias) {
    return $TransportModesTable(attachedDatabase, alias);
  }
}

class TransportModeRow extends DataClass
    implements Insertable<TransportModeRow> {
  final int id;

  /// The [TransportMode] value this row was seeded from (its `name`), or null
  /// for a user-created mode. Gives a built-in its localized label and default
  /// icon, and a stable identity that survives sharing across databases.
  final String? builtinKey;

  /// The user-visible label. Null on a pristine built-in (whose label comes from
  /// [builtinKey] instead); set for a custom mode or a renamed built-in. Unique
  /// among the modes that have one, so no two read the same.
  final String? name;

  /// Stable key into the curated icon set (`kTransportModeIcons`), or null to
  /// use the default icon. Not a font code point, so the set can change safely.
  final int? iconId;

  /// Manual ordering for the picker and settings list.
  final int sortOrder;
  const TransportModeRow({
    required this.id,
    this.builtinKey,
    this.name,
    this.iconId,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || builtinKey != null) {
      map['builtin_key'] = Variable<String>(builtinKey);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || iconId != null) {
      map['icon_id'] = Variable<int>(iconId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TransportModesCompanion toCompanion(bool nullToAbsent) {
    return TransportModesCompanion(
      id: Value(id),
      builtinKey: builtinKey == null && nullToAbsent
          ? const Value.absent()
          : Value(builtinKey),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      iconId: iconId == null && nullToAbsent
          ? const Value.absent()
          : Value(iconId),
      sortOrder: Value(sortOrder),
    );
  }

  factory TransportModeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransportModeRow(
      id: serializer.fromJson<int>(json['id']),
      builtinKey: serializer.fromJson<String?>(json['builtinKey']),
      name: serializer.fromJson<String?>(json['name']),
      iconId: serializer.fromJson<int?>(json['iconId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'builtinKey': serializer.toJson<String?>(builtinKey),
      'name': serializer.toJson<String?>(name),
      'iconId': serializer.toJson<int?>(iconId),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  TransportModeRow copyWith({
    int? id,
    Value<String?> builtinKey = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<int?> iconId = const Value.absent(),
    int? sortOrder,
  }) => TransportModeRow(
    id: id ?? this.id,
    builtinKey: builtinKey.present ? builtinKey.value : this.builtinKey,
    name: name.present ? name.value : this.name,
    iconId: iconId.present ? iconId.value : this.iconId,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  TransportModeRow copyWithCompanion(TransportModesCompanion data) {
    return TransportModeRow(
      id: data.id.present ? data.id.value : this.id,
      builtinKey: data.builtinKey.present
          ? data.builtinKey.value
          : this.builtinKey,
      name: data.name.present ? data.name.value : this.name,
      iconId: data.iconId.present ? data.iconId.value : this.iconId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransportModeRow(')
          ..write('id: $id, ')
          ..write('builtinKey: $builtinKey, ')
          ..write('name: $name, ')
          ..write('iconId: $iconId, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, builtinKey, name, iconId, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransportModeRow &&
          other.id == this.id &&
          other.builtinKey == this.builtinKey &&
          other.name == this.name &&
          other.iconId == this.iconId &&
          other.sortOrder == this.sortOrder);
}

class TransportModesCompanion extends UpdateCompanion<TransportModeRow> {
  final Value<int> id;
  final Value<String?> builtinKey;
  final Value<String?> name;
  final Value<int?> iconId;
  final Value<int> sortOrder;
  const TransportModesCompanion({
    this.id = const Value.absent(),
    this.builtinKey = const Value.absent(),
    this.name = const Value.absent(),
    this.iconId = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  TransportModesCompanion.insert({
    this.id = const Value.absent(),
    this.builtinKey = const Value.absent(),
    this.name = const Value.absent(),
    this.iconId = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  static Insertable<TransportModeRow> custom({
    Expression<int>? id,
    Expression<String>? builtinKey,
    Expression<String>? name,
    Expression<int>? iconId,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (builtinKey != null) 'builtin_key': builtinKey,
      if (name != null) 'name': name,
      if (iconId != null) 'icon_id': iconId,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  TransportModesCompanion copyWith({
    Value<int>? id,
    Value<String?>? builtinKey,
    Value<String?>? name,
    Value<int?>? iconId,
    Value<int>? sortOrder,
  }) {
    return TransportModesCompanion(
      id: id ?? this.id,
      builtinKey: builtinKey ?? this.builtinKey,
      name: name ?? this.name,
      iconId: iconId ?? this.iconId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (builtinKey.present) {
      map['builtin_key'] = Variable<String>(builtinKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconId.present) {
      map['icon_id'] = Variable<int>(iconId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransportModesCompanion(')
          ..write('id: $id, ')
          ..write('builtinKey: $builtinKey, ')
          ..write('name: $name, ')
          ..write('iconId: $iconId, ')
          ..write('sortOrder: $sortOrder')
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
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES item_groups (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _alternativeIdMeta = const VerificationMeta(
    'alternativeId',
  );
  @override
  late final GeneratedColumn<int> alternativeId = GeneratedColumn<int>(
    'alternative_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES alternatives (id) ON DELETE CASCADE',
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
  static const VerificationMeta _actualStartMinutesMeta =
      const VerificationMeta('actualStartMinutes');
  @override
  late final GeneratedColumn<int> actualStartMinutes = GeneratedColumn<int>(
    'actual_start_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualEndMinutesMeta = const VerificationMeta(
    'actualEndMinutes',
  );
  @override
  late final GeneratedColumn<int> actualEndMinutes = GeneratedColumn<int>(
    'actual_end_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spansNextDayMeta = const VerificationMeta(
    'spansNextDay',
  );
  @override
  late final GeneratedColumn<bool> spansNextDay = GeneratedColumn<bool>(
    'spans_next_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("spans_next_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<int> mode = GeneratedColumn<int>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transport_modes (id) ON DELETE SET NULL',
    ),
  );
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
  static const VerificationMeta _fromLatMeta = const VerificationMeta(
    'fromLat',
  );
  @override
  late final GeneratedColumn<double> fromLat = GeneratedColumn<double>(
    'from_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromLonMeta = const VerificationMeta(
    'fromLon',
  );
  @override
  late final GeneratedColumn<double> fromLon = GeneratedColumn<double>(
    'from_lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toLatMeta = const VerificationMeta('toLat');
  @override
  late final GeneratedColumn<double> toLat = GeneratedColumn<double>(
    'to_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toLonMeta = const VerificationMeta('toLon');
  @override
  late final GeneratedColumn<double> toLon = GeneratedColumn<double>(
    'to_lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTripIdMeta = const VerificationMeta(
    'sourceTripId',
  );
  @override
  late final GeneratedColumn<String> sourceTripId = GeneratedColumn<String>(
    'source_trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromPlaceIdMeta = const VerificationMeta(
    'fromPlaceId',
  );
  @override
  late final GeneratedColumn<String> fromPlaceId = GeneratedColumn<String>(
    'from_place_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toPlaceIdMeta = const VerificationMeta(
    'toPlaceId',
  );
  @override
  late final GeneratedColumn<String> toPlaceId = GeneratedColumn<String>(
    'to_place_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stopoversMeta = const VerificationMeta(
    'stopovers',
  );
  @override
  late final GeneratedColumn<String> stopovers = GeneratedColumn<String>(
    'stopovers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    groupId,
    alternativeId,
    date,
    sortOrder,
    kind,
    title,
    startMinutes,
    endMinutes,
    actualStartMinutes,
    actualEndMinutes,
    spansNextDay,
    notes,
    colorValue,
    location,
    lat,
    lon,
    mode,
    fromLocation,
    toLocation,
    fromLat,
    fromLon,
    toLat,
    toLon,
    sourceTripId,
    fromPlaceId,
    toPlaceId,
    stopovers,
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
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('alternative_id')) {
      context.handle(
        _alternativeIdMeta,
        alternativeId.isAcceptableOrUnknown(
          data['alternative_id']!,
          _alternativeIdMeta,
        ),
      );
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
    if (data.containsKey('actual_start_minutes')) {
      context.handle(
        _actualStartMinutesMeta,
        actualStartMinutes.isAcceptableOrUnknown(
          data['actual_start_minutes']!,
          _actualStartMinutesMeta,
        ),
      );
    }
    if (data.containsKey('actual_end_minutes')) {
      context.handle(
        _actualEndMinutesMeta,
        actualEndMinutes.isAcceptableOrUnknown(
          data['actual_end_minutes']!,
          _actualEndMinutesMeta,
        ),
      );
    }
    if (data.containsKey('spans_next_day')) {
      context.handle(
        _spansNextDayMeta,
        spansNextDay.isAcceptableOrUnknown(
          data['spans_next_day']!,
          _spansNextDayMeta,
        ),
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
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
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
    if (data.containsKey('from_lat')) {
      context.handle(
        _fromLatMeta,
        fromLat.isAcceptableOrUnknown(data['from_lat']!, _fromLatMeta),
      );
    }
    if (data.containsKey('from_lon')) {
      context.handle(
        _fromLonMeta,
        fromLon.isAcceptableOrUnknown(data['from_lon']!, _fromLonMeta),
      );
    }
    if (data.containsKey('to_lat')) {
      context.handle(
        _toLatMeta,
        toLat.isAcceptableOrUnknown(data['to_lat']!, _toLatMeta),
      );
    }
    if (data.containsKey('to_lon')) {
      context.handle(
        _toLonMeta,
        toLon.isAcceptableOrUnknown(data['to_lon']!, _toLonMeta),
      );
    }
    if (data.containsKey('source_trip_id')) {
      context.handle(
        _sourceTripIdMeta,
        sourceTripId.isAcceptableOrUnknown(
          data['source_trip_id']!,
          _sourceTripIdMeta,
        ),
      );
    }
    if (data.containsKey('from_place_id')) {
      context.handle(
        _fromPlaceIdMeta,
        fromPlaceId.isAcceptableOrUnknown(
          data['from_place_id']!,
          _fromPlaceIdMeta,
        ),
      );
    }
    if (data.containsKey('to_place_id')) {
      context.handle(
        _toPlaceIdMeta,
        toPlaceId.isAcceptableOrUnknown(data['to_place_id']!, _toPlaceIdMeta),
      );
    }
    if (data.containsKey('stopovers')) {
      context.handle(
        _stopoversMeta,
        stopovers.isAcceptableOrUnknown(data['stopovers']!, _stopoversMeta),
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
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
      alternativeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alternative_id'],
      ),
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
      actualStartMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_start_minutes'],
      ),
      actualEndMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_end_minutes'],
      ),
      spansNextDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}spans_next_day'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mode'],
      ),
      fromLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_location'],
      ),
      toLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_location'],
      ),
      fromLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}from_lat'],
      ),
      fromLon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}from_lon'],
      ),
      toLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}to_lat'],
      ),
      toLon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}to_lon'],
      ),
      sourceTripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_trip_id'],
      ),
      fromPlaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_place_id'],
      ),
      toPlaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_place_id'],
      ),
      stopovers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stopovers'],
      ),
    );
  }

  @override
  $ItineraryItemsTable createAlias(String alias) {
    return $ItineraryItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemKind, int, int> $converterkind =
      const EnumIndexConverter<ItemKind>(ItemKind.values);
}

class ItineraryItem extends DataClass implements Insertable<ItineraryItem> {
  final int id;
  final int tripId;

  /// The group this item belongs to, or null when it stands alone. On group
  /// deletion this is set to null (see [ItemGroups]) rather than cascading, so
  /// dissolving a group never removes the underlying places/legs.
  final int? groupId;

  /// The branch this item belongs to, or null when it is a *loose* item sitting
  /// directly on its day (the ordinary case). Cascades on branch deletion — see
  /// [Alternatives]. An item in an unchosen branch is invisible to the day's
  /// timeline, the trip totals and the home-screen widget.
  final int? alternativeId;

  /// The day this entry belongs to (time component ignored, normalised to midnight).
  final DateTime date;

  /// Manual ordering, used for reordering the timeline. For a loose item this
  /// orders it within its day, in one space shared with that day's
  /// [AlternativeSets]; for an item inside a branch it orders it within that
  /// branch.
  final int sortOrder;
  final ItemKind kind;
  final String? title;

  /// The **planned** times — when the entry is meant to start/end (for a
  /// transport leg: to depart/arrive). Minutes since midnight (0-1439), or null
  /// if unset.
  final int? startMinutes;
  final int? endMinutes;

  /// The **actual** times — when the entry really started/ended, recorded during
  /// or after the trip. Same encoding as the planned pair, and just as optional:
  /// an entry the trip never got round to timing simply has none. Each is
  /// compared against its planned counterpart to show how late or early the
  /// entry ran; with no plan to compare against, an actual time just stands on
  /// its own.
  final int? actualStartMinutes;
  final int? actualEndMinutes;

  /// Whether this entry's **end** falls on the day *after* [date]. Almost always
  /// an overnight transport leg — a night train that departs before midnight and
  /// arrives the next morning: the entry stays anchored to its departure [date]
  /// and appears once, on that day, while [endMinutes]/[actualEndMinutes] are
  /// read as minutes into the following calendar day. This keeps the 0-1439
  /// encoding intact rather than letting a single row straddle two dates.
  final bool spansNextDay;
  final String? notes;

  /// ARGB color this entry is drawn in **on the map**, or null to be drawn in
  /// the trip's own accent — which is what every entry written before this
  /// existed means, and what the great majority go on meaning.
  ///
  /// The one property of an entry that is purely about how it is *drawn*: the
  /// line of a leg (whichever line that is — its recorded track when it has one,
  /// the segment between its ends when it has not) and the pin of a place. It
  /// says nothing about the plan, which is why nothing outside the map reads it:
  /// the timeline, the PDF and the totals are unaffected, and a trip whose
  /// entries are all uncolored looks exactly as it did.
  ///
  /// Deliberately **not** on [Tracks]: a line has to be colorable before there
  /// is a track to hang the color on — the straight segment is the ordinary
  /// case — and an entry that later gains a recording would otherwise lose the
  /// color it was given. One entry, one color, however it is drawn.
  final int? colorValue;
  final String? location;

  /// Coordinates (WGS84) of this place, when known — what the user pointed at on
  /// the map, null for a place that was only named.
  ///
  /// Deliberately independent of [location]: that is what the user *wrote*, and
  /// the app never turns a name into a position by itself. A place keeps its name
  /// when the coordinates are cleared, and keeps the coordinates when it is
  /// renamed, because the two answer different questions.
  final double? lat;
  final double? lon;

  /// The transport mode of this leg — a row in [TransportModes], or null when
  /// unassigned. On mode deletion this is set to null (the leg keeps its route,
  /// it just loses its mode), like an item losing its group.
  final int? mode;
  final String? fromLocation;
  final String? toLocation;

  /// Coordinates (WGS84) of this leg's endpoints, when known — filled in by the
  /// connection search from the routing service, null for a hand-entered leg.
  /// Nothing renders them yet; they are stored so a future map can draw the leg
  /// without having to re-geocode its stations.
  final double? fromLat;
  final double? fromLon;
  final double? toLat;
  final double? toLon;

  /// The routing provider's trip identifier for an imported leg, kept so the
  /// live-times refresh can re-query this exact trip and fill in the actual
  /// departure/arrival. Null for a hand-entered leg (nothing to refresh).
  ///
  /// It names **one dated run of one service**, so it is the one imported field
  /// that must never be copied onto another day — see [fromPlaceId] for what is
  /// kept instead.
  final String? sourceTripId;

  /// How the routing service addresses this leg's endpoints — the `queryId` of
  /// the places the search was issued against: a stop id, or a `"lat,lon"` pair
  /// for an address or point of interest.
  ///
  /// Unlike [sourceTripId] these say nothing about *when*, so they survive a
  /// copy and are what lets a leg be searched again for another date — which is
  /// how a routine's journey becomes a real, refreshable connection when it is
  /// materialized. The coordinates alone would nearly do it, but a station
  /// addressed by its stop id routes from the platform, whereas the same
  /// station addressed by coordinate routes from a point outside it and picks
  /// up a spurious walk. Null for a hand-entered leg.
  final String? fromPlaceId;
  final String? toPlaceId;

  /// The stops this leg passes through, encoded by `stopovers.dart` — written by
  /// the connection import, null for a hand-entered leg. Stored on the leg
  /// rather than in a table of their own so they are read offline, with the row
  /// they belong to, long after the routing service is out of reach.
  final String? stopovers;
  const ItineraryItem({
    required this.id,
    required this.tripId,
    this.groupId,
    this.alternativeId,
    required this.date,
    required this.sortOrder,
    required this.kind,
    this.title,
    this.startMinutes,
    this.endMinutes,
    this.actualStartMinutes,
    this.actualEndMinutes,
    required this.spansNextDay,
    this.notes,
    this.colorValue,
    this.location,
    this.lat,
    this.lon,
    this.mode,
    this.fromLocation,
    this.toLocation,
    this.fromLat,
    this.fromLon,
    this.toLat,
    this.toLon,
    this.sourceTripId,
    this.fromPlaceId,
    this.toPlaceId,
    this.stopovers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trip_id'] = Variable<int>(tripId);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    if (!nullToAbsent || alternativeId != null) {
      map['alternative_id'] = Variable<int>(alternativeId);
    }
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
    if (!nullToAbsent || actualStartMinutes != null) {
      map['actual_start_minutes'] = Variable<int>(actualStartMinutes);
    }
    if (!nullToAbsent || actualEndMinutes != null) {
      map['actual_end_minutes'] = Variable<int>(actualEndMinutes);
    }
    map['spans_next_day'] = Variable<bool>(spansNextDay);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || colorValue != null) {
      map['color_value'] = Variable<int>(colorValue);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<int>(mode);
    }
    if (!nullToAbsent || fromLocation != null) {
      map['from_location'] = Variable<String>(fromLocation);
    }
    if (!nullToAbsent || toLocation != null) {
      map['to_location'] = Variable<String>(toLocation);
    }
    if (!nullToAbsent || fromLat != null) {
      map['from_lat'] = Variable<double>(fromLat);
    }
    if (!nullToAbsent || fromLon != null) {
      map['from_lon'] = Variable<double>(fromLon);
    }
    if (!nullToAbsent || toLat != null) {
      map['to_lat'] = Variable<double>(toLat);
    }
    if (!nullToAbsent || toLon != null) {
      map['to_lon'] = Variable<double>(toLon);
    }
    if (!nullToAbsent || sourceTripId != null) {
      map['source_trip_id'] = Variable<String>(sourceTripId);
    }
    if (!nullToAbsent || fromPlaceId != null) {
      map['from_place_id'] = Variable<String>(fromPlaceId);
    }
    if (!nullToAbsent || toPlaceId != null) {
      map['to_place_id'] = Variable<String>(toPlaceId);
    }
    if (!nullToAbsent || stopovers != null) {
      map['stopovers'] = Variable<String>(stopovers);
    }
    return map;
  }

  ItineraryItemsCompanion toCompanion(bool nullToAbsent) {
    return ItineraryItemsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      alternativeId: alternativeId == null && nullToAbsent
          ? const Value.absent()
          : Value(alternativeId),
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
      actualStartMinutes: actualStartMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(actualStartMinutes),
      actualEndMinutes: actualEndMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(actualEndMinutes),
      spansNextDay: Value(spansNextDay),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      colorValue: colorValue == null && nullToAbsent
          ? const Value.absent()
          : Value(colorValue),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      fromLocation: fromLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLocation),
      toLocation: toLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(toLocation),
      fromLat: fromLat == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLat),
      fromLon: fromLon == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLon),
      toLat: toLat == null && nullToAbsent
          ? const Value.absent()
          : Value(toLat),
      toLon: toLon == null && nullToAbsent
          ? const Value.absent()
          : Value(toLon),
      sourceTripId: sourceTripId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTripId),
      fromPlaceId: fromPlaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(fromPlaceId),
      toPlaceId: toPlaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(toPlaceId),
      stopovers: stopovers == null && nullToAbsent
          ? const Value.absent()
          : Value(stopovers),
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
      groupId: serializer.fromJson<int?>(json['groupId']),
      alternativeId: serializer.fromJson<int?>(json['alternativeId']),
      date: serializer.fromJson<DateTime>(json['date']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      kind: $ItineraryItemsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      title: serializer.fromJson<String?>(json['title']),
      startMinutes: serializer.fromJson<int?>(json['startMinutes']),
      endMinutes: serializer.fromJson<int?>(json['endMinutes']),
      actualStartMinutes: serializer.fromJson<int?>(json['actualStartMinutes']),
      actualEndMinutes: serializer.fromJson<int?>(json['actualEndMinutes']),
      spansNextDay: serializer.fromJson<bool>(json['spansNextDay']),
      notes: serializer.fromJson<String?>(json['notes']),
      colorValue: serializer.fromJson<int?>(json['colorValue']),
      location: serializer.fromJson<String?>(json['location']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      mode: serializer.fromJson<int?>(json['mode']),
      fromLocation: serializer.fromJson<String?>(json['fromLocation']),
      toLocation: serializer.fromJson<String?>(json['toLocation']),
      fromLat: serializer.fromJson<double?>(json['fromLat']),
      fromLon: serializer.fromJson<double?>(json['fromLon']),
      toLat: serializer.fromJson<double?>(json['toLat']),
      toLon: serializer.fromJson<double?>(json['toLon']),
      sourceTripId: serializer.fromJson<String?>(json['sourceTripId']),
      fromPlaceId: serializer.fromJson<String?>(json['fromPlaceId']),
      toPlaceId: serializer.fromJson<String?>(json['toPlaceId']),
      stopovers: serializer.fromJson<String?>(json['stopovers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tripId': serializer.toJson<int>(tripId),
      'groupId': serializer.toJson<int?>(groupId),
      'alternativeId': serializer.toJson<int?>(alternativeId),
      'date': serializer.toJson<DateTime>(date),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'kind': serializer.toJson<int>(
        $ItineraryItemsTable.$converterkind.toJson(kind),
      ),
      'title': serializer.toJson<String?>(title),
      'startMinutes': serializer.toJson<int?>(startMinutes),
      'endMinutes': serializer.toJson<int?>(endMinutes),
      'actualStartMinutes': serializer.toJson<int?>(actualStartMinutes),
      'actualEndMinutes': serializer.toJson<int?>(actualEndMinutes),
      'spansNextDay': serializer.toJson<bool>(spansNextDay),
      'notes': serializer.toJson<String?>(notes),
      'colorValue': serializer.toJson<int?>(colorValue),
      'location': serializer.toJson<String?>(location),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'mode': serializer.toJson<int?>(mode),
      'fromLocation': serializer.toJson<String?>(fromLocation),
      'toLocation': serializer.toJson<String?>(toLocation),
      'fromLat': serializer.toJson<double?>(fromLat),
      'fromLon': serializer.toJson<double?>(fromLon),
      'toLat': serializer.toJson<double?>(toLat),
      'toLon': serializer.toJson<double?>(toLon),
      'sourceTripId': serializer.toJson<String?>(sourceTripId),
      'fromPlaceId': serializer.toJson<String?>(fromPlaceId),
      'toPlaceId': serializer.toJson<String?>(toPlaceId),
      'stopovers': serializer.toJson<String?>(stopovers),
    };
  }

  ItineraryItem copyWith({
    int? id,
    int? tripId,
    Value<int?> groupId = const Value.absent(),
    Value<int?> alternativeId = const Value.absent(),
    DateTime? date,
    int? sortOrder,
    ItemKind? kind,
    Value<String?> title = const Value.absent(),
    Value<int?> startMinutes = const Value.absent(),
    Value<int?> endMinutes = const Value.absent(),
    Value<int?> actualStartMinutes = const Value.absent(),
    Value<int?> actualEndMinutes = const Value.absent(),
    bool? spansNextDay,
    Value<String?> notes = const Value.absent(),
    Value<int?> colorValue = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    Value<int?> mode = const Value.absent(),
    Value<String?> fromLocation = const Value.absent(),
    Value<String?> toLocation = const Value.absent(),
    Value<double?> fromLat = const Value.absent(),
    Value<double?> fromLon = const Value.absent(),
    Value<double?> toLat = const Value.absent(),
    Value<double?> toLon = const Value.absent(),
    Value<String?> sourceTripId = const Value.absent(),
    Value<String?> fromPlaceId = const Value.absent(),
    Value<String?> toPlaceId = const Value.absent(),
    Value<String?> stopovers = const Value.absent(),
  }) => ItineraryItem(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    groupId: groupId.present ? groupId.value : this.groupId,
    alternativeId: alternativeId.present
        ? alternativeId.value
        : this.alternativeId,
    date: date ?? this.date,
    sortOrder: sortOrder ?? this.sortOrder,
    kind: kind ?? this.kind,
    title: title.present ? title.value : this.title,
    startMinutes: startMinutes.present ? startMinutes.value : this.startMinutes,
    endMinutes: endMinutes.present ? endMinutes.value : this.endMinutes,
    actualStartMinutes: actualStartMinutes.present
        ? actualStartMinutes.value
        : this.actualStartMinutes,
    actualEndMinutes: actualEndMinutes.present
        ? actualEndMinutes.value
        : this.actualEndMinutes,
    spansNextDay: spansNextDay ?? this.spansNextDay,
    notes: notes.present ? notes.value : this.notes,
    colorValue: colorValue.present ? colorValue.value : this.colorValue,
    location: location.present ? location.value : this.location,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    mode: mode.present ? mode.value : this.mode,
    fromLocation: fromLocation.present ? fromLocation.value : this.fromLocation,
    toLocation: toLocation.present ? toLocation.value : this.toLocation,
    fromLat: fromLat.present ? fromLat.value : this.fromLat,
    fromLon: fromLon.present ? fromLon.value : this.fromLon,
    toLat: toLat.present ? toLat.value : this.toLat,
    toLon: toLon.present ? toLon.value : this.toLon,
    sourceTripId: sourceTripId.present ? sourceTripId.value : this.sourceTripId,
    fromPlaceId: fromPlaceId.present ? fromPlaceId.value : this.fromPlaceId,
    toPlaceId: toPlaceId.present ? toPlaceId.value : this.toPlaceId,
    stopovers: stopovers.present ? stopovers.value : this.stopovers,
  );
  ItineraryItem copyWithCompanion(ItineraryItemsCompanion data) {
    return ItineraryItem(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      alternativeId: data.alternativeId.present
          ? data.alternativeId.value
          : this.alternativeId,
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
      actualStartMinutes: data.actualStartMinutes.present
          ? data.actualStartMinutes.value
          : this.actualStartMinutes,
      actualEndMinutes: data.actualEndMinutes.present
          ? data.actualEndMinutes.value
          : this.actualEndMinutes,
      spansNextDay: data.spansNextDay.present
          ? data.spansNextDay.value
          : this.spansNextDay,
      notes: data.notes.present ? data.notes.value : this.notes,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      location: data.location.present ? data.location.value : this.location,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      mode: data.mode.present ? data.mode.value : this.mode,
      fromLocation: data.fromLocation.present
          ? data.fromLocation.value
          : this.fromLocation,
      toLocation: data.toLocation.present
          ? data.toLocation.value
          : this.toLocation,
      fromLat: data.fromLat.present ? data.fromLat.value : this.fromLat,
      fromLon: data.fromLon.present ? data.fromLon.value : this.fromLon,
      toLat: data.toLat.present ? data.toLat.value : this.toLat,
      toLon: data.toLon.present ? data.toLon.value : this.toLon,
      sourceTripId: data.sourceTripId.present
          ? data.sourceTripId.value
          : this.sourceTripId,
      fromPlaceId: data.fromPlaceId.present
          ? data.fromPlaceId.value
          : this.fromPlaceId,
      toPlaceId: data.toPlaceId.present ? data.toPlaceId.value : this.toPlaceId,
      stopovers: data.stopovers.present ? data.stopovers.value : this.stopovers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItineraryItem(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('groupId: $groupId, ')
          ..write('alternativeId: $alternativeId, ')
          ..write('date: $date, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('endMinutes: $endMinutes, ')
          ..write('actualStartMinutes: $actualStartMinutes, ')
          ..write('actualEndMinutes: $actualEndMinutes, ')
          ..write('spansNextDay: $spansNextDay, ')
          ..write('notes: $notes, ')
          ..write('colorValue: $colorValue, ')
          ..write('location: $location, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('mode: $mode, ')
          ..write('fromLocation: $fromLocation, ')
          ..write('toLocation: $toLocation, ')
          ..write('fromLat: $fromLat, ')
          ..write('fromLon: $fromLon, ')
          ..write('toLat: $toLat, ')
          ..write('toLon: $toLon, ')
          ..write('sourceTripId: $sourceTripId, ')
          ..write('fromPlaceId: $fromPlaceId, ')
          ..write('toPlaceId: $toPlaceId, ')
          ..write('stopovers: $stopovers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    tripId,
    groupId,
    alternativeId,
    date,
    sortOrder,
    kind,
    title,
    startMinutes,
    endMinutes,
    actualStartMinutes,
    actualEndMinutes,
    spansNextDay,
    notes,
    colorValue,
    location,
    lat,
    lon,
    mode,
    fromLocation,
    toLocation,
    fromLat,
    fromLon,
    toLat,
    toLon,
    sourceTripId,
    fromPlaceId,
    toPlaceId,
    stopovers,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItineraryItem &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.groupId == this.groupId &&
          other.alternativeId == this.alternativeId &&
          other.date == this.date &&
          other.sortOrder == this.sortOrder &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.startMinutes == this.startMinutes &&
          other.endMinutes == this.endMinutes &&
          other.actualStartMinutes == this.actualStartMinutes &&
          other.actualEndMinutes == this.actualEndMinutes &&
          other.spansNextDay == this.spansNextDay &&
          other.notes == this.notes &&
          other.colorValue == this.colorValue &&
          other.location == this.location &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.mode == this.mode &&
          other.fromLocation == this.fromLocation &&
          other.toLocation == this.toLocation &&
          other.fromLat == this.fromLat &&
          other.fromLon == this.fromLon &&
          other.toLat == this.toLat &&
          other.toLon == this.toLon &&
          other.sourceTripId == this.sourceTripId &&
          other.fromPlaceId == this.fromPlaceId &&
          other.toPlaceId == this.toPlaceId &&
          other.stopovers == this.stopovers);
}

class ItineraryItemsCompanion extends UpdateCompanion<ItineraryItem> {
  final Value<int> id;
  final Value<int> tripId;
  final Value<int?> groupId;
  final Value<int?> alternativeId;
  final Value<DateTime> date;
  final Value<int> sortOrder;
  final Value<ItemKind> kind;
  final Value<String?> title;
  final Value<int?> startMinutes;
  final Value<int?> endMinutes;
  final Value<int?> actualStartMinutes;
  final Value<int?> actualEndMinutes;
  final Value<bool> spansNextDay;
  final Value<String?> notes;
  final Value<int?> colorValue;
  final Value<String?> location;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<int?> mode;
  final Value<String?> fromLocation;
  final Value<String?> toLocation;
  final Value<double?> fromLat;
  final Value<double?> fromLon;
  final Value<double?> toLat;
  final Value<double?> toLon;
  final Value<String?> sourceTripId;
  final Value<String?> fromPlaceId;
  final Value<String?> toPlaceId;
  final Value<String?> stopovers;
  const ItineraryItemsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.alternativeId = const Value.absent(),
    this.date = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.startMinutes = const Value.absent(),
    this.endMinutes = const Value.absent(),
    this.actualStartMinutes = const Value.absent(),
    this.actualEndMinutes = const Value.absent(),
    this.spansNextDay = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.location = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.mode = const Value.absent(),
    this.fromLocation = const Value.absent(),
    this.toLocation = const Value.absent(),
    this.fromLat = const Value.absent(),
    this.fromLon = const Value.absent(),
    this.toLat = const Value.absent(),
    this.toLon = const Value.absent(),
    this.sourceTripId = const Value.absent(),
    this.fromPlaceId = const Value.absent(),
    this.toPlaceId = const Value.absent(),
    this.stopovers = const Value.absent(),
  });
  ItineraryItemsCompanion.insert({
    this.id = const Value.absent(),
    required int tripId,
    this.groupId = const Value.absent(),
    this.alternativeId = const Value.absent(),
    required DateTime date,
    this.sortOrder = const Value.absent(),
    required ItemKind kind,
    this.title = const Value.absent(),
    this.startMinutes = const Value.absent(),
    this.endMinutes = const Value.absent(),
    this.actualStartMinutes = const Value.absent(),
    this.actualEndMinutes = const Value.absent(),
    this.spansNextDay = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.location = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.mode = const Value.absent(),
    this.fromLocation = const Value.absent(),
    this.toLocation = const Value.absent(),
    this.fromLat = const Value.absent(),
    this.fromLon = const Value.absent(),
    this.toLat = const Value.absent(),
    this.toLon = const Value.absent(),
    this.sourceTripId = const Value.absent(),
    this.fromPlaceId = const Value.absent(),
    this.toPlaceId = const Value.absent(),
    this.stopovers = const Value.absent(),
  }) : tripId = Value(tripId),
       date = Value(date),
       kind = Value(kind);
  static Insertable<ItineraryItem> custom({
    Expression<int>? id,
    Expression<int>? tripId,
    Expression<int>? groupId,
    Expression<int>? alternativeId,
    Expression<DateTime>? date,
    Expression<int>? sortOrder,
    Expression<int>? kind,
    Expression<String>? title,
    Expression<int>? startMinutes,
    Expression<int>? endMinutes,
    Expression<int>? actualStartMinutes,
    Expression<int>? actualEndMinutes,
    Expression<bool>? spansNextDay,
    Expression<String>? notes,
    Expression<int>? colorValue,
    Expression<String>? location,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<int>? mode,
    Expression<String>? fromLocation,
    Expression<String>? toLocation,
    Expression<double>? fromLat,
    Expression<double>? fromLon,
    Expression<double>? toLat,
    Expression<double>? toLon,
    Expression<String>? sourceTripId,
    Expression<String>? fromPlaceId,
    Expression<String>? toPlaceId,
    Expression<String>? stopovers,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (groupId != null) 'group_id': groupId,
      if (alternativeId != null) 'alternative_id': alternativeId,
      if (date != null) 'date': date,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (startMinutes != null) 'start_minutes': startMinutes,
      if (endMinutes != null) 'end_minutes': endMinutes,
      if (actualStartMinutes != null)
        'actual_start_minutes': actualStartMinutes,
      if (actualEndMinutes != null) 'actual_end_minutes': actualEndMinutes,
      if (spansNextDay != null) 'spans_next_day': spansNextDay,
      if (notes != null) 'notes': notes,
      if (colorValue != null) 'color_value': colorValue,
      if (location != null) 'location': location,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (mode != null) 'mode': mode,
      if (fromLocation != null) 'from_location': fromLocation,
      if (toLocation != null) 'to_location': toLocation,
      if (fromLat != null) 'from_lat': fromLat,
      if (fromLon != null) 'from_lon': fromLon,
      if (toLat != null) 'to_lat': toLat,
      if (toLon != null) 'to_lon': toLon,
      if (sourceTripId != null) 'source_trip_id': sourceTripId,
      if (fromPlaceId != null) 'from_place_id': fromPlaceId,
      if (toPlaceId != null) 'to_place_id': toPlaceId,
      if (stopovers != null) 'stopovers': stopovers,
    });
  }

  ItineraryItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? tripId,
    Value<int?>? groupId,
    Value<int?>? alternativeId,
    Value<DateTime>? date,
    Value<int>? sortOrder,
    Value<ItemKind>? kind,
    Value<String?>? title,
    Value<int?>? startMinutes,
    Value<int?>? endMinutes,
    Value<int?>? actualStartMinutes,
    Value<int?>? actualEndMinutes,
    Value<bool>? spansNextDay,
    Value<String?>? notes,
    Value<int?>? colorValue,
    Value<String?>? location,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<int?>? mode,
    Value<String?>? fromLocation,
    Value<String?>? toLocation,
    Value<double?>? fromLat,
    Value<double?>? fromLon,
    Value<double?>? toLat,
    Value<double?>? toLon,
    Value<String?>? sourceTripId,
    Value<String?>? fromPlaceId,
    Value<String?>? toPlaceId,
    Value<String?>? stopovers,
  }) {
    return ItineraryItemsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      groupId: groupId ?? this.groupId,
      alternativeId: alternativeId ?? this.alternativeId,
      date: date ?? this.date,
      sortOrder: sortOrder ?? this.sortOrder,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      actualStartMinutes: actualStartMinutes ?? this.actualStartMinutes,
      actualEndMinutes: actualEndMinutes ?? this.actualEndMinutes,
      spansNextDay: spansNextDay ?? this.spansNextDay,
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      mode: mode ?? this.mode,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      fromLat: fromLat ?? this.fromLat,
      fromLon: fromLon ?? this.fromLon,
      toLat: toLat ?? this.toLat,
      toLon: toLon ?? this.toLon,
      sourceTripId: sourceTripId ?? this.sourceTripId,
      fromPlaceId: fromPlaceId ?? this.fromPlaceId,
      toPlaceId: toPlaceId ?? this.toPlaceId,
      stopovers: stopovers ?? this.stopovers,
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
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (alternativeId.present) {
      map['alternative_id'] = Variable<int>(alternativeId.value);
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
    if (actualStartMinutes.present) {
      map['actual_start_minutes'] = Variable<int>(actualStartMinutes.value);
    }
    if (actualEndMinutes.present) {
      map['actual_end_minutes'] = Variable<int>(actualEndMinutes.value);
    }
    if (spansNextDay.present) {
      map['spans_next_day'] = Variable<bool>(spansNextDay.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (mode.present) {
      map['mode'] = Variable<int>(mode.value);
    }
    if (fromLocation.present) {
      map['from_location'] = Variable<String>(fromLocation.value);
    }
    if (toLocation.present) {
      map['to_location'] = Variable<String>(toLocation.value);
    }
    if (fromLat.present) {
      map['from_lat'] = Variable<double>(fromLat.value);
    }
    if (fromLon.present) {
      map['from_lon'] = Variable<double>(fromLon.value);
    }
    if (toLat.present) {
      map['to_lat'] = Variable<double>(toLat.value);
    }
    if (toLon.present) {
      map['to_lon'] = Variable<double>(toLon.value);
    }
    if (sourceTripId.present) {
      map['source_trip_id'] = Variable<String>(sourceTripId.value);
    }
    if (fromPlaceId.present) {
      map['from_place_id'] = Variable<String>(fromPlaceId.value);
    }
    if (toPlaceId.present) {
      map['to_place_id'] = Variable<String>(toPlaceId.value);
    }
    if (stopovers.present) {
      map['stopovers'] = Variable<String>(stopovers.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItineraryItemsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('groupId: $groupId, ')
          ..write('alternativeId: $alternativeId, ')
          ..write('date: $date, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('endMinutes: $endMinutes, ')
          ..write('actualStartMinutes: $actualStartMinutes, ')
          ..write('actualEndMinutes: $actualEndMinutes, ')
          ..write('spansNextDay: $spansNextDay, ')
          ..write('notes: $notes, ')
          ..write('colorValue: $colorValue, ')
          ..write('location: $location, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('mode: $mode, ')
          ..write('fromLocation: $fromLocation, ')
          ..write('toLocation: $toLocation, ')
          ..write('fromLat: $fromLat, ')
          ..write('fromLon: $fromLon, ')
          ..write('toLat: $toLat, ')
          ..write('toLon: $toLon, ')
          ..write('sourceTripId: $sourceTripId, ')
          ..write('fromPlaceId: $fromPlaceId, ')
          ..write('toPlaceId: $toPlaceId, ')
          ..write('stopovers: $stopovers')
          ..write(')'))
        .toString();
  }
}

class $CurrenciesTable extends Currencies
    with TableInfo<$CurrenciesTable, CurrencyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurrenciesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMicrosMeta = const VerificationMeta(
    'rateMicros',
  );
  @override
  late final GeneratedColumn<int> rateMicros = GeneratedColumn<int>(
    'rate_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isBaseMeta = const VerificationMeta('isBase');
  @override
  late final GeneratedColumn<bool> isBase = GeneratedColumn<bool>(
    'is_base',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_base" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  List<GeneratedColumn> get $columns => [
    id,
    code,
    symbol,
    rateMicros,
    isBase,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'currencies';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurrencyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('rate_micros')) {
      context.handle(
        _rateMicrosMeta,
        rateMicros.isAcceptableOrUnknown(data['rate_micros']!, _rateMicrosMeta),
      );
    }
    if (data.containsKey('is_base')) {
      context.handle(
        _isBaseMeta,
        isBase.isAcceptableOrUnknown(data['is_base']!, _isBaseMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CurrencyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurrencyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      rateMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_micros'],
      ),
      isBase: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_base'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CurrenciesTable createAlias(String alias) {
    return $CurrenciesTable(attachedDatabase, alias);
  }
}

class CurrencyRow extends DataClass implements Insertable<CurrencyRow> {
  final int id;

  /// ISO-ish code, e.g. `EUR`. Unique, and the currency's portable identity:
  /// it is what a shared trip carries instead of a row id.
  final String code;

  /// Symbol shown next to amounts, e.g. `€`. Free text — plenty of currencies
  /// have no symbol beyond their code, which is then simply repeated here.
  final String symbol;

  /// What one unit of this currency is worth in the base currency, in millionths
  /// (see [kRateOne]) — so with base EUR, a USD worth €0.92 stores `920000`.
  /// Null when no rate has been set; the base row's own rate is [kRateOne] by
  /// definition.
  final int? rateMicros;

  /// Marks the single currency every rate is expressed in. At most one row is
  /// true, enforced in `CurrencyDao` rather than by the schema (mirroring
  /// [People.isMe]). Travels with the database file.
  final bool isBase;

  /// Manual ordering for the expense form's picker and the settings list. Also
  /// the order per-currency totals are printed in.
  final int sortOrder;
  const CurrencyRow({
    required this.id,
    required this.code,
    required this.symbol,
    this.rateMicros,
    required this.isBase,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    map['symbol'] = Variable<String>(symbol);
    if (!nullToAbsent || rateMicros != null) {
      map['rate_micros'] = Variable<int>(rateMicros);
    }
    map['is_base'] = Variable<bool>(isBase);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CurrenciesCompanion toCompanion(bool nullToAbsent) {
    return CurrenciesCompanion(
      id: Value(id),
      code: Value(code),
      symbol: Value(symbol),
      rateMicros: rateMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(rateMicros),
      isBase: Value(isBase),
      sortOrder: Value(sortOrder),
    );
  }

  factory CurrencyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurrencyRow(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      symbol: serializer.fromJson<String>(json['symbol']),
      rateMicros: serializer.fromJson<int?>(json['rateMicros']),
      isBase: serializer.fromJson<bool>(json['isBase']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'symbol': serializer.toJson<String>(symbol),
      'rateMicros': serializer.toJson<int?>(rateMicros),
      'isBase': serializer.toJson<bool>(isBase),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CurrencyRow copyWith({
    int? id,
    String? code,
    String? symbol,
    Value<int?> rateMicros = const Value.absent(),
    bool? isBase,
    int? sortOrder,
  }) => CurrencyRow(
    id: id ?? this.id,
    code: code ?? this.code,
    symbol: symbol ?? this.symbol,
    rateMicros: rateMicros.present ? rateMicros.value : this.rateMicros,
    isBase: isBase ?? this.isBase,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CurrencyRow copyWithCompanion(CurrenciesCompanion data) {
    return CurrencyRow(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      rateMicros: data.rateMicros.present
          ? data.rateMicros.value
          : this.rateMicros,
      isBase: data.isBase.present ? data.isBase.value : this.isBase,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurrencyRow(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('symbol: $symbol, ')
          ..write('rateMicros: $rateMicros, ')
          ..write('isBase: $isBase, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, code, symbol, rateMicros, isBase, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurrencyRow &&
          other.id == this.id &&
          other.code == this.code &&
          other.symbol == this.symbol &&
          other.rateMicros == this.rateMicros &&
          other.isBase == this.isBase &&
          other.sortOrder == this.sortOrder);
}

class CurrenciesCompanion extends UpdateCompanion<CurrencyRow> {
  final Value<int> id;
  final Value<String> code;
  final Value<String> symbol;
  final Value<int?> rateMicros;
  final Value<bool> isBase;
  final Value<int> sortOrder;
  const CurrenciesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.symbol = const Value.absent(),
    this.rateMicros = const Value.absent(),
    this.isBase = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  CurrenciesCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    required String symbol,
    this.rateMicros = const Value.absent(),
    this.isBase = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : code = Value(code),
       symbol = Value(symbol);
  static Insertable<CurrencyRow> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<String>? symbol,
    Expression<int>? rateMicros,
    Expression<bool>? isBase,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (symbol != null) 'symbol': symbol,
      if (rateMicros != null) 'rate_micros': rateMicros,
      if (isBase != null) 'is_base': isBase,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  CurrenciesCompanion copyWith({
    Value<int>? id,
    Value<String>? code,
    Value<String>? symbol,
    Value<int?>? rateMicros,
    Value<bool>? isBase,
    Value<int>? sortOrder,
  }) {
    return CurrenciesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      symbol: symbol ?? this.symbol,
      rateMicros: rateMicros ?? this.rateMicros,
      isBase: isBase ?? this.isBase,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (rateMicros.present) {
      map['rate_micros'] = Variable<int>(rateMicros.value);
    }
    if (isBase.present) {
      map['is_base'] = Variable<bool>(isBase.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrenciesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('symbol: $symbol, ')
          ..write('rateMicros: $rateMicros, ')
          ..write('isBase: $isBase, ')
          ..write('sortOrder: $sortOrder')
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
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES item_groups (id) ON DELETE CASCADE',
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
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<int> currency = GeneratedColumn<int>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES currencies (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidByMeta = const VerificationMeta('paidBy');
  @override
  late final GeneratedColumn<String> paidBy = GeneratedColumn<String>(
    'paid_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  @override
  late final GeneratedColumn<bool> paid = GeneratedColumn<bool>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paid" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isTransferMeta = const VerificationMeta(
    'isTransfer',
  );
  @override
  late final GeneratedColumn<bool> isTransfer = GeneratedColumn<bool>(
    'is_transfer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_transfer" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    groupId,
    tripId,
    amountMinor,
    currency,
    reason,
    paidBy,
    paid,
    isTransfer,
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
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
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
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('paid_by')) {
      context.handle(
        _paidByMeta,
        paidBy.isAcceptableOrUnknown(data['paid_by']!, _paidByMeta),
      );
    }
    if (data.containsKey('paid')) {
      context.handle(
        _paidMeta,
        paid.isAcceptableOrUnknown(data['paid']!, _paidMeta),
      );
    }
    if (data.containsKey('is_transfer')) {
      context.handle(
        _isTransferMeta,
        isTransfer.isAcceptableOrUnknown(data['is_transfer']!, _isTransferMeta),
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
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}currency'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      paidBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_by'],
      ),
      paid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paid'],
      )!,
      isTransfer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_transfer'],
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
}

class Cost extends DataClass implements Insertable<Cost> {
  final int id;
  final int? itemId;

  /// Set for costs shared across an [ItemGroups] group instead of a single item.
  final int? groupId;

  /// Set for trip-level costs that aren't tied to a specific itinerary item.
  final int? tripId;

  /// Amount in the currency's minor unit (e.g. cents) to avoid float rounding.
  final int amountMinor;

  /// The currency the amount is in — a row in [Currencies]. Unlike a leg's
  /// transport mode, this can never be dropped: an amount with no currency says
  /// nothing, so the reference restricts the delete instead of nulling itself.
  final int currency;
  final String reason;

  /// Name of the person who paid, or null if unassigned. Stored as text (like
  /// [reason]) so an expense keeps its payer even if the person is later
  /// removed; renaming a person repoints every expense they paid.
  final String? paidBy;

  /// Whether this expense has already been paid/settled. Defaults to false.
  final bool paid;

  /// Marks the row as a **transfer** — money handed from one person to another
  /// (settling a debt) rather than money spent on the trip. A transfer is
  /// always trip-level, its [paidBy] is the sender and its single beneficiary
  /// the receiver, and it carries no [reason] (the category makes no sense for
  /// it). It moves the two people's balances and nothing else: totals, the
  /// paid/open split and the category breakdown all leave it out, because no
  /// money left the group. See `computeTripStats`.
  final bool isTransfer;
  final DateTime createdAt;
  const Cost({
    required this.id,
    this.itemId,
    this.groupId,
    this.tripId,
    required this.amountMinor,
    required this.currency,
    required this.reason,
    this.paidBy,
    required this.paid,
    required this.isTransfer,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<int>(itemId);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<int>(tripId);
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<int>(currency);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || paidBy != null) {
      map['paid_by'] = Variable<String>(paidBy);
    }
    map['paid'] = Variable<bool>(paid);
    map['is_transfer'] = Variable<bool>(isTransfer);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CostsCompanion toCompanion(bool nullToAbsent) {
    return CostsCompanion(
      id: Value(id),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      reason: Value(reason),
      paidBy: paidBy == null && nullToAbsent
          ? const Value.absent()
          : Value(paidBy),
      paid: Value(paid),
      isTransfer: Value(isTransfer),
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
      groupId: serializer.fromJson<int?>(json['groupId']),
      tripId: serializer.fromJson<int?>(json['tripId']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<int>(json['currency']),
      reason: serializer.fromJson<String>(json['reason']),
      paidBy: serializer.fromJson<String?>(json['paidBy']),
      paid: serializer.fromJson<bool>(json['paid']),
      isTransfer: serializer.fromJson<bool>(json['isTransfer']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<int?>(itemId),
      'groupId': serializer.toJson<int?>(groupId),
      'tripId': serializer.toJson<int?>(tripId),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<int>(currency),
      'reason': serializer.toJson<String>(reason),
      'paidBy': serializer.toJson<String?>(paidBy),
      'paid': serializer.toJson<bool>(paid),
      'isTransfer': serializer.toJson<bool>(isTransfer),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Cost copyWith({
    int? id,
    Value<int?> itemId = const Value.absent(),
    Value<int?> groupId = const Value.absent(),
    Value<int?> tripId = const Value.absent(),
    int? amountMinor,
    int? currency,
    String? reason,
    Value<String?> paidBy = const Value.absent(),
    bool? paid,
    bool? isTransfer,
    DateTime? createdAt,
  }) => Cost(
    id: id ?? this.id,
    itemId: itemId.present ? itemId.value : this.itemId,
    groupId: groupId.present ? groupId.value : this.groupId,
    tripId: tripId.present ? tripId.value : this.tripId,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    reason: reason ?? this.reason,
    paidBy: paidBy.present ? paidBy.value : this.paidBy,
    paid: paid ?? this.paid,
    isTransfer: isTransfer ?? this.isTransfer,
    createdAt: createdAt ?? this.createdAt,
  );
  Cost copyWithCompanion(CostsCompanion data) {
    return Cost(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      reason: data.reason.present ? data.reason.value : this.reason,
      paidBy: data.paidBy.present ? data.paidBy.value : this.paidBy,
      paid: data.paid.present ? data.paid.value : this.paid,
      isTransfer: data.isTransfer.present
          ? data.isTransfer.value
          : this.isTransfer,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cost(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('groupId: $groupId, ')
          ..write('tripId: $tripId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('reason: $reason, ')
          ..write('paidBy: $paidBy, ')
          ..write('paid: $paid, ')
          ..write('isTransfer: $isTransfer, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    groupId,
    tripId,
    amountMinor,
    currency,
    reason,
    paidBy,
    paid,
    isTransfer,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cost &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.groupId == this.groupId &&
          other.tripId == this.tripId &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.reason == this.reason &&
          other.paidBy == this.paidBy &&
          other.paid == this.paid &&
          other.isTransfer == this.isTransfer &&
          other.createdAt == this.createdAt);
}

class CostsCompanion extends UpdateCompanion<Cost> {
  final Value<int> id;
  final Value<int?> itemId;
  final Value<int?> groupId;
  final Value<int?> tripId;
  final Value<int> amountMinor;
  final Value<int> currency;
  final Value<String> reason;
  final Value<String?> paidBy;
  final Value<bool> paid;
  final Value<bool> isTransfer;
  final Value<DateTime> createdAt;
  const CostsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.reason = const Value.absent(),
    this.paidBy = const Value.absent(),
    this.paid = const Value.absent(),
    this.isTransfer = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CostsCompanion.insert({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.tripId = const Value.absent(),
    required int amountMinor,
    required int currency,
    required String reason,
    this.paidBy = const Value.absent(),
    this.paid = const Value.absent(),
    this.isTransfer = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : amountMinor = Value(amountMinor),
       currency = Value(currency),
       reason = Value(reason);
  static Insertable<Cost> custom({
    Expression<int>? id,
    Expression<int>? itemId,
    Expression<int>? groupId,
    Expression<int>? tripId,
    Expression<int>? amountMinor,
    Expression<int>? currency,
    Expression<String>? reason,
    Expression<String>? paidBy,
    Expression<bool>? paid,
    Expression<bool>? isTransfer,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (groupId != null) 'group_id': groupId,
      if (tripId != null) 'trip_id': tripId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (reason != null) 'reason': reason,
      if (paidBy != null) 'paid_by': paidBy,
      if (paid != null) 'paid': paid,
      if (isTransfer != null) 'is_transfer': isTransfer,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CostsCompanion copyWith({
    Value<int>? id,
    Value<int?>? itemId,
    Value<int?>? groupId,
    Value<int?>? tripId,
    Value<int>? amountMinor,
    Value<int>? currency,
    Value<String>? reason,
    Value<String?>? paidBy,
    Value<bool>? paid,
    Value<bool>? isTransfer,
    Value<DateTime>? createdAt,
  }) {
    return CostsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      groupId: groupId ?? this.groupId,
      tripId: tripId ?? this.tripId,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      reason: reason ?? this.reason,
      paidBy: paidBy ?? this.paidBy,
      paid: paid ?? this.paid,
      isTransfer: isTransfer ?? this.isTransfer,
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
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<int>(currency.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (paidBy.present) {
      map['paid_by'] = Variable<String>(paidBy.value);
    }
    if (paid.present) {
      map['paid'] = Variable<bool>(paid.value);
    }
    if (isTransfer.present) {
      map['is_transfer'] = Variable<bool>(isTransfer.value);
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
          ..write('groupId: $groupId, ')
          ..write('tripId: $tripId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('reason: $reason, ')
          ..write('paidBy: $paidBy, ')
          ..write('paid: $paid, ')
          ..write('isTransfer: $isTransfer, ')
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
  static const VerificationMeta _iconIdMeta = const VerificationMeta('iconId');
  @override
  late final GeneratedColumn<int> iconId = GeneratedColumn<int>(
    'icon_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, label, iconId];
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
    if (data.containsKey('icon_id')) {
      context.handle(
        _iconIdMeta,
        iconId.isAcceptableOrUnknown(data['icon_id']!, _iconIdMeta),
      );
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
      iconId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_id'],
      ),
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

  /// Stable key into the curated icon set (`kCostReasonIcons`), or null to use
  /// the default icon. Not a font code point, so the set can change safely.
  final int? iconId;
  const CostReason({required this.id, required this.label, this.iconId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || iconId != null) {
      map['icon_id'] = Variable<int>(iconId);
    }
    return map;
  }

  CostReasonsCompanion toCompanion(bool nullToAbsent) {
    return CostReasonsCompanion(
      id: Value(id),
      label: Value(label),
      iconId: iconId == null && nullToAbsent
          ? const Value.absent()
          : Value(iconId),
    );
  }

  factory CostReason.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CostReason(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      iconId: serializer.fromJson<int?>(json['iconId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'iconId': serializer.toJson<int?>(iconId),
    };
  }

  CostReason copyWith({
    int? id,
    String? label,
    Value<int?> iconId = const Value.absent(),
  }) => CostReason(
    id: id ?? this.id,
    label: label ?? this.label,
    iconId: iconId.present ? iconId.value : this.iconId,
  );
  CostReason copyWithCompanion(CostReasonsCompanion data) {
    return CostReason(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      iconId: data.iconId.present ? data.iconId.value : this.iconId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CostReason(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('iconId: $iconId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, label, iconId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CostReason &&
          other.id == this.id &&
          other.label == this.label &&
          other.iconId == this.iconId);
}

class CostReasonsCompanion extends UpdateCompanion<CostReason> {
  final Value<int> id;
  final Value<String> label;
  final Value<int?> iconId;
  const CostReasonsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.iconId = const Value.absent(),
  });
  CostReasonsCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    this.iconId = const Value.absent(),
  }) : label = Value(label);
  static Insertable<CostReason> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<int>? iconId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (iconId != null) 'icon_id': iconId,
    });
  }

  CostReasonsCompanion copyWith({
    Value<int>? id,
    Value<String>? label,
    Value<int?>? iconId,
  }) {
    return CostReasonsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      iconId: iconId ?? this.iconId,
    );
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
    if (iconId.present) {
      map['icon_id'] = Variable<int>(iconId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CostReasonsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('iconId: $iconId')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
    defaultValue: const Constant(0xFF546E7A),
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
  List<GeneratedColumn> get $columns => [id, name, colorValue, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;

  /// The tag's identity, so the same label cannot exist twice.
  final String name;

  /// ARGB colour for the tag's chip, so a row of them is scannable at a glance.
  final int colorValue;

  /// Manual ordering for the filter bar, so the tags used daily can be put
  /// first.
  final int sortOrder;
  const Tag({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      sortOrder: Value(sortOrder),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Tag copyWith({int? id, String? name, int? colorValue, int? sortOrder}) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.sortOrder == this.sortOrder);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<int> sortOrder;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.colorValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<int>? sortOrder,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $TripTagsTable extends TripTags with TableInfo<$TripTagsTable, TripTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripTagsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [tripId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, tagId};
  @override
  TripTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripTag(
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TripTagsTable createAlias(String alias) {
    return $TripTagsTable(attachedDatabase, alias);
  }
}

class TripTag extends DataClass implements Insertable<TripTag> {
  final int tripId;
  final int tagId;
  const TripTag({required this.tripId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<int>(tripId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  TripTagsCompanion toCompanion(bool nullToAbsent) {
    return TripTagsCompanion(tripId: Value(tripId), tagId: Value(tagId));
  }

  factory TripTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripTag(
      tripId: serializer.fromJson<int>(json['tripId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<int>(tripId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  TripTag copyWith({int? tripId, int? tagId}) =>
      TripTag(tripId: tripId ?? this.tripId, tagId: tagId ?? this.tagId);
  TripTag copyWithCompanion(TripTagsCompanion data) {
    return TripTag(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripTag(')
          ..write('tripId: $tripId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tripId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripTag &&
          other.tripId == this.tripId &&
          other.tagId == this.tagId);
}

class TripTagsCompanion extends UpdateCompanion<TripTag> {
  final Value<int> tripId;
  final Value<int> tagId;
  final Value<int> rowid;
  const TripTagsCompanion({
    this.tripId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripTagsCompanion.insert({
    required int tripId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       tagId = Value(tagId);
  static Insertable<TripTag> custom({
    Expression<int>? tripId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripTagsCompanion copyWith({
    Value<int>? tripId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return TripTagsCompanion(
      tripId: tripId ?? this.tripId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripTagsCompanion(')
          ..write('tripId: $tripId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeopleTable extends People with TableInfo<$PeopleTable, Person> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
    'is_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, isMe];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people';
  @override
  VerificationContext validateIntegrity(
    Insertable<Person> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_me')) {
      context.handle(
        _isMeMeta,
        isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Person map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Person(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_me'],
      )!,
    );
  }

  @override
  $PeopleTable createAlias(String alias) {
    return $PeopleTable(attachedDatabase, alias);
  }
}

class Person extends DataClass implements Insertable<Person> {
  final int id;
  final String name;

  /// Marks the single person the app's user identifies as, used to filter the
  /// trip overview down to "my" expenses. At most one row is true; setting a new
  /// "me" clears the previous one. Travels with the database file.
  final bool isMe;
  const Person({required this.id, required this.name, required this.isMe});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_me'] = Variable<bool>(isMe);
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(id: Value(id), name: Value(name), isMe: Value(isMe));
  }

  factory Person.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Person(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isMe: serializer.fromJson<bool>(json['isMe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isMe': serializer.toJson<bool>(isMe),
    };
  }

  Person copyWith({int? id, String? name, bool? isMe}) => Person(
    id: id ?? this.id,
    name: name ?? this.name,
    isMe: isMe ?? this.isMe,
  );
  Person copyWithCompanion(PeopleCompanion data) {
    return Person(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Person(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isMe: $isMe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isMe);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Person &&
          other.id == this.id &&
          other.name == this.name &&
          other.isMe == this.isMe);
}

class PeopleCompanion extends UpdateCompanion<Person> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isMe;
  const PeopleCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isMe = const Value.absent(),
  });
  PeopleCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isMe = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Person> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isMe,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isMe != null) 'is_me': isMe,
    });
  }

  PeopleCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? isMe,
  }) {
    return PeopleCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isMe: isMe ?? this.isMe,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isMe: $isMe')
          ..write(')'))
        .toString();
  }
}

class $TripParticipantsTable extends TripParticipants
    with TableInfo<$TripParticipantsTable, TripParticipant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripParticipantsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [tripId, personId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_participants';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripParticipant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, personId};
  @override
  TripParticipant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripParticipant(
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}person_id'],
      )!,
    );
  }

  @override
  $TripParticipantsTable createAlias(String alias) {
    return $TripParticipantsTable(attachedDatabase, alias);
  }
}

class TripParticipant extends DataClass implements Insertable<TripParticipant> {
  final int tripId;
  final int personId;
  const TripParticipant({required this.tripId, required this.personId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<int>(tripId);
    map['person_id'] = Variable<int>(personId);
    return map;
  }

  TripParticipantsCompanion toCompanion(bool nullToAbsent) {
    return TripParticipantsCompanion(
      tripId: Value(tripId),
      personId: Value(personId),
    );
  }

  factory TripParticipant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripParticipant(
      tripId: serializer.fromJson<int>(json['tripId']),
      personId: serializer.fromJson<int>(json['personId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<int>(tripId),
      'personId': serializer.toJson<int>(personId),
    };
  }

  TripParticipant copyWith({int? tripId, int? personId}) => TripParticipant(
    tripId: tripId ?? this.tripId,
    personId: personId ?? this.personId,
  );
  TripParticipant copyWithCompanion(TripParticipantsCompanion data) {
    return TripParticipant(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      personId: data.personId.present ? data.personId.value : this.personId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripParticipant(')
          ..write('tripId: $tripId, ')
          ..write('personId: $personId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tripId, personId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripParticipant &&
          other.tripId == this.tripId &&
          other.personId == this.personId);
}

class TripParticipantsCompanion extends UpdateCompanion<TripParticipant> {
  final Value<int> tripId;
  final Value<int> personId;
  final Value<int> rowid;
  const TripParticipantsCompanion({
    this.tripId = const Value.absent(),
    this.personId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripParticipantsCompanion.insert({
    required int tripId,
    required int personId,
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       personId = Value(personId);
  static Insertable<TripParticipant> custom({
    Expression<int>? tripId,
    Expression<int>? personId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (personId != null) 'person_id': personId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripParticipantsCompanion copyWith({
    Value<int>? tripId,
    Value<int>? personId,
    Value<int>? rowid,
  }) {
    return TripParticipantsCompanion(
      tripId: tripId ?? this.tripId,
      personId: personId ?? this.personId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripParticipantsCompanion(')
          ..write('tripId: $tripId, ')
          ..write('personId: $personId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CostBeneficiariesTable extends CostBeneficiaries
    with TableInfo<$CostBeneficiariesTable, CostBeneficiary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CostBeneficiariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _costIdMeta = const VerificationMeta('costId');
  @override
  late final GeneratedColumn<int> costId = GeneratedColumn<int>(
    'cost_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES costs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [costId, personId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cost_beneficiaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CostBeneficiary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cost_id')) {
      context.handle(
        _costIdMeta,
        costId.isAcceptableOrUnknown(data['cost_id']!, _costIdMeta),
      );
    } else if (isInserting) {
      context.missing(_costIdMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {costId, personId};
  @override
  CostBeneficiary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CostBeneficiary(
      costId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}person_id'],
      )!,
    );
  }

  @override
  $CostBeneficiariesTable createAlias(String alias) {
    return $CostBeneficiariesTable(attachedDatabase, alias);
  }
}

class CostBeneficiary extends DataClass implements Insertable<CostBeneficiary> {
  final int costId;
  final int personId;
  const CostBeneficiary({required this.costId, required this.personId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cost_id'] = Variable<int>(costId);
    map['person_id'] = Variable<int>(personId);
    return map;
  }

  CostBeneficiariesCompanion toCompanion(bool nullToAbsent) {
    return CostBeneficiariesCompanion(
      costId: Value(costId),
      personId: Value(personId),
    );
  }

  factory CostBeneficiary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CostBeneficiary(
      costId: serializer.fromJson<int>(json['costId']),
      personId: serializer.fromJson<int>(json['personId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'costId': serializer.toJson<int>(costId),
      'personId': serializer.toJson<int>(personId),
    };
  }

  CostBeneficiary copyWith({int? costId, int? personId}) => CostBeneficiary(
    costId: costId ?? this.costId,
    personId: personId ?? this.personId,
  );
  CostBeneficiary copyWithCompanion(CostBeneficiariesCompanion data) {
    return CostBeneficiary(
      costId: data.costId.present ? data.costId.value : this.costId,
      personId: data.personId.present ? data.personId.value : this.personId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CostBeneficiary(')
          ..write('costId: $costId, ')
          ..write('personId: $personId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(costId, personId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CostBeneficiary &&
          other.costId == this.costId &&
          other.personId == this.personId);
}

class CostBeneficiariesCompanion extends UpdateCompanion<CostBeneficiary> {
  final Value<int> costId;
  final Value<int> personId;
  final Value<int> rowid;
  const CostBeneficiariesCompanion({
    this.costId = const Value.absent(),
    this.personId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CostBeneficiariesCompanion.insert({
    required int costId,
    required int personId,
    this.rowid = const Value.absent(),
  }) : costId = Value(costId),
       personId = Value(personId);
  static Insertable<CostBeneficiary> custom({
    Expression<int>? costId,
    Expression<int>? personId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (costId != null) 'cost_id': costId,
      if (personId != null) 'person_id': personId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CostBeneficiariesCompanion copyWith({
    Value<int>? costId,
    Value<int>? personId,
    Value<int>? rowid,
  }) {
    return CostBeneficiariesCompanion(
      costId: costId ?? this.costId,
      personId: personId ?? this.personId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (costId.present) {
      map['cost_id'] = Variable<int>(costId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CostBeneficiariesCompanion(')
          ..write('costId: $costId, ')
          ..write('personId: $personId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChecklistsTable extends Checklists
    with TableInfo<$ChecklistsTable, Checklist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _collapsedMeta = const VerificationMeta(
    'collapsed',
  );
  @override
  late final GeneratedColumn<bool> collapsed = GeneratedColumn<bool>(
    'collapsed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collapsed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    title,
    sortOrder,
    createdAt,
    collapsed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Checklist> instance, {
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('collapsed')) {
      context.handle(
        _collapsedMeta,
        collapsed.isAcceptableOrUnknown(data['collapsed']!, _collapsedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Checklist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Checklist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      collapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collapsed'],
      )!,
    );
  }

  @override
  $ChecklistsTable createAlias(String alias) {
    return $ChecklistsTable(attachedDatabase, alias);
  }
}

class Checklist extends DataClass implements Insertable<Checklist> {
  final int id;
  final int tripId;
  final String title;

  /// Manual ordering of a trip's checklists (appended to the end).
  final int sortOrder;
  final DateTime createdAt;

  /// Whether the card is shown collapsed in the trip overview. Persisted so the
  /// collapse state is restored when reopening the trip or the app.
  final bool collapsed;
  const Checklist({
    required this.id,
    required this.tripId,
    required this.title,
    required this.sortOrder,
    required this.createdAt,
    required this.collapsed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trip_id'] = Variable<int>(tripId);
    map['title'] = Variable<String>(title);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['collapsed'] = Variable<bool>(collapsed);
    return map;
  }

  ChecklistsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      title: Value(title),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      collapsed: Value(collapsed),
    );
  }

  factory Checklist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Checklist(
      id: serializer.fromJson<int>(json['id']),
      tripId: serializer.fromJson<int>(json['tripId']),
      title: serializer.fromJson<String>(json['title']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      collapsed: serializer.fromJson<bool>(json['collapsed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tripId': serializer.toJson<int>(tripId),
      'title': serializer.toJson<String>(title),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'collapsed': serializer.toJson<bool>(collapsed),
    };
  }

  Checklist copyWith({
    int? id,
    int? tripId,
    String? title,
    int? sortOrder,
    DateTime? createdAt,
    bool? collapsed,
  }) => Checklist(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    title: title ?? this.title,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    collapsed: collapsed ?? this.collapsed,
  );
  Checklist copyWithCompanion(ChecklistsCompanion data) {
    return Checklist(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      title: data.title.present ? data.title.value : this.title,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      collapsed: data.collapsed.present ? data.collapsed.value : this.collapsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Checklist(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('title: $title, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('collapsed: $collapsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tripId, title, sortOrder, createdAt, collapsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Checklist &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.title == this.title &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.collapsed == this.collapsed);
}

class ChecklistsCompanion extends UpdateCompanion<Checklist> {
  final Value<int> id;
  final Value<int> tripId;
  final Value<String> title;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<bool> collapsed;
  const ChecklistsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.title = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.collapsed = const Value.absent(),
  });
  ChecklistsCompanion.insert({
    this.id = const Value.absent(),
    required int tripId,
    this.title = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.collapsed = const Value.absent(),
  }) : tripId = Value(tripId);
  static Insertable<Checklist> custom({
    Expression<int>? id,
    Expression<int>? tripId,
    Expression<String>? title,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<bool>? collapsed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (title != null) 'title': title,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (collapsed != null) 'collapsed': collapsed,
    });
  }

  ChecklistsCompanion copyWith({
    Value<int>? id,
    Value<int>? tripId,
    Value<String>? title,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<bool>? collapsed,
  }) {
    return ChecklistsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      collapsed: collapsed ?? this.collapsed,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (collapsed.present) {
      map['collapsed'] = Variable<bool>(collapsed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('title: $title, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('collapsed: $collapsed')
          ..write(')'))
        .toString();
  }
}

class $ChecklistItemsTable extends ChecklistItems
    with TableInfo<$ChecklistItemsTable, ChecklistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _checklistIdMeta = const VerificationMeta(
    'checklistId',
  );
  @override
  late final GeneratedColumn<int> checklistId = GeneratedColumn<int>(
    'checklist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES checklists (id) ON DELETE CASCADE',
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
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    checklistId,
    label,
    done,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChecklistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('checklist_id')) {
      context.handle(
        _checklistIdMeta,
        checklistId.isAcceptableOrUnknown(
          data['checklist_id']!,
          _checklistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checklistIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
  ChecklistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChecklistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      checklistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checklist_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChecklistItemsTable createAlias(String alias) {
    return $ChecklistItemsTable(attachedDatabase, alias);
  }
}

class ChecklistItem extends DataClass implements Insertable<ChecklistItem> {
  final int id;
  final int checklistId;
  final String label;
  final bool done;

  /// Manual ordering within the checklist (appended to the end).
  final int sortOrder;
  final DateTime createdAt;
  const ChecklistItem({
    required this.id,
    required this.checklistId,
    required this.label,
    required this.done,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['checklist_id'] = Variable<int>(checklistId);
    map['label'] = Variable<String>(label);
    map['done'] = Variable<bool>(done);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistItemsCompanion(
      id: Value(id),
      checklistId: Value(checklistId),
      label: Value(label),
      done: Value(done),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory ChecklistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChecklistItem(
      id: serializer.fromJson<int>(json['id']),
      checklistId: serializer.fromJson<int>(json['checklistId']),
      label: serializer.fromJson<String>(json['label']),
      done: serializer.fromJson<bool>(json['done']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'checklistId': serializer.toJson<int>(checklistId),
      'label': serializer.toJson<String>(label),
      'done': serializer.toJson<bool>(done),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChecklistItem copyWith({
    int? id,
    int? checklistId,
    String? label,
    bool? done,
    int? sortOrder,
    DateTime? createdAt,
  }) => ChecklistItem(
    id: id ?? this.id,
    checklistId: checklistId ?? this.checklistId,
    label: label ?? this.label,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  ChecklistItem copyWithCompanion(ChecklistItemsCompanion data) {
    return ChecklistItem(
      id: data.id.present ? data.id.value : this.id,
      checklistId: data.checklistId.present
          ? data.checklistId.value
          : this.checklistId,
      label: data.label.present ? data.label.value : this.label,
      done: data.done.present ? data.done.value : this.done,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItem(')
          ..write('id: $id, ')
          ..write('checklistId: $checklistId, ')
          ..write('label: $label, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, checklistId, label, done, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChecklistItem &&
          other.id == this.id &&
          other.checklistId == this.checklistId &&
          other.label == this.label &&
          other.done == this.done &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class ChecklistItemsCompanion extends UpdateCompanion<ChecklistItem> {
  final Value<int> id;
  final Value<int> checklistId;
  final Value<String> label;
  final Value<bool> done;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const ChecklistItemsCompanion({
    this.id = const Value.absent(),
    this.checklistId = const Value.absent(),
    this.label = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ChecklistItemsCompanion.insert({
    this.id = const Value.absent(),
    required int checklistId,
    required String label,
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : checklistId = Value(checklistId),
       label = Value(label);
  static Insertable<ChecklistItem> custom({
    Expression<int>? id,
    Expression<int>? checklistId,
    Expression<String>? label,
    Expression<bool>? done,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (checklistId != null) 'checklist_id': checklistId,
      if (label != null) 'label': label,
      if (done != null) 'done': done,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ChecklistItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? checklistId,
    Value<String>? label,
    Value<bool>? done,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return ChecklistItemsCompanion(
      id: id ?? this.id,
      checklistId: checklistId ?? this.checklistId,
      label: label ?? this.label,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (checklistId.present) {
      map['checklist_id'] = Variable<int>(checklistId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItemsCompanion(')
          ..write('id: $id, ')
          ..write('checklistId: $checklistId, ')
          ..write('label: $label, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CollapsedDaysTable extends CollapsedDays
    with TableInfo<$CollapsedDaysTable, CollapsedDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollapsedDaysTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<DateTime> day = GeneratedColumn<DateTime>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tripId, day];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collapsed_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollapsedDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, day};
  @override
  CollapsedDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollapsedDay(
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}day'],
      )!,
    );
  }

  @override
  $CollapsedDaysTable createAlias(String alias) {
    return $CollapsedDaysTable(attachedDatabase, alias);
  }
}

class CollapsedDay extends DataClass implements Insertable<CollapsedDay> {
  final int tripId;

  /// The day, normalized to midnight (see `normalizeDay`).
  final DateTime day;
  const CollapsedDay({required this.tripId, required this.day});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<int>(tripId);
    map['day'] = Variable<DateTime>(day);
    return map;
  }

  CollapsedDaysCompanion toCompanion(bool nullToAbsent) {
    return CollapsedDaysCompanion(tripId: Value(tripId), day: Value(day));
  }

  factory CollapsedDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollapsedDay(
      tripId: serializer.fromJson<int>(json['tripId']),
      day: serializer.fromJson<DateTime>(json['day']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<int>(tripId),
      'day': serializer.toJson<DateTime>(day),
    };
  }

  CollapsedDay copyWith({int? tripId, DateTime? day}) =>
      CollapsedDay(tripId: tripId ?? this.tripId, day: day ?? this.day);
  CollapsedDay copyWithCompanion(CollapsedDaysCompanion data) {
    return CollapsedDay(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      day: data.day.present ? data.day.value : this.day,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollapsedDay(')
          ..write('tripId: $tripId, ')
          ..write('day: $day')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tripId, day);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollapsedDay &&
          other.tripId == this.tripId &&
          other.day == this.day);
}

class CollapsedDaysCompanion extends UpdateCompanion<CollapsedDay> {
  final Value<int> tripId;
  final Value<DateTime> day;
  final Value<int> rowid;
  const CollapsedDaysCompanion({
    this.tripId = const Value.absent(),
    this.day = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollapsedDaysCompanion.insert({
    required int tripId,
    required DateTime day,
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       day = Value(day);
  static Insertable<CollapsedDay> custom({
    Expression<int>? tripId,
    Expression<DateTime>? day,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (day != null) 'day': day,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollapsedDaysCompanion copyWith({
    Value<int>? tripId,
    Value<DateTime>? day,
    Value<int>? rowid,
  }) {
    return CollapsedDaysCompanion(
      tripId: tripId ?? this.tripId,
      day: day ?? this.day,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (day.present) {
      map['day'] = Variable<DateTime>(day.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollapsedDaysCompanion(')
          ..write('tripId: $tripId, ')
          ..write('day: $day, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, Track> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
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
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES itinerary_items (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TrackSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<TrackSource>($TracksTable.$convertersource);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<String> points = GeneratedColumn<String>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    source,
    name,
    points,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Track> instance, {
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
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Track map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Track(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      source: $TracksTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}points'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TrackSource, int, int> $convertersource =
      const EnumIndexConverter<TrackSource>(TrackSource.values);
}

class Track extends DataClass implements Insertable<Track> {
  final int id;
  final int itemId;

  /// Where the line came from. Defaults to [TrackSource.imported], which is
  /// what every row written today is.
  final TrackSource source;

  /// The name the file gave this line, when it had one. Not defaulted to
  /// anything: an unnamed track reads as the leg it is on, which is more than a
  /// made-up "Track 1" would say.
  final String? name;

  /// The line itself, packed by `encodeTrackPoints`. Never XML: the file was a
  /// transport, and keeping it would mean re-parsing foreign markup on every
  /// draw.
  final String points;

  /// Manual ordering among the tracks of one item, appended at the end — a leg
  /// can carry the walk out of the station and the walk into the next one.
  final int sortOrder;
  const Track({
    required this.id,
    required this.itemId,
    required this.source,
    this.name,
    required this.points,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item_id'] = Variable<int>(itemId);
    {
      map['source'] = Variable<int>(
        $TracksTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['points'] = Variable<String>(points);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      itemId: Value(itemId),
      source: Value(source),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      points: Value(points),
      sortOrder: Value(sortOrder),
    );
  }

  factory Track.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Track(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<int>(json['itemId']),
      source: $TracksTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      name: serializer.fromJson<String?>(json['name']),
      points: serializer.fromJson<String>(json['points']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<int>(itemId),
      'source': serializer.toJson<int>(
        $TracksTable.$convertersource.toJson(source),
      ),
      'name': serializer.toJson<String?>(name),
      'points': serializer.toJson<String>(points),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Track copyWith({
    int? id,
    int? itemId,
    TrackSource? source,
    Value<String?> name = const Value.absent(),
    String? points,
    int? sortOrder,
  }) => Track(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    source: source ?? this.source,
    name: name.present ? name.value : this.name,
    points: points ?? this.points,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Track copyWithCompanion(TracksCompanion data) {
    return Track(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      source: data.source.present ? data.source.value : this.source,
      name: data.name.present ? data.name.value : this.name,
      points: data.points.present ? data.points.value : this.points,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Track(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('source: $source, ')
          ..write('name: $name, ')
          ..write('points: $points, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, source, name, points, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.source == this.source &&
          other.name == this.name &&
          other.points == this.points &&
          other.sortOrder == this.sortOrder);
}

class TracksCompanion extends UpdateCompanion<Track> {
  final Value<int> id;
  final Value<int> itemId;
  final Value<TrackSource> source;
  final Value<String?> name;
  final Value<String> points;
  final Value<int> sortOrder;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.source = const Value.absent(),
    this.name = const Value.absent(),
    this.points = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required int itemId,
    this.source = const Value.absent(),
    this.name = const Value.absent(),
    required String points,
    this.sortOrder = const Value.absent(),
  }) : itemId = Value(itemId),
       points = Value(points);
  static Insertable<Track> custom({
    Expression<int>? id,
    Expression<int>? itemId,
    Expression<int>? source,
    Expression<String>? name,
    Expression<String>? points,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (source != null) 'source': source,
      if (name != null) 'name': name,
      if (points != null) 'points': points,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<int>? itemId,
    Value<TrackSource>? source,
    Value<String?>? name,
    Value<String>? points,
    Value<int>? sortOrder,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      source: source ?? this.source,
      name: name ?? this.name,
      points: points ?? this.points,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (source.present) {
      map['source'] = Variable<int>(
        $TracksTable.$convertersource.toSql(source.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (points.present) {
      map['points'] = Variable<String>(points.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('source: $source, ')
          ..write('name: $name, ')
          ..write('points: $points, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $VisitedCountriesTable extends VisitedCountries
    with TableInfo<$VisitedCountriesTable, VisitedCountry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitedCountriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markedAtMeta = const VerificationMeta(
    'markedAt',
  );
  @override
  late final GeneratedColumn<DateTime> markedAt = GeneratedColumn<DateTime>(
    'marked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [code, markedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visited_countries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitedCountry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('marked_at')) {
      context.handle(
        _markedAtMeta,
        markedAt.isAcceptableOrUnknown(data['marked_at']!, _markedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  VisitedCountry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitedCountry(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      markedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}marked_at'],
      )!,
    );
  }

  @override
  $VisitedCountriesTable createAlias(String alias) {
    return $VisitedCountriesTable(attachedDatabase, alias);
  }
}

class VisitedCountry extends DataClass implements Insertable<VisitedCountry> {
  final String code;
  final DateTime markedAt;
  const VisitedCountry({required this.code, required this.markedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['marked_at'] = Variable<DateTime>(markedAt);
    return map;
  }

  VisitedCountriesCompanion toCompanion(bool nullToAbsent) {
    return VisitedCountriesCompanion(
      code: Value(code),
      markedAt: Value(markedAt),
    );
  }

  factory VisitedCountry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitedCountry(
      code: serializer.fromJson<String>(json['code']),
      markedAt: serializer.fromJson<DateTime>(json['markedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'markedAt': serializer.toJson<DateTime>(markedAt),
    };
  }

  VisitedCountry copyWith({String? code, DateTime? markedAt}) => VisitedCountry(
    code: code ?? this.code,
    markedAt: markedAt ?? this.markedAt,
  );
  VisitedCountry copyWithCompanion(VisitedCountriesCompanion data) {
    return VisitedCountry(
      code: data.code.present ? data.code.value : this.code,
      markedAt: data.markedAt.present ? data.markedAt.value : this.markedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitedCountry(')
          ..write('code: $code, ')
          ..write('markedAt: $markedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, markedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitedCountry &&
          other.code == this.code &&
          other.markedAt == this.markedAt);
}

class VisitedCountriesCompanion extends UpdateCompanion<VisitedCountry> {
  final Value<String> code;
  final Value<DateTime> markedAt;
  final Value<int> rowid;
  const VisitedCountriesCompanion({
    this.code = const Value.absent(),
    this.markedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitedCountriesCompanion.insert({
    required String code,
    this.markedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : code = Value(code);
  static Insertable<VisitedCountry> custom({
    Expression<String>? code,
    Expression<DateTime>? markedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (markedAt != null) 'marked_at': markedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitedCountriesCompanion copyWith({
    Value<String>? code,
    Value<DateTime>? markedAt,
    Value<int>? rowid,
  }) {
    return VisitedCountriesCompanion(
      code: code ?? this.code,
      markedAt: markedAt ?? this.markedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (markedAt.present) {
      map['marked_at'] = Variable<DateTime>(markedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitedCountriesCompanion(')
          ..write('code: $code, ')
          ..write('markedAt: $markedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES item_groups (id) ON DELETE CASCADE',
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
  @override
  late final GeneratedColumnWithTypeConverter<AttachmentKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<AttachmentKind>($AttachmentsTable.$converterkind);
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AttachmentPositionSource?, int>
  positionSource =
      GeneratedColumn<int>(
        'position_source',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<AttachmentPositionSource?>(
        $AttachmentsTable.$converterpositionSourcen,
      );
  static const VerificationMeta _thumbnailMeta = const VerificationMeta(
    'thumbnail',
  );
  @override
  late final GeneratedColumn<Uint8List> thumbnail = GeneratedColumn<Uint8List>(
    'thumbnail',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
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
    groupId,
    tripId,
    kind,
    mimeType,
    name,
    byteSize,
    width,
    height,
    lat,
    lon,
    positionSource,
    thumbnail,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
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
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    if (data.containsKey('thumbnail')) {
      context.handle(
        _thumbnailMeta,
        thumbnail.isAcceptableOrUnknown(data['thumbnail']!, _thumbnailMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      ),
      kind: $AttachmentsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
      positionSource: $AttachmentsTable.$converterpositionSourcen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}position_source'],
        ),
      ),
      thumbnail: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}thumbnail'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AttachmentKind, int, int> $converterkind =
      const EnumIndexConverter<AttachmentKind>(AttachmentKind.values);
  static JsonTypeConverter2<AttachmentPositionSource, int, int>
  $converterpositionSource = const EnumIndexConverter<AttachmentPositionSource>(
    AttachmentPositionSource.values,
  );
  static JsonTypeConverter2<AttachmentPositionSource?, int?, int?>
  $converterpositionSourcen = JsonTypeConverter2.asNullable(
    $converterpositionSource,
  );
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final int id;

  /// The entry this hangs off, or null when it belongs to a [groupId] instead.
  final int? itemId;

  /// The run this hangs off, or null when it belongs to a single [itemId].
  final int? groupId;

  /// Set for a file that belongs to the whole trip rather than to any one part
  /// of it: the insurance, the passport scan, the visa, a routine's season
  /// ticket. Null when it hangs on an [itemId] or a [groupId] instead.
  final int? tripId;
  final AttachmentKind kind;

  /// The media type, kept to hand the file back to the platform when it is
  /// opened or shared. Ours for a photo (the app re-encoded it and knows what it
  /// wrote); the picker's for a document, which is a claim about a file we did
  /// not write and is treated as one.
  final String mimeType;

  /// The name the file arrived under, when it had one — as with [Tracks.name],
  /// not defaulted to anything, since an unnamed attachment reads as the entry
  /// it hangs on and that says more than "Attachment 1" would.
  final String? name;

  /// The size of what is stored, in bytes. Denormalised from the blob on
  /// purpose: it is the one number a list has to show, and reading it off the
  /// payload would mean loading the payload.
  final int byteSize;

  /// Pixel dimensions of a photo, so a viewer can lay out space for it before
  /// the bytes arrive. Null for a document.
  final int? width;
  final int? height;

  /// Where the photo was taken, when that is known — read from the file's EXIF
  /// or pointed at on the map, see [positionSource]. Null for everything else,
  /// and deliberately **not** inherited from the entry it hangs on: the entry
  /// already has a pin there, and a second one at the same spot would be the app
  /// claiming to know where a picture was taken.
  ///
  /// A pair, like a place's own coordinates: half of one is not half a position,
  /// so the two are written and cleared together.
  final double? lat;
  final double? lon;

  /// Which of the two the position above is. Null exactly when there is none.
  final AttachmentPositionSource? positionSource;

  /// A small copy of a photo, for lists and for the map marker. Null for a
  /// document, which has nothing to show but its icon.
  ///
  /// Stored rather than derived: decoding a full-size photo to draw it at 40 px
  /// is the shape of the pinch freeze this app has already been through, and
  /// on the web there is no disk cache to fall back on.
  final Uint8List? thumbnail;

  /// Manual ordering among the attachments of one owner, appended at the end.
  final int sortOrder;
  final DateTime createdAt;
  const Attachment({
    required this.id,
    this.itemId,
    this.groupId,
    this.tripId,
    required this.kind,
    required this.mimeType,
    this.name,
    required this.byteSize,
    this.width,
    this.height,
    this.lat,
    this.lon,
    this.positionSource,
    this.thumbnail,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<int>(itemId);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<int>(tripId);
    }
    {
      map['kind'] = Variable<int>($AttachmentsTable.$converterkind.toSql(kind));
    }
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    if (!nullToAbsent || positionSource != null) {
      map['position_source'] = Variable<int>(
        $AttachmentsTable.$converterpositionSourcen.toSql(positionSource),
      );
    }
    if (!nullToAbsent || thumbnail != null) {
      map['thumbnail'] = Variable<Uint8List>(thumbnail);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      kind: Value(kind),
      mimeType: Value(mimeType),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      byteSize: Value(byteSize),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      positionSource: positionSource == null && nullToAbsent
          ? const Value.absent()
          : Value(positionSource),
      thumbnail: thumbnail == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnail),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<int?>(json['itemId']),
      groupId: serializer.fromJson<int?>(json['groupId']),
      tripId: serializer.fromJson<int?>(json['tripId']),
      kind: $AttachmentsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      name: serializer.fromJson<String?>(json['name']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      positionSource: $AttachmentsTable.$converterpositionSourcen.fromJson(
        serializer.fromJson<int?>(json['positionSource']),
      ),
      thumbnail: serializer.fromJson<Uint8List?>(json['thumbnail']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<int?>(itemId),
      'groupId': serializer.toJson<int?>(groupId),
      'tripId': serializer.toJson<int?>(tripId),
      'kind': serializer.toJson<int>(
        $AttachmentsTable.$converterkind.toJson(kind),
      ),
      'mimeType': serializer.toJson<String>(mimeType),
      'name': serializer.toJson<String?>(name),
      'byteSize': serializer.toJson<int>(byteSize),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'positionSource': serializer.toJson<int?>(
        $AttachmentsTable.$converterpositionSourcen.toJson(positionSource),
      ),
      'thumbnail': serializer.toJson<Uint8List?>(thumbnail),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Attachment copyWith({
    int? id,
    Value<int?> itemId = const Value.absent(),
    Value<int?> groupId = const Value.absent(),
    Value<int?> tripId = const Value.absent(),
    AttachmentKind? kind,
    String? mimeType,
    Value<String?> name = const Value.absent(),
    int? byteSize,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    Value<AttachmentPositionSource?> positionSource = const Value.absent(),
    Value<Uint8List?> thumbnail = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
  }) => Attachment(
    id: id ?? this.id,
    itemId: itemId.present ? itemId.value : this.itemId,
    groupId: groupId.present ? groupId.value : this.groupId,
    tripId: tripId.present ? tripId.value : this.tripId,
    kind: kind ?? this.kind,
    mimeType: mimeType ?? this.mimeType,
    name: name.present ? name.value : this.name,
    byteSize: byteSize ?? this.byteSize,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    positionSource: positionSource.present
        ? positionSource.value
        : this.positionSource,
    thumbnail: thumbnail.present ? thumbnail.value : this.thumbnail,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      kind: data.kind.present ? data.kind.value : this.kind,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      name: data.name.present ? data.name.value : this.name,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      positionSource: data.positionSource.present
          ? data.positionSource.value
          : this.positionSource,
      thumbnail: data.thumbnail.present ? data.thumbnail.value : this.thumbnail,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('groupId: $groupId, ')
          ..write('tripId: $tripId, ')
          ..write('kind: $kind, ')
          ..write('mimeType: $mimeType, ')
          ..write('name: $name, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('positionSource: $positionSource, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    groupId,
    tripId,
    kind,
    mimeType,
    name,
    byteSize,
    width,
    height,
    lat,
    lon,
    positionSource,
    $driftBlobEquality.hash(thumbnail),
    sortOrder,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.groupId == this.groupId &&
          other.tripId == this.tripId &&
          other.kind == this.kind &&
          other.mimeType == this.mimeType &&
          other.name == this.name &&
          other.byteSize == this.byteSize &&
          other.width == this.width &&
          other.height == this.height &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.positionSource == this.positionSource &&
          $driftBlobEquality.equals(other.thumbnail, this.thumbnail) &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<int> id;
  final Value<int?> itemId;
  final Value<int?> groupId;
  final Value<int?> tripId;
  final Value<AttachmentKind> kind;
  final Value<String> mimeType;
  final Value<String?> name;
  final Value<int> byteSize;
  final Value<int?> width;
  final Value<int?> height;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<AttachmentPositionSource?> positionSource;
  final Value<Uint8List?> thumbnail;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.kind = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.name = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.positionSource = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.tripId = const Value.absent(),
    required AttachmentKind kind,
    required String mimeType,
    this.name = const Value.absent(),
    required int byteSize,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.positionSource = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : kind = Value(kind),
       mimeType = Value(mimeType),
       byteSize = Value(byteSize);
  static Insertable<Attachment> custom({
    Expression<int>? id,
    Expression<int>? itemId,
    Expression<int>? groupId,
    Expression<int>? tripId,
    Expression<int>? kind,
    Expression<String>? mimeType,
    Expression<String>? name,
    Expression<int>? byteSize,
    Expression<int>? width,
    Expression<int>? height,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<int>? positionSource,
    Expression<Uint8List>? thumbnail,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (groupId != null) 'group_id': groupId,
      if (tripId != null) 'trip_id': tripId,
      if (kind != null) 'kind': kind,
      if (mimeType != null) 'mime_type': mimeType,
      if (name != null) 'name': name,
      if (byteSize != null) 'byte_size': byteSize,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (positionSource != null) 'position_source': positionSource,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttachmentsCompanion copyWith({
    Value<int>? id,
    Value<int?>? itemId,
    Value<int?>? groupId,
    Value<int?>? tripId,
    Value<AttachmentKind>? kind,
    Value<String>? mimeType,
    Value<String?>? name,
    Value<int>? byteSize,
    Value<int?>? width,
    Value<int?>? height,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<AttachmentPositionSource?>? positionSource,
    Value<Uint8List?>? thumbnail,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      groupId: groupId ?? this.groupId,
      tripId: tripId ?? this.tripId,
      kind: kind ?? this.kind,
      mimeType: mimeType ?? this.mimeType,
      name: name ?? this.name,
      byteSize: byteSize ?? this.byteSize,
      width: width ?? this.width,
      height: height ?? this.height,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      positionSource: positionSource ?? this.positionSource,
      thumbnail: thumbnail ?? this.thumbnail,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $AttachmentsTable.$converterkind.toSql(kind.value),
      );
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (positionSource.present) {
      map['position_source'] = Variable<int>(
        $AttachmentsTable.$converterpositionSourcen.toSql(positionSource.value),
      );
    }
    if (thumbnail.present) {
      map['thumbnail'] = Variable<Uint8List>(thumbnail.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('groupId: $groupId, ')
          ..write('tripId: $tripId, ')
          ..write('kind: $kind, ')
          ..write('mimeType: $mimeType, ')
          ..write('name: $name, ')
          ..write('byteSize: $byteSize, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('positionSource: $positionSource, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AttachmentBlobsTable extends AttachmentBlobs
    with TableInfo<$AttachmentBlobsTable, AttachmentBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attachmentIdMeta = const VerificationMeta(
    'attachmentId',
  );
  @override
  late final GeneratedColumn<int> attachmentId = GeneratedColumn<int>(
    'attachment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attachments (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [attachmentId, bytes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachment_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attachment_id')) {
      context.handle(
        _attachmentIdMeta,
        attachmentId.isAcceptableOrUnknown(
          data['attachment_id']!,
          _attachmentIdMeta,
        ),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attachmentId};
  @override
  AttachmentBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentBlob(
      attachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attachment_id'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
    );
  }

  @override
  $AttachmentBlobsTable createAlias(String alias) {
    return $AttachmentBlobsTable(attachedDatabase, alias);
  }
}

class AttachmentBlob extends DataClass implements Insertable<AttachmentBlob> {
  final int attachmentId;
  final Uint8List bytes;
  const AttachmentBlob({required this.attachmentId, required this.bytes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attachment_id'] = Variable<int>(attachmentId);
    map['bytes'] = Variable<Uint8List>(bytes);
    return map;
  }

  AttachmentBlobsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentBlobsCompanion(
      attachmentId: Value(attachmentId),
      bytes: Value(bytes),
    );
  }

  factory AttachmentBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentBlob(
      attachmentId: serializer.fromJson<int>(json['attachmentId']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attachmentId': serializer.toJson<int>(attachmentId),
      'bytes': serializer.toJson<Uint8List>(bytes),
    };
  }

  AttachmentBlob copyWith({int? attachmentId, Uint8List? bytes}) =>
      AttachmentBlob(
        attachmentId: attachmentId ?? this.attachmentId,
        bytes: bytes ?? this.bytes,
      );
  AttachmentBlob copyWithCompanion(AttachmentBlobsCompanion data) {
    return AttachmentBlob(
      attachmentId: data.attachmentId.present
          ? data.attachmentId.value
          : this.attachmentId,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentBlob(')
          ..write('attachmentId: $attachmentId, ')
          ..write('bytes: $bytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(attachmentId, $driftBlobEquality.hash(bytes));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentBlob &&
          other.attachmentId == this.attachmentId &&
          $driftBlobEquality.equals(other.bytes, this.bytes));
}

class AttachmentBlobsCompanion extends UpdateCompanion<AttachmentBlob> {
  final Value<int> attachmentId;
  final Value<Uint8List> bytes;
  const AttachmentBlobsCompanion({
    this.attachmentId = const Value.absent(),
    this.bytes = const Value.absent(),
  });
  AttachmentBlobsCompanion.insert({
    this.attachmentId = const Value.absent(),
    required Uint8List bytes,
  }) : bytes = Value(bytes);
  static Insertable<AttachmentBlob> custom({
    Expression<int>? attachmentId,
    Expression<Uint8List>? bytes,
  }) {
    return RawValuesInsertable({
      if (attachmentId != null) 'attachment_id': attachmentId,
      if (bytes != null) 'bytes': bytes,
    });
  }

  AttachmentBlobsCompanion copyWith({
    Value<int>? attachmentId,
    Value<Uint8List>? bytes,
  }) {
    return AttachmentBlobsCompanion(
      attachmentId: attachmentId ?? this.attachmentId,
      bytes: bytes ?? this.bytes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attachmentId.present) {
      map['attachment_id'] = Variable<int>(attachmentId.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentBlobsCompanion(')
          ..write('attachmentId: $attachmentId, ')
          ..write('bytes: $bytes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $ItemGroupsTable itemGroups = $ItemGroupsTable(this);
  late final $AlternativeSetsTable alternativeSets = $AlternativeSetsTable(
    this,
  );
  late final $AlternativesTable alternatives = $AlternativesTable(this);
  late final $TransportModesTable transportModes = $TransportModesTable(this);
  late final $ItineraryItemsTable itineraryItems = $ItineraryItemsTable(this);
  late final $CurrenciesTable currencies = $CurrenciesTable(this);
  late final $CostsTable costs = $CostsTable(this);
  late final $CostReasonsTable costReasons = $CostReasonsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TripTagsTable tripTags = $TripTagsTable(this);
  late final $PeopleTable people = $PeopleTable(this);
  late final $TripParticipantsTable tripParticipants = $TripParticipantsTable(
    this,
  );
  late final $CostBeneficiariesTable costBeneficiaries =
      $CostBeneficiariesTable(this);
  late final $ChecklistsTable checklists = $ChecklistsTable(this);
  late final $ChecklistItemsTable checklistItems = $ChecklistItemsTable(this);
  late final $CollapsedDaysTable collapsedDays = $CollapsedDaysTable(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $VisitedCountriesTable visitedCountries = $VisitedCountriesTable(
    this,
  );
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $AttachmentBlobsTable attachmentBlobs = $AttachmentBlobsTable(
    this,
  );
  late final TripDao tripDao = TripDao(this as AppDatabase);
  late final ItineraryDao itineraryDao = ItineraryDao(this as AppDatabase);
  late final CostDao costDao = CostDao(this as AppDatabase);
  late final ChecklistDao checklistDao = ChecklistDao(this as AppDatabase);
  late final GroupDao groupDao = GroupDao(this as AppDatabase);
  late final AlternativeDao alternativeDao = AlternativeDao(
    this as AppDatabase,
  );
  late final RoutineDao routineDao = RoutineDao(this as AppDatabase);
  late final TagDao tagDao = TagDao(this as AppDatabase);
  late final TrackDao trackDao = TrackDao(this as AppDatabase);
  late final AttachmentDao attachmentDao = AttachmentDao(this as AppDatabase);
  late final VisitedCountryDao visitedCountryDao = VisitedCountryDao(
    this as AppDatabase,
  );
  late final SharingDao sharingDao = SharingDao(this as AppDatabase);
  late final TransportModeDao transportModeDao = TransportModeDao(
    this as AppDatabase,
  );
  late final CurrencyDao currencyDao = CurrencyDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trips,
    itemGroups,
    alternativeSets,
    alternatives,
    transportModes,
    itineraryItems,
    currencies,
    costs,
    costReasons,
    tags,
    tripTags,
    people,
    tripParticipants,
    costBeneficiaries,
    checklists,
    checklistItems,
    collapsedDays,
    tracks,
    visitedCountries,
    attachments,
    attachmentBlobs,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trips', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_groups', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('alternative_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'alternative_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('alternatives', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('itinerary_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'item_groups',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('itinerary_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'alternatives',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('itinerary_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transport_modes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('itinerary_items', kind: UpdateKind.update)],
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
        'item_groups',
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_participants', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'people',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_participants', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'costs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cost_beneficiaries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'people',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cost_beneficiaries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('checklists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'checklists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('checklist_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('collapsed_days', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'itinerary_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'itinerary_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'item_groups',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'attachments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachment_blobs', kind: UpdateKind.delete)],
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
      Value<TripKind> kind,
      Value<int?> fromRoutineId,
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
      Value<TripKind> kind,
      Value<int?> fromRoutineId,
      Value<int> colorValue,
      Value<DateTime> createdAt,
    });

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, Trip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _fromRoutineIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trips__from_routine_id__trips__id');

  $$TripsTableProcessedTableManager? get fromRoutineId {
    final $_column = $_itemColumn<int>('from_routine_id');
    if ($_column == null) return null;
    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fromRoutineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItemGroupsTable, List<ItemGroup>>
  _itemGroupsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemGroups,
    aliasName: 'trips__id__item_groups__trip_id',
  );

  $$ItemGroupsTableProcessedTableManager get itemGroupsRefs {
    final manager = $$ItemGroupsTableTableManager(
      $_db,
      $_db.itemGroups,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemGroupsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AlternativeSetsTable, List<AlternativeSet>>
  _alternativeSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.alternativeSets,
    aliasName: 'trips__id__alternative_sets__trip_id',
  );

  $$AlternativeSetsTableProcessedTableManager get alternativeSetsRefs {
    final manager = $$AlternativeSetsTableTableManager(
      $_db,
      $_db.alternativeSets,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _alternativeSetsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

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

  static MultiTypedResultKey<$TripTagsTable, List<TripTag>> _tripTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tripTags,
    aliasName: 'trips__id__trip_tags__trip_id',
  );

  $$TripTagsTableProcessedTableManager get tripTagsRefs {
    final manager = $$TripTagsTableTableManager(
      $_db,
      $_db.tripTags,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TripParticipantsTable, List<TripParticipant>>
  _tripParticipantsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripParticipants,
    aliasName: 'trips__id__trip_participants__trip_id',
  );

  $$TripParticipantsTableProcessedTableManager get tripParticipantsRefs {
    final manager = $$TripParticipantsTableTableManager(
      $_db,
      $_db.tripParticipants,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _tripParticipantsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChecklistsTable, List<Checklist>>
  _checklistsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.checklists,
    aliasName: 'trips__id__checklists__trip_id',
  );

  $$ChecklistsTableProcessedTableManager get checklistsRefs {
    final manager = $$ChecklistsTableTableManager(
      $_db,
      $_db.checklists,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_checklistsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CollapsedDaysTable, List<CollapsedDay>>
  _collapsedDaysRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.collapsedDays,
    aliasName: 'trips__id__collapsed_days__trip_id',
  );

  $$CollapsedDaysTableProcessedTableManager get collapsedDaysRefs {
    final manager = $$CollapsedDaysTableTableManager(
      $_db,
      $_db.collapsedDays,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_collapsedDaysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'trips__id__attachments__trip_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
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

  ColumnWithTypeConverterFilters<TripKind, TripKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get fromRoutineId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromRoutineId,
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

  Expression<bool> itemGroupsRefs(
    Expression<bool> Function($$ItemGroupsTableFilterComposer f) f,
  ) {
    final $$ItemGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableFilterComposer(
            $db: $db,
            $table: $db.itemGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> alternativeSetsRefs(
    Expression<bool> Function($$AlternativeSetsTableFilterComposer f) f,
  ) {
    final $$AlternativeSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alternativeSets,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativeSetsTableFilterComposer(
            $db: $db,
            $table: $db.alternativeSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

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

  Expression<bool> tripTagsRefs(
    Expression<bool> Function($$TripTagsTableFilterComposer f) f,
  ) {
    final $$TripTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripTags,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripTagsTableFilterComposer(
            $db: $db,
            $table: $db.tripTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tripParticipantsRefs(
    Expression<bool> Function($$TripParticipantsTableFilterComposer f) f,
  ) {
    final $$TripParticipantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripParticipants,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripParticipantsTableFilterComposer(
            $db: $db,
            $table: $db.tripParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> checklistsRefs(
    Expression<bool> Function($$ChecklistsTableFilterComposer f) f,
  ) {
    final $$ChecklistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklists,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistsTableFilterComposer(
            $db: $db,
            $table: $db.checklists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> collapsedDaysRefs(
    Expression<bool> Function($$CollapsedDaysTableFilterComposer f) f,
  ) {
    final $$CollapsedDaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collapsedDays,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollapsedDaysTableFilterComposer(
            $db: $db,
            $table: $db.collapsedDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
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

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
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

  $$TripsTableOrderingComposer get fromRoutineId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromRoutineId,
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

  GeneratedColumnWithTypeConverter<TripKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TripsTableAnnotationComposer get fromRoutineId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromRoutineId,
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

  Expression<T> itemGroupsRefs<T extends Object>(
    Expression<T> Function($$ItemGroupsTableAnnotationComposer a) f,
  ) {
    final $$ItemGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> alternativeSetsRefs<T extends Object>(
    Expression<T> Function($$AlternativeSetsTableAnnotationComposer a) f,
  ) {
    final $$AlternativeSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alternativeSets,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativeSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.alternativeSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

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

  Expression<T> tripTagsRefs<T extends Object>(
    Expression<T> Function($$TripTagsTableAnnotationComposer a) f,
  ) {
    final $$TripTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripTags,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tripParticipantsRefs<T extends Object>(
    Expression<T> Function($$TripParticipantsTableAnnotationComposer a) f,
  ) {
    final $$TripParticipantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripParticipants,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripParticipantsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> checklistsRefs<T extends Object>(
    Expression<T> Function($$ChecklistsTableAnnotationComposer a) f,
  ) {
    final $$ChecklistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklists,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistsTableAnnotationComposer(
            $db: $db,
            $table: $db.checklists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> collapsedDaysRefs<T extends Object>(
    Expression<T> Function($$CollapsedDaysTableAnnotationComposer a) f,
  ) {
    final $$CollapsedDaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collapsedDays,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollapsedDaysTableAnnotationComposer(
            $db: $db,
            $table: $db.collapsedDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
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
          PrefetchHooks Function({
            bool fromRoutineId,
            bool itemGroupsRefs,
            bool alternativeSetsRefs,
            bool itineraryItemsRefs,
            bool costsRefs,
            bool tripTagsRefs,
            bool tripParticipantsRefs,
            bool checklistsRefs,
            bool collapsedDaysRefs,
            bool attachmentsRefs,
          })
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
                Value<TripKind> kind = const Value.absent(),
                Value<int?> fromRoutineId = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                title: title,
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                notes: notes,
                kind: kind,
                fromRoutineId: fromRoutineId,
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
                Value<TripKind> kind = const Value.absent(),
                Value<int?> fromRoutineId = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                title: title,
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                notes: notes,
                kind: kind,
                fromRoutineId: fromRoutineId,
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
              ({
                fromRoutineId = false,
                itemGroupsRefs = false,
                alternativeSetsRefs = false,
                itineraryItemsRefs = false,
                costsRefs = false,
                tripTagsRefs = false,
                tripParticipantsRefs = false,
                checklistsRefs = false,
                collapsedDaysRefs = false,
                attachmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itemGroupsRefs) db.itemGroups,
                    if (alternativeSetsRefs) db.alternativeSets,
                    if (itineraryItemsRefs) db.itineraryItems,
                    if (costsRefs) db.costs,
                    if (tripTagsRefs) db.tripTags,
                    if (tripParticipantsRefs) db.tripParticipants,
                    if (checklistsRefs) db.checklists,
                    if (collapsedDaysRefs) db.collapsedDays,
                    if (attachmentsRefs) db.attachments,
                  ],
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
                        if (fromRoutineId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.fromRoutineId,
                                    referencedTable: $$TripsTableReferences
                                        ._fromRoutineIdTable(db),
                                    referencedColumn: $$TripsTableReferences
                                        ._fromRoutineIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itemGroupsRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, ItemGroup>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._itemGroupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).itemGroupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (alternativeSetsRefs)
                        await $_getPrefetchedData<
                          Trip,
                          $TripsTable,
                          AlternativeSet
                        >(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._alternativeSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).alternativeSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
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
                      if (tripTagsRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, TripTag>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._tripTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).tripTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tripParticipantsRefs)
                        await $_getPrefetchedData<
                          Trip,
                          $TripsTable,
                          TripParticipant
                        >(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._tripParticipantsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).tripParticipantsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (checklistsRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, Checklist>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._checklistsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).checklistsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (collapsedDaysRefs)
                        await $_getPrefetchedData<
                          Trip,
                          $TripsTable,
                          CollapsedDay
                        >(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._collapsedDaysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).collapsedDaysRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          Trip,
                          $TripsTable,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
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
      PrefetchHooks Function({
        bool fromRoutineId,
        bool itemGroupsRefs,
        bool alternativeSetsRefs,
        bool itineraryItemsRefs,
        bool costsRefs,
        bool tripTagsRefs,
        bool tripParticipantsRefs,
        bool checklistsRefs,
        bool collapsedDaysRefs,
        bool attachmentsRefs,
      })
    >;
typedef $$ItemGroupsTableCreateCompanionBuilder =
    ItemGroupsCompanion Function({
      Value<int> id,
      required int tripId,
      Value<String?> label,
      Value<bool> collapsed,
    });
typedef $$ItemGroupsTableUpdateCompanionBuilder =
    ItemGroupsCompanion Function({
      Value<int> id,
      Value<int> tripId,
      Value<String?> label,
      Value<bool> collapsed,
    });

final class $$ItemGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemGroupsTable, ItemGroup> {
  $$ItemGroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('item_groups__trip_id__trips__id');

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

  static MultiTypedResultKey<$ItineraryItemsTable, List<ItineraryItem>>
  _itineraryItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itineraryItems,
    aliasName: 'item_groups__id__itinerary_items__group_id',
  );

  $$ItineraryItemsTableProcessedTableManager get itineraryItemsRefs {
    final manager = $$ItineraryItemsTableTableManager(
      $_db,
      $_db.itineraryItems,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_itineraryItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CostsTable, List<Cost>> _costsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.costs,
    aliasName: 'item_groups__id__costs__group_id',
  );

  $$CostsTableProcessedTableManager get costsRefs {
    final manager = $$CostsTableTableManager(
      $_db,
      $_db.costs,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_costsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'item_groups__id__attachments__group_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItemGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemGroupsTable> {
  $$ItemGroupsTableFilterComposer({
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

  ColumnFilters<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
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

  Expression<bool> itineraryItemsRefs(
    Expression<bool> Function($$ItineraryItemsTableFilterComposer f) f,
  ) {
    final $$ItineraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.groupId,
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
      getReferencedColumn: (t) => t.groupId,
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

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemGroupsTable> {
  $$ItemGroupsTableOrderingComposer({
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

  ColumnOrderings<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
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

class $$ItemGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemGroupsTable> {
  $$ItemGroupsTableAnnotationComposer({
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

  GeneratedColumn<bool> get collapsed =>
      $composableBuilder(column: $table.collapsed, builder: (column) => column);

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

  Expression<T> itineraryItemsRefs<T extends Object>(
    Expression<T> Function($$ItineraryItemsTableAnnotationComposer a) f,
  ) {
    final $$ItineraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.groupId,
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
      getReferencedColumn: (t) => t.groupId,
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

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemGroupsTable,
          ItemGroup,
          $$ItemGroupsTableFilterComposer,
          $$ItemGroupsTableOrderingComposer,
          $$ItemGroupsTableAnnotationComposer,
          $$ItemGroupsTableCreateCompanionBuilder,
          $$ItemGroupsTableUpdateCompanionBuilder,
          (ItemGroup, $$ItemGroupsTableReferences),
          ItemGroup,
          PrefetchHooks Function({
            bool tripId,
            bool itineraryItemsRefs,
            bool costsRefs,
            bool attachmentsRefs,
          })
        > {
  $$ItemGroupsTableTableManager(_$AppDatabase db, $ItemGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tripId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
              }) => ItemGroupsCompanion(
                id: id,
                tripId: tripId,
                label: label,
                collapsed: collapsed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tripId,
                Value<String?> label = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
              }) => ItemGroupsCompanion.insert(
                id: id,
                tripId: tripId,
                label: label,
                collapsed: collapsed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tripId = false,
                itineraryItemsRefs = false,
                costsRefs = false,
                attachmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itineraryItemsRefs) db.itineraryItems,
                    if (costsRefs) db.costs,
                    if (attachmentsRefs) db.attachments,
                  ],
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
                                    referencedTable: $$ItemGroupsTableReferences
                                        ._tripIdTable(db),
                                    referencedColumn:
                                        $$ItemGroupsTableReferences
                                            ._tripIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itineraryItemsRefs)
                        await $_getPrefetchedData<
                          ItemGroup,
                          $ItemGroupsTable,
                          ItineraryItem
                        >(
                          currentTable: table,
                          referencedTable: $$ItemGroupsTableReferences
                              ._itineraryItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).itineraryItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (costsRefs)
                        await $_getPrefetchedData<
                          ItemGroup,
                          $ItemGroupsTable,
                          Cost
                        >(
                          currentTable: table,
                          referencedTable: $$ItemGroupsTableReferences
                              ._costsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).costsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          ItemGroup,
                          $ItemGroupsTable,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $$ItemGroupsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
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

typedef $$ItemGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemGroupsTable,
      ItemGroup,
      $$ItemGroupsTableFilterComposer,
      $$ItemGroupsTableOrderingComposer,
      $$ItemGroupsTableAnnotationComposer,
      $$ItemGroupsTableCreateCompanionBuilder,
      $$ItemGroupsTableUpdateCompanionBuilder,
      (ItemGroup, $$ItemGroupsTableReferences),
      ItemGroup,
      PrefetchHooks Function({
        bool tripId,
        bool itineraryItemsRefs,
        bool costsRefs,
        bool attachmentsRefs,
      })
    >;
typedef $$AlternativeSetsTableCreateCompanionBuilder =
    AlternativeSetsCompanion Function({
      Value<int> id,
      required int tripId,
      required DateTime date,
      Value<int> sortOrder,
      Value<String?> label,
    });
typedef $$AlternativeSetsTableUpdateCompanionBuilder =
    AlternativeSetsCompanion Function({
      Value<int> id,
      Value<int> tripId,
      Value<DateTime> date,
      Value<int> sortOrder,
      Value<String?> label,
    });

final class $$AlternativeSetsTableReferences
    extends
        BaseReferences<_$AppDatabase, $AlternativeSetsTable, AlternativeSet> {
  $$AlternativeSetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('alternative_sets__trip_id__trips__id');

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

  static MultiTypedResultKey<$AlternativesTable, List<Alternative>>
  _alternativesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.alternatives,
    aliasName: 'alternative_sets__id__alternatives__set_id',
  );

  $$AlternativesTableProcessedTableManager get alternativesRefs {
    final manager = $$AlternativesTableTableManager(
      $_db,
      $_db.alternatives,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_alternativesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlternativeSetsTableFilterComposer
    extends Composer<_$AppDatabase, $AlternativeSetsTable> {
  $$AlternativeSetsTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
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

  Expression<bool> alternativesRefs(
    Expression<bool> Function($$AlternativesTableFilterComposer f) f,
  ) {
    final $$AlternativesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alternatives,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativesTableFilterComposer(
            $db: $db,
            $table: $db.alternatives,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlternativeSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlternativeSetsTable> {
  $$AlternativeSetsTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
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

class $$AlternativeSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlternativeSetsTable> {
  $$AlternativeSetsTableAnnotationComposer({
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

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

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

  Expression<T> alternativesRefs<T extends Object>(
    Expression<T> Function($$AlternativesTableAnnotationComposer a) f,
  ) {
    final $$AlternativesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alternatives,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativesTableAnnotationComposer(
            $db: $db,
            $table: $db.alternatives,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlternativeSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlternativeSetsTable,
          AlternativeSet,
          $$AlternativeSetsTableFilterComposer,
          $$AlternativeSetsTableOrderingComposer,
          $$AlternativeSetsTableAnnotationComposer,
          $$AlternativeSetsTableCreateCompanionBuilder,
          $$AlternativeSetsTableUpdateCompanionBuilder,
          (AlternativeSet, $$AlternativeSetsTableReferences),
          AlternativeSet,
          PrefetchHooks Function({bool tripId, bool alternativesRefs})
        > {
  $$AlternativeSetsTableTableManager(
    _$AppDatabase db,
    $AlternativeSetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlternativeSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlternativeSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlternativeSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tripId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> label = const Value.absent(),
              }) => AlternativeSetsCompanion(
                id: id,
                tripId: tripId,
                date: date,
                sortOrder: sortOrder,
                label: label,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tripId,
                required DateTime date,
                Value<int> sortOrder = const Value.absent(),
                Value<String?> label = const Value.absent(),
              }) => AlternativeSetsCompanion.insert(
                id: id,
                tripId: tripId,
                date: date,
                sortOrder: sortOrder,
                label: label,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AlternativeSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false, alternativesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (alternativesRefs) db.alternatives],
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
                                referencedTable:
                                    $$AlternativeSetsTableReferences
                                        ._tripIdTable(db),
                                referencedColumn:
                                    $$AlternativeSetsTableReferences
                                        ._tripIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (alternativesRefs)
                    await $_getPrefetchedData<
                      AlternativeSet,
                      $AlternativeSetsTable,
                      Alternative
                    >(
                      currentTable: table,
                      referencedTable: $$AlternativeSetsTableReferences
                          ._alternativesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AlternativeSetsTableReferences(
                            db,
                            table,
                            p0,
                          ).alternativesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.setId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AlternativeSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlternativeSetsTable,
      AlternativeSet,
      $$AlternativeSetsTableFilterComposer,
      $$AlternativeSetsTableOrderingComposer,
      $$AlternativeSetsTableAnnotationComposer,
      $$AlternativeSetsTableCreateCompanionBuilder,
      $$AlternativeSetsTableUpdateCompanionBuilder,
      (AlternativeSet, $$AlternativeSetsTableReferences),
      AlternativeSet,
      PrefetchHooks Function({bool tripId, bool alternativesRefs})
    >;
typedef $$AlternativesTableCreateCompanionBuilder =
    AlternativesCompanion Function({
      Value<int> id,
      required int setId,
      Value<String?> label,
      Value<int> sortOrder,
      Value<bool> chosen,
    });
typedef $$AlternativesTableUpdateCompanionBuilder =
    AlternativesCompanion Function({
      Value<int> id,
      Value<int> setId,
      Value<String?> label,
      Value<int> sortOrder,
      Value<bool> chosen,
    });

final class $$AlternativesTableReferences
    extends BaseReferences<_$AppDatabase, $AlternativesTable, Alternative> {
  $$AlternativesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AlternativeSetsTable _setIdTable(_$AppDatabase db) => db
      .alternativeSets
      .createAlias('alternatives__set_id__alternative_sets__id');

  $$AlternativeSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<int>('set_id')!;

    final manager = $$AlternativeSetsTableTableManager(
      $_db,
      $_db.alternativeSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItineraryItemsTable, List<ItineraryItem>>
  _itineraryItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itineraryItems,
    aliasName: 'alternatives__id__itinerary_items__alternative_id',
  );

  $$ItineraryItemsTableProcessedTableManager get itineraryItemsRefs {
    final manager = $$ItineraryItemsTableTableManager(
      $_db,
      $_db.itineraryItems,
    ).filter((f) => f.alternativeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_itineraryItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlternativesTableFilterComposer
    extends Composer<_$AppDatabase, $AlternativesTable> {
  $$AlternativesTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get chosen => $composableBuilder(
    column: $table.chosen,
    builder: (column) => ColumnFilters(column),
  );

  $$AlternativeSetsTableFilterComposer get setId {
    final $$AlternativeSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.alternativeSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativeSetsTableFilterComposer(
            $db: $db,
            $table: $db.alternativeSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> itineraryItemsRefs(
    Expression<bool> Function($$ItineraryItemsTableFilterComposer f) f,
  ) {
    final $$ItineraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.alternativeId,
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
}

class $$AlternativesTableOrderingComposer
    extends Composer<_$AppDatabase, $AlternativesTable> {
  $$AlternativesTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get chosen => $composableBuilder(
    column: $table.chosen,
    builder: (column) => ColumnOrderings(column),
  );

  $$AlternativeSetsTableOrderingComposer get setId {
    final $$AlternativeSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.alternativeSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativeSetsTableOrderingComposer(
            $db: $db,
            $table: $db.alternativeSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlternativesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlternativesTable> {
  $$AlternativesTableAnnotationComposer({
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get chosen =>
      $composableBuilder(column: $table.chosen, builder: (column) => column);

  $$AlternativeSetsTableAnnotationComposer get setId {
    final $$AlternativeSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.alternativeSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativeSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.alternativeSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> itineraryItemsRefs<T extends Object>(
    Expression<T> Function($$ItineraryItemsTableAnnotationComposer a) f,
  ) {
    final $$ItineraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.alternativeId,
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
}

class $$AlternativesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlternativesTable,
          Alternative,
          $$AlternativesTableFilterComposer,
          $$AlternativesTableOrderingComposer,
          $$AlternativesTableAnnotationComposer,
          $$AlternativesTableCreateCompanionBuilder,
          $$AlternativesTableUpdateCompanionBuilder,
          (Alternative, $$AlternativesTableReferences),
          Alternative,
          PrefetchHooks Function({bool setId, bool itineraryItemsRefs})
        > {
  $$AlternativesTableTableManager(_$AppDatabase db, $AlternativesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlternativesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlternativesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlternativesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> setId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> chosen = const Value.absent(),
              }) => AlternativesCompanion(
                id: id,
                setId: setId,
                label: label,
                sortOrder: sortOrder,
                chosen: chosen,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int setId,
                Value<String?> label = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> chosen = const Value.absent(),
              }) => AlternativesCompanion.insert(
                id: id,
                setId: setId,
                label: label,
                sortOrder: sortOrder,
                chosen: chosen,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AlternativesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false, itineraryItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (itineraryItemsRefs) db.itineraryItems,
              ],
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
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$AlternativesTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$AlternativesTableReferences
                                    ._setIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itineraryItemsRefs)
                    await $_getPrefetchedData<
                      Alternative,
                      $AlternativesTable,
                      ItineraryItem
                    >(
                      currentTable: table,
                      referencedTable: $$AlternativesTableReferences
                          ._itineraryItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AlternativesTableReferences(
                            db,
                            table,
                            p0,
                          ).itineraryItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.alternativeId == item.id,
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

typedef $$AlternativesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlternativesTable,
      Alternative,
      $$AlternativesTableFilterComposer,
      $$AlternativesTableOrderingComposer,
      $$AlternativesTableAnnotationComposer,
      $$AlternativesTableCreateCompanionBuilder,
      $$AlternativesTableUpdateCompanionBuilder,
      (Alternative, $$AlternativesTableReferences),
      Alternative,
      PrefetchHooks Function({bool setId, bool itineraryItemsRefs})
    >;
typedef $$TransportModesTableCreateCompanionBuilder =
    TransportModesCompanion Function({
      Value<int> id,
      Value<String?> builtinKey,
      Value<String?> name,
      Value<int?> iconId,
      Value<int> sortOrder,
    });
typedef $$TransportModesTableUpdateCompanionBuilder =
    TransportModesCompanion Function({
      Value<int> id,
      Value<String?> builtinKey,
      Value<String?> name,
      Value<int?> iconId,
      Value<int> sortOrder,
    });

final class $$TransportModesTableReferences
    extends
        BaseReferences<_$AppDatabase, $TransportModesTable, TransportModeRow> {
  $$TransportModesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ItineraryItemsTable, List<ItineraryItem>>
  _itineraryItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itineraryItems,
    aliasName: 'transport_modes__id__itinerary_items__mode',
  );

  $$ItineraryItemsTableProcessedTableManager get itineraryItemsRefs {
    final manager = $$ItineraryItemsTableTableManager(
      $_db,
      $_db.itineraryItems,
    ).filter((f) => f.mode.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_itineraryItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransportModesTableFilterComposer
    extends Composer<_$AppDatabase, $TransportModesTable> {
  $$TransportModesTableFilterComposer({
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

  ColumnFilters<String> get builtinKey => $composableBuilder(
    column: $table.builtinKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconId => $composableBuilder(
    column: $table.iconId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itineraryItemsRefs(
    Expression<bool> Function($$ItineraryItemsTableFilterComposer f) f,
  ) {
    final $$ItineraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.mode,
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
}

class $$TransportModesTableOrderingComposer
    extends Composer<_$AppDatabase, $TransportModesTable> {
  $$TransportModesTableOrderingComposer({
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

  ColumnOrderings<String> get builtinKey => $composableBuilder(
    column: $table.builtinKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconId => $composableBuilder(
    column: $table.iconId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransportModesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransportModesTable> {
  $$TransportModesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get builtinKey => $composableBuilder(
    column: $table.builtinKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get iconId =>
      $composableBuilder(column: $table.iconId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> itineraryItemsRefs<T extends Object>(
    Expression<T> Function($$ItineraryItemsTableAnnotationComposer a) f,
  ) {
    final $$ItineraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itineraryItems,
      getReferencedColumn: (t) => t.mode,
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
}

class $$TransportModesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransportModesTable,
          TransportModeRow,
          $$TransportModesTableFilterComposer,
          $$TransportModesTableOrderingComposer,
          $$TransportModesTableAnnotationComposer,
          $$TransportModesTableCreateCompanionBuilder,
          $$TransportModesTableUpdateCompanionBuilder,
          (TransportModeRow, $$TransportModesTableReferences),
          TransportModeRow,
          PrefetchHooks Function({bool itineraryItemsRefs})
        > {
  $$TransportModesTableTableManager(
    _$AppDatabase db,
    $TransportModesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransportModesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransportModesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransportModesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> builtinKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int?> iconId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => TransportModesCompanion(
                id: id,
                builtinKey: builtinKey,
                name: name,
                iconId: iconId,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> builtinKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int?> iconId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => TransportModesCompanion.insert(
                id: id,
                builtinKey: builtinKey,
                name: name,
                iconId: iconId,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransportModesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itineraryItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (itineraryItemsRefs) db.itineraryItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itineraryItemsRefs)
                    await $_getPrefetchedData<
                      TransportModeRow,
                      $TransportModesTable,
                      ItineraryItem
                    >(
                      currentTable: table,
                      referencedTable: $$TransportModesTableReferences
                          ._itineraryItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TransportModesTableReferences(
                            db,
                            table,
                            p0,
                          ).itineraryItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mode == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TransportModesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransportModesTable,
      TransportModeRow,
      $$TransportModesTableFilterComposer,
      $$TransportModesTableOrderingComposer,
      $$TransportModesTableAnnotationComposer,
      $$TransportModesTableCreateCompanionBuilder,
      $$TransportModesTableUpdateCompanionBuilder,
      (TransportModeRow, $$TransportModesTableReferences),
      TransportModeRow,
      PrefetchHooks Function({bool itineraryItemsRefs})
    >;
typedef $$ItineraryItemsTableCreateCompanionBuilder =
    ItineraryItemsCompanion Function({
      Value<int> id,
      required int tripId,
      Value<int?> groupId,
      Value<int?> alternativeId,
      required DateTime date,
      Value<int> sortOrder,
      required ItemKind kind,
      Value<String?> title,
      Value<int?> startMinutes,
      Value<int?> endMinutes,
      Value<int?> actualStartMinutes,
      Value<int?> actualEndMinutes,
      Value<bool> spansNextDay,
      Value<String?> notes,
      Value<int?> colorValue,
      Value<String?> location,
      Value<double?> lat,
      Value<double?> lon,
      Value<int?> mode,
      Value<String?> fromLocation,
      Value<String?> toLocation,
      Value<double?> fromLat,
      Value<double?> fromLon,
      Value<double?> toLat,
      Value<double?> toLon,
      Value<String?> sourceTripId,
      Value<String?> fromPlaceId,
      Value<String?> toPlaceId,
      Value<String?> stopovers,
    });
typedef $$ItineraryItemsTableUpdateCompanionBuilder =
    ItineraryItemsCompanion Function({
      Value<int> id,
      Value<int> tripId,
      Value<int?> groupId,
      Value<int?> alternativeId,
      Value<DateTime> date,
      Value<int> sortOrder,
      Value<ItemKind> kind,
      Value<String?> title,
      Value<int?> startMinutes,
      Value<int?> endMinutes,
      Value<int?> actualStartMinutes,
      Value<int?> actualEndMinutes,
      Value<bool> spansNextDay,
      Value<String?> notes,
      Value<int?> colorValue,
      Value<String?> location,
      Value<double?> lat,
      Value<double?> lon,
      Value<int?> mode,
      Value<String?> fromLocation,
      Value<String?> toLocation,
      Value<double?> fromLat,
      Value<double?> fromLon,
      Value<double?> toLat,
      Value<double?> toLon,
      Value<String?> sourceTripId,
      Value<String?> fromPlaceId,
      Value<String?> toPlaceId,
      Value<String?> stopovers,
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

  static $ItemGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.itemGroups.createAlias('itinerary_items__group_id__item_groups__id');

  $$ItemGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<int>('group_id');
    if ($_column == null) return null;
    final manager = $$ItemGroupsTableTableManager(
      $_db,
      $_db.itemGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AlternativesTable _alternativeIdTable(_$AppDatabase db) => db
      .alternatives
      .createAlias('itinerary_items__alternative_id__alternatives__id');

  $$AlternativesTableProcessedTableManager? get alternativeId {
    final $_column = $_itemColumn<int>('alternative_id');
    if ($_column == null) return null;
    final manager = $$AlternativesTableTableManager(
      $_db,
      $_db.alternatives,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_alternativeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransportModesTable _modeTable(_$AppDatabase db) => db.transportModes
      .createAlias('itinerary_items__mode__transport_modes__id');

  $$TransportModesTableProcessedTableManager? get mode {
    final $_column = $_itemColumn<int>('mode');
    if ($_column == null) return null;
    final manager = $$TransportModesTableTableManager(
      $_db,
      $_db.transportModes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modeTable($_db));
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

  static MultiTypedResultKey<$TracksTable, List<Track>> _tracksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tracks,
    aliasName: 'itinerary_items__id__tracks__item_id',
  );

  $$TracksTableProcessedTableManager get tracksRefs {
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'itinerary_items__id__attachments__item_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
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

  ColumnFilters<int> get actualStartMinutes => $composableBuilder(
    column: $table.actualStartMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualEndMinutes => $composableBuilder(
    column: $table.actualEndMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get spansNextDay => $composableBuilder(
    column: $table.spansNextDay,
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

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromLocation => $composableBuilder(
    column: $table.fromLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toLocation => $composableBuilder(
    column: $table.toLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fromLat => $composableBuilder(
    column: $table.fromLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fromLon => $composableBuilder(
    column: $table.fromLon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toLat => $composableBuilder(
    column: $table.toLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toLon => $composableBuilder(
    column: $table.toLon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTripId => $composableBuilder(
    column: $table.sourceTripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromPlaceId => $composableBuilder(
    column: $table.fromPlaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toPlaceId => $composableBuilder(
    column: $table.toPlaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stopovers => $composableBuilder(
    column: $table.stopovers,
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

  $$ItemGroupsTableFilterComposer get groupId {
    final $$ItemGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableFilterComposer(
            $db: $db,
            $table: $db.itemGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlternativesTableFilterComposer get alternativeId {
    final $$AlternativesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alternativeId,
      referencedTable: $db.alternatives,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativesTableFilterComposer(
            $db: $db,
            $table: $db.alternatives,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransportModesTableFilterComposer get mode {
    final $$TransportModesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mode,
      referencedTable: $db.transportModes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransportModesTableFilterComposer(
            $db: $db,
            $table: $db.transportModes,
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

  Expression<bool> tracksRefs(
    Expression<bool> Function($$TracksTableFilterComposer f) f,
  ) {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
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

  ColumnOrderings<int> get actualStartMinutes => $composableBuilder(
    column: $table.actualStartMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualEndMinutes => $composableBuilder(
    column: $table.actualEndMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get spansNextDay => $composableBuilder(
    column: $table.spansNextDay,
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

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
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

  ColumnOrderings<double> get fromLat => $composableBuilder(
    column: $table.fromLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fromLon => $composableBuilder(
    column: $table.fromLon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toLat => $composableBuilder(
    column: $table.toLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toLon => $composableBuilder(
    column: $table.toLon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTripId => $composableBuilder(
    column: $table.sourceTripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromPlaceId => $composableBuilder(
    column: $table.fromPlaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toPlaceId => $composableBuilder(
    column: $table.toPlaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stopovers => $composableBuilder(
    column: $table.stopovers,
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

  $$ItemGroupsTableOrderingComposer get groupId {
    final $$ItemGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.itemGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlternativesTableOrderingComposer get alternativeId {
    final $$AlternativesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alternativeId,
      referencedTable: $db.alternatives,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativesTableOrderingComposer(
            $db: $db,
            $table: $db.alternatives,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransportModesTableOrderingComposer get mode {
    final $$TransportModesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mode,
      referencedTable: $db.transportModes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransportModesTableOrderingComposer(
            $db: $db,
            $table: $db.transportModes,
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

  GeneratedColumn<int> get actualStartMinutes => $composableBuilder(
    column: $table.actualStartMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualEndMinutes => $composableBuilder(
    column: $table.actualEndMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get spansNextDay => $composableBuilder(
    column: $table.spansNextDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<String> get fromLocation => $composableBuilder(
    column: $table.fromLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toLocation => $composableBuilder(
    column: $table.toLocation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fromLat =>
      $composableBuilder(column: $table.fromLat, builder: (column) => column);

  GeneratedColumn<double> get fromLon =>
      $composableBuilder(column: $table.fromLon, builder: (column) => column);

  GeneratedColumn<double> get toLat =>
      $composableBuilder(column: $table.toLat, builder: (column) => column);

  GeneratedColumn<double> get toLon =>
      $composableBuilder(column: $table.toLon, builder: (column) => column);

  GeneratedColumn<String> get sourceTripId => $composableBuilder(
    column: $table.sourceTripId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromPlaceId => $composableBuilder(
    column: $table.fromPlaceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toPlaceId =>
      $composableBuilder(column: $table.toPlaceId, builder: (column) => column);

  GeneratedColumn<String> get stopovers =>
      $composableBuilder(column: $table.stopovers, builder: (column) => column);

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

  $$ItemGroupsTableAnnotationComposer get groupId {
    final $$ItemGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AlternativesTableAnnotationComposer get alternativeId {
    final $$AlternativesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alternativeId,
      referencedTable: $db.alternatives,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlternativesTableAnnotationComposer(
            $db: $db,
            $table: $db.alternatives,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransportModesTableAnnotationComposer get mode {
    final $$TransportModesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mode,
      referencedTable: $db.transportModes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransportModesTableAnnotationComposer(
            $db: $db,
            $table: $db.transportModes,
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

  Expression<T> tracksRefs<T extends Object>(
    Expression<T> Function($$TracksTableAnnotationComposer a) f,
  ) {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
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
          PrefetchHooks Function({
            bool tripId,
            bool groupId,
            bool alternativeId,
            bool mode,
            bool costsRefs,
            bool tracksRefs,
            bool attachmentsRefs,
          })
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
                Value<int?> groupId = const Value.absent(),
                Value<int?> alternativeId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<ItemKind> kind = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> startMinutes = const Value.absent(),
                Value<int?> endMinutes = const Value.absent(),
                Value<int?> actualStartMinutes = const Value.absent(),
                Value<int?> actualEndMinutes = const Value.absent(),
                Value<bool> spansNextDay = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> colorValue = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<int?> mode = const Value.absent(),
                Value<String?> fromLocation = const Value.absent(),
                Value<String?> toLocation = const Value.absent(),
                Value<double?> fromLat = const Value.absent(),
                Value<double?> fromLon = const Value.absent(),
                Value<double?> toLat = const Value.absent(),
                Value<double?> toLon = const Value.absent(),
                Value<String?> sourceTripId = const Value.absent(),
                Value<String?> fromPlaceId = const Value.absent(),
                Value<String?> toPlaceId = const Value.absent(),
                Value<String?> stopovers = const Value.absent(),
              }) => ItineraryItemsCompanion(
                id: id,
                tripId: tripId,
                groupId: groupId,
                alternativeId: alternativeId,
                date: date,
                sortOrder: sortOrder,
                kind: kind,
                title: title,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                actualStartMinutes: actualStartMinutes,
                actualEndMinutes: actualEndMinutes,
                spansNextDay: spansNextDay,
                notes: notes,
                colorValue: colorValue,
                location: location,
                lat: lat,
                lon: lon,
                mode: mode,
                fromLocation: fromLocation,
                toLocation: toLocation,
                fromLat: fromLat,
                fromLon: fromLon,
                toLat: toLat,
                toLon: toLon,
                sourceTripId: sourceTripId,
                fromPlaceId: fromPlaceId,
                toPlaceId: toPlaceId,
                stopovers: stopovers,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tripId,
                Value<int?> groupId = const Value.absent(),
                Value<int?> alternativeId = const Value.absent(),
                required DateTime date,
                Value<int> sortOrder = const Value.absent(),
                required ItemKind kind,
                Value<String?> title = const Value.absent(),
                Value<int?> startMinutes = const Value.absent(),
                Value<int?> endMinutes = const Value.absent(),
                Value<int?> actualStartMinutes = const Value.absent(),
                Value<int?> actualEndMinutes = const Value.absent(),
                Value<bool> spansNextDay = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> colorValue = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<int?> mode = const Value.absent(),
                Value<String?> fromLocation = const Value.absent(),
                Value<String?> toLocation = const Value.absent(),
                Value<double?> fromLat = const Value.absent(),
                Value<double?> fromLon = const Value.absent(),
                Value<double?> toLat = const Value.absent(),
                Value<double?> toLon = const Value.absent(),
                Value<String?> sourceTripId = const Value.absent(),
                Value<String?> fromPlaceId = const Value.absent(),
                Value<String?> toPlaceId = const Value.absent(),
                Value<String?> stopovers = const Value.absent(),
              }) => ItineraryItemsCompanion.insert(
                id: id,
                tripId: tripId,
                groupId: groupId,
                alternativeId: alternativeId,
                date: date,
                sortOrder: sortOrder,
                kind: kind,
                title: title,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                actualStartMinutes: actualStartMinutes,
                actualEndMinutes: actualEndMinutes,
                spansNextDay: spansNextDay,
                notes: notes,
                colorValue: colorValue,
                location: location,
                lat: lat,
                lon: lon,
                mode: mode,
                fromLocation: fromLocation,
                toLocation: toLocation,
                fromLat: fromLat,
                fromLon: fromLon,
                toLat: toLat,
                toLon: toLon,
                sourceTripId: sourceTripId,
                fromPlaceId: fromPlaceId,
                toPlaceId: toPlaceId,
                stopovers: stopovers,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItineraryItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tripId = false,
                groupId = false,
                alternativeId = false,
                mode = false,
                costsRefs = false,
                tracksRefs = false,
                attachmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (costsRefs) db.costs,
                    if (tracksRefs) db.tracks,
                    if (attachmentsRefs) db.attachments,
                  ],
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
                                    referencedTable:
                                        $$ItineraryItemsTableReferences
                                            ._tripIdTable(db),
                                    referencedColumn:
                                        $$ItineraryItemsTableReferences
                                            ._tripIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable:
                                        $$ItineraryItemsTableReferences
                                            ._groupIdTable(db),
                                    referencedColumn:
                                        $$ItineraryItemsTableReferences
                                            ._groupIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (alternativeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.alternativeId,
                                    referencedTable:
                                        $$ItineraryItemsTableReferences
                                            ._alternativeIdTable(db),
                                    referencedColumn:
                                        $$ItineraryItemsTableReferences
                                            ._alternativeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (mode) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.mode,
                                    referencedTable:
                                        $$ItineraryItemsTableReferences
                                            ._modeTable(db),
                                    referencedColumn:
                                        $$ItineraryItemsTableReferences
                                            ._modeTable(db)
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
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tracksRefs)
                        await $_getPrefetchedData<
                          ItineraryItem,
                          $ItineraryItemsTable,
                          Track
                        >(
                          currentTable: table,
                          referencedTable: $$ItineraryItemsTableReferences
                              ._tracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItineraryItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).tracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          ItineraryItem,
                          $ItineraryItemsTable,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $$ItineraryItemsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItineraryItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
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
      PrefetchHooks Function({
        bool tripId,
        bool groupId,
        bool alternativeId,
        bool mode,
        bool costsRefs,
        bool tracksRefs,
        bool attachmentsRefs,
      })
    >;
typedef $$CurrenciesTableCreateCompanionBuilder =
    CurrenciesCompanion Function({
      Value<int> id,
      required String code,
      required String symbol,
      Value<int?> rateMicros,
      Value<bool> isBase,
      Value<int> sortOrder,
    });
typedef $$CurrenciesTableUpdateCompanionBuilder =
    CurrenciesCompanion Function({
      Value<int> id,
      Value<String> code,
      Value<String> symbol,
      Value<int?> rateMicros,
      Value<bool> isBase,
      Value<int> sortOrder,
    });

final class $$CurrenciesTableReferences
    extends BaseReferences<_$AppDatabase, $CurrenciesTable, CurrencyRow> {
  $$CurrenciesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CostsTable, List<Cost>> _costsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.costs,
    aliasName: 'currencies__id__costs__currency',
  );

  $$CostsTableProcessedTableManager get costsRefs {
    final manager = $$CostsTableTableManager(
      $_db,
      $_db.costs,
    ).filter((f) => f.currency.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_costsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CurrenciesTableFilterComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateMicros => $composableBuilder(
    column: $table.rateMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBase => $composableBuilder(
    column: $table.isBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> costsRefs(
    Expression<bool> Function($$CostsTableFilterComposer f) f,
  ) {
    final $$CostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.currency,
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

class $$CurrenciesTableOrderingComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateMicros => $composableBuilder(
    column: $table.rateMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBase => $composableBuilder(
    column: $table.isBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurrenciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<int> get rateMicros => $composableBuilder(
    column: $table.rateMicros,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBase =>
      $composableBuilder(column: $table.isBase, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> costsRefs<T extends Object>(
    Expression<T> Function($$CostsTableAnnotationComposer a) f,
  ) {
    final $$CostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.currency,
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

class $$CurrenciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CurrenciesTable,
          CurrencyRow,
          $$CurrenciesTableFilterComposer,
          $$CurrenciesTableOrderingComposer,
          $$CurrenciesTableAnnotationComposer,
          $$CurrenciesTableCreateCompanionBuilder,
          $$CurrenciesTableUpdateCompanionBuilder,
          (CurrencyRow, $$CurrenciesTableReferences),
          CurrencyRow,
          PrefetchHooks Function({bool costsRefs})
        > {
  $$CurrenciesTableTableManager(_$AppDatabase db, $CurrenciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurrenciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurrenciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurrenciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<int?> rateMicros = const Value.absent(),
                Value<bool> isBase = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => CurrenciesCompanion(
                id: id,
                code: code,
                symbol: symbol,
                rateMicros: rateMicros,
                isBase: isBase,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String code,
                required String symbol,
                Value<int?> rateMicros = const Value.absent(),
                Value<bool> isBase = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => CurrenciesCompanion.insert(
                id: id,
                code: code,
                symbol: symbol,
                rateMicros: rateMicros,
                isBase: isBase,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CurrenciesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({costsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (costsRefs) db.costs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (costsRefs)
                    await $_getPrefetchedData<
                      CurrencyRow,
                      $CurrenciesTable,
                      Cost
                    >(
                      currentTable: table,
                      referencedTable: $$CurrenciesTableReferences
                          ._costsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CurrenciesTableReferences(db, table, p0).costsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.currency == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CurrenciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CurrenciesTable,
      CurrencyRow,
      $$CurrenciesTableFilterComposer,
      $$CurrenciesTableOrderingComposer,
      $$CurrenciesTableAnnotationComposer,
      $$CurrenciesTableCreateCompanionBuilder,
      $$CurrenciesTableUpdateCompanionBuilder,
      (CurrencyRow, $$CurrenciesTableReferences),
      CurrencyRow,
      PrefetchHooks Function({bool costsRefs})
    >;
typedef $$CostsTableCreateCompanionBuilder =
    CostsCompanion Function({
      Value<int> id,
      Value<int?> itemId,
      Value<int?> groupId,
      Value<int?> tripId,
      required int amountMinor,
      required int currency,
      required String reason,
      Value<String?> paidBy,
      Value<bool> paid,
      Value<bool> isTransfer,
      Value<DateTime> createdAt,
    });
typedef $$CostsTableUpdateCompanionBuilder =
    CostsCompanion Function({
      Value<int> id,
      Value<int?> itemId,
      Value<int?> groupId,
      Value<int?> tripId,
      Value<int> amountMinor,
      Value<int> currency,
      Value<String> reason,
      Value<String?> paidBy,
      Value<bool> paid,
      Value<bool> isTransfer,
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

  static $ItemGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.itemGroups.createAlias('costs__group_id__item_groups__id');

  $$ItemGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<int>('group_id');
    if ($_column == null) return null;
    final manager = $$ItemGroupsTableTableManager(
      $_db,
      $_db.itemGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
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

  static $CurrenciesTable _currencyTable(_$AppDatabase db) =>
      db.currencies.createAlias('costs__currency__currencies__id');

  $$CurrenciesTableProcessedTableManager get currency {
    final $_column = $_itemColumn<int>('currency')!;

    final manager = $$CurrenciesTableTableManager(
      $_db,
      $_db.currencies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currencyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CostBeneficiariesTable, List<CostBeneficiary>>
  _costBeneficiariesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.costBeneficiaries,
        aliasName: 'costs__id__cost_beneficiaries__cost_id',
      );

  $$CostBeneficiariesTableProcessedTableManager get costBeneficiariesRefs {
    final manager = $$CostBeneficiariesTableTableManager(
      $_db,
      $_db.costBeneficiaries,
    ).filter((f) => f.costId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _costBeneficiariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidBy => $composableBuilder(
    column: $table.paidBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTransfer => $composableBuilder(
    column: $table.isTransfer,
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

  $$ItemGroupsTableFilterComposer get groupId {
    final $$ItemGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableFilterComposer(
            $db: $db,
            $table: $db.itemGroups,
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

  $$CurrenciesTableFilterComposer get currency {
    final $$CurrenciesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currency,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurrenciesTableFilterComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> costBeneficiariesRefs(
    Expression<bool> Function($$CostBeneficiariesTableFilterComposer f) f,
  ) {
    final $$CostBeneficiariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.costBeneficiaries,
      getReferencedColumn: (t) => t.costId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CostBeneficiariesTableFilterComposer(
            $db: $db,
            $table: $db.costBeneficiaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidBy => $composableBuilder(
    column: $table.paidBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTransfer => $composableBuilder(
    column: $table.isTransfer,
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

  $$ItemGroupsTableOrderingComposer get groupId {
    final $$ItemGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.itemGroups,
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

  $$CurrenciesTableOrderingComposer get currency {
    final $$CurrenciesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currency,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurrenciesTableOrderingComposer(
            $db: $db,
            $table: $db.currencies,
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

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get paidBy =>
      $composableBuilder(column: $table.paidBy, builder: (column) => column);

  GeneratedColumn<bool> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<bool> get isTransfer => $composableBuilder(
    column: $table.isTransfer,
    builder: (column) => column,
  );

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

  $$ItemGroupsTableAnnotationComposer get groupId {
    final $$ItemGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemGroups,
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

  $$CurrenciesTableAnnotationComposer get currency {
    final $$CurrenciesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currency,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurrenciesTableAnnotationComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> costBeneficiariesRefs<T extends Object>(
    Expression<T> Function($$CostBeneficiariesTableAnnotationComposer a) f,
  ) {
    final $$CostBeneficiariesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.costBeneficiaries,
          getReferencedColumn: (t) => t.costId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CostBeneficiariesTableAnnotationComposer(
                $db: $db,
                $table: $db.costBeneficiaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
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
          PrefetchHooks Function({
            bool itemId,
            bool groupId,
            bool tripId,
            bool currency,
            bool costBeneficiariesRefs,
          })
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
                Value<int?> groupId = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<int> currency = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String?> paidBy = const Value.absent(),
                Value<bool> paid = const Value.absent(),
                Value<bool> isTransfer = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CostsCompanion(
                id: id,
                itemId: itemId,
                groupId: groupId,
                tripId: tripId,
                amountMinor: amountMinor,
                currency: currency,
                reason: reason,
                paidBy: paidBy,
                paid: paid,
                isTransfer: isTransfer,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> itemId = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                required int amountMinor,
                required int currency,
                required String reason,
                Value<String?> paidBy = const Value.absent(),
                Value<bool> paid = const Value.absent(),
                Value<bool> isTransfer = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CostsCompanion.insert(
                id: id,
                itemId: itemId,
                groupId: groupId,
                tripId: tripId,
                amountMinor: amountMinor,
                currency: currency,
                reason: reason,
                paidBy: paidBy,
                paid: paid,
                isTransfer: isTransfer,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CostsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                itemId = false,
                groupId = false,
                tripId = false,
                currency = false,
                costBeneficiariesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (costBeneficiariesRefs) db.costBeneficiaries,
                  ],
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
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable: $$CostsTableReferences
                                        ._groupIdTable(db),
                                    referencedColumn: $$CostsTableReferences
                                        ._groupIdTable(db)
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
                        if (currency) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.currency,
                                    referencedTable: $$CostsTableReferences
                                        ._currencyTable(db),
                                    referencedColumn: $$CostsTableReferences
                                        ._currencyTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (costBeneficiariesRefs)
                        await $_getPrefetchedData<
                          Cost,
                          $CostsTable,
                          CostBeneficiary
                        >(
                          currentTable: table,
                          referencedTable: $$CostsTableReferences
                              ._costBeneficiariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CostsTableReferences(
                                db,
                                table,
                                p0,
                              ).costBeneficiariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.costId == item.id,
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
      PrefetchHooks Function({
        bool itemId,
        bool groupId,
        bool tripId,
        bool currency,
        bool costBeneficiariesRefs,
      })
    >;
typedef $$CostReasonsTableCreateCompanionBuilder =
    CostReasonsCompanion Function({
      Value<int> id,
      required String label,
      Value<int?> iconId,
    });
typedef $$CostReasonsTableUpdateCompanionBuilder =
    CostReasonsCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<int?> iconId,
    });

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

  ColumnFilters<int> get iconId => $composableBuilder(
    column: $table.iconId,
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

  ColumnOrderings<int> get iconId => $composableBuilder(
    column: $table.iconId,
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

  GeneratedColumn<int> get iconId =>
      $composableBuilder(column: $table.iconId, builder: (column) => column);
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
                Value<int?> iconId = const Value.absent(),
              }) => CostReasonsCompanion(id: id, label: label, iconId: iconId),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String label,
                Value<int?> iconId = const Value.absent(),
              }) => CostReasonsCompanion.insert(
                id: id,
                label: label,
                iconId: iconId,
              ),
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
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> colorValue,
      Value<int> sortOrder,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
      Value<int> sortOrder,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripTagsTable, List<TripTag>> _tripTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tripTags,
    aliasName: 'tags__id__trip_tags__tag_id',
  );

  $$TripTagsTableProcessedTableManager get tripTagsRefs {
    final manager = $$TripTagsTableTableManager(
      $_db,
      $_db.tripTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripTagsRefs(
    Expression<bool> Function($$TripTagsTableFilterComposer f) f,
  ) {
    final $$TripTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripTagsTableFilterComposer(
            $db: $db,
            $table: $db.tripTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> tripTagsRefs<T extends Object>(
    Expression<T> Function($$TripTagsTableAnnotationComposer a) f,
  ) {
    final $$TripTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool tripTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> colorValue = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({tripTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tripTagsRefs) db.tripTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tripTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, TripTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._tripTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).tripTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool tripTagsRefs})
    >;
typedef $$TripTagsTableCreateCompanionBuilder =
    TripTagsCompanion Function({
      required int tripId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$TripTagsTableUpdateCompanionBuilder =
    TripTagsCompanion Function({
      Value<int> tripId,
      Value<int> tagId,
      Value<int> rowid,
    });

final class $$TripTagsTableReferences
    extends BaseReferences<_$AppDatabase, $TripTagsTable, TripTag> {
  $$TripTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_tags__trip_id__trips__id');

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

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('trip_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TripTagsTable> {
  $$TripTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripTagsTable> {
  $$TripTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripTagsTable> {
  $$TripTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripTagsTable,
          TripTag,
          $$TripTagsTableFilterComposer,
          $$TripTagsTableOrderingComposer,
          $$TripTagsTableAnnotationComposer,
          $$TripTagsTableCreateCompanionBuilder,
          $$TripTagsTableUpdateCompanionBuilder,
          (TripTag, $$TripTagsTableReferences),
          TripTag,
          PrefetchHooks Function({bool tripId, bool tagId})
        > {
  $$TripTagsTableTableManager(_$AppDatabase db, $TripTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> tripId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  TripTagsCompanion(tripId: tripId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required int tripId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => TripTagsCompanion.insert(
                tripId: tripId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false, tagId = false}) {
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
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$TripTagsTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$TripTagsTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$TripTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$TripTagsTableReferences
                                    ._tagIdTable(db)
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

typedef $$TripTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripTagsTable,
      TripTag,
      $$TripTagsTableFilterComposer,
      $$TripTagsTableOrderingComposer,
      $$TripTagsTableAnnotationComposer,
      $$TripTagsTableCreateCompanionBuilder,
      $$TripTagsTableUpdateCompanionBuilder,
      (TripTag, $$TripTagsTableReferences),
      TripTag,
      PrefetchHooks Function({bool tripId, bool tagId})
    >;
typedef $$PeopleTableCreateCompanionBuilder =
    PeopleCompanion Function({
      Value<int> id,
      required String name,
      Value<bool> isMe,
    });
typedef $$PeopleTableUpdateCompanionBuilder =
    PeopleCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<bool> isMe,
    });

final class $$PeopleTableReferences
    extends BaseReferences<_$AppDatabase, $PeopleTable, Person> {
  $$PeopleTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripParticipantsTable, List<TripParticipant>>
  _tripParticipantsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripParticipants,
    aliasName: 'people__id__trip_participants__person_id',
  );

  $$TripParticipantsTableProcessedTableManager get tripParticipantsRefs {
    final manager = $$TripParticipantsTableTableManager(
      $_db,
      $_db.tripParticipants,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _tripParticipantsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CostBeneficiariesTable, List<CostBeneficiary>>
  _costBeneficiariesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.costBeneficiaries,
        aliasName: 'people__id__cost_beneficiaries__person_id',
      );

  $$CostBeneficiariesTableProcessedTableManager get costBeneficiariesRefs {
    final manager = $$CostBeneficiariesTableTableManager(
      $_db,
      $_db.costBeneficiaries,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _costBeneficiariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeopleTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripParticipantsRefs(
    Expression<bool> Function($$TripParticipantsTableFilterComposer f) f,
  ) {
    final $$TripParticipantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripParticipants,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripParticipantsTableFilterComposer(
            $db: $db,
            $table: $db.tripParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> costBeneficiariesRefs(
    Expression<bool> Function($$CostBeneficiariesTableFilterComposer f) f,
  ) {
    final $$CostBeneficiariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.costBeneficiaries,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CostBeneficiariesTableFilterComposer(
            $db: $db,
            $table: $db.costBeneficiaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);

  Expression<T> tripParticipantsRefs<T extends Object>(
    Expression<T> Function($$TripParticipantsTableAnnotationComposer a) f,
  ) {
    final $$TripParticipantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripParticipants,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripParticipantsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> costBeneficiariesRefs<T extends Object>(
    Expression<T> Function($$CostBeneficiariesTableAnnotationComposer a) f,
  ) {
    final $$CostBeneficiariesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.costBeneficiaries,
          getReferencedColumn: (t) => t.personId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CostBeneficiariesTableAnnotationComposer(
                $db: $db,
                $table: $db.costBeneficiaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleTable,
          Person,
          $$PeopleTableFilterComposer,
          $$PeopleTableOrderingComposer,
          $$PeopleTableAnnotationComposer,
          $$PeopleTableCreateCompanionBuilder,
          $$PeopleTableUpdateCompanionBuilder,
          (Person, $$PeopleTableReferences),
          Person,
          PrefetchHooks Function({
            bool tripParticipantsRefs,
            bool costBeneficiariesRefs,
          })
        > {
  $$PeopleTableTableManager(_$AppDatabase db, $PeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
              }) => PeopleCompanion(id: id, name: name, isMe: isMe),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> isMe = const Value.absent(),
              }) => PeopleCompanion.insert(id: id, name: name, isMe: isMe),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PeopleTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({tripParticipantsRefs = false, costBeneficiariesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tripParticipantsRefs) db.tripParticipants,
                    if (costBeneficiariesRefs) db.costBeneficiaries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tripParticipantsRefs)
                        await $_getPrefetchedData<
                          Person,
                          $PeopleTable,
                          TripParticipant
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._tripParticipantsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).tripParticipantsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (costBeneficiariesRefs)
                        await $_getPrefetchedData<
                          Person,
                          $PeopleTable,
                          CostBeneficiary
                        >(
                          currentTable: table,
                          referencedTable: $$PeopleTableReferences
                              ._costBeneficiariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).costBeneficiariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
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

typedef $$PeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleTable,
      Person,
      $$PeopleTableFilterComposer,
      $$PeopleTableOrderingComposer,
      $$PeopleTableAnnotationComposer,
      $$PeopleTableCreateCompanionBuilder,
      $$PeopleTableUpdateCompanionBuilder,
      (Person, $$PeopleTableReferences),
      Person,
      PrefetchHooks Function({
        bool tripParticipantsRefs,
        bool costBeneficiariesRefs,
      })
    >;
typedef $$TripParticipantsTableCreateCompanionBuilder =
    TripParticipantsCompanion Function({
      required int tripId,
      required int personId,
      Value<int> rowid,
    });
typedef $$TripParticipantsTableUpdateCompanionBuilder =
    TripParticipantsCompanion Function({
      Value<int> tripId,
      Value<int> personId,
      Value<int> rowid,
    });

final class $$TripParticipantsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TripParticipantsTable, TripParticipant> {
  $$TripParticipantsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_participants__trip_id__trips__id');

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

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('trip_participants__person_id__people__id');

  $$PeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<int>('person_id')!;

    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripParticipantsTableFilterComposer
    extends Composer<_$AppDatabase, $TripParticipantsTable> {
  $$TripParticipantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripParticipantsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripParticipantsTable> {
  $$TripParticipantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripParticipantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripParticipantsTable> {
  $$TripParticipantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
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

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripParticipantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripParticipantsTable,
          TripParticipant,
          $$TripParticipantsTableFilterComposer,
          $$TripParticipantsTableOrderingComposer,
          $$TripParticipantsTableAnnotationComposer,
          $$TripParticipantsTableCreateCompanionBuilder,
          $$TripParticipantsTableUpdateCompanionBuilder,
          (TripParticipant, $$TripParticipantsTableReferences),
          TripParticipant,
          PrefetchHooks Function({bool tripId, bool personId})
        > {
  $$TripParticipantsTableTableManager(
    _$AppDatabase db,
    $TripParticipantsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripParticipantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripParticipantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripParticipantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> tripId = const Value.absent(),
                Value<int> personId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripParticipantsCompanion(
                tripId: tripId,
                personId: personId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int tripId,
                required int personId,
                Value<int> rowid = const Value.absent(),
              }) => TripParticipantsCompanion.insert(
                tripId: tripId,
                personId: personId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripParticipantsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false, personId = false}) {
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
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable:
                                    $$TripParticipantsTableReferences
                                        ._tripIdTable(db),
                                referencedColumn:
                                    $$TripParticipantsTableReferences
                                        ._tripIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (personId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.personId,
                                referencedTable:
                                    $$TripParticipantsTableReferences
                                        ._personIdTable(db),
                                referencedColumn:
                                    $$TripParticipantsTableReferences
                                        ._personIdTable(db)
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

typedef $$TripParticipantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripParticipantsTable,
      TripParticipant,
      $$TripParticipantsTableFilterComposer,
      $$TripParticipantsTableOrderingComposer,
      $$TripParticipantsTableAnnotationComposer,
      $$TripParticipantsTableCreateCompanionBuilder,
      $$TripParticipantsTableUpdateCompanionBuilder,
      (TripParticipant, $$TripParticipantsTableReferences),
      TripParticipant,
      PrefetchHooks Function({bool tripId, bool personId})
    >;
typedef $$CostBeneficiariesTableCreateCompanionBuilder =
    CostBeneficiariesCompanion Function({
      required int costId,
      required int personId,
      Value<int> rowid,
    });
typedef $$CostBeneficiariesTableUpdateCompanionBuilder =
    CostBeneficiariesCompanion Function({
      Value<int> costId,
      Value<int> personId,
      Value<int> rowid,
    });

final class $$CostBeneficiariesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CostBeneficiariesTable,
          CostBeneficiary
        > {
  $$CostBeneficiariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CostsTable _costIdTable(_$AppDatabase db) =>
      db.costs.createAlias('cost_beneficiaries__cost_id__costs__id');

  $$CostsTableProcessedTableManager get costId {
    final $_column = $_itemColumn<int>('cost_id')!;

    final manager = $$CostsTableTableManager(
      $_db,
      $_db.costs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_costIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('cost_beneficiaries__person_id__people__id');

  $$PeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<int>('person_id')!;

    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CostBeneficiariesTableFilterComposer
    extends Composer<_$AppDatabase, $CostBeneficiariesTable> {
  $$CostBeneficiariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CostsTableFilterComposer get costId {
    final $$CostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.costId,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CostBeneficiariesTableOrderingComposer
    extends Composer<_$AppDatabase, $CostBeneficiariesTable> {
  $$CostBeneficiariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CostsTableOrderingComposer get costId {
    final $$CostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.costId,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CostsTableOrderingComposer(
            $db: $db,
            $table: $db.costs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CostBeneficiariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CostBeneficiariesTable> {
  $$CostBeneficiariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CostsTableAnnotationComposer get costId {
    final $$CostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.costId,
      referencedTable: $db.costs,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CostBeneficiariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CostBeneficiariesTable,
          CostBeneficiary,
          $$CostBeneficiariesTableFilterComposer,
          $$CostBeneficiariesTableOrderingComposer,
          $$CostBeneficiariesTableAnnotationComposer,
          $$CostBeneficiariesTableCreateCompanionBuilder,
          $$CostBeneficiariesTableUpdateCompanionBuilder,
          (CostBeneficiary, $$CostBeneficiariesTableReferences),
          CostBeneficiary,
          PrefetchHooks Function({bool costId, bool personId})
        > {
  $$CostBeneficiariesTableTableManager(
    _$AppDatabase db,
    $CostBeneficiariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CostBeneficiariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CostBeneficiariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CostBeneficiariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> costId = const Value.absent(),
                Value<int> personId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CostBeneficiariesCompanion(
                costId: costId,
                personId: personId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int costId,
                required int personId,
                Value<int> rowid = const Value.absent(),
              }) => CostBeneficiariesCompanion.insert(
                costId: costId,
                personId: personId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CostBeneficiariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({costId = false, personId = false}) {
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
                    if (costId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.costId,
                                referencedTable:
                                    $$CostBeneficiariesTableReferences
                                        ._costIdTable(db),
                                referencedColumn:
                                    $$CostBeneficiariesTableReferences
                                        ._costIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (personId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.personId,
                                referencedTable:
                                    $$CostBeneficiariesTableReferences
                                        ._personIdTable(db),
                                referencedColumn:
                                    $$CostBeneficiariesTableReferences
                                        ._personIdTable(db)
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

typedef $$CostBeneficiariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CostBeneficiariesTable,
      CostBeneficiary,
      $$CostBeneficiariesTableFilterComposer,
      $$CostBeneficiariesTableOrderingComposer,
      $$CostBeneficiariesTableAnnotationComposer,
      $$CostBeneficiariesTableCreateCompanionBuilder,
      $$CostBeneficiariesTableUpdateCompanionBuilder,
      (CostBeneficiary, $$CostBeneficiariesTableReferences),
      CostBeneficiary,
      PrefetchHooks Function({bool costId, bool personId})
    >;
typedef $$ChecklistsTableCreateCompanionBuilder =
    ChecklistsCompanion Function({
      Value<int> id,
      required int tripId,
      Value<String> title,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<bool> collapsed,
    });
typedef $$ChecklistsTableUpdateCompanionBuilder =
    ChecklistsCompanion Function({
      Value<int> id,
      Value<int> tripId,
      Value<String> title,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<bool> collapsed,
    });

final class $$ChecklistsTableReferences
    extends BaseReferences<_$AppDatabase, $ChecklistsTable, Checklist> {
  $$ChecklistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('checklists__trip_id__trips__id');

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

  static MultiTypedResultKey<$ChecklistItemsTable, List<ChecklistItem>>
  _checklistItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.checklistItems,
    aliasName: 'checklists__id__checklist_items__checklist_id',
  );

  $$ChecklistItemsTableProcessedTableManager get checklistItemsRefs {
    final manager = $$ChecklistItemsTableTableManager(
      $_db,
      $_db.checklistItems,
    ).filter((f) => f.checklistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_checklistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChecklistsTableFilterComposer
    extends Composer<_$AppDatabase, $ChecklistsTable> {
  $$ChecklistsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
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

  Expression<bool> checklistItemsRefs(
    Expression<bool> Function($$ChecklistItemsTableFilterComposer f) f,
  ) {
    final $$ChecklistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklistItems,
      getReferencedColumn: (t) => t.checklistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistItemsTableFilterComposer(
            $db: $db,
            $table: $db.checklistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChecklistsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChecklistsTable> {
  $$ChecklistsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
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

class $$ChecklistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChecklistsTable> {
  $$ChecklistsTableAnnotationComposer({
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get collapsed =>
      $composableBuilder(column: $table.collapsed, builder: (column) => column);

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

  Expression<T> checklistItemsRefs<T extends Object>(
    Expression<T> Function($$ChecklistItemsTableAnnotationComposer a) f,
  ) {
    final $$ChecklistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklistItems,
      getReferencedColumn: (t) => t.checklistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.checklistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChecklistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChecklistsTable,
          Checklist,
          $$ChecklistsTableFilterComposer,
          $$ChecklistsTableOrderingComposer,
          $$ChecklistsTableAnnotationComposer,
          $$ChecklistsTableCreateCompanionBuilder,
          $$ChecklistsTableUpdateCompanionBuilder,
          (Checklist, $$ChecklistsTableReferences),
          Checklist,
          PrefetchHooks Function({bool tripId, bool checklistItemsRefs})
        > {
  $$ChecklistsTableTableManager(_$AppDatabase db, $ChecklistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChecklistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChecklistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChecklistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tripId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
              }) => ChecklistsCompanion(
                id: id,
                tripId: tripId,
                title: title,
                sortOrder: sortOrder,
                createdAt: createdAt,
                collapsed: collapsed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tripId,
                Value<String> title = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
              }) => ChecklistsCompanion.insert(
                id: id,
                tripId: tripId,
                title: title,
                sortOrder: sortOrder,
                createdAt: createdAt,
                collapsed: collapsed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChecklistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({tripId = false, checklistItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (checklistItemsRefs) db.checklistItems,
                  ],
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
                                    referencedTable: $$ChecklistsTableReferences
                                        ._tripIdTable(db),
                                    referencedColumn:
                                        $$ChecklistsTableReferences
                                            ._tripIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (checklistItemsRefs)
                        await $_getPrefetchedData<
                          Checklist,
                          $ChecklistsTable,
                          ChecklistItem
                        >(
                          currentTable: table,
                          referencedTable: $$ChecklistsTableReferences
                              ._checklistItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChecklistsTableReferences(
                                db,
                                table,
                                p0,
                              ).checklistItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.checklistId == item.id,
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

typedef $$ChecklistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChecklistsTable,
      Checklist,
      $$ChecklistsTableFilterComposer,
      $$ChecklistsTableOrderingComposer,
      $$ChecklistsTableAnnotationComposer,
      $$ChecklistsTableCreateCompanionBuilder,
      $$ChecklistsTableUpdateCompanionBuilder,
      (Checklist, $$ChecklistsTableReferences),
      Checklist,
      PrefetchHooks Function({bool tripId, bool checklistItemsRefs})
    >;
typedef $$ChecklistItemsTableCreateCompanionBuilder =
    ChecklistItemsCompanion Function({
      Value<int> id,
      required int checklistId,
      required String label,
      Value<bool> done,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });
typedef $$ChecklistItemsTableUpdateCompanionBuilder =
    ChecklistItemsCompanion Function({
      Value<int> id,
      Value<int> checklistId,
      Value<String> label,
      Value<bool> done,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

final class $$ChecklistItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ChecklistItemsTable, ChecklistItem> {
  $$ChecklistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChecklistsTable _checklistIdTable(_$AppDatabase db) => db.checklists
      .createAlias('checklist_items__checklist_id__checklists__id');

  $$ChecklistsTableProcessedTableManager get checklistId {
    final $_column = $_itemColumn<int>('checklist_id')!;

    final manager = $$ChecklistsTableTableManager(
      $_db,
      $_db.checklists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_checklistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChecklistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableFilterComposer({
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

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChecklistsTableFilterComposer get checklistId {
    final $$ChecklistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checklistId,
      referencedTable: $db.checklists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistsTableFilterComposer(
            $db: $db,
            $table: $db.checklists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableOrderingComposer({
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

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChecklistsTableOrderingComposer get checklistId {
    final $$ChecklistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checklistId,
      referencedTable: $db.checklists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistsTableOrderingComposer(
            $db: $db,
            $table: $db.checklists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableAnnotationComposer({
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

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ChecklistsTableAnnotationComposer get checklistId {
    final $$ChecklistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checklistId,
      referencedTable: $db.checklists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistsTableAnnotationComposer(
            $db: $db,
            $table: $db.checklists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChecklistItemsTable,
          ChecklistItem,
          $$ChecklistItemsTableFilterComposer,
          $$ChecklistItemsTableOrderingComposer,
          $$ChecklistItemsTableAnnotationComposer,
          $$ChecklistItemsTableCreateCompanionBuilder,
          $$ChecklistItemsTableUpdateCompanionBuilder,
          (ChecklistItem, $$ChecklistItemsTableReferences),
          ChecklistItem,
          PrefetchHooks Function({bool checklistId})
        > {
  $$ChecklistItemsTableTableManager(
    _$AppDatabase db,
    $ChecklistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChecklistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChecklistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChecklistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> checklistId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChecklistItemsCompanion(
                id: id,
                checklistId: checklistId,
                label: label,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int checklistId,
                required String label,
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChecklistItemsCompanion.insert(
                id: id,
                checklistId: checklistId,
                label: label,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChecklistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({checklistId = false}) {
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
                    if (checklistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.checklistId,
                                referencedTable: $$ChecklistItemsTableReferences
                                    ._checklistIdTable(db),
                                referencedColumn:
                                    $$ChecklistItemsTableReferences
                                        ._checklistIdTable(db)
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

typedef $$ChecklistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChecklistItemsTable,
      ChecklistItem,
      $$ChecklistItemsTableFilterComposer,
      $$ChecklistItemsTableOrderingComposer,
      $$ChecklistItemsTableAnnotationComposer,
      $$ChecklistItemsTableCreateCompanionBuilder,
      $$ChecklistItemsTableUpdateCompanionBuilder,
      (ChecklistItem, $$ChecklistItemsTableReferences),
      ChecklistItem,
      PrefetchHooks Function({bool checklistId})
    >;
typedef $$CollapsedDaysTableCreateCompanionBuilder =
    CollapsedDaysCompanion Function({
      required int tripId,
      required DateTime day,
      Value<int> rowid,
    });
typedef $$CollapsedDaysTableUpdateCompanionBuilder =
    CollapsedDaysCompanion Function({
      Value<int> tripId,
      Value<DateTime> day,
      Value<int> rowid,
    });

final class $$CollapsedDaysTableReferences
    extends BaseReferences<_$AppDatabase, $CollapsedDaysTable, CollapsedDay> {
  $$CollapsedDaysTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('collapsed_days__trip_id__trips__id');

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
}

class $$CollapsedDaysTableFilterComposer
    extends Composer<_$AppDatabase, $CollapsedDaysTable> {
  $$CollapsedDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get day => $composableBuilder(
    column: $table.day,
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
}

class $$CollapsedDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $CollapsedDaysTable> {
  $$CollapsedDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get day => $composableBuilder(
    column: $table.day,
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

class $$CollapsedDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollapsedDaysTable> {
  $$CollapsedDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

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

class $$CollapsedDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollapsedDaysTable,
          CollapsedDay,
          $$CollapsedDaysTableFilterComposer,
          $$CollapsedDaysTableOrderingComposer,
          $$CollapsedDaysTableAnnotationComposer,
          $$CollapsedDaysTableCreateCompanionBuilder,
          $$CollapsedDaysTableUpdateCompanionBuilder,
          (CollapsedDay, $$CollapsedDaysTableReferences),
          CollapsedDay,
          PrefetchHooks Function({bool tripId})
        > {
  $$CollapsedDaysTableTableManager(_$AppDatabase db, $CollapsedDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollapsedDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollapsedDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollapsedDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> tripId = const Value.absent(),
                Value<DateTime> day = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollapsedDaysCompanion(
                tripId: tripId,
                day: day,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int tripId,
                required DateTime day,
                Value<int> rowid = const Value.absent(),
              }) => CollapsedDaysCompanion.insert(
                tripId: tripId,
                day: day,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CollapsedDaysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
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
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$CollapsedDaysTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$CollapsedDaysTableReferences
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

typedef $$CollapsedDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollapsedDaysTable,
      CollapsedDay,
      $$CollapsedDaysTableFilterComposer,
      $$CollapsedDaysTableOrderingComposer,
      $$CollapsedDaysTableAnnotationComposer,
      $$CollapsedDaysTableCreateCompanionBuilder,
      $$CollapsedDaysTableUpdateCompanionBuilder,
      (CollapsedDay, $$CollapsedDaysTableReferences),
      CollapsedDay,
      PrefetchHooks Function({bool tripId})
    >;
typedef $$TracksTableCreateCompanionBuilder =
    TracksCompanion Function({
      Value<int> id,
      required int itemId,
      Value<TrackSource> source,
      Value<String?> name,
      required String points,
      Value<int> sortOrder,
    });
typedef $$TracksTableUpdateCompanionBuilder =
    TracksCompanion Function({
      Value<int> id,
      Value<int> itemId,
      Value<TrackSource> source,
      Value<String?> name,
      Value<String> points,
      Value<int> sortOrder,
    });

final class $$TracksTableReferences
    extends BaseReferences<_$AppDatabase, $TracksTable, Track> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItineraryItemsTable _itemIdTable(_$AppDatabase db) =>
      db.itineraryItems.createAlias('tracks__item_id__itinerary_items__id');

  $$ItineraryItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<int>('item_id')!;

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
}

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
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

  ColumnWithTypeConverterFilters<TrackSource, TrackSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
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

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TrackSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

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
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          Track,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (Track, $$TracksTableReferences),
          Track,
          PrefetchHooks Function({bool itemId})
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> itemId = const Value.absent(),
                Value<TrackSource> source = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String> points = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                itemId: itemId,
                source: source,
                name: name,
                points: points,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int itemId,
                Value<TrackSource> source = const Value.absent(),
                Value<String?> name = const Value.absent(),
                required String points,
                Value<int> sortOrder = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                itemId: itemId,
                source: source,
                name: name,
                points: points,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TracksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
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
                                referencedTable: $$TracksTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$TracksTableReferences
                                    ._itemIdTable(db)
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

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      Track,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (Track, $$TracksTableReferences),
      Track,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$VisitedCountriesTableCreateCompanionBuilder =
    VisitedCountriesCompanion Function({
      required String code,
      Value<DateTime> markedAt,
      Value<int> rowid,
    });
typedef $$VisitedCountriesTableUpdateCompanionBuilder =
    VisitedCountriesCompanion Function({
      Value<String> code,
      Value<DateTime> markedAt,
      Value<int> rowid,
    });

class $$VisitedCountriesTableFilterComposer
    extends Composer<_$AppDatabase, $VisitedCountriesTable> {
  $$VisitedCountriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get markedAt => $composableBuilder(
    column: $table.markedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VisitedCountriesTableOrderingComposer
    extends Composer<_$AppDatabase, $VisitedCountriesTable> {
  $$VisitedCountriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get markedAt => $composableBuilder(
    column: $table.markedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VisitedCountriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisitedCountriesTable> {
  $$VisitedCountriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<DateTime> get markedAt =>
      $composableBuilder(column: $table.markedAt, builder: (column) => column);
}

class $$VisitedCountriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisitedCountriesTable,
          VisitedCountry,
          $$VisitedCountriesTableFilterComposer,
          $$VisitedCountriesTableOrderingComposer,
          $$VisitedCountriesTableAnnotationComposer,
          $$VisitedCountriesTableCreateCompanionBuilder,
          $$VisitedCountriesTableUpdateCompanionBuilder,
          (
            VisitedCountry,
            BaseReferences<
              _$AppDatabase,
              $VisitedCountriesTable,
              VisitedCountry
            >,
          ),
          VisitedCountry,
          PrefetchHooks Function()
        > {
  $$VisitedCountriesTableTableManager(
    _$AppDatabase db,
    $VisitedCountriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitedCountriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitedCountriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitedCountriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<DateTime> markedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitedCountriesCompanion(
                code: code,
                markedAt: markedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                Value<DateTime> markedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitedCountriesCompanion.insert(
                code: code,
                markedAt: markedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VisitedCountriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisitedCountriesTable,
      VisitedCountry,
      $$VisitedCountriesTableFilterComposer,
      $$VisitedCountriesTableOrderingComposer,
      $$VisitedCountriesTableAnnotationComposer,
      $$VisitedCountriesTableCreateCompanionBuilder,
      $$VisitedCountriesTableUpdateCompanionBuilder,
      (
        VisitedCountry,
        BaseReferences<_$AppDatabase, $VisitedCountriesTable, VisitedCountry>,
      ),
      VisitedCountry,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      Value<int?> itemId,
      Value<int?> groupId,
      Value<int?> tripId,
      required AttachmentKind kind,
      required String mimeType,
      Value<String?> name,
      required int byteSize,
      Value<int?> width,
      Value<int?> height,
      Value<double?> lat,
      Value<double?> lon,
      Value<AttachmentPositionSource?> positionSource,
      Value<Uint8List?> thumbnail,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      Value<int?> itemId,
      Value<int?> groupId,
      Value<int?> tripId,
      Value<AttachmentKind> kind,
      Value<String> mimeType,
      Value<String?> name,
      Value<int> byteSize,
      Value<int?> width,
      Value<int?> height,
      Value<double?> lat,
      Value<double?> lon,
      Value<AttachmentPositionSource?> positionSource,
      Value<Uint8List?> thumbnail,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItineraryItemsTable _itemIdTable(_$AppDatabase db) => db
      .itineraryItems
      .createAlias('attachments__item_id__itinerary_items__id');

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

  static $ItemGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.itemGroups.createAlias('attachments__group_id__item_groups__id');

  $$ItemGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<int>('group_id');
    if ($_column == null) return null;
    final manager = $$ItemGroupsTableTableManager(
      $_db,
      $_db.itemGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('attachments__trip_id__trips__id');

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

  static MultiTypedResultKey<$AttachmentBlobsTable, List<AttachmentBlob>>
  _attachmentBlobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachmentBlobs,
    aliasName: 'attachments__id__attachment_blobs__attachment_id',
  );

  $$AttachmentBlobsTableProcessedTableManager get attachmentBlobsRefs {
    final manager = $$AttachmentBlobsTableTableManager(
      $_db,
      $_db.attachmentBlobs,
    ).filter((f) => f.attachmentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attachmentBlobsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<AttachmentKind, AttachmentKind, int>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    AttachmentPositionSource?,
    AttachmentPositionSource,
    int
  >
  get positionSource => $composableBuilder(
    column: $table.positionSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<Uint8List> get thumbnail => $composableBuilder(
    column: $table.thumbnail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  $$ItemGroupsTableFilterComposer get groupId {
    final $$ItemGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableFilterComposer(
            $db: $db,
            $table: $db.itemGroups,
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

  Expression<bool> attachmentBlobsRefs(
    Expression<bool> Function($$AttachmentBlobsTableFilterComposer f) f,
  ) {
    final $$AttachmentBlobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachmentBlobs,
      getReferencedColumn: (t) => t.attachmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentBlobsTableFilterComposer(
            $db: $db,
            $table: $db.attachmentBlobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
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

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionSource => $composableBuilder(
    column: $table.positionSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get thumbnail => $composableBuilder(
    column: $table.thumbnail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  $$ItemGroupsTableOrderingComposer get groupId {
    final $$ItemGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.itemGroups,
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

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AttachmentKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AttachmentPositionSource?, int>
  get positionSource => $composableBuilder(
    column: $table.positionSource,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get thumbnail =>
      $composableBuilder(column: $table.thumbnail, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

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

  $$ItemGroupsTableAnnotationComposer get groupId {
    final $$ItemGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.itemGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemGroups,
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

  Expression<T> attachmentBlobsRefs<T extends Object>(
    Expression<T> Function($$AttachmentBlobsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentBlobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachmentBlobs,
      getReferencedColumn: (t) => t.attachmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentBlobsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachmentBlobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({
            bool itemId,
            bool groupId,
            bool tripId,
            bool attachmentBlobsRefs,
          })
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> itemId = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                Value<AttachmentKind> kind = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<AttachmentPositionSource?> positionSource =
                    const Value.absent(),
                Value<Uint8List?> thumbnail = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                itemId: itemId,
                groupId: groupId,
                tripId: tripId,
                kind: kind,
                mimeType: mimeType,
                name: name,
                byteSize: byteSize,
                width: width,
                height: height,
                lat: lat,
                lon: lon,
                positionSource: positionSource,
                thumbnail: thumbnail,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> itemId = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                Value<int?> tripId = const Value.absent(),
                required AttachmentKind kind,
                required String mimeType,
                Value<String?> name = const Value.absent(),
                required int byteSize,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<AttachmentPositionSource?> positionSource =
                    const Value.absent(),
                Value<Uint8List?> thumbnail = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                itemId: itemId,
                groupId: groupId,
                tripId: tripId,
                kind: kind,
                mimeType: mimeType,
                name: name,
                byteSize: byteSize,
                width: width,
                height: height,
                lat: lat,
                lon: lon,
                positionSource: positionSource,
                thumbnail: thumbnail,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                itemId = false,
                groupId = false,
                tripId = false,
                attachmentBlobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (attachmentBlobsRefs) db.attachmentBlobs,
                  ],
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
                                    referencedTable:
                                        $$AttachmentsTableReferences
                                            ._itemIdTable(db),
                                    referencedColumn:
                                        $$AttachmentsTableReferences
                                            ._itemIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable:
                                        $$AttachmentsTableReferences
                                            ._groupIdTable(db),
                                    referencedColumn:
                                        $$AttachmentsTableReferences
                                            ._groupIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (tripId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tripId,
                                    referencedTable:
                                        $$AttachmentsTableReferences
                                            ._tripIdTable(db),
                                    referencedColumn:
                                        $$AttachmentsTableReferences
                                            ._tripIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (attachmentBlobsRefs)
                        await $_getPrefetchedData<
                          Attachment,
                          $AttachmentsTable,
                          AttachmentBlob
                        >(
                          currentTable: table,
                          referencedTable: $$AttachmentsTableReferences
                              ._attachmentBlobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AttachmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentBlobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.attachmentId == item.id,
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

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({
        bool itemId,
        bool groupId,
        bool tripId,
        bool attachmentBlobsRefs,
      })
    >;
typedef $$AttachmentBlobsTableCreateCompanionBuilder =
    AttachmentBlobsCompanion Function({
      Value<int> attachmentId,
      required Uint8List bytes,
    });
typedef $$AttachmentBlobsTableUpdateCompanionBuilder =
    AttachmentBlobsCompanion Function({
      Value<int> attachmentId,
      Value<Uint8List> bytes,
    });

final class $$AttachmentBlobsTableReferences
    extends
        BaseReferences<_$AppDatabase, $AttachmentBlobsTable, AttachmentBlob> {
  $$AttachmentBlobsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AttachmentsTable _attachmentIdTable(_$AppDatabase db) => db
      .attachments
      .createAlias('attachment_blobs__attachment_id__attachments__id');

  $$AttachmentsTableProcessedTableManager get attachmentId {
    final $_column = $_itemColumn<int>('attachment_id')!;

    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attachmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentBlobsTable> {
  $$AttachmentBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  $$AttachmentsTableFilterComposer get attachmentId {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentBlobsTable> {
  $$AttachmentBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  $$AttachmentsTableOrderingComposer get attachmentId {
    final $$AttachmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableOrderingComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentBlobsTable> {
  $$AttachmentBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  $$AttachmentsTableAnnotationComposer get attachmentId {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentBlobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentBlobsTable,
          AttachmentBlob,
          $$AttachmentBlobsTableFilterComposer,
          $$AttachmentBlobsTableOrderingComposer,
          $$AttachmentBlobsTableAnnotationComposer,
          $$AttachmentBlobsTableCreateCompanionBuilder,
          $$AttachmentBlobsTableUpdateCompanionBuilder,
          (AttachmentBlob, $$AttachmentBlobsTableReferences),
          AttachmentBlob,
          PrefetchHooks Function({bool attachmentId})
        > {
  $$AttachmentBlobsTableTableManager(
    _$AppDatabase db,
    $AttachmentBlobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> attachmentId = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
              }) => AttachmentBlobsCompanion(
                attachmentId: attachmentId,
                bytes: bytes,
              ),
          createCompanionCallback:
              ({
                Value<int> attachmentId = const Value.absent(),
                required Uint8List bytes,
              }) => AttachmentBlobsCompanion.insert(
                attachmentId: attachmentId,
                bytes: bytes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttachmentBlobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({attachmentId = false}) {
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
                    if (attachmentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.attachmentId,
                                referencedTable:
                                    $$AttachmentBlobsTableReferences
                                        ._attachmentIdTable(db),
                                referencedColumn:
                                    $$AttachmentBlobsTableReferences
                                        ._attachmentIdTable(db)
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

typedef $$AttachmentBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentBlobsTable,
      AttachmentBlob,
      $$AttachmentBlobsTableFilterComposer,
      $$AttachmentBlobsTableOrderingComposer,
      $$AttachmentBlobsTableAnnotationComposer,
      $$AttachmentBlobsTableCreateCompanionBuilder,
      $$AttachmentBlobsTableUpdateCompanionBuilder,
      (AttachmentBlob, $$AttachmentBlobsTableReferences),
      AttachmentBlob,
      PrefetchHooks Function({bool attachmentId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$ItemGroupsTableTableManager get itemGroups =>
      $$ItemGroupsTableTableManager(_db, _db.itemGroups);
  $$AlternativeSetsTableTableManager get alternativeSets =>
      $$AlternativeSetsTableTableManager(_db, _db.alternativeSets);
  $$AlternativesTableTableManager get alternatives =>
      $$AlternativesTableTableManager(_db, _db.alternatives);
  $$TransportModesTableTableManager get transportModes =>
      $$TransportModesTableTableManager(_db, _db.transportModes);
  $$ItineraryItemsTableTableManager get itineraryItems =>
      $$ItineraryItemsTableTableManager(_db, _db.itineraryItems);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db, _db.currencies);
  $$CostsTableTableManager get costs =>
      $$CostsTableTableManager(_db, _db.costs);
  $$CostReasonsTableTableManager get costReasons =>
      $$CostReasonsTableTableManager(_db, _db.costReasons);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TripTagsTableTableManager get tripTags =>
      $$TripTagsTableTableManager(_db, _db.tripTags);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$TripParticipantsTableTableManager get tripParticipants =>
      $$TripParticipantsTableTableManager(_db, _db.tripParticipants);
  $$CostBeneficiariesTableTableManager get costBeneficiaries =>
      $$CostBeneficiariesTableTableManager(_db, _db.costBeneficiaries);
  $$ChecklistsTableTableManager get checklists =>
      $$ChecklistsTableTableManager(_db, _db.checklists);
  $$ChecklistItemsTableTableManager get checklistItems =>
      $$ChecklistItemsTableTableManager(_db, _db.checklistItems);
  $$CollapsedDaysTableTableManager get collapsedDays =>
      $$CollapsedDaysTableTableManager(_db, _db.collapsedDays);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$VisitedCountriesTableTableManager get visitedCountries =>
      $$VisitedCountriesTableTableManager(_db, _db.visitedCountries);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$AttachmentBlobsTableTableManager get attachmentBlobs =>
      $$AttachmentBlobsTableTableManager(_db, _db.attachmentBlobs);
}
