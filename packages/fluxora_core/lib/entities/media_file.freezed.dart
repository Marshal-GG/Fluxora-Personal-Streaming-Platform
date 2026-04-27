// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_file.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MediaFile _$MediaFileFromJson(Map<String, dynamic> json) {
  return _MediaFile.fromJson(json);
}

/// @nodoc
mixin _$MediaFile {
  String get id => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get extension => throw _privateConstructorUsedError;
  int get sizeBytes => throw _privateConstructorUsedError;
  double? get durationSec => throw _privateConstructorUsedError;
  String? get libraryId => throw _privateConstructorUsedError;
  int? get tmdbId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this MediaFile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MediaFile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaFileCopyWith<MediaFile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaFileCopyWith<$Res> {
  factory $MediaFileCopyWith(MediaFile value, $Res Function(MediaFile) then) =
      _$MediaFileCopyWithImpl<$Res, MediaFile>;
  @useResult
  $Res call(
      {String id,
      String path,
      String name,
      String extension,
      int sizeBytes,
      double? durationSec,
      String? libraryId,
      int? tmdbId,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      DateTime createdAt,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      DateTime updatedAt});
}

/// @nodoc
class _$MediaFileCopyWithImpl<$Res, $Val extends MediaFile>
    implements $MediaFileCopyWith<$Res> {
  _$MediaFileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaFile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? path = null,
    Object? name = null,
    Object? extension = null,
    Object? sizeBytes = null,
    Object? durationSec = freezed,
    Object? libraryId = freezed,
    Object? tmdbId = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      path: null == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      extension: null == extension
          ? _value.extension
          : extension // ignore: cast_nullable_to_non_nullable
              as String,
      sizeBytes: null == sizeBytes
          ? _value.sizeBytes
          : sizeBytes // ignore: cast_nullable_to_non_nullable
              as int,
      durationSec: freezed == durationSec
          ? _value.durationSec
          : durationSec // ignore: cast_nullable_to_non_nullable
              as double?,
      libraryId: freezed == libraryId
          ? _value.libraryId
          : libraryId // ignore: cast_nullable_to_non_nullable
              as String?,
      tmdbId: freezed == tmdbId
          ? _value.tmdbId
          : tmdbId // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MediaFileImplCopyWith<$Res>
    implements $MediaFileCopyWith<$Res> {
  factory _$$MediaFileImplCopyWith(
          _$MediaFileImpl value, $Res Function(_$MediaFileImpl) then) =
      __$$MediaFileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String path,
      String name,
      String extension,
      int sizeBytes,
      double? durationSec,
      String? libraryId,
      int? tmdbId,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      DateTime createdAt,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      DateTime updatedAt});
}

/// @nodoc
class __$$MediaFileImplCopyWithImpl<$Res>
    extends _$MediaFileCopyWithImpl<$Res, _$MediaFileImpl>
    implements _$$MediaFileImplCopyWith<$Res> {
  __$$MediaFileImplCopyWithImpl(
      _$MediaFileImpl _value, $Res Function(_$MediaFileImpl) _then)
      : super(_value, _then);

  /// Create a copy of MediaFile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? path = null,
    Object? name = null,
    Object? extension = null,
    Object? sizeBytes = null,
    Object? durationSec = freezed,
    Object? libraryId = freezed,
    Object? tmdbId = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$MediaFileImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      path: null == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      extension: null == extension
          ? _value.extension
          : extension // ignore: cast_nullable_to_non_nullable
              as String,
      sizeBytes: null == sizeBytes
          ? _value.sizeBytes
          : sizeBytes // ignore: cast_nullable_to_non_nullable
              as int,
      durationSec: freezed == durationSec
          ? _value.durationSec
          : durationSec // ignore: cast_nullable_to_non_nullable
              as double?,
      libraryId: freezed == libraryId
          ? _value.libraryId
          : libraryId // ignore: cast_nullable_to_non_nullable
              as String?,
      tmdbId: freezed == tmdbId
          ? _value.tmdbId
          : tmdbId // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MediaFileImpl implements _MediaFile {
  const _$MediaFileImpl(
      {required this.id,
      required this.path,
      required this.name,
      required this.extension,
      required this.sizeBytes,
      this.durationSec,
      this.libraryId,
      this.tmdbId,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      required this.createdAt,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      required this.updatedAt});

  factory _$MediaFileImpl.fromJson(Map<String, dynamic> json) =>
      _$$MediaFileImplFromJson(json);

  @override
  final String id;
  @override
  final String path;
  @override
  final String name;
  @override
  final String extension;
  @override
  final int sizeBytes;
  @override
  final double? durationSec;
  @override
  final String? libraryId;
  @override
  final int? tmdbId;
  @override
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  final DateTime createdAt;
  @override
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  final DateTime updatedAt;

  @override
  String toString() {
    return 'MediaFile(id: $id, path: $path, name: $name, extension: $extension, sizeBytes: $sizeBytes, durationSec: $durationSec, libraryId: $libraryId, tmdbId: $tmdbId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaFileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.extension, extension) ||
                other.extension == extension) &&
            (identical(other.sizeBytes, sizeBytes) ||
                other.sizeBytes == sizeBytes) &&
            (identical(other.durationSec, durationSec) ||
                other.durationSec == durationSec) &&
            (identical(other.libraryId, libraryId) ||
                other.libraryId == libraryId) &&
            (identical(other.tmdbId, tmdbId) || other.tmdbId == tmdbId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, path, name, extension,
      sizeBytes, durationSec, libraryId, tmdbId, createdAt, updatedAt);

  /// Create a copy of MediaFile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaFileImplCopyWith<_$MediaFileImpl> get copyWith =>
      __$$MediaFileImplCopyWithImpl<_$MediaFileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MediaFileImplToJson(
      this,
    );
  }
}

abstract class _MediaFile implements MediaFile {
  const factory _MediaFile(
      {required final String id,
      required final String path,
      required final String name,
      required final String extension,
      required final int sizeBytes,
      final double? durationSec,
      final String? libraryId,
      final int? tmdbId,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      required final DateTime createdAt,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      required final DateTime updatedAt}) = _$MediaFileImpl;

  factory _MediaFile.fromJson(Map<String, dynamic> json) =
      _$MediaFileImpl.fromJson;

  @override
  String get id;
  @override
  String get path;
  @override
  String get name;
  @override
  String get extension;
  @override
  int get sizeBytes;
  @override
  double? get durationSec;
  @override
  String? get libraryId;
  @override
  int? get tmdbId;
  @override
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  DateTime get createdAt;
  @override
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  DateTime get updatedAt;

  /// Create a copy of MediaFile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaFileImplCopyWith<_$MediaFileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
