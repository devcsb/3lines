// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _prompt1Meta = const VerificationMeta(
    'prompt1',
  );
  @override
  late final GeneratedColumn<String> prompt1 = GeneratedColumn<String>(
    'prompt1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _answer1Meta = const VerificationMeta(
    'answer1',
  );
  @override
  late final GeneratedColumn<String> answer1 = GeneratedColumn<String>(
    'answer1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _prompt2Meta = const VerificationMeta(
    'prompt2',
  );
  @override
  late final GeneratedColumn<String> prompt2 = GeneratedColumn<String>(
    'prompt2',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _answer2Meta = const VerificationMeta(
    'answer2',
  );
  @override
  late final GeneratedColumn<String> answer2 = GeneratedColumn<String>(
    'answer2',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _prompt3Meta = const VerificationMeta(
    'prompt3',
  );
  @override
  late final GeneratedColumn<String> prompt3 = GeneratedColumn<String>(
    'prompt3',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _answer3Meta = const VerificationMeta(
    'answer3',
  );
  @override
  late final GeneratedColumn<String> answer3 = GeneratedColumn<String>(
    'answer3',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _emotionMeta = const VerificationMeta(
    'emotion',
  );
  @override
  late final GeneratedColumn<int> emotion = GeneratedColumn<int>(
    'emotion',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    prompt1,
    answer1,
    prompt2,
    answer2,
    prompt3,
    answer3,
    emotion,
    createdAt,
    updatedAt,
    photoPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('prompt1')) {
      context.handle(
        _prompt1Meta,
        prompt1.isAcceptableOrUnknown(data['prompt1']!, _prompt1Meta),
      );
    }
    if (data.containsKey('answer1')) {
      context.handle(
        _answer1Meta,
        answer1.isAcceptableOrUnknown(data['answer1']!, _answer1Meta),
      );
    }
    if (data.containsKey('prompt2')) {
      context.handle(
        _prompt2Meta,
        prompt2.isAcceptableOrUnknown(data['prompt2']!, _prompt2Meta),
      );
    }
    if (data.containsKey('answer2')) {
      context.handle(
        _answer2Meta,
        answer2.isAcceptableOrUnknown(data['answer2']!, _answer2Meta),
      );
    }
    if (data.containsKey('prompt3')) {
      context.handle(
        _prompt3Meta,
        prompt3.isAcceptableOrUnknown(data['prompt3']!, _prompt3Meta),
      );
    }
    if (data.containsKey('answer3')) {
      context.handle(
        _answer3Meta,
        answer3.isAcceptableOrUnknown(data['answer3']!, _answer3Meta),
      );
    }
    if (data.containsKey('emotion')) {
      context.handle(
        _emotionMeta,
        emotion.isAcceptableOrUnknown(data['emotion']!, _emotionMeta),
      );
    } else if (isInserting) {
      context.missing(_emotionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      prompt1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt1'],
      )!,
      answer1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer1'],
      )!,
      prompt2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt2'],
      )!,
      answer2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer2'],
      )!,
      prompt3: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt3'],
      )!,
      answer3: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer3'],
      )!,
      emotion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}emotion'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final int id;
  final String date;
  final String prompt1;
  final String answer1;
  final String prompt2;
  final String answer2;
  final String prompt3;
  final String answer3;
  final int emotion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoPath;
  const Entry({
    required this.id,
    required this.date,
    required this.prompt1,
    required this.answer1,
    required this.prompt2,
    required this.answer2,
    required this.prompt3,
    required this.answer3,
    required this.emotion,
    required this.createdAt,
    required this.updatedAt,
    this.photoPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    map['prompt1'] = Variable<String>(prompt1);
    map['answer1'] = Variable<String>(answer1);
    map['prompt2'] = Variable<String>(prompt2);
    map['answer2'] = Variable<String>(answer2);
    map['prompt3'] = Variable<String>(prompt3);
    map['answer3'] = Variable<String>(answer3);
    map['emotion'] = Variable<int>(emotion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      date: Value(date),
      prompt1: Value(prompt1),
      answer1: Value(answer1),
      prompt2: Value(prompt2),
      answer2: Value(answer2),
      prompt3: Value(prompt3),
      answer3: Value(answer3),
      emotion: Value(emotion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      prompt1: serializer.fromJson<String>(json['prompt1']),
      answer1: serializer.fromJson<String>(json['answer1']),
      prompt2: serializer.fromJson<String>(json['prompt2']),
      answer2: serializer.fromJson<String>(json['answer2']),
      prompt3: serializer.fromJson<String>(json['prompt3']),
      answer3: serializer.fromJson<String>(json['answer3']),
      emotion: serializer.fromJson<int>(json['emotion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'prompt1': serializer.toJson<String>(prompt1),
      'answer1': serializer.toJson<String>(answer1),
      'prompt2': serializer.toJson<String>(prompt2),
      'answer2': serializer.toJson<String>(answer2),
      'prompt3': serializer.toJson<String>(prompt3),
      'answer3': serializer.toJson<String>(answer3),
      'emotion': serializer.toJson<int>(emotion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'photoPath': serializer.toJson<String?>(photoPath),
    };
  }

  Entry copyWith({
    int? id,
    String? date,
    String? prompt1,
    String? answer1,
    String? prompt2,
    String? answer2,
    String? prompt3,
    String? answer3,
    int? emotion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> photoPath = const Value.absent(),
  }) => Entry(
    id: id ?? this.id,
    date: date ?? this.date,
    prompt1: prompt1 ?? this.prompt1,
    answer1: answer1 ?? this.answer1,
    prompt2: prompt2 ?? this.prompt2,
    answer2: answer2 ?? this.answer2,
    prompt3: prompt3 ?? this.prompt3,
    answer3: answer3 ?? this.answer3,
    emotion: emotion ?? this.emotion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      prompt1: data.prompt1.present ? data.prompt1.value : this.prompt1,
      answer1: data.answer1.present ? data.answer1.value : this.answer1,
      prompt2: data.prompt2.present ? data.prompt2.value : this.prompt2,
      answer2: data.answer2.present ? data.answer2.value : this.answer2,
      prompt3: data.prompt3.present ? data.prompt3.value : this.prompt3,
      answer3: data.answer3.present ? data.answer3.value : this.answer3,
      emotion: data.emotion.present ? data.emotion.value : this.emotion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('prompt1: $prompt1, ')
          ..write('answer1: $answer1, ')
          ..write('prompt2: $prompt2, ')
          ..write('answer2: $answer2, ')
          ..write('prompt3: $prompt3, ')
          ..write('answer3: $answer3, ')
          ..write('emotion: $emotion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('photoPath: $photoPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    prompt1,
    answer1,
    prompt2,
    answer2,
    prompt3,
    answer3,
    emotion,
    createdAt,
    updatedAt,
    photoPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.date == this.date &&
          other.prompt1 == this.prompt1 &&
          other.answer1 == this.answer1 &&
          other.prompt2 == this.prompt2 &&
          other.answer2 == this.answer2 &&
          other.prompt3 == this.prompt3 &&
          other.answer3 == this.answer3 &&
          other.emotion == this.emotion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.photoPath == this.photoPath);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<int> id;
  final Value<String> date;
  final Value<String> prompt1;
  final Value<String> answer1;
  final Value<String> prompt2;
  final Value<String> answer2;
  final Value<String> prompt3;
  final Value<String> answer3;
  final Value<int> emotion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> photoPath;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.prompt1 = const Value.absent(),
    this.answer1 = const Value.absent(),
    this.prompt2 = const Value.absent(),
    this.answer2 = const Value.absent(),
    this.prompt3 = const Value.absent(),
    this.answer3 = const Value.absent(),
    this.emotion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.photoPath = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    this.prompt1 = const Value.absent(),
    this.answer1 = const Value.absent(),
    this.prompt2 = const Value.absent(),
    this.answer2 = const Value.absent(),
    this.prompt3 = const Value.absent(),
    this.answer3 = const Value.absent(),
    required int emotion,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.photoPath = const Value.absent(),
  }) : date = Value(date),
       emotion = Value(emotion);
  static Insertable<Entry> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<String>? prompt1,
    Expression<String>? answer1,
    Expression<String>? prompt2,
    Expression<String>? answer2,
    Expression<String>? prompt3,
    Expression<String>? answer3,
    Expression<int>? emotion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? photoPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (prompt1 != null) 'prompt1': prompt1,
      if (answer1 != null) 'answer1': answer1,
      if (prompt2 != null) 'prompt2': prompt2,
      if (answer2 != null) 'answer2': answer2,
      if (prompt3 != null) 'prompt3': prompt3,
      if (answer3 != null) 'answer3': answer3,
      if (emotion != null) 'emotion': emotion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (photoPath != null) 'photo_path': photoPath,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<String>? prompt1,
    Value<String>? answer1,
    Value<String>? prompt2,
    Value<String>? answer2,
    Value<String>? prompt3,
    Value<String>? answer3,
    Value<int>? emotion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? photoPath,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      prompt1: prompt1 ?? this.prompt1,
      answer1: answer1 ?? this.answer1,
      prompt2: prompt2 ?? this.prompt2,
      answer2: answer2 ?? this.answer2,
      prompt3: prompt3 ?? this.prompt3,
      answer3: answer3 ?? this.answer3,
      emotion: emotion ?? this.emotion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (prompt1.present) {
      map['prompt1'] = Variable<String>(prompt1.value);
    }
    if (answer1.present) {
      map['answer1'] = Variable<String>(answer1.value);
    }
    if (prompt2.present) {
      map['prompt2'] = Variable<String>(prompt2.value);
    }
    if (answer2.present) {
      map['answer2'] = Variable<String>(answer2.value);
    }
    if (prompt3.present) {
      map['prompt3'] = Variable<String>(prompt3.value);
    }
    if (answer3.present) {
      map['answer3'] = Variable<String>(answer3.value);
    }
    if (emotion.present) {
      map['emotion'] = Variable<int>(emotion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('prompt1: $prompt1, ')
          ..write('answer1: $answer1, ')
          ..write('prompt2: $prompt2, ')
          ..write('answer2: $answer2, ')
          ..write('prompt3: $prompt3, ')
          ..write('answer3: $answer3, ')
          ..write('emotion: $emotion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('photoPath: $photoPath')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [entries, settings];
}

typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      required String date,
      Value<String> prompt1,
      Value<String> answer1,
      Value<String> prompt2,
      Value<String> answer2,
      Value<String> prompt3,
      Value<String> answer3,
      required int emotion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> photoPath,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      Value<String> date,
      Value<String> prompt1,
      Value<String> answer1,
      Value<String> prompt2,
      Value<String> answer2,
      Value<String> prompt3,
      Value<String> answer3,
      Value<int> emotion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> photoPath,
    });

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
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

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt1 => $composableBuilder(
    column: $table.prompt1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer1 => $composableBuilder(
    column: $table.answer1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt2 => $composableBuilder(
    column: $table.prompt2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer2 => $composableBuilder(
    column: $table.answer2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt3 => $composableBuilder(
    column: $table.prompt3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer3 => $composableBuilder(
    column: $table.answer3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get emotion => $composableBuilder(
    column: $table.emotion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
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

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt1 => $composableBuilder(
    column: $table.prompt1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer1 => $composableBuilder(
    column: $table.answer1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt2 => $composableBuilder(
    column: $table.prompt2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer2 => $composableBuilder(
    column: $table.answer2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt3 => $composableBuilder(
    column: $table.prompt3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer3 => $composableBuilder(
    column: $table.answer3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get emotion => $composableBuilder(
    column: $table.emotion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get prompt1 =>
      $composableBuilder(column: $table.prompt1, builder: (column) => column);

  GeneratedColumn<String> get answer1 =>
      $composableBuilder(column: $table.answer1, builder: (column) => column);

  GeneratedColumn<String> get prompt2 =>
      $composableBuilder(column: $table.prompt2, builder: (column) => column);

  GeneratedColumn<String> get answer2 =>
      $composableBuilder(column: $table.answer2, builder: (column) => column);

  GeneratedColumn<String> get prompt3 =>
      $composableBuilder(column: $table.prompt3, builder: (column) => column);

  GeneratedColumn<String> get answer3 =>
      $composableBuilder(column: $table.answer3, builder: (column) => column);

  GeneratedColumn<int> get emotion =>
      $composableBuilder(column: $table.emotion, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, BaseReferences<_$AppDatabase, $EntriesTable, Entry>),
          Entry,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> prompt1 = const Value.absent(),
                Value<String> answer1 = const Value.absent(),
                Value<String> prompt2 = const Value.absent(),
                Value<String> answer2 = const Value.absent(),
                Value<String> prompt3 = const Value.absent(),
                Value<String> answer3 = const Value.absent(),
                Value<int> emotion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                date: date,
                prompt1: prompt1,
                answer1: answer1,
                prompt2: prompt2,
                answer2: answer2,
                prompt3: prompt3,
                answer3: answer3,
                emotion: emotion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                photoPath: photoPath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                Value<String> prompt1 = const Value.absent(),
                Value<String> answer1 = const Value.absent(),
                Value<String> prompt2 = const Value.absent(),
                Value<String> answer2 = const Value.absent(),
                Value<String> prompt3 = const Value.absent(),
                Value<String> answer3 = const Value.absent(),
                required int emotion,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                date: date,
                prompt1: prompt1,
                answer1: answer1,
                prompt2: prompt2,
                answer2: answer2,
                prompt3: prompt3,
                answer3: answer3,
                emotion: emotion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                photoPath: photoPath,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, BaseReferences<_$AppDatabase, $EntriesTable, Entry>),
      Entry,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
