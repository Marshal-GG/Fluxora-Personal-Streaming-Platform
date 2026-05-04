// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fallback_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FallbackEvent {

 String get timestamp; String get sessionId; String get requestedEncoder; String get actualEncoder; String get reason;
/// Create a copy of FallbackEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FallbackEventCopyWith<FallbackEvent> get copyWith => _$FallbackEventCopyWithImpl<FallbackEvent>(this as FallbackEvent, _$identity);

  /// Serializes this FallbackEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FallbackEvent&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.requestedEncoder, requestedEncoder) || other.requestedEncoder == requestedEncoder)&&(identical(other.actualEncoder, actualEncoder) || other.actualEncoder == actualEncoder)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,sessionId,requestedEncoder,actualEncoder,reason);

@override
String toString() {
  return 'FallbackEvent(timestamp: $timestamp, sessionId: $sessionId, requestedEncoder: $requestedEncoder, actualEncoder: $actualEncoder, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $FallbackEventCopyWith<$Res>  {
  factory $FallbackEventCopyWith(FallbackEvent value, $Res Function(FallbackEvent) _then) = _$FallbackEventCopyWithImpl;
@useResult
$Res call({
 String timestamp, String sessionId, String requestedEncoder, String actualEncoder, String reason
});




}
/// @nodoc
class _$FallbackEventCopyWithImpl<$Res>
    implements $FallbackEventCopyWith<$Res> {
  _$FallbackEventCopyWithImpl(this._self, this._then);

  final FallbackEvent _self;
  final $Res Function(FallbackEvent) _then;

/// Create a copy of FallbackEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? sessionId = null,Object? requestedEncoder = null,Object? actualEncoder = null,Object? reason = null,}) {
  return _then(_self.copyWith(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,requestedEncoder: null == requestedEncoder ? _self.requestedEncoder : requestedEncoder // ignore: cast_nullable_to_non_nullable
as String,actualEncoder: null == actualEncoder ? _self.actualEncoder : actualEncoder // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FallbackEvent].
extension FallbackEventPatterns on FallbackEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FallbackEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FallbackEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FallbackEvent value)  $default,){
final _that = this;
switch (_that) {
case _FallbackEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FallbackEvent value)?  $default,){
final _that = this;
switch (_that) {
case _FallbackEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String timestamp,  String sessionId,  String requestedEncoder,  String actualEncoder,  String reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FallbackEvent() when $default != null:
return $default(_that.timestamp,_that.sessionId,_that.requestedEncoder,_that.actualEncoder,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String timestamp,  String sessionId,  String requestedEncoder,  String actualEncoder,  String reason)  $default,) {final _that = this;
switch (_that) {
case _FallbackEvent():
return $default(_that.timestamp,_that.sessionId,_that.requestedEncoder,_that.actualEncoder,_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String timestamp,  String sessionId,  String requestedEncoder,  String actualEncoder,  String reason)?  $default,) {final _that = this;
switch (_that) {
case _FallbackEvent() when $default != null:
return $default(_that.timestamp,_that.sessionId,_that.requestedEncoder,_that.actualEncoder,_that.reason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FallbackEvent implements FallbackEvent {
  const _FallbackEvent({required this.timestamp, required this.sessionId, required this.requestedEncoder, required this.actualEncoder, required this.reason});
  factory _FallbackEvent.fromJson(Map<String, dynamic> json) => _$FallbackEventFromJson(json);

@override final  String timestamp;
@override final  String sessionId;
@override final  String requestedEncoder;
@override final  String actualEncoder;
@override final  String reason;

/// Create a copy of FallbackEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FallbackEventCopyWith<_FallbackEvent> get copyWith => __$FallbackEventCopyWithImpl<_FallbackEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FallbackEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FallbackEvent&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.requestedEncoder, requestedEncoder) || other.requestedEncoder == requestedEncoder)&&(identical(other.actualEncoder, actualEncoder) || other.actualEncoder == actualEncoder)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,sessionId,requestedEncoder,actualEncoder,reason);

@override
String toString() {
  return 'FallbackEvent(timestamp: $timestamp, sessionId: $sessionId, requestedEncoder: $requestedEncoder, actualEncoder: $actualEncoder, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$FallbackEventCopyWith<$Res> implements $FallbackEventCopyWith<$Res> {
  factory _$FallbackEventCopyWith(_FallbackEvent value, $Res Function(_FallbackEvent) _then) = __$FallbackEventCopyWithImpl;
@override @useResult
$Res call({
 String timestamp, String sessionId, String requestedEncoder, String actualEncoder, String reason
});




}
/// @nodoc
class __$FallbackEventCopyWithImpl<$Res>
    implements _$FallbackEventCopyWith<$Res> {
  __$FallbackEventCopyWithImpl(this._self, this._then);

  final _FallbackEvent _self;
  final $Res Function(_FallbackEvent) _then;

/// Create a copy of FallbackEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? sessionId = null,Object? requestedEncoder = null,Object? actualEncoder = null,Object? reason = null,}) {
  return _then(_FallbackEvent(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,requestedEncoder: null == requestedEncoder ? _self.requestedEncoder : requestedEncoder // ignore: cast_nullable_to_non_nullable
as String,actualEncoder: null == actualEncoder ? _self.actualEncoder : actualEncoder // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$FallbackHistory {

 List<FallbackEvent> get events;
/// Create a copy of FallbackHistory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FallbackHistoryCopyWith<FallbackHistory> get copyWith => _$FallbackHistoryCopyWithImpl<FallbackHistory>(this as FallbackHistory, _$identity);

  /// Serializes this FallbackHistory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FallbackHistory&&const DeepCollectionEquality().equals(other.events, events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(events));

@override
String toString() {
  return 'FallbackHistory(events: $events)';
}


}

/// @nodoc
abstract mixin class $FallbackHistoryCopyWith<$Res>  {
  factory $FallbackHistoryCopyWith(FallbackHistory value, $Res Function(FallbackHistory) _then) = _$FallbackHistoryCopyWithImpl;
@useResult
$Res call({
 List<FallbackEvent> events
});




}
/// @nodoc
class _$FallbackHistoryCopyWithImpl<$Res>
    implements $FallbackHistoryCopyWith<$Res> {
  _$FallbackHistoryCopyWithImpl(this._self, this._then);

  final FallbackHistory _self;
  final $Res Function(FallbackHistory) _then;

/// Create a copy of FallbackHistory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? events = null,}) {
  return _then(_self.copyWith(
events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<FallbackEvent>,
  ));
}

}


/// Adds pattern-matching-related methods to [FallbackHistory].
extension FallbackHistoryPatterns on FallbackHistory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FallbackHistory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FallbackHistory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FallbackHistory value)  $default,){
final _that = this;
switch (_that) {
case _FallbackHistory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FallbackHistory value)?  $default,){
final _that = this;
switch (_that) {
case _FallbackHistory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<FallbackEvent> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FallbackHistory() when $default != null:
return $default(_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<FallbackEvent> events)  $default,) {final _that = this;
switch (_that) {
case _FallbackHistory():
return $default(_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<FallbackEvent> events)?  $default,) {final _that = this;
switch (_that) {
case _FallbackHistory() when $default != null:
return $default(_that.events);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FallbackHistory implements FallbackHistory {
  const _FallbackHistory({final  List<FallbackEvent> events = const []}): _events = events;
  factory _FallbackHistory.fromJson(Map<String, dynamic> json) => _$FallbackHistoryFromJson(json);

 final  List<FallbackEvent> _events;
@override@JsonKey() List<FallbackEvent> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of FallbackHistory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FallbackHistoryCopyWith<_FallbackHistory> get copyWith => __$FallbackHistoryCopyWithImpl<_FallbackHistory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FallbackHistoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FallbackHistory&&const DeepCollectionEquality().equals(other._events, _events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_events));

@override
String toString() {
  return 'FallbackHistory(events: $events)';
}


}

/// @nodoc
abstract mixin class _$FallbackHistoryCopyWith<$Res> implements $FallbackHistoryCopyWith<$Res> {
  factory _$FallbackHistoryCopyWith(_FallbackHistory value, $Res Function(_FallbackHistory) _then) = __$FallbackHistoryCopyWithImpl;
@override @useResult
$Res call({
 List<FallbackEvent> events
});




}
/// @nodoc
class __$FallbackHistoryCopyWithImpl<$Res>
    implements _$FallbackHistoryCopyWith<$Res> {
  __$FallbackHistoryCopyWithImpl(this._self, this._then);

  final _FallbackHistory _self;
  final $Res Function(_FallbackHistory) _then;

/// Create a copy of FallbackHistory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? events = null,}) {
  return _then(_FallbackHistory(
events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<FallbackEvent>,
  ));
}


}

// dart format on
