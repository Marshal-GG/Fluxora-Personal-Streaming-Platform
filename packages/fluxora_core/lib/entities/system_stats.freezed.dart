// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'system_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SystemStats {

 int get uptimeSeconds; String? get lanIp; String? get publicAddress; bool get internetConnected; double get cpuPercent; double get ramPercent; int get ramUsedBytes; int get ramTotalBytes; double get networkInMbps; double get networkOutMbps; int get activeStreams;
/// Create a copy of SystemStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemStatsCopyWith<SystemStats> get copyWith => _$SystemStatsCopyWithImpl<SystemStats>(this as SystemStats, _$identity);

  /// Serializes this SystemStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemStats&&(identical(other.uptimeSeconds, uptimeSeconds) || other.uptimeSeconds == uptimeSeconds)&&(identical(other.lanIp, lanIp) || other.lanIp == lanIp)&&(identical(other.publicAddress, publicAddress) || other.publicAddress == publicAddress)&&(identical(other.internetConnected, internetConnected) || other.internetConnected == internetConnected)&&(identical(other.cpuPercent, cpuPercent) || other.cpuPercent == cpuPercent)&&(identical(other.ramPercent, ramPercent) || other.ramPercent == ramPercent)&&(identical(other.ramUsedBytes, ramUsedBytes) || other.ramUsedBytes == ramUsedBytes)&&(identical(other.ramTotalBytes, ramTotalBytes) || other.ramTotalBytes == ramTotalBytes)&&(identical(other.networkInMbps, networkInMbps) || other.networkInMbps == networkInMbps)&&(identical(other.networkOutMbps, networkOutMbps) || other.networkOutMbps == networkOutMbps)&&(identical(other.activeStreams, activeStreams) || other.activeStreams == activeStreams));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uptimeSeconds,lanIp,publicAddress,internetConnected,cpuPercent,ramPercent,ramUsedBytes,ramTotalBytes,networkInMbps,networkOutMbps,activeStreams);

@override
String toString() {
  return 'SystemStats(uptimeSeconds: $uptimeSeconds, lanIp: $lanIp, publicAddress: $publicAddress, internetConnected: $internetConnected, cpuPercent: $cpuPercent, ramPercent: $ramPercent, ramUsedBytes: $ramUsedBytes, ramTotalBytes: $ramTotalBytes, networkInMbps: $networkInMbps, networkOutMbps: $networkOutMbps, activeStreams: $activeStreams)';
}


}

