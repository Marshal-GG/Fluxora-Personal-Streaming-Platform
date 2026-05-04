// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClientStats {

 int get hours; int get movies; int get shows;
/// Create a copy of ClientStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientStatsCopyWith<ClientStats> get copyWith => _$ClientStatsCopyWithImpl<ClientStats>(this as ClientStats, _$identity);

  /// Serializes this ClientStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientStats&&(identical(other.hours, hours) || other.hours == hours)&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.shows, shows) || other.shows == shows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hours,movies,shows);

@override
String toString() {
  return 'ClientStats(hours: $hours, movies: $movies, shows: $shows)';
}


}

/// @nodoc
abstract mixin class $ClientStatsCopyWith<$Res>  {
  factory $ClientStatsCopyWith(ClientStats value, $Res Function(ClientStats) _then) = _$ClientStatsCopyWithImpl;
@useResult
$Res call({
 int hours, int movies, int shows
});




}
/// @nodoc
class _$ClientStatsCopyWithImpl<$Res>
    implements $ClientStatsCopyWith<$Res> {
  _$ClientStatsCopyWithImpl(this._self, this._then);

  final ClientStats _self;
  final $Res Function(ClientStats) _then;

/// Create a copy of ClientStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hours = null,Object? movies = null,Object? shows = null,}) {
  return _then(_self.copyWith(
hours: null == hours ? _self.hours : hours // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,shows: null == shows ? _self.shows : shows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ClientStats].
extension ClientStatsPatterns on ClientStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientStats value)  $default,){
final _that = this;
switch (_that) {
case _ClientStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientStats value)?  $default,){
final _that = this;
switch (_that) {
case _ClientStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int hours,  int movies,  int shows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientStats() when $default != null:
return $default(_that.hours,_that.movies,_that.shows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int hours,  int movies,  int shows)  $default,) {final _that = this;
switch (_that) {
case _ClientStats():
return $default(_that.hours,_that.movies,_that.shows);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int hours,  int movies,  int shows)?  $default,) {final _that = this;
switch (_that) {
case _ClientStats() when $default != null:
return $default(_that.hours,_that.movies,_that.shows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClientStats implements ClientStats {
  const _ClientStats({required this.hours, required this.movies, required this.shows});
  factory _ClientStats.fromJson(Map<String, dynamic> json) => _$ClientStatsFromJson(json);

@override final  int hours;
@override final  int movies;
@override final  int shows;

/// Create a copy of ClientStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientStatsCopyWith<_ClientStats> get copyWith => __$ClientStatsCopyWithImpl<_ClientStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientStats&&(identical(other.hours, hours) || other.hours == hours)&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.shows, shows) || other.shows == shows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hours,movies,shows);

@override
String toString() {
  return 'ClientStats(hours: $hours, movies: $movies, shows: $shows)';
}


}

/// @nodoc
abstract mixin class _$ClientStatsCopyWith<$Res> implements $ClientStatsCopyWith<$Res> {
  factory _$ClientStatsCopyWith(_ClientStats value, $Res Function(_ClientStats) _then) = __$ClientStatsCopyWithImpl;
@override @useResult
$Res call({
 int hours, int movies, int shows
});




}
/// @nodoc
class __$ClientStatsCopyWithImpl<$Res>
    implements _$ClientStatsCopyWith<$Res> {
  __$ClientStatsCopyWithImpl(this._self, this._then);

  final _ClientStats _self;
  final $Res Function(_ClientStats) _then;

/// Create a copy of ClientStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hours = null,Object? movies = null,Object? shows = null,}) {
  return _then(_ClientStats(
hours: null == hours ? _self.hours : hours // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,shows: null == shows ? _self.shows : shows // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
