// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Library _$LibraryFromJson(Map<String, dynamic> json) {
  return _Library.fromJson(json);
}

/// @nodoc
mixin _$Library {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  LibraryType get type => throw _privateConstructorUsedError;
  List<String> get rootPaths => throw _privateConstructorUsedError;
  @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
  DateTime? get lastScanned => throw _privateConstructorUsedError;
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Library to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Library
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LibraryCopyWith<Library> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LibraryCopyWith<$Res> {
  factory $LibraryCopyWith(Library value, $Res Function(Library) then) =
      _$LibraryCopyWithImpl<$Res, Library>;
  @useResult
  $Res call(
      {String id,
      String name,
      LibraryType type,
      List<String> rootPaths,
      @JsonKey(
          fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
      DateTime? lastScanned,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      DateTime createdAt});
}

/// @nodoc
class _$LibraryCopyWithImpl<$Res, $Val extends Library>
    implements $LibraryCopyWith<$Res> {
  _$LibraryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Library
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? rootPaths = null,
    Object? lastScanned = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as LibraryType,
      rootPaths: null == rootPaths
          ? _value.rootPaths
          : rootPaths // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastScanned: freezed == lastScanned
          ? _value.lastScanned
          : lastScanned // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LibraryImplCopyWith<$Res> implements $LibraryCopyWith<$Res> {
  factory _$$LibraryImplCopyWith(
          _$LibraryImpl value, $Res Function(_$LibraryImpl) then) =
      __$$LibraryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      LibraryType type,
      List<String> rootPaths,
      @JsonKey(
          fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
      DateTime? lastScanned,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      DateTime createdAt});
}

/// @nodoc
class __$$LibraryImplCopyWithImpl<$Res>
    extends _$LibraryCopyWithImpl<$Res, _$LibraryImpl>
    implements _$$LibraryImplCopyWith<$Res> {
  __$$LibraryImplCopyWithImpl(
      _$LibraryImpl _value, $Res Function(_$LibraryImpl) _then)
      : super(_value, _then);

  /// Create a copy of Library
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? rootPaths = null,
    Object? lastScanned = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$LibraryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as LibraryType,
      rootPaths: null == rootPaths
          ? _value._rootPaths
          : rootPaths // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastScanned: freezed == lastScanned
          ? _value.lastScanned
          : lastScanned // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LibraryImpl implements _Library {
  const _$LibraryImpl(
      {required this.id,
      required this.name,
      required this.type,
      required final List<String> rootPaths,
      @JsonKey(
          fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
      this.lastScanned,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      required this.createdAt})
      : _rootPaths = rootPaths;

  factory _$LibraryImpl.fromJson(Map<String, dynamic> json) =>
      _$$LibraryImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final LibraryType type;
  final List<String> _rootPaths;
  @override
  List<String> get rootPaths {
    if (_rootPaths is EqualUnmodifiableListView) return _rootPaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rootPaths);
  }

  @override
  @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
  final DateTime? lastScanned;
  @override
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  final DateTime createdAt;

  @override
  String toString() {
    return 'Library(id: $id, name: $name, type: $type, rootPaths: $rootPaths, lastScanned: $lastScanned, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LibraryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality()
                .equals(other._rootPaths, _rootPaths) &&
            (identical(other.lastScanned, lastScanned) ||
                other.lastScanned == lastScanned) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, type,
      const DeepCollectionEquality().hash(_rootPaths), lastScanned, createdAt);

  /// Create a copy of Library
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LibraryImplCopyWith<_$LibraryImpl> get copyWith =>
      __$$LibraryImplCopyWithImpl<_$LibraryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LibraryImplToJson(
      this,
    );
  }
}

abstract class _Library implements Library {
  const factory _Library(
      {required final String id,
      required final String name,
      required final LibraryType type,
      required final List<String> rootPaths,
      @JsonKey(
          fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
      final DateTime? lastScanned,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      required final DateTime createdAt}) = _$LibraryImpl;

  factory _Library.fromJson(Map<String, dynamic> json) = _$LibraryImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  LibraryType get type;
  @override
  List<String> get rootPaths;
  @override
  @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
  DateTime? get lastScanned;
  @override
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  DateTime get createdAt;

  /// Create a copy of Library
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LibraryImplCopyWith<_$LibraryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
