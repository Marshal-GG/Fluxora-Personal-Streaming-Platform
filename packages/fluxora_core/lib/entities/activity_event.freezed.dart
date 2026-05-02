// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActivityEvent {

 String get id;/// Category string e.g. 'stream.start', 'client.pair', 'storage', 'system'.
 String get type;/// 'client' | 'system' | 'operator' | null
 String? get actorKind; String? get actorId; String? get targetKind; String? get targetId;/// Human-readable summary shown in the activity row.
 String get summary;/// Arbitrary JSON payload attached to the event.
 Map<String, dynamic>? get payload;/// ISO-8601 UTC timestamp.
 String get createdAt;
/// Create a copy of ActivityEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityEventCopyWith<ActivityEvent> get copyWith => _$ActivityEventCopyWithImpl<ActivityEvent>(this as ActivityEvent, _$identity);

  /// Serializes this ActivityEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actorKind, actorKind) || other.actorKind == actorKind)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.targetKind, targetKind) || other.targetKind == targetKind)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,actorKind,actorId,targetKind,targetId,summary,const DeepCollectionEquality().hash(payload),createdAt);

@override
String toString() {
  return 'ActivityEvent(id: $id, type: $type, actorKind: $actorKind, actorId: $actorId, targetKind: $targetKind, targetId: $targetId, summary: $summary, payload: $payload, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ActivityEventCopyWith<$Res>  {
  factory $ActivityEventCopyWith(ActivityEvent value, $Res Function(ActivityEvent) _then) = _$ActivityEventCopyWithImpl;
@useResult
$Res call({
 String id, String type, String? actorKind, String? actorId, String? targetKind, String? targetId, String summary, Map<String, dynamic>? payload, String createdAt
});




}
/// @nodoc
class _$ActivityEventCopyWithImpl<$Res>
    implements $ActivityEventCopyWith<$Res> {
  _$ActivityEventCopyWithImpl(this._self, this._then);

  final ActivityEvent _self;
  final $Res Function(ActivityEvent) _then;

/// Create a copy of ActivityEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? actorKind = freezed,Object? actorId = freezed,Object? targetKind = freezed,Object? targetId = freezed,Object? summary = null,Object? payload = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,actorKind: freezed == actorKind ? _self.actorKind : actorKind // ignore: cast_nullable_to_non_nullable
as String?,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,targetKind: freezed == targetKind ? _self.targetKind : targetKind // ignore: cast_nullable_to_non_nullable
as String?,targetId: freezed == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String?,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,payload: freezed == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityEvent].
extension ActivityEventPatterns on ActivityEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityEvent value)  $default,){
final _that = this;
switch (_that) {
case _ActivityEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String? actorKind,  String? actorId,  String? targetKind,  String? targetId,  String summary,  Map<String, dynamic>? payload,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityEvent() when $default != null:
return $default(_that.id,_that.type,_that.actorKind,_that.actorId,_that.targetKind,_that.targetId,_that.summary,_that.payload,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String? actorKind,  String? actorId,  String? targetKind,  String? targetId,  String summary,  Map<String, dynamic>? payload,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _ActivityEvent():
return $default(_that.id,_that.type,_that.actorKind,_that.actorId,_that.targetKind,_that.targetId,_that.summary,_that.payload,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String? actorKind,  String? actorId,  String? targetKind,  String? targetId,  String summary,  Map<String, dynamic>? payload,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ActivityEvent() when $default != null:
return $default(_that.id,_that.type,_that.actorKind,_that.actorId,_that.targetKind,_that.targetId,_that.summary,_that.payload,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActivityEvent implements ActivityEvent {
  const _ActivityEvent({required this.id, required this.type, this.actorKind, this.actorId, this.targetKind, this.targetId, required this.summary, final  Map<String, dynamic>? payload, required this.createdAt}): _payload = payload;
  factory _ActivityEvent.fromJson(Map<String, dynamic> json) => _$ActivityEventFromJson(json);

@override final  String id;
/// Category string e.g. 'stream.start', 'client.pair', 'storage', 'system'.
@override final  String type;
/// 'client' | 'system' | 'operator' | null
@override final  String? actorKind;
@override final  String? actorId;
@override final  String? targetKind;
@override final  String? targetId;
/// Human-readable summary shown in the activity row.
@override final  String summary;
/// Arbitrary JSON payload attached to the event.
 final  Map<String, dynamic>? _payload;
/// Arbitrary JSON payload attached to the event.
@override Map<String, dynamic>? get payload {
  final value = _payload;
  if (value == null) return null;
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// ISO-8601 UTC timestamp.
@override final  String createdAt;

/// Create a copy of ActivityEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityEventCopyWith<_ActivityEvent> get copyWith => __$ActivityEventCopyWithImpl<_ActivityEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivityEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.actorKind, actorKind) || other.actorKind == actorKind)&&(identical(other.actorId, actorId) || other.actorId == actorId)&&(identical(other.targetKind, targetKind) || other.targetKind == targetKind)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,actorKind,actorId,targetKind,targetId,summary,const DeepCollectionEquality().hash(_payload),createdAt);

@override
String toString() {
  return 'ActivityEvent(id: $id, type: $type, actorKind: $actorKind, actorId: $actorId, targetKind: $targetKind, targetId: $targetId, summary: $summary, payload: $payload, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ActivityEventCopyWith<$Res> implements $ActivityEventCopyWith<$Res> {
  factory _$ActivityEventCopyWith(_ActivityEvent value, $Res Function(_ActivityEvent) _then) = __$ActivityEventCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String? actorKind, String? actorId, String? targetKind, String? targetId, String summary, Map<String, dynamic>? payload, String createdAt
});




}
/// @nodoc
class __$ActivityEventCopyWithImpl<$Res>
    implements _$ActivityEventCopyWith<$Res> {
  __$ActivityEventCopyWithImpl(this._self, this._then);

  final _ActivityEvent _self;
  final $Res Function(_ActivityEvent) _then;

/// Create a copy of ActivityEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? actorKind = freezed,Object? actorId = freezed,Object? targetKind = freezed,Object? targetId = freezed,Object? summary = null,Object? payload = freezed,Object? createdAt = null,}) {
  return _then(_ActivityEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,actorKind: freezed == actorKind ? _self.actorKind : actorKind // ignore: cast_nullable_to_non_nullable
as String?,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,targetKind: freezed == targetKind ? _self.targetKind : targetKind // ignore: cast_nullable_to_non_nullable
as String?,targetId: freezed == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String?,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,payload: freezed == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
