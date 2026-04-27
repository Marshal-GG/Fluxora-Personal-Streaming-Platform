// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stream_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

StreamSession _$StreamSessionFromJson(Map<String, dynamic> json) {
  return _StreamSession.fromJson(json);
}

/// @nodoc
mixin _$StreamSession {
  String get id => throw _privateConstructorUsedError;
  String get fileId => throw _privateConstructorUsedError;
  String get clientId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  DateTime get startedAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
  DateTime? get endedAt => throw _privateConstructorUsedError;
  ConnectionType get connectionType => throw _privateConstructorUsedError;
  int? get bytesTransferred => throw _privateConstructorUsedError;
  double? get progressSec => throw _privateConstructorUsedError;

  /// Serializes this StreamSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StreamSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StreamSessionCopyWith<StreamSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StreamSessionCopyWith<$Res> {
  factory $StreamSessionCopyWith(
          StreamSession value, $Res Function(StreamSession) then) =
      _$StreamSessionCopyWithImpl<$Res, StreamSession>;
  @useResult
  $Res call(
      {String id,
      String fileId,
      String clientId,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      DateTime startedAt,
      @JsonKey(
          fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
      DateTime? endedAt,
      ConnectionType connectionType,
      int? bytesTransferred,
      double? progressSec});
}

/// @nodoc
class _$StreamSessionCopyWithImpl<$Res, $Val extends StreamSession>
    implements $StreamSessionCopyWith<$Res> {
  _$StreamSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StreamSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileId = null,
    Object? clientId = null,
    Object? startedAt = null,
    Object? endedAt = freezed,
    Object? connectionType = null,
    Object? bytesTransferred = freezed,
    Object? progressSec = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fileId: null == fileId
          ? _value.fileId
          : fileId // ignore: cast_nullable_to_non_nullable
              as String,
      clientId: null == clientId
          ? _value.clientId
          : clientId // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endedAt: freezed == endedAt
          ? _value.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      connectionType: null == connectionType
          ? _value.connectionType
          : connectionType // ignore: cast_nullable_to_non_nullable
              as ConnectionType,
      bytesTransferred: freezed == bytesTransferred
          ? _value.bytesTransferred
          : bytesTransferred // ignore: cast_nullable_to_non_nullable
              as int?,
      progressSec: freezed == progressSec
          ? _value.progressSec
          : progressSec // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StreamSessionImplCopyWith<$Res>
    implements $StreamSessionCopyWith<$Res> {
  factory _$$StreamSessionImplCopyWith(
          _$StreamSessionImpl value, $Res Function(_$StreamSessionImpl) then) =
      __$$StreamSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String fileId,
      String clientId,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      DateTime startedAt,
      @JsonKey(
          fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
      DateTime? endedAt,
      ConnectionType connectionType,
      int? bytesTransferred,
      double? progressSec});
}

/// @nodoc
class __$$StreamSessionImplCopyWithImpl<$Res>
    extends _$StreamSessionCopyWithImpl<$Res, _$StreamSessionImpl>
    implements _$$StreamSessionImplCopyWith<$Res> {
  __$$StreamSessionImplCopyWithImpl(
      _$StreamSessionImpl _value, $Res Function(_$StreamSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of StreamSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fileId = null,
    Object? clientId = null,
    Object? startedAt = null,
    Object? endedAt = freezed,
    Object? connectionType = null,
    Object? bytesTransferred = freezed,
    Object? progressSec = freezed,
  }) {
    return _then(_$StreamSessionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fileId: null == fileId
          ? _value.fileId
          : fileId // ignore: cast_nullable_to_non_nullable
              as String,
      clientId: null == clientId
          ? _value.clientId
          : clientId // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endedAt: freezed == endedAt
          ? _value.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      connectionType: null == connectionType
          ? _value.connectionType
          : connectionType // ignore: cast_nullable_to_non_nullable
              as ConnectionType,
      bytesTransferred: freezed == bytesTransferred
          ? _value.bytesTransferred
          : bytesTransferred // ignore: cast_nullable_to_non_nullable
              as int?,
      progressSec: freezed == progressSec
          ? _value.progressSec
          : progressSec // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StreamSessionImpl implements _StreamSession {
  const _$StreamSessionImpl(
      {required this.id,
      required this.fileId,
      required this.clientId,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      required this.startedAt,
      @JsonKey(
          fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
      this.endedAt,
      required this.connectionType,
      this.bytesTransferred,
      this.progressSec});

  factory _$StreamSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$StreamSessionImplFromJson(json);

  @override
  final String id;
  @override
  final String fileId;
  @override
  final String clientId;
  @override
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  final DateTime startedAt;
  @override
  @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
  final DateTime? endedAt;
  @override
  final ConnectionType connectionType;
  @override
  final int? bytesTransferred;
  @override
  final double? progressSec;

  @override
  String toString() {
    return 'StreamSession(id: $id, fileId: $fileId, clientId: $clientId, startedAt: $startedAt, endedAt: $endedAt, connectionType: $connectionType, bytesTransferred: $bytesTransferred, progressSec: $progressSec)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StreamSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fileId, fileId) || other.fileId == fileId) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
            (identical(other.connectionType, connectionType) ||
                other.connectionType == connectionType) &&
            (identical(other.bytesTransferred, bytesTransferred) ||
                other.bytesTransferred == bytesTransferred) &&
            (identical(other.progressSec, progressSec) ||
                other.progressSec == progressSec));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fileId, clientId, startedAt,
      endedAt, connectionType, bytesTransferred, progressSec);

  /// Create a copy of StreamSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StreamSessionImplCopyWith<_$StreamSessionImpl> get copyWith =>
      __$$StreamSessionImplCopyWithImpl<_$StreamSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StreamSessionImplToJson(
      this,
    );
  }
}

abstract class _StreamSession implements StreamSession {
  const factory _StreamSession(
      {required final String id,
      required final String fileId,
      required final String clientId,
      @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
      required final DateTime startedAt,
      @JsonKey(
          fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
      final DateTime? endedAt,
      required final ConnectionType connectionType,
      final int? bytesTransferred,
      final double? progressSec}) = _$StreamSessionImpl;

  factory _StreamSession.fromJson(Map<String, dynamic> json) =
      _$StreamSessionImpl.fromJson;

  @override
  String get id;
  @override
  String get fileId;
  @override
  String get clientId;
  @override
  @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
  DateTime get startedAt;
  @override
  @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)
  DateTime? get endedAt;
  @override
  ConnectionType get connectionType;
  @override
  int? get bytesTransferred;
  @override
  double? get progressSec;

  /// Create a copy of StreamSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StreamSessionImplCopyWith<_$StreamSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