/// @nodoc
abstract mixin class $SystemStatsCopyWith<$Res>  {
  factory $SystemStatsCopyWith(SystemStats value, $Res Function(SystemStats) _then) = _$SystemStatsCopyWithImpl;
@useResult
$Res call({
 int uptimeSeconds, String? lanIp, String? publicAddress, bool internetConnected, double cpuPercent, double ramPercent, int ramUsedBytes, int ramTotalBytes, double networkInMbps, double networkOutMbps, int activeStreams
});




}
/// @nodoc
class _$SystemStatsCopyWithImpl<$Res>
    implements $SystemStatsCopyWith<$Res> {
  _$SystemStatsCopyWithImpl(this._self, this._then);

  final SystemStats _self;
  final $Res Function(SystemStats) _then;

/// Create a copy of SystemStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uptimeSeconds = null,Object? lanIp = freezed,Object? publicAddress = freezed,Object? internetConnected = null,Object? cpuPercent = null,Object? ramPercent = null,Object? ramUsedBytes = null,Object? ramTotalBytes = null,Object? networkInMbps = null,Object? networkOutMbps = null,Object? activeStreams = null,}) {
  return _then(_self.copyWith(
uptimeSeconds: null == uptimeSeconds ? _self.uptimeSeconds : uptimeSeconds // ignore: cast_nullable_to_non_nullable
as int,lanIp: freezed == lanIp ? _self.lanIp : lanIp // ignore: cast_nullable_to_non_nullable
as String?,publicAddress: freezed == publicAddress ? _self.publicAddress : publicAddress // ignore: cast_nullable_to_non_nullable
as String?,internetConnected: null == internetConnected ? _self.internetConnected : internetConnected // ignore: cast_nullable_to_non_nullable
as bool,cpuPercent: null == cpuPercent ? _self.cpuPercent : cpuPercent // ignore: cast_nullable_to_non_nullable
as double,ramPercent: null == ramPercent ? _self.ramPercent : ramPercent // ignore: cast_nullable_to_non_nullable
as double,ramUsedBytes: null == ramUsedBytes ? _self.ramUsedBytes : ramUsedBytes // ignore: cast_nullable_to_non_nullable
as int,ramTotalBytes: null == ramTotalBytes ? _self.ramTotalBytes : ramTotalBytes // ignore: cast_nullable_to_non_nullable
as int,networkInMbps: null == networkInMbps ? _self.networkInMbps : networkInMbps // ignore: cast_nullable_to_non_nullable
as double,networkOutMbps: null == networkOutMbps ? _self.networkOutMbps : networkOutMbps // ignore: cast_nullable_to_non_nullable
as double,activeStreams: null == activeStreams ? _self.activeStreams : activeStreams // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SystemStats].
extension SystemStatsPatterns on SystemStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemStats value)  $default,){
final _that = this;
switch (_that) {
case _SystemStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemStats value)?  $default,){
final _that = this;
switch (_that) {
case _SystemStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int uptimeSeconds,  String? lanIp,  String? publicAddress,  bool internetConnected,  double cpuPercent,  double ramPercent,  int ramUsedBytes,  int ramTotalBytes,  double networkInMbps,  double networkOutMbps,  int activeStreams)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemStats() when $default != null:
return $default(_that.uptimeSeconds,_that.lanIp,_that.publicAddress,_that.internetConnected,_that.cpuPercent,_that.ramPercent,_that.ramUsedBytes,_that.ramTotalBytes,_that.networkInMbps,_that.networkOutMbps,_that.activeStreams);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int uptimeSeconds,  String? lanIp,  String? publicAddress,  bool internetConnected,  double cpuPercent,  double ramPercent,  int ramUsedBytes,  int ramTotalBytes,  double networkInMbps,  double networkOutMbps,  int activeStreams)  $default,) {final _that = this;
switch (_that) {
case _SystemStats():
return $default(_that.uptimeSeconds,_that.lanIp,_that.publicAddress,_that.internetConnected,_that.cpuPercent,_that.ramPercent,_that.ramUsedBytes,_that.ramTotalBytes,_that.networkInMbps,_that.networkOutMbps,_that.activeStreams);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int uptimeSeconds,  String? lanIp,  String? publicAddress,  bool internetConnected,  double cpuPercent,  double ramPercent,  int ramUsedBytes,  int ramTotalBytes,  double networkInMbps,  double networkOutMbps,  int activeStreams)?  $default,) {final _that = this;
switch (_that) {
case _SystemStats() when $default != null:
return $default(_that.uptimeSeconds,_that.lanIp,_that.publicAddress,_that.internetConnected,_that.cpuPercent,_that.ramPercent,_that.ramUsedBytes,_that.ramTotalBytes,_that.networkInMbps,_that.networkOutMbps,_that.activeStreams);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SystemStats implements SystemStats {
  const _SystemStats({required this.uptimeSeconds, this.lanIp, this.publicAddress, required this.internetConnected, required this.cpuPercent, required this.ramPercent, required this.ramUsedBytes, required this.ramTotalBytes, required this.networkInMbps, required this.networkOutMbps, required this.activeStreams});
  factory _SystemStats.fromJson(Map<String, dynamic> json) => _$SystemStatsFromJson(json);

@override final  int uptimeSeconds;
@override final  String? lanIp;
@override final  String? publicAddress;
@override final  bool internetConnected;
@override final  double cpuPercent;
@override final  double ramPercent;
@override final  int ramUsedBytes;
@override final  int ramTotalBytes;
@override final  double networkInMbps;
@override final  double networkOutMbps;
@override final  int activeStreams;

/// Create a copy of SystemStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemStatsCopyWith<_SystemStats> get copyWith => __$SystemStatsCopyWithImpl<_SystemStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SystemStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemStats&&(identical(other.uptimeSeconds, uptimeSeconds) || other.uptimeSeconds == uptimeSeconds)&&(identical(other.lanIp, lanIp) || other.lanIp == lanIp)&&(identical(other.publicAddress, publicAddress) || other.publicAddress == publicAddress)&&(identical(other.internetConnected, internetConnected) || other.internetConnected == internetConnected)&&(identical(other.cpuPercent, cpuPercent) || other.cpuPercent == cpuPercent)&&(identical(other.ramPercent, ramPercent) || other.ramPercent == ramPercent)&&(identical(other.ramUsedBytes, ramUsedBytes) || other.ramUsedBytes == ramUsedBytes)&&(identical(other.ramTotalBytes, ramTotalBytes) || other.ramTotalBytes == ramTotalBytes)&&(identical(other.networkInMbps, networkInMbps) || other.networkInMbps == networkInMbps)&&(identical(other.networkOutMbps, networkOutMbps) || other.networkOutMbps == networkOutMbps)&&(identical(other.activeStreams, activeStreams) || other.activeStreams == activeStreams));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uptimeSeconds,lanIp,publicAddress,internetConnected,cpuPercent,ramPercent,ramUsedBytes,ramTotalBytes,networkInMbps,networkOutMbps,activeStreams);

@override
String toString() {
  return 'SystemStats(uptimeSeconds: $uptimeSeconds, lanIp: $lanIp, publicAddress: $publicAddress, internetConnected: $internetConnected, cpuPercent: $cpuPercent, ramPercent: $ramPercent, ramUsedBytes: $ramUsedBytes, ramTotalBytes: $ramTotalBytes, networkInMbps: $networkInMbps, networkOutMbps: $networkOutMbps, activeStreams: $activeStreams)';
}


}

/// @nodoc
abstract mixin class _$SystemStatsCopyWith<$Res> implements $SystemStatsCopyWith<$Res> {
  factory _$SystemStatsCopyWith(_SystemStats value, $Res Function(_SystemStats) _then) = __$SystemStatsCopyWithImpl;
@override @useResult
$Res call({
 int uptimeSeconds, String? lanIp, String? publicAddress, bool internetConnected, double cpuPercent, double ramPercent, int ramUsedBytes, int ramTotalBytes, double networkInMbps, double networkOutMbps, int activeStreams
});




}
/// @nodoc
class __$SystemStatsCopyWithImpl<$Res>
    implements _$SystemStatsCopyWith<$Res> {
  __$SystemStatsCopyWithImpl(this._self, this._then);

  final _SystemStats _self;
  final $Res Function(_SystemStats) _then;

/// Create a copy of SystemStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uptimeSeconds = null,Object? lanIp = freezed,Object? publicAddress = freezed,Object? internetConnected = null,Object? cpuPercent = null,Object? ramPercent = null,Object? ramUsedBytes = null,Object? ramTotalBytes = null,Object? networkInMbps = null,Object? networkOutMbps = null,Object? activeStreams = null,}) {
  return _then(_SystemStats(
uptimeSeconds: null == uptimeSeconds ? _self.uptimeSeconds : uptimeSeconds // ignore: cast_nullable_to_non_nullable
as int,lanIp: freezed == lanIp ? _self.lanIp : lanIp // ignore: cast_nullable_to_non_nullable
as String?,publicAddress: freezed == publicAddress ? _self.publicAddress : publicAddress // ignore: cast_nullable_to_non_nullable
as String?,internetConnected: null == internetConnected ? _self.internetConnected : internetConnected // ignore: cast_nullable_to_non_nullable
as bool,cpuPercent: null == cpuPercent ? _self.cpuPercent : cpuPercent // ignore: cast_nullable_to_non_nullable
as double,ramPercent: null == ramPercent ? _self.ramPercent : ramPercent // ignore: cast_nullable_to_non_nullable
as double,ramUsedBytes: null == ramUsedBytes ? _self.ramUsedBytes : ramUsedBytes // ignore: cast_nullable_to_non_nullable
as int,ramTotalBytes: null == ramTotalBytes ? _self.ramTotalBytes : ramTotalBytes // ignore: cast_nullable_to_non_nullable
as int,networkInMbps: null == networkInMbps ? _self.networkInMbps : networkInMbps // ignore: cast_nullable_to_non_nullable
as double,networkOutMbps: null == networkOutMbps ? _self.networkOutMbps : networkOutMbps // ignore: cast_nullable_to_non_nullable
as double,activeStreams: null == activeStreams ? _self.activeStreams : activeStreams // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
