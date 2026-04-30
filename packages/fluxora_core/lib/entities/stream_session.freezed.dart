// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stream_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StreamSession {

 String get id; String get fileId; String get clientId;@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime get startedAt;@JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) DateTime? get endedAt; ConnectionType get connectionType; int? get bytesTransferred; double? get progressSec;
/// Create a copy of StreamSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreamSessionCopyWith<StreamSession> get copyWith => _$StreamSessionCopyWithImpl<StreamSession>(this as StreamSession, _$identity);

  /// Serializes this StreamSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreamSession&&(identical(other.id, id) || other.id == id)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.connectionType, connectionType) || other.connectionType == connectionType)&&(identical(other.bytesTransferred, bytesTransferred) || other.bytesTransferred == bytesTransferred)&&(identical(other.progressSec, progressSec) || other.progressSec == progressSec));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fileId,clientId,startedAt,endedAt,connectionType,bytesTransferred,progressSec);

@override
String toString() {
  return 'StreamSession(id: $id, fileId: $fileId, clientId: $clientId, startedAt: $startedAt, endedAt: $endedAt, connectionType: $connectionType, bytesTransferred: $bytesTransferred, progressSec: $progressSec)';
}


}

/// @nodoc
abstract mixin class $StreamSessionCopyWith<$Res>  {
  factory $StreamSessionCopyWith(StreamSession value, $Res Function(StreamSession) _then) = _$StreamSessionCopyWithImpl;
@useResult
$Res call({
 String id, String fileId, String clientId,@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime startedAt,@JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) DateTime? endedAt, ConnectionType connectionType, int? bytesTransferred, double? progressSec
});




}
/// @nodoc
class _$StreamSessionCopyWithImpl<$Res>
    implements $StreamSessionCopyWith<$Res> {
  _$StreamSessionCopyWithImpl(this._self, this._then);

  final StreamSession _self;
  final $Res Function(StreamSession) _then;

/// Create a copy of StreamSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fileId = null,Object? clientId = null,Object? startedAt = null,Object? endedAt = freezed,Object? connectionType = null,Object? bytesTransferred = freezed,Object? progressSec = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,connectionType: null == connectionType ? _self.connectionType : connectionType // ignore: cast_nullable_to_non_nullable
as ConnectionType,bytesTransferred: freezed == bytesTransferred ? _self.bytesTransferred : bytesTransferred // ignore: cast_nullable_to_non_nullable
as int?,progressSec: freezed == progressSec ? _self.progressSec : progressSec // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [StreamSession].
extension StreamSessionPatterns on StreamSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StreamSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StreamSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StreamSession value)  $default,){
final _that = this;
switch (_that) {
case _StreamSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StreamSession value)?  $default,){
final _that = this;
switch (_that) {
case _StreamSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fileId,  String clientId, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime startedAt, @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)  DateTime? endedAt,  ConnectionType connectionType,  int? bytesTransferred,  double? progressSec)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StreamSession() when $default != null:
return $default(_that.id,_that.fileId,_that.clientId,_that.startedAt,_that.endedAt,_that.connectionType,_that.bytesTransferred,_that.progressSec);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fileId,  String clientId, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime startedAt, @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)  DateTime? endedAt,  ConnectionType connectionType,  int? bytesTransferred,  double? progressSec)  $default,) {final _that = this;
switch (_that) {
case _StreamSession():
return $default(_that.id,_that.fileId,_that.clientId,_that.startedAt,_that.endedAt,_that.connectionType,_that.bytesTransferred,_that.progressSec);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fileId,  String clientId, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime startedAt, @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)  DateTime? endedAt,  ConnectionType connectionType,  int? bytesTransferred,  double? progressSec)?  $default,) {final _that = this;
switch (_that) {
case _StreamSession() when $default != null:
return $default(_that.id,_that.fileId,_that.clientId,_that.startedAt,_that.endedAt,_that.connectionType,_that.bytesTransferred,_that.progressSec);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StreamSession implements StreamSession {
  const _StreamSession({required this.id, required this.fileId, required this.clientId, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) required this.startedAt, @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) this.endedAt, required this.connectionType, this.bytesTransferred, this.progressSec});
  factory _StreamSession.fromJson(Map<String, dynamic> json) => _$StreamSessionFromJson(json);

@override final  String id;
@override final  String fileId;
@override final  String clientId;
@override@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) final  DateTime startedAt;
@override@JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) final  DateTime? endedAt;
@override final  ConnectionType connectionType;
@override final  int? bytesTransferred;
@override final  double? progressSec;

/// Create a copy of StreamSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StreamSessionCopyWith<_StreamSession> get copyWith => __$StreamSessionCopyWithImpl<_StreamSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StreamSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StreamSession&&(identical(other.id, id) || other.id == id)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.connectionType, connectionType) || other.connectionType == connectionType)&&(identical(other.bytesTransferred, bytesTransferred) || other.bytesTransferred == bytesTransferred)&&(identical(other.progressSec, progressSec) || other.progressSec == progressSec));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fileId,clientId,startedAt,endedAt,connectionType,bytesTransferred,progressSec);

@override
String toString() {
  return 'StreamSession(id: $id, fileId: $fileId, clientId: $clientId, startedAt: $startedAt, endedAt: $endedAt, connectionType: $connectionType, bytesTransferred: $bytesTransferred, progressSec: $progressSec)';
}


}

/// @nodoc
abstract mixin class _$StreamSessionCopyWith<$Res> implements $StreamSessionCopyWith<$Res> {
  factory _$StreamSessionCopyWith(_StreamSession value, $Res Function(_StreamSession) _then) = __$StreamSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String fileId, String clientId,@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime startedAt,@JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) DateTime? endedAt, ConnectionType connectionType, int? bytesTransferred, double? progressSec
});




}
/// @nodoc
class __$StreamSessionCopyWithImpl<$Res>
    implements _$StreamSessionCopyWith<$Res> {
  __$StreamSessionCopyWithImpl(this._self, this._then);

  final _StreamSession _self;
  final $Res Function(_StreamSession) _then;

/// Create a copy of StreamSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fileId = null,Object? clientId = null,Object? startedAt = null,Object? endedAt = freezed,Object? connectionType = null,Object? bytesTransferred = freezed,Object? progressSec = freezed,}) {
  return _then(_StreamSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,connectionType: null == connectionType ? _self.connectionType : connectionType // ignore: cast_nullable_to_non_nullable
as ConnectionType,bytesTransferred: freezed == bytesTransferred ? _self.bytesTransferred : bytesTransferred // ignore: cast_nullable_to_non_nullable
as int?,progressSec: freezed == progressSec ? _self.progressSec : progressSec // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
