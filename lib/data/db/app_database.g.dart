// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SpecimensTable extends Specimens
    with TableInfo<$SpecimensTable, Specimen> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpecimensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionTextMeta = const VerificationMeta(
    'questionText',
  );
  @override
  late final GeneratedColumn<String> questionText = GeneratedColumn<String>(
    'question_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerTextMeta = const VerificationMeta(
    'answerText',
  );
  @override
  late final GeneratedColumn<String> answerText = GeneratedColumn<String>(
    'answer_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('alive'),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageIdMeta = const VerificationMeta(
    'imageId',
  );
  @override
  late final GeneratedColumn<String> imageId = GeneratedColumn<String>(
    'image_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageRarityMeta = const VerificationMeta(
    'imageRarity',
  );
  @override
  late final GeneratedColumn<int> imageRarity = GeneratedColumn<int>(
    'image_rarity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    questionId,
    questionText,
    answerText,
    status,
    createdAt,
    imageId,
    localPath,
    imageRarity,
    name,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'specimens';
  @override
  VerificationContext validateIntegrity(
    Insertable<Specimen> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('question_text')) {
      context.handle(
        _questionTextMeta,
        questionText.isAcceptableOrUnknown(
          data['question_text']!,
          _questionTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionTextMeta);
    }
    if (data.containsKey('answer_text')) {
      context.handle(
        _answerTextMeta,
        answerText.isAcceptableOrUnknown(data['answer_text']!, _answerTextMeta),
      );
    } else if (isInserting) {
      context.missing(_answerTextMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('image_id')) {
      context.handle(
        _imageIdMeta,
        imageId.isAcceptableOrUnknown(data['image_id']!, _imageIdMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('image_rarity')) {
      context.handle(
        _imageRarityMeta,
        imageRarity.isAcceptableOrUnknown(
          data['image_rarity']!,
          _imageRarityMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Specimen map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Specimen(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      questionText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_text'],
      )!,
      answerText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_text'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      imageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_id'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      imageRarity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_rarity'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
    );
  }

  @override
  $SpecimensTable createAlias(String alias) {
    return $SpecimensTable(attachedDatabase, alias);
  }
}

class Specimen extends DataClass implements Insertable<Specimen> {
  final String id;
  final String date;
  final String questionId;
  final String questionText;
  final String answerText;
  final String status;
  final DateTime createdAt;
  final String? imageId;
  final String? localPath;
  final int? imageRarity;
  final String? name;
  const Specimen({
    required this.id,
    required this.date,
    required this.questionId,
    required this.questionText,
    required this.answerText,
    required this.status,
    required this.createdAt,
    this.imageId,
    this.localPath,
    this.imageRarity,
    this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['question_id'] = Variable<String>(questionId);
    map['question_text'] = Variable<String>(questionText);
    map['answer_text'] = Variable<String>(answerText);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || imageId != null) {
      map['image_id'] = Variable<String>(imageId);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || imageRarity != null) {
      map['image_rarity'] = Variable<int>(imageRarity);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    return map;
  }

  SpecimensCompanion toCompanion(bool nullToAbsent) {
    return SpecimensCompanion(
      id: Value(id),
      date: Value(date),
      questionId: Value(questionId),
      questionText: Value(questionText),
      answerText: Value(answerText),
      status: Value(status),
      createdAt: Value(createdAt),
      imageId: imageId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageId),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      imageRarity: imageRarity == null && nullToAbsent
          ? const Value.absent()
          : Value(imageRarity),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
    );
  }

  factory Specimen.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Specimen(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      questionId: serializer.fromJson<String>(json['questionId']),
      questionText: serializer.fromJson<String>(json['questionText']),
      answerText: serializer.fromJson<String>(json['answerText']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      imageId: serializer.fromJson<String?>(json['imageId']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      imageRarity: serializer.fromJson<int?>(json['imageRarity']),
      name: serializer.fromJson<String?>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'questionId': serializer.toJson<String>(questionId),
      'questionText': serializer.toJson<String>(questionText),
      'answerText': serializer.toJson<String>(answerText),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'imageId': serializer.toJson<String?>(imageId),
      'localPath': serializer.toJson<String?>(localPath),
      'imageRarity': serializer.toJson<int?>(imageRarity),
      'name': serializer.toJson<String?>(name),
    };
  }

  Specimen copyWith({
    String? id,
    String? date,
    String? questionId,
    String? questionText,
    String? answerText,
    String? status,
    DateTime? createdAt,
    Value<String?> imageId = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<int?> imageRarity = const Value.absent(),
    Value<String?> name = const Value.absent(),
  }) => Specimen(
    id: id ?? this.id,
    date: date ?? this.date,
    questionId: questionId ?? this.questionId,
    questionText: questionText ?? this.questionText,
    answerText: answerText ?? this.answerText,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    imageId: imageId.present ? imageId.value : this.imageId,
    localPath: localPath.present ? localPath.value : this.localPath,
    imageRarity: imageRarity.present ? imageRarity.value : this.imageRarity,
    name: name.present ? name.value : this.name,
  );
  Specimen copyWithCompanion(SpecimensCompanion data) {
    return Specimen(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      questionText: data.questionText.present
          ? data.questionText.value
          : this.questionText,
      answerText: data.answerText.present
          ? data.answerText.value
          : this.answerText,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      imageId: data.imageId.present ? data.imageId.value : this.imageId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      imageRarity: data.imageRarity.present
          ? data.imageRarity.value
          : this.imageRarity,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Specimen(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('questionId: $questionId, ')
          ..write('questionText: $questionText, ')
          ..write('answerText: $answerText, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('imageId: $imageId, ')
          ..write('localPath: $localPath, ')
          ..write('imageRarity: $imageRarity, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    questionId,
    questionText,
    answerText,
    status,
    createdAt,
    imageId,
    localPath,
    imageRarity,
    name,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Specimen &&
          other.id == this.id &&
          other.date == this.date &&
          other.questionId == this.questionId &&
          other.questionText == this.questionText &&
          other.answerText == this.answerText &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.imageId == this.imageId &&
          other.localPath == this.localPath &&
          other.imageRarity == this.imageRarity &&
          other.name == this.name);
}

class SpecimensCompanion extends UpdateCompanion<Specimen> {
  final Value<String> id;
  final Value<String> date;
  final Value<String> questionId;
  final Value<String> questionText;
  final Value<String> answerText;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<String?> imageId;
  final Value<String?> localPath;
  final Value<int?> imageRarity;
  final Value<String?> name;
  final Value<int> rowid;
  const SpecimensCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.questionId = const Value.absent(),
    this.questionText = const Value.absent(),
    this.answerText = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.imageId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.imageRarity = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpecimensCompanion.insert({
    required String id,
    required String date,
    required String questionId,
    required String questionText,
    required String answerText,
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.imageId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.imageRarity = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       questionId = Value(questionId),
       questionText = Value(questionText),
       answerText = Value(answerText),
       createdAt = Value(createdAt);
  static Insertable<Specimen> custom({
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? questionId,
    Expression<String>? questionText,
    Expression<String>? answerText,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<String>? imageId,
    Expression<String>? localPath,
    Expression<int>? imageRarity,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (questionId != null) 'question_id': questionId,
      if (questionText != null) 'question_text': questionText,
      if (answerText != null) 'answer_text': answerText,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (imageId != null) 'image_id': imageId,
      if (localPath != null) 'local_path': localPath,
      if (imageRarity != null) 'image_rarity': imageRarity,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpecimensCompanion copyWith({
    Value<String>? id,
    Value<String>? date,
    Value<String>? questionId,
    Value<String>? questionText,
    Value<String>? answerText,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<String?>? imageId,
    Value<String?>? localPath,
    Value<int?>? imageRarity,
    Value<String?>? name,
    Value<int>? rowid,
  }) {
    return SpecimensCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      questionId: questionId ?? this.questionId,
      questionText: questionText ?? this.questionText,
      answerText: answerText ?? this.answerText,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      imageId: imageId ?? this.imageId,
      localPath: localPath ?? this.localPath,
      imageRarity: imageRarity ?? this.imageRarity,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (questionText.present) {
      map['question_text'] = Variable<String>(questionText.value);
    }
    if (answerText.present) {
      map['answer_text'] = Variable<String>(answerText.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (imageId.present) {
      map['image_id'] = Variable<String>(imageId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (imageRarity.present) {
      map['image_rarity'] = Variable<int>(imageRarity.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpecimensCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('questionId: $questionId, ')
          ..write('questionText: $questionText, ')
          ..write('answerText: $answerText, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('imageId: $imageId, ')
          ..write('localPath: $localPath, ')
          ..write('imageRarity: $imageRarity, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
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
  late final $SpecimensTable specimens = $SpecimensTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final SpecimensDao specimensDao = SpecimensDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [specimens, settings];
}

typedef $$SpecimensTableCreateCompanionBuilder =
    SpecimensCompanion Function({
      required String id,
      required String date,
      required String questionId,
      required String questionText,
      required String answerText,
      Value<String> status,
      required DateTime createdAt,
      Value<String?> imageId,
      Value<String?> localPath,
      Value<int?> imageRarity,
      Value<String?> name,
      Value<int> rowid,
    });
typedef $$SpecimensTableUpdateCompanionBuilder =
    SpecimensCompanion Function({
      Value<String> id,
      Value<String> date,
      Value<String> questionId,
      Value<String> questionText,
      Value<String> answerText,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<String?> imageId,
      Value<String?> localPath,
      Value<int?> imageRarity,
      Value<String?> name,
      Value<int> rowid,
    });

class $$SpecimensTableFilterComposer
    extends Composer<_$AppDatabase, $SpecimensTable> {
  $$SpecimensTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionText => $composableBuilder(
    column: $table.questionText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerText => $composableBuilder(
    column: $table.answerText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageId => $composableBuilder(
    column: $table.imageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageRarity => $composableBuilder(
    column: $table.imageRarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpecimensTableOrderingComposer
    extends Composer<_$AppDatabase, $SpecimensTable> {
  $$SpecimensTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionText => $composableBuilder(
    column: $table.questionText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerText => $composableBuilder(
    column: $table.answerText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageId => $composableBuilder(
    column: $table.imageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageRarity => $composableBuilder(
    column: $table.imageRarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpecimensTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpecimensTable> {
  $$SpecimensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questionText => $composableBuilder(
    column: $table.questionText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answerText => $composableBuilder(
    column: $table.answerText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get imageId =>
      $composableBuilder(column: $table.imageId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get imageRarity => $composableBuilder(
    column: $table.imageRarity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$SpecimensTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpecimensTable,
          Specimen,
          $$SpecimensTableFilterComposer,
          $$SpecimensTableOrderingComposer,
          $$SpecimensTableAnnotationComposer,
          $$SpecimensTableCreateCompanionBuilder,
          $$SpecimensTableUpdateCompanionBuilder,
          (Specimen, BaseReferences<_$AppDatabase, $SpecimensTable, Specimen>),
          Specimen,
          PrefetchHooks Function()
        > {
  $$SpecimensTableTableManager(_$AppDatabase db, $SpecimensTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpecimensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpecimensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpecimensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> questionId = const Value.absent(),
                Value<String> questionText = const Value.absent(),
                Value<String> answerText = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> imageId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> imageRarity = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpecimensCompanion(
                id: id,
                date: date,
                questionId: questionId,
                questionText: questionText,
                answerText: answerText,
                status: status,
                createdAt: createdAt,
                imageId: imageId,
                localPath: localPath,
                imageRarity: imageRarity,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String date,
                required String questionId,
                required String questionText,
                required String answerText,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                Value<String?> imageId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> imageRarity = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpecimensCompanion.insert(
                id: id,
                date: date,
                questionId: questionId,
                questionText: questionText,
                answerText: answerText,
                status: status,
                createdAt: createdAt,
                imageId: imageId,
                localPath: localPath,
                imageRarity: imageRarity,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpecimensTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpecimensTable,
      Specimen,
      $$SpecimensTableFilterComposer,
      $$SpecimensTableOrderingComposer,
      $$SpecimensTableAnnotationComposer,
      $$SpecimensTableCreateCompanionBuilder,
      $$SpecimensTableUpdateCompanionBuilder,
      (Specimen, BaseReferences<_$AppDatabase, $SpecimensTable, Specimen>),
      Specimen,
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
  $$SpecimensTableTableManager get specimens =>
      $$SpecimensTableTableManager(_db, _db.specimens);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
