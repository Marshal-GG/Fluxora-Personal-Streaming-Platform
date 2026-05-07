// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'encoder_benchmark.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Resolution {

 int get width; int get height;
/// Create a copy of Resolution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResolutionCopyWith<Resolution> get copyWith => _$ResolutionCopyWithImpl<Resolution>(this as Resolution, _$identity);

  /// Serializes this Resolution to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Resolution&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'Resolution(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $ResolutionCopyWith<$Res>  {
  factory $ResolutionCopyWith(Resolution value, $Res Function(Resolution) _then) = _$ResolutionCopyWithImpl;
@useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$ResolutionCopyWithImpl<$Res>
    implements $ResolutionCopyWith<$Res> {
  _$ResolutionCopyWithImpl(this._self, this._then);

  final Resolution _self;
  final $Res Function(Resolution) _then;

/// Create a copy of Resolution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Resolution].
extension ResolutionPatterns on Resolution {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Resolution value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Resolution() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Resolution value)  $default,){
final _that = this;
switch (_that) {
case _Resolution():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Resolution value)?  $default,){
final _that = this;
switch (_that) {
case _Resolution() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int width,  int height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Resolution() when $default != null:
return $default(_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int width,  int height)  $default,) {final _that = this;
switch (_that) {
case _Resolution():
return $default(_that.width,_that.height);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int width,  int height)?  $default,) {final _that = this;
switch (_that) {
case _Resolution() when $default != null:
return $default(_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Resolution implements Resolution {
  const _Resolution({required this.width, required this.height});
  factory _Resolution.fromJson(Map<String, dynamic> json) => _$ResolutionFromJson(json);

@override final  int width;
@override final  int height;

/// Create a copy of Resolution
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResolutionCopyWith<_Resolution> get copyWith => __$ResolutionCopyWithImpl<_Resolution>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResolutionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Resolution&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'Resolution(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$ResolutionCopyWith<$Res> implements $ResolutionCopyWith<$Res> {
  factory _$ResolutionCopyWith(_Resolution value, $Res Function(_Resolution) _then) = __$ResolutionCopyWithImpl;
@override @useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class __$ResolutionCopyWithImpl<$Res>
    implements _$ResolutionCopyWith<$Res> {
  __$ResolutionCopyWithImpl(this._self, this._then);

  final _Resolution _self;
  final $Res Function(_Resolution) _then;

/// Create a copy of Resolution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(_Resolution(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$EncoderBenchmarkResult {

 String get encoder; String get vendor; String get codec;/// Source resolution this row was measured at.  Required because
/// matrix-mode runs produce N rows per encoder (one per resolution),
/// so each row must self-describe rather than infer from the parent
/// run's primary [EncoderBenchmarkRun.width] / [EncoderBenchmarkRun.height].
/// Single-resolution runs still populate these — the contract is
/// unconditional.
 int get width; int get height; bool get passed; String? get error; double? get fps; double? get speedX; double? get bitrateKbps; int? get encodedFrames; double? get elapsedSec; double? get realtimeMultiplier; int? get initMs; double? get gpuUtilizationPercent; int? get vramUsedMb; int? get concurrentSessionCap; int? get recommendedConcurrent; int? get verifiedConcurrent;
/// Create a copy of EncoderBenchmarkResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EncoderBenchmarkResultCopyWith<EncoderBenchmarkResult> get copyWith => _$EncoderBenchmarkResultCopyWithImpl<EncoderBenchmarkResult>(this as EncoderBenchmarkResult, _$identity);

  /// Serializes this EncoderBenchmarkResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EncoderBenchmarkResult&&(identical(other.encoder, encoder) || other.encoder == encoder)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.passed, passed) || other.passed == passed)&&(identical(other.error, error) || other.error == error)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.speedX, speedX) || other.speedX == speedX)&&(identical(other.bitrateKbps, bitrateKbps) || other.bitrateKbps == bitrateKbps)&&(identical(other.encodedFrames, encodedFrames) || other.encodedFrames == encodedFrames)&&(identical(other.elapsedSec, elapsedSec) || other.elapsedSec == elapsedSec)&&(identical(other.realtimeMultiplier, realtimeMultiplier) || other.realtimeMultiplier == realtimeMultiplier)&&(identical(other.initMs, initMs) || other.initMs == initMs)&&(identical(other.gpuUtilizationPercent, gpuUtilizationPercent) || other.gpuUtilizationPercent == gpuUtilizationPercent)&&(identical(other.vramUsedMb, vramUsedMb) || other.vramUsedMb == vramUsedMb)&&(identical(other.concurrentSessionCap, concurrentSessionCap) || other.concurrentSessionCap == concurrentSessionCap)&&(identical(other.recommendedConcurrent, recommendedConcurrent) || other.recommendedConcurrent == recommendedConcurrent)&&(identical(other.verifiedConcurrent, verifiedConcurrent) || other.verifiedConcurrent == verifiedConcurrent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,encoder,vendor,codec,width,height,passed,error,fps,speedX,bitrateKbps,encodedFrames,elapsedSec,realtimeMultiplier,initMs,gpuUtilizationPercent,vramUsedMb,concurrentSessionCap,recommendedConcurrent,verifiedConcurrent]);

@override
String toString() {
  return 'EncoderBenchmarkResult(encoder: $encoder, vendor: $vendor, codec: $codec, width: $width, height: $height, passed: $passed, error: $error, fps: $fps, speedX: $speedX, bitrateKbps: $bitrateKbps, encodedFrames: $encodedFrames, elapsedSec: $elapsedSec, realtimeMultiplier: $realtimeMultiplier, initMs: $initMs, gpuUtilizationPercent: $gpuUtilizationPercent, vramUsedMb: $vramUsedMb, concurrentSessionCap: $concurrentSessionCap, recommendedConcurrent: $recommendedConcurrent, verifiedConcurrent: $verifiedConcurrent)';
}


}

/// @nodoc
abstract mixin class $EncoderBenchmarkResultCopyWith<$Res>  {
  factory $EncoderBenchmarkResultCopyWith(EncoderBenchmarkResult value, $Res Function(EncoderBenchmarkResult) _then) = _$EncoderBenchmarkResultCopyWithImpl;
@useResult
$Res call({
 String encoder, String vendor, String codec, int width, int height, bool passed, String? error, double? fps, double? speedX, double? bitrateKbps, int? encodedFrames, double? elapsedSec, double? realtimeMultiplier, int? initMs, double? gpuUtilizationPercent, int? vramUsedMb, int? concurrentSessionCap, int? recommendedConcurrent, int? verifiedConcurrent
});




}
/// @nodoc
class _$EncoderBenchmarkResultCopyWithImpl<$Res>
    implements $EncoderBenchmarkResultCopyWith<$Res> {
  _$EncoderBenchmarkResultCopyWithImpl(this._self, this._then);

  final EncoderBenchmarkResult _self;
  final $Res Function(EncoderBenchmarkResult) _then;

/// Create a copy of EncoderBenchmarkResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? encoder = null,Object? vendor = null,Object? codec = null,Object? width = null,Object? height = null,Object? passed = null,Object? error = freezed,Object? fps = freezed,Object? speedX = freezed,Object? bitrateKbps = freezed,Object? encodedFrames = freezed,Object? elapsedSec = freezed,Object? realtimeMultiplier = freezed,Object? initMs = freezed,Object? gpuUtilizationPercent = freezed,Object? vramUsedMb = freezed,Object? concurrentSessionCap = freezed,Object? recommendedConcurrent = freezed,Object? verifiedConcurrent = freezed,}) {
  return _then(_self.copyWith(
encoder: null == encoder ? _self.encoder : encoder // ignore: cast_nullable_to_non_nullable
as String,vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,passed: null == passed ? _self.passed : passed // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,fps: freezed == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double?,speedX: freezed == speedX ? _self.speedX : speedX // ignore: cast_nullable_to_non_nullable
as double?,bitrateKbps: freezed == bitrateKbps ? _self.bitrateKbps : bitrateKbps // ignore: cast_nullable_to_non_nullable
as double?,encodedFrames: freezed == encodedFrames ? _self.encodedFrames : encodedFrames // ignore: cast_nullable_to_non_nullable
as int?,elapsedSec: freezed == elapsedSec ? _self.elapsedSec : elapsedSec // ignore: cast_nullable_to_non_nullable
as double?,realtimeMultiplier: freezed == realtimeMultiplier ? _self.realtimeMultiplier : realtimeMultiplier // ignore: cast_nullable_to_non_nullable
as double?,initMs: freezed == initMs ? _self.initMs : initMs // ignore: cast_nullable_to_non_nullable
as int?,gpuUtilizationPercent: freezed == gpuUtilizationPercent ? _self.gpuUtilizationPercent : gpuUtilizationPercent // ignore: cast_nullable_to_non_nullable
as double?,vramUsedMb: freezed == vramUsedMb ? _self.vramUsedMb : vramUsedMb // ignore: cast_nullable_to_non_nullable
as int?,concurrentSessionCap: freezed == concurrentSessionCap ? _self.concurrentSessionCap : concurrentSessionCap // ignore: cast_nullable_to_non_nullable
as int?,recommendedConcurrent: freezed == recommendedConcurrent ? _self.recommendedConcurrent : recommendedConcurrent // ignore: cast_nullable_to_non_nullable
as int?,verifiedConcurrent: freezed == verifiedConcurrent ? _self.verifiedConcurrent : verifiedConcurrent // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [EncoderBenchmarkResult].
extension EncoderBenchmarkResultPatterns on EncoderBenchmarkResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EncoderBenchmarkResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EncoderBenchmarkResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EncoderBenchmarkResult value)  $default,){
final _that = this;
switch (_that) {
case _EncoderBenchmarkResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EncoderBenchmarkResult value)?  $default,){
final _that = this;
switch (_that) {
case _EncoderBenchmarkResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String encoder,  String vendor,  String codec,  int width,  int height,  bool passed,  String? error,  double? fps,  double? speedX,  double? bitrateKbps,  int? encodedFrames,  double? elapsedSec,  double? realtimeMultiplier,  int? initMs,  double? gpuUtilizationPercent,  int? vramUsedMb,  int? concurrentSessionCap,  int? recommendedConcurrent,  int? verifiedConcurrent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EncoderBenchmarkResult() when $default != null:
return $default(_that.encoder,_that.vendor,_that.codec,_that.width,_that.height,_that.passed,_that.error,_that.fps,_that.speedX,_that.bitrateKbps,_that.encodedFrames,_that.elapsedSec,_that.realtimeMultiplier,_that.initMs,_that.gpuUtilizationPercent,_that.vramUsedMb,_that.concurrentSessionCap,_that.recommendedConcurrent,_that.verifiedConcurrent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String encoder,  String vendor,  String codec,  int width,  int height,  bool passed,  String? error,  double? fps,  double? speedX,  double? bitrateKbps,  int? encodedFrames,  double? elapsedSec,  double? realtimeMultiplier,  int? initMs,  double? gpuUtilizationPercent,  int? vramUsedMb,  int? concurrentSessionCap,  int? recommendedConcurrent,  int? verifiedConcurrent)  $default,) {final _that = this;
switch (_that) {
case _EncoderBenchmarkResult():
return $default(_that.encoder,_that.vendor,_that.codec,_that.width,_that.height,_that.passed,_that.error,_that.fps,_that.speedX,_that.bitrateKbps,_that.encodedFrames,_that.elapsedSec,_that.realtimeMultiplier,_that.initMs,_that.gpuUtilizationPercent,_that.vramUsedMb,_that.concurrentSessionCap,_that.recommendedConcurrent,_that.verifiedConcurrent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String encoder,  String vendor,  String codec,  int width,  int height,  bool passed,  String? error,  double? fps,  double? speedX,  double? bitrateKbps,  int? encodedFrames,  double? elapsedSec,  double? realtimeMultiplier,  int? initMs,  double? gpuUtilizationPercent,  int? vramUsedMb,  int? concurrentSessionCap,  int? recommendedConcurrent,  int? verifiedConcurrent)?  $default,) {final _that = this;
switch (_that) {
case _EncoderBenchmarkResult() when $default != null:
return $default(_that.encoder,_that.vendor,_that.codec,_that.width,_that.height,_that.passed,_that.error,_that.fps,_that.speedX,_that.bitrateKbps,_that.encodedFrames,_that.elapsedSec,_that.realtimeMultiplier,_that.initMs,_that.gpuUtilizationPercent,_that.vramUsedMb,_that.concurrentSessionCap,_that.recommendedConcurrent,_that.verifiedConcurrent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EncoderBenchmarkResult implements EncoderBenchmarkResult {
  const _EncoderBenchmarkResult({required this.encoder, required this.vendor, required this.codec, required this.width, required this.height, required this.passed, this.error, this.fps, this.speedX, this.bitrateKbps, this.encodedFrames, this.elapsedSec, this.realtimeMultiplier, this.initMs, this.gpuUtilizationPercent, this.vramUsedMb, this.concurrentSessionCap, this.recommendedConcurrent, this.verifiedConcurrent});
  factory _EncoderBenchmarkResult.fromJson(Map<String, dynamic> json) => _$EncoderBenchmarkResultFromJson(json);

@override final  String encoder;
@override final  String vendor;
@override final  String codec;
/// Source resolution this row was measured at.  Required because
/// matrix-mode runs produce N rows per encoder (one per resolution),
/// so each row must self-describe rather than infer from the parent
/// run's primary [EncoderBenchmarkRun.width] / [EncoderBenchmarkRun.height].
/// Single-resolution runs still populate these — the contract is
/// unconditional.
@override final  int width;
@override final  int height;
@override final  bool passed;
@override final  String? error;
@override final  double? fps;
@override final  double? speedX;
@override final  double? bitrateKbps;
@override final  int? encodedFrames;
@override final  double? elapsedSec;
@override final  double? realtimeMultiplier;
@override final  int? initMs;
@override final  double? gpuUtilizationPercent;
@override final  int? vramUsedMb;
@override final  int? concurrentSessionCap;
@override final  int? recommendedConcurrent;
@override final  int? verifiedConcurrent;

/// Create a copy of EncoderBenchmarkResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EncoderBenchmarkResultCopyWith<_EncoderBenchmarkResult> get copyWith => __$EncoderBenchmarkResultCopyWithImpl<_EncoderBenchmarkResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EncoderBenchmarkResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EncoderBenchmarkResult&&(identical(other.encoder, encoder) || other.encoder == encoder)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.passed, passed) || other.passed == passed)&&(identical(other.error, error) || other.error == error)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.speedX, speedX) || other.speedX == speedX)&&(identical(other.bitrateKbps, bitrateKbps) || other.bitrateKbps == bitrateKbps)&&(identical(other.encodedFrames, encodedFrames) || other.encodedFrames == encodedFrames)&&(identical(other.elapsedSec, elapsedSec) || other.elapsedSec == elapsedSec)&&(identical(other.realtimeMultiplier, realtimeMultiplier) || other.realtimeMultiplier == realtimeMultiplier)&&(identical(other.initMs, initMs) || other.initMs == initMs)&&(identical(other.gpuUtilizationPercent, gpuUtilizationPercent) || other.gpuUtilizationPercent == gpuUtilizationPercent)&&(identical(other.vramUsedMb, vramUsedMb) || other.vramUsedMb == vramUsedMb)&&(identical(other.concurrentSessionCap, concurrentSessionCap) || other.concurrentSessionCap == concurrentSessionCap)&&(identical(other.recommendedConcurrent, recommendedConcurrent) || other.recommendedConcurrent == recommendedConcurrent)&&(identical(other.verifiedConcurrent, verifiedConcurrent) || other.verifiedConcurrent == verifiedConcurrent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,encoder,vendor,codec,width,height,passed,error,fps,speedX,bitrateKbps,encodedFrames,elapsedSec,realtimeMultiplier,initMs,gpuUtilizationPercent,vramUsedMb,concurrentSessionCap,recommendedConcurrent,verifiedConcurrent]);

@override
String toString() {
  return 'EncoderBenchmarkResult(encoder: $encoder, vendor: $vendor, codec: $codec, width: $width, height: $height, passed: $passed, error: $error, fps: $fps, speedX: $speedX, bitrateKbps: $bitrateKbps, encodedFrames: $encodedFrames, elapsedSec: $elapsedSec, realtimeMultiplier: $realtimeMultiplier, initMs: $initMs, gpuUtilizationPercent: $gpuUtilizationPercent, vramUsedMb: $vramUsedMb, concurrentSessionCap: $concurrentSessionCap, recommendedConcurrent: $recommendedConcurrent, verifiedConcurrent: $verifiedConcurrent)';
}


}

/// @nodoc
abstract mixin class _$EncoderBenchmarkResultCopyWith<$Res> implements $EncoderBenchmarkResultCopyWith<$Res> {
  factory _$EncoderBenchmarkResultCopyWith(_EncoderBenchmarkResult value, $Res Function(_EncoderBenchmarkResult) _then) = __$EncoderBenchmarkResultCopyWithImpl;
@override @useResult
$Res call({
 String encoder, String vendor, String codec, int width, int height, bool passed, String? error, double? fps, double? speedX, double? bitrateKbps, int? encodedFrames, double? elapsedSec, double? realtimeMultiplier, int? initMs, double? gpuUtilizationPercent, int? vramUsedMb, int? concurrentSessionCap, int? recommendedConcurrent, int? verifiedConcurrent
});




}
/// @nodoc
class __$EncoderBenchmarkResultCopyWithImpl<$Res>
    implements _$EncoderBenchmarkResultCopyWith<$Res> {
  __$EncoderBenchmarkResultCopyWithImpl(this._self, this._then);

  final _EncoderBenchmarkResult _self;
  final $Res Function(_EncoderBenchmarkResult) _then;

/// Create a copy of EncoderBenchmarkResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? encoder = null,Object? vendor = null,Object? codec = null,Object? width = null,Object? height = null,Object? passed = null,Object? error = freezed,Object? fps = freezed,Object? speedX = freezed,Object? bitrateKbps = freezed,Object? encodedFrames = freezed,Object? elapsedSec = freezed,Object? realtimeMultiplier = freezed,Object? initMs = freezed,Object? gpuUtilizationPercent = freezed,Object? vramUsedMb = freezed,Object? concurrentSessionCap = freezed,Object? recommendedConcurrent = freezed,Object? verifiedConcurrent = freezed,}) {
  return _then(_EncoderBenchmarkResult(
encoder: null == encoder ? _self.encoder : encoder // ignore: cast_nullable_to_non_nullable
as String,vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,passed: null == passed ? _self.passed : passed // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,fps: freezed == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double?,speedX: freezed == speedX ? _self.speedX : speedX // ignore: cast_nullable_to_non_nullable
as double?,bitrateKbps: freezed == bitrateKbps ? _self.bitrateKbps : bitrateKbps // ignore: cast_nullable_to_non_nullable
as double?,encodedFrames: freezed == encodedFrames ? _self.encodedFrames : encodedFrames // ignore: cast_nullable_to_non_nullable
as int?,elapsedSec: freezed == elapsedSec ? _self.elapsedSec : elapsedSec // ignore: cast_nullable_to_non_nullable
as double?,realtimeMultiplier: freezed == realtimeMultiplier ? _self.realtimeMultiplier : realtimeMultiplier // ignore: cast_nullable_to_non_nullable
as double?,initMs: freezed == initMs ? _self.initMs : initMs // ignore: cast_nullable_to_non_nullable
as int?,gpuUtilizationPercent: freezed == gpuUtilizationPercent ? _self.gpuUtilizationPercent : gpuUtilizationPercent // ignore: cast_nullable_to_non_nullable
as double?,vramUsedMb: freezed == vramUsedMb ? _self.vramUsedMb : vramUsedMb // ignore: cast_nullable_to_non_nullable
as int?,concurrentSessionCap: freezed == concurrentSessionCap ? _self.concurrentSessionCap : concurrentSessionCap // ignore: cast_nullable_to_non_nullable
as int?,recommendedConcurrent: freezed == recommendedConcurrent ? _self.recommendedConcurrent : recommendedConcurrent // ignore: cast_nullable_to_non_nullable
as int?,verifiedConcurrent: freezed == verifiedConcurrent ? _self.verifiedConcurrent : verifiedConcurrent // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$EncoderBenchmarkRun {

/// Autoincrement id from the server's ``benchmark_runs`` table.  The
/// desktop uses it to keep the visible "current run" highlighted in
/// the history sidebar + to fetch / delete the run by id.
 int get id; String get startedAt; String get finishedAt; int get durationSec; int get fps; int get width; int get height; List<Resolution> get resolutions; bool get verifyCaps; List<EncoderBenchmarkResult> get results;
/// Create a copy of EncoderBenchmarkRun
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EncoderBenchmarkRunCopyWith<EncoderBenchmarkRun> get copyWith => _$EncoderBenchmarkRunCopyWithImpl<EncoderBenchmarkRun>(this as EncoderBenchmarkRun, _$identity);

  /// Serializes this EncoderBenchmarkRun to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EncoderBenchmarkRun&&(identical(other.id, id) || other.id == id)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&const DeepCollectionEquality().equals(other.resolutions, resolutions)&&(identical(other.verifyCaps, verifyCaps) || other.verifyCaps == verifyCaps)&&const DeepCollectionEquality().equals(other.results, results));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,startedAt,finishedAt,durationSec,fps,width,height,const DeepCollectionEquality().hash(resolutions),verifyCaps,const DeepCollectionEquality().hash(results));

@override
String toString() {
  return 'EncoderBenchmarkRun(id: $id, startedAt: $startedAt, finishedAt: $finishedAt, durationSec: $durationSec, fps: $fps, width: $width, height: $height, resolutions: $resolutions, verifyCaps: $verifyCaps, results: $results)';
}


}

/// @nodoc
abstract mixin class $EncoderBenchmarkRunCopyWith<$Res>  {
  factory $EncoderBenchmarkRunCopyWith(EncoderBenchmarkRun value, $Res Function(EncoderBenchmarkRun) _then) = _$EncoderBenchmarkRunCopyWithImpl;
@useResult
$Res call({
 int id, String startedAt, String finishedAt, int durationSec, int fps, int width, int height, List<Resolution> resolutions, bool verifyCaps, List<EncoderBenchmarkResult> results
});




}
/// @nodoc
class _$EncoderBenchmarkRunCopyWithImpl<$Res>
    implements $EncoderBenchmarkRunCopyWith<$Res> {
  _$EncoderBenchmarkRunCopyWithImpl(this._self, this._then);

  final EncoderBenchmarkRun _self;
  final $Res Function(EncoderBenchmarkRun) _then;

/// Create a copy of EncoderBenchmarkRun
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? startedAt = null,Object? finishedAt = null,Object? durationSec = null,Object? fps = null,Object? width = null,Object? height = null,Object? resolutions = null,Object? verifyCaps = null,Object? results = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String,finishedAt: null == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as String,durationSec: null == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as int,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,resolutions: null == resolutions ? _self.resolutions : resolutions // ignore: cast_nullable_to_non_nullable
as List<Resolution>,verifyCaps: null == verifyCaps ? _self.verifyCaps : verifyCaps // ignore: cast_nullable_to_non_nullable
as bool,results: null == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<EncoderBenchmarkResult>,
  ));
}

}


/// Adds pattern-matching-related methods to [EncoderBenchmarkRun].
extension EncoderBenchmarkRunPatterns on EncoderBenchmarkRun {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EncoderBenchmarkRun value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EncoderBenchmarkRun() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EncoderBenchmarkRun value)  $default,){
final _that = this;
switch (_that) {
case _EncoderBenchmarkRun():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EncoderBenchmarkRun value)?  $default,){
final _that = this;
switch (_that) {
case _EncoderBenchmarkRun() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String startedAt,  String finishedAt,  int durationSec,  int fps,  int width,  int height,  List<Resolution> resolutions,  bool verifyCaps,  List<EncoderBenchmarkResult> results)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EncoderBenchmarkRun() when $default != null:
return $default(_that.id,_that.startedAt,_that.finishedAt,_that.durationSec,_that.fps,_that.width,_that.height,_that.resolutions,_that.verifyCaps,_that.results);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String startedAt,  String finishedAt,  int durationSec,  int fps,  int width,  int height,  List<Resolution> resolutions,  bool verifyCaps,  List<EncoderBenchmarkResult> results)  $default,) {final _that = this;
switch (_that) {
case _EncoderBenchmarkRun():
return $default(_that.id,_that.startedAt,_that.finishedAt,_that.durationSec,_that.fps,_that.width,_that.height,_that.resolutions,_that.verifyCaps,_that.results);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String startedAt,  String finishedAt,  int durationSec,  int fps,  int width,  int height,  List<Resolution> resolutions,  bool verifyCaps,  List<EncoderBenchmarkResult> results)?  $default,) {final _that = this;
switch (_that) {
case _EncoderBenchmarkRun() when $default != null:
return $default(_that.id,_that.startedAt,_that.finishedAt,_that.durationSec,_that.fps,_that.width,_that.height,_that.resolutions,_that.verifyCaps,_that.results);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EncoderBenchmarkRun implements EncoderBenchmarkRun {
  const _EncoderBenchmarkRun({required this.id, required this.startedAt, required this.finishedAt, required this.durationSec, required this.fps, required this.width, required this.height, final  List<Resolution> resolutions = const <Resolution>[], required this.verifyCaps, required final  List<EncoderBenchmarkResult> results}): _resolutions = resolutions,_results = results;
  factory _EncoderBenchmarkRun.fromJson(Map<String, dynamic> json) => _$EncoderBenchmarkRunFromJson(json);

/// Autoincrement id from the server's ``benchmark_runs`` table.  The
/// desktop uses it to keep the visible "current run" highlighted in
/// the history sidebar + to fetch / delete the run by id.
@override final  int id;
@override final  String startedAt;
@override final  String finishedAt;
@override final  int durationSec;
@override final  int fps;
@override final  int width;
@override final  int height;
 final  List<Resolution> _resolutions;
@override@JsonKey() List<Resolution> get resolutions {
  if (_resolutions is EqualUnmodifiableListView) return _resolutions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_resolutions);
}

@override final  bool verifyCaps;
 final  List<EncoderBenchmarkResult> _results;
@override List<EncoderBenchmarkResult> get results {
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_results);
}


/// Create a copy of EncoderBenchmarkRun
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EncoderBenchmarkRunCopyWith<_EncoderBenchmarkRun> get copyWith => __$EncoderBenchmarkRunCopyWithImpl<_EncoderBenchmarkRun>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EncoderBenchmarkRunToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EncoderBenchmarkRun&&(identical(other.id, id) || other.id == id)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&const DeepCollectionEquality().equals(other._resolutions, _resolutions)&&(identical(other.verifyCaps, verifyCaps) || other.verifyCaps == verifyCaps)&&const DeepCollectionEquality().equals(other._results, _results));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,startedAt,finishedAt,durationSec,fps,width,height,const DeepCollectionEquality().hash(_resolutions),verifyCaps,const DeepCollectionEquality().hash(_results));

@override
String toString() {
  return 'EncoderBenchmarkRun(id: $id, startedAt: $startedAt, finishedAt: $finishedAt, durationSec: $durationSec, fps: $fps, width: $width, height: $height, resolutions: $resolutions, verifyCaps: $verifyCaps, results: $results)';
}


}

/// @nodoc
abstract mixin class _$EncoderBenchmarkRunCopyWith<$Res> implements $EncoderBenchmarkRunCopyWith<$Res> {
  factory _$EncoderBenchmarkRunCopyWith(_EncoderBenchmarkRun value, $Res Function(_EncoderBenchmarkRun) _then) = __$EncoderBenchmarkRunCopyWithImpl;
@override @useResult
$Res call({
 int id, String startedAt, String finishedAt, int durationSec, int fps, int width, int height, List<Resolution> resolutions, bool verifyCaps, List<EncoderBenchmarkResult> results
});




}
/// @nodoc
class __$EncoderBenchmarkRunCopyWithImpl<$Res>
    implements _$EncoderBenchmarkRunCopyWith<$Res> {
  __$EncoderBenchmarkRunCopyWithImpl(this._self, this._then);

  final _EncoderBenchmarkRun _self;
  final $Res Function(_EncoderBenchmarkRun) _then;

/// Create a copy of EncoderBenchmarkRun
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? startedAt = null,Object? finishedAt = null,Object? durationSec = null,Object? fps = null,Object? width = null,Object? height = null,Object? resolutions = null,Object? verifyCaps = null,Object? results = null,}) {
  return _then(_EncoderBenchmarkRun(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String,finishedAt: null == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as String,durationSec: null == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as int,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,resolutions: null == resolutions ? _self._resolutions : resolutions // ignore: cast_nullable_to_non_nullable
as List<Resolution>,verifyCaps: null == verifyCaps ? _self.verifyCaps : verifyCaps // ignore: cast_nullable_to_non_nullable
as bool,results: null == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<EncoderBenchmarkResult>,
  ));
}


}


/// @nodoc
mixin _$BenchmarkHistoryEntry {

 int get id; String get startedAt; String get finishedAt; int get durationSec; int get fps; int get width; int get height; bool get verifyCaps; int get encoderCount;/// Distinct ``(width, height)`` pair count.  Defaults to 1 so legacy
/// rows persisted before matrix mode shipped (no per-row width/height
/// in their results blob) render the historical "1080p · 30 fps · 6 enc"
/// caption.  Matrix runs render "3 res · 30 fps · 18 enc" instead.
 int get resolutionCount;
/// Create a copy of BenchmarkHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BenchmarkHistoryEntryCopyWith<BenchmarkHistoryEntry> get copyWith => _$BenchmarkHistoryEntryCopyWithImpl<BenchmarkHistoryEntry>(this as BenchmarkHistoryEntry, _$identity);

  /// Serializes this BenchmarkHistoryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BenchmarkHistoryEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.verifyCaps, verifyCaps) || other.verifyCaps == verifyCaps)&&(identical(other.encoderCount, encoderCount) || other.encoderCount == encoderCount)&&(identical(other.resolutionCount, resolutionCount) || other.resolutionCount == resolutionCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,startedAt,finishedAt,durationSec,fps,width,height,verifyCaps,encoderCount,resolutionCount);

@override
String toString() {
  return 'BenchmarkHistoryEntry(id: $id, startedAt: $startedAt, finishedAt: $finishedAt, durationSec: $durationSec, fps: $fps, width: $width, height: $height, verifyCaps: $verifyCaps, encoderCount: $encoderCount, resolutionCount: $resolutionCount)';
}


}

/// @nodoc
abstract mixin class $BenchmarkHistoryEntryCopyWith<$Res>  {
  factory $BenchmarkHistoryEntryCopyWith(BenchmarkHistoryEntry value, $Res Function(BenchmarkHistoryEntry) _then) = _$BenchmarkHistoryEntryCopyWithImpl;
@useResult
$Res call({
 int id, String startedAt, String finishedAt, int durationSec, int fps, int width, int height, bool verifyCaps, int encoderCount, int resolutionCount
});




}
/// @nodoc
class _$BenchmarkHistoryEntryCopyWithImpl<$Res>
    implements $BenchmarkHistoryEntryCopyWith<$Res> {
  _$BenchmarkHistoryEntryCopyWithImpl(this._self, this._then);

  final BenchmarkHistoryEntry _self;
  final $Res Function(BenchmarkHistoryEntry) _then;

/// Create a copy of BenchmarkHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? startedAt = null,Object? finishedAt = null,Object? durationSec = null,Object? fps = null,Object? width = null,Object? height = null,Object? verifyCaps = null,Object? encoderCount = null,Object? resolutionCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String,finishedAt: null == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as String,durationSec: null == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as int,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,verifyCaps: null == verifyCaps ? _self.verifyCaps : verifyCaps // ignore: cast_nullable_to_non_nullable
as bool,encoderCount: null == encoderCount ? _self.encoderCount : encoderCount // ignore: cast_nullable_to_non_nullable
as int,resolutionCount: null == resolutionCount ? _self.resolutionCount : resolutionCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BenchmarkHistoryEntry].
extension BenchmarkHistoryEntryPatterns on BenchmarkHistoryEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BenchmarkHistoryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BenchmarkHistoryEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BenchmarkHistoryEntry value)  $default,){
final _that = this;
switch (_that) {
case _BenchmarkHistoryEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BenchmarkHistoryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _BenchmarkHistoryEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String startedAt,  String finishedAt,  int durationSec,  int fps,  int width,  int height,  bool verifyCaps,  int encoderCount,  int resolutionCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BenchmarkHistoryEntry() when $default != null:
return $default(_that.id,_that.startedAt,_that.finishedAt,_that.durationSec,_that.fps,_that.width,_that.height,_that.verifyCaps,_that.encoderCount,_that.resolutionCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String startedAt,  String finishedAt,  int durationSec,  int fps,  int width,  int height,  bool verifyCaps,  int encoderCount,  int resolutionCount)  $default,) {final _that = this;
switch (_that) {
case _BenchmarkHistoryEntry():
return $default(_that.id,_that.startedAt,_that.finishedAt,_that.durationSec,_that.fps,_that.width,_that.height,_that.verifyCaps,_that.encoderCount,_that.resolutionCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String startedAt,  String finishedAt,  int durationSec,  int fps,  int width,  int height,  bool verifyCaps,  int encoderCount,  int resolutionCount)?  $default,) {final _that = this;
switch (_that) {
case _BenchmarkHistoryEntry() when $default != null:
return $default(_that.id,_that.startedAt,_that.finishedAt,_that.durationSec,_that.fps,_that.width,_that.height,_that.verifyCaps,_that.encoderCount,_that.resolutionCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BenchmarkHistoryEntry implements BenchmarkHistoryEntry {
  const _BenchmarkHistoryEntry({required this.id, required this.startedAt, required this.finishedAt, required this.durationSec, required this.fps, required this.width, required this.height, required this.verifyCaps, required this.encoderCount, this.resolutionCount = 1});
  factory _BenchmarkHistoryEntry.fromJson(Map<String, dynamic> json) => _$BenchmarkHistoryEntryFromJson(json);

@override final  int id;
@override final  String startedAt;
@override final  String finishedAt;
@override final  int durationSec;
@override final  int fps;
@override final  int width;
@override final  int height;
@override final  bool verifyCaps;
@override final  int encoderCount;
/// Distinct ``(width, height)`` pair count.  Defaults to 1 so legacy
/// rows persisted before matrix mode shipped (no per-row width/height
/// in their results blob) render the historical "1080p · 30 fps · 6 enc"
/// caption.  Matrix runs render "3 res · 30 fps · 18 enc" instead.
@override@JsonKey() final  int resolutionCount;

/// Create a copy of BenchmarkHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BenchmarkHistoryEntryCopyWith<_BenchmarkHistoryEntry> get copyWith => __$BenchmarkHistoryEntryCopyWithImpl<_BenchmarkHistoryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BenchmarkHistoryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BenchmarkHistoryEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.verifyCaps, verifyCaps) || other.verifyCaps == verifyCaps)&&(identical(other.encoderCount, encoderCount) || other.encoderCount == encoderCount)&&(identical(other.resolutionCount, resolutionCount) || other.resolutionCount == resolutionCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,startedAt,finishedAt,durationSec,fps,width,height,verifyCaps,encoderCount,resolutionCount);

@override
String toString() {
  return 'BenchmarkHistoryEntry(id: $id, startedAt: $startedAt, finishedAt: $finishedAt, durationSec: $durationSec, fps: $fps, width: $width, height: $height, verifyCaps: $verifyCaps, encoderCount: $encoderCount, resolutionCount: $resolutionCount)';
}


}

/// @nodoc
abstract mixin class _$BenchmarkHistoryEntryCopyWith<$Res> implements $BenchmarkHistoryEntryCopyWith<$Res> {
  factory _$BenchmarkHistoryEntryCopyWith(_BenchmarkHistoryEntry value, $Res Function(_BenchmarkHistoryEntry) _then) = __$BenchmarkHistoryEntryCopyWithImpl;
@override @useResult
$Res call({
 int id, String startedAt, String finishedAt, int durationSec, int fps, int width, int height, bool verifyCaps, int encoderCount, int resolutionCount
});




}
/// @nodoc
class __$BenchmarkHistoryEntryCopyWithImpl<$Res>
    implements _$BenchmarkHistoryEntryCopyWith<$Res> {
  __$BenchmarkHistoryEntryCopyWithImpl(this._self, this._then);

  final _BenchmarkHistoryEntry _self;
  final $Res Function(_BenchmarkHistoryEntry) _then;

/// Create a copy of BenchmarkHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? startedAt = null,Object? finishedAt = null,Object? durationSec = null,Object? fps = null,Object? width = null,Object? height = null,Object? verifyCaps = null,Object? encoderCount = null,Object? resolutionCount = null,}) {
  return _then(_BenchmarkHistoryEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String,finishedAt: null == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as String,durationSec: null == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as int,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,verifyCaps: null == verifyCaps ? _self.verifyCaps : verifyCaps // ignore: cast_nullable_to_non_nullable
as bool,encoderCount: null == encoderCount ? _self.encoderCount : encoderCount // ignore: cast_nullable_to_non_nullable
as int,resolutionCount: null == resolutionCount ? _self.resolutionCount : resolutionCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$BenchmarkHistory {

 List<BenchmarkHistoryEntry> get entries;
/// Create a copy of BenchmarkHistory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BenchmarkHistoryCopyWith<BenchmarkHistory> get copyWith => _$BenchmarkHistoryCopyWithImpl<BenchmarkHistory>(this as BenchmarkHistory, _$identity);

  /// Serializes this BenchmarkHistory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BenchmarkHistory&&const DeepCollectionEquality().equals(other.entries, entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(entries));

@override
String toString() {
  return 'BenchmarkHistory(entries: $entries)';
}


}

/// @nodoc
abstract mixin class $BenchmarkHistoryCopyWith<$Res>  {
  factory $BenchmarkHistoryCopyWith(BenchmarkHistory value, $Res Function(BenchmarkHistory) _then) = _$BenchmarkHistoryCopyWithImpl;
@useResult
$Res call({
 List<BenchmarkHistoryEntry> entries
});




}
/// @nodoc
class _$BenchmarkHistoryCopyWithImpl<$Res>
    implements $BenchmarkHistoryCopyWith<$Res> {
  _$BenchmarkHistoryCopyWithImpl(this._self, this._then);

  final BenchmarkHistory _self;
  final $Res Function(BenchmarkHistory) _then;

/// Create a copy of BenchmarkHistory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entries = null,}) {
  return _then(_self.copyWith(
entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<BenchmarkHistoryEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [BenchmarkHistory].
extension BenchmarkHistoryPatterns on BenchmarkHistory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BenchmarkHistory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BenchmarkHistory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BenchmarkHistory value)  $default,){
final _that = this;
switch (_that) {
case _BenchmarkHistory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BenchmarkHistory value)?  $default,){
final _that = this;
switch (_that) {
case _BenchmarkHistory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<BenchmarkHistoryEntry> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BenchmarkHistory() when $default != null:
return $default(_that.entries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<BenchmarkHistoryEntry> entries)  $default,) {final _that = this;
switch (_that) {
case _BenchmarkHistory():
return $default(_that.entries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<BenchmarkHistoryEntry> entries)?  $default,) {final _that = this;
switch (_that) {
case _BenchmarkHistory() when $default != null:
return $default(_that.entries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BenchmarkHistory implements BenchmarkHistory {
  const _BenchmarkHistory({required final  List<BenchmarkHistoryEntry> entries}): _entries = entries;
  factory _BenchmarkHistory.fromJson(Map<String, dynamic> json) => _$BenchmarkHistoryFromJson(json);

 final  List<BenchmarkHistoryEntry> _entries;
@override List<BenchmarkHistoryEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of BenchmarkHistory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BenchmarkHistoryCopyWith<_BenchmarkHistory> get copyWith => __$BenchmarkHistoryCopyWithImpl<_BenchmarkHistory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BenchmarkHistoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BenchmarkHistory&&const DeepCollectionEquality().equals(other._entries, _entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries));

@override
String toString() {
  return 'BenchmarkHistory(entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$BenchmarkHistoryCopyWith<$Res> implements $BenchmarkHistoryCopyWith<$Res> {
  factory _$BenchmarkHistoryCopyWith(_BenchmarkHistory value, $Res Function(_BenchmarkHistory) _then) = __$BenchmarkHistoryCopyWithImpl;
@override @useResult
$Res call({
 List<BenchmarkHistoryEntry> entries
});




}
/// @nodoc
class __$BenchmarkHistoryCopyWithImpl<$Res>
    implements _$BenchmarkHistoryCopyWith<$Res> {
  __$BenchmarkHistoryCopyWithImpl(this._self, this._then);

  final _BenchmarkHistory _self;
  final $Res Function(_BenchmarkHistory) _then;

/// Create a copy of BenchmarkHistory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entries = null,}) {
  return _then(_BenchmarkHistory(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<BenchmarkHistoryEntry>,
  ));
}


}


/// @nodoc
mixin _$BenchmarkProgress {

 bool get running; String? get startedAt; int? get totalEncoders; int? get completed; String? get currentEncoder; String? get currentStep; int? get currentIndex;/// Matrix-mode counters.  ``totalResolutions`` is the size of the
/// operator's resolution list (1 for single-resolution runs);
/// ``currentResolutionIndex`` is 1-based so the UI can render
/// "Resolution N of M" without subtracting; the width/height pair
/// names the resolution currently being measured.  All four are
/// null in the idle state and populated as soon as ``running``
/// flips to true.
 int? get totalResolutions; int? get currentResolutionIndex; int? get currentResolutionWidth; int? get currentResolutionHeight;
/// Create a copy of BenchmarkProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BenchmarkProgressCopyWith<BenchmarkProgress> get copyWith => _$BenchmarkProgressCopyWithImpl<BenchmarkProgress>(this as BenchmarkProgress, _$identity);

  /// Serializes this BenchmarkProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BenchmarkProgress&&(identical(other.running, running) || other.running == running)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.totalEncoders, totalEncoders) || other.totalEncoders == totalEncoders)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.currentEncoder, currentEncoder) || other.currentEncoder == currentEncoder)&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.totalResolutions, totalResolutions) || other.totalResolutions == totalResolutions)&&(identical(other.currentResolutionIndex, currentResolutionIndex) || other.currentResolutionIndex == currentResolutionIndex)&&(identical(other.currentResolutionWidth, currentResolutionWidth) || other.currentResolutionWidth == currentResolutionWidth)&&(identical(other.currentResolutionHeight, currentResolutionHeight) || other.currentResolutionHeight == currentResolutionHeight));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,running,startedAt,totalEncoders,completed,currentEncoder,currentStep,currentIndex,totalResolutions,currentResolutionIndex,currentResolutionWidth,currentResolutionHeight);

@override
String toString() {
  return 'BenchmarkProgress(running: $running, startedAt: $startedAt, totalEncoders: $totalEncoders, completed: $completed, currentEncoder: $currentEncoder, currentStep: $currentStep, currentIndex: $currentIndex, totalResolutions: $totalResolutions, currentResolutionIndex: $currentResolutionIndex, currentResolutionWidth: $currentResolutionWidth, currentResolutionHeight: $currentResolutionHeight)';
}


}

/// @nodoc
abstract mixin class $BenchmarkProgressCopyWith<$Res>  {
  factory $BenchmarkProgressCopyWith(BenchmarkProgress value, $Res Function(BenchmarkProgress) _then) = _$BenchmarkProgressCopyWithImpl;
@useResult
$Res call({
 bool running, String? startedAt, int? totalEncoders, int? completed, String? currentEncoder, String? currentStep, int? currentIndex, int? totalResolutions, int? currentResolutionIndex, int? currentResolutionWidth, int? currentResolutionHeight
});




}
/// @nodoc
class _$BenchmarkProgressCopyWithImpl<$Res>
    implements $BenchmarkProgressCopyWith<$Res> {
  _$BenchmarkProgressCopyWithImpl(this._self, this._then);

  final BenchmarkProgress _self;
  final $Res Function(BenchmarkProgress) _then;

/// Create a copy of BenchmarkProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? running = null,Object? startedAt = freezed,Object? totalEncoders = freezed,Object? completed = freezed,Object? currentEncoder = freezed,Object? currentStep = freezed,Object? currentIndex = freezed,Object? totalResolutions = freezed,Object? currentResolutionIndex = freezed,Object? currentResolutionWidth = freezed,Object? currentResolutionHeight = freezed,}) {
  return _then(_self.copyWith(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String?,totalEncoders: freezed == totalEncoders ? _self.totalEncoders : totalEncoders // ignore: cast_nullable_to_non_nullable
as int?,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int?,currentEncoder: freezed == currentEncoder ? _self.currentEncoder : currentEncoder // ignore: cast_nullable_to_non_nullable
as String?,currentStep: freezed == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as String?,currentIndex: freezed == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int?,totalResolutions: freezed == totalResolutions ? _self.totalResolutions : totalResolutions // ignore: cast_nullable_to_non_nullable
as int?,currentResolutionIndex: freezed == currentResolutionIndex ? _self.currentResolutionIndex : currentResolutionIndex // ignore: cast_nullable_to_non_nullable
as int?,currentResolutionWidth: freezed == currentResolutionWidth ? _self.currentResolutionWidth : currentResolutionWidth // ignore: cast_nullable_to_non_nullable
as int?,currentResolutionHeight: freezed == currentResolutionHeight ? _self.currentResolutionHeight : currentResolutionHeight // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [BenchmarkProgress].
extension BenchmarkProgressPatterns on BenchmarkProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BenchmarkProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BenchmarkProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BenchmarkProgress value)  $default,){
final _that = this;
switch (_that) {
case _BenchmarkProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BenchmarkProgress value)?  $default,){
final _that = this;
switch (_that) {
case _BenchmarkProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool running,  String? startedAt,  int? totalEncoders,  int? completed,  String? currentEncoder,  String? currentStep,  int? currentIndex,  int? totalResolutions,  int? currentResolutionIndex,  int? currentResolutionWidth,  int? currentResolutionHeight)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BenchmarkProgress() when $default != null:
return $default(_that.running,_that.startedAt,_that.totalEncoders,_that.completed,_that.currentEncoder,_that.currentStep,_that.currentIndex,_that.totalResolutions,_that.currentResolutionIndex,_that.currentResolutionWidth,_that.currentResolutionHeight);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool running,  String? startedAt,  int? totalEncoders,  int? completed,  String? currentEncoder,  String? currentStep,  int? currentIndex,  int? totalResolutions,  int? currentResolutionIndex,  int? currentResolutionWidth,  int? currentResolutionHeight)  $default,) {final _that = this;
switch (_that) {
case _BenchmarkProgress():
return $default(_that.running,_that.startedAt,_that.totalEncoders,_that.completed,_that.currentEncoder,_that.currentStep,_that.currentIndex,_that.totalResolutions,_that.currentResolutionIndex,_that.currentResolutionWidth,_that.currentResolutionHeight);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool running,  String? startedAt,  int? totalEncoders,  int? completed,  String? currentEncoder,  String? currentStep,  int? currentIndex,  int? totalResolutions,  int? currentResolutionIndex,  int? currentResolutionWidth,  int? currentResolutionHeight)?  $default,) {final _that = this;
switch (_that) {
case _BenchmarkProgress() when $default != null:
return $default(_that.running,_that.startedAt,_that.totalEncoders,_that.completed,_that.currentEncoder,_that.currentStep,_that.currentIndex,_that.totalResolutions,_that.currentResolutionIndex,_that.currentResolutionWidth,_that.currentResolutionHeight);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BenchmarkProgress implements BenchmarkProgress {
  const _BenchmarkProgress({required this.running, this.startedAt, this.totalEncoders, this.completed, this.currentEncoder, this.currentStep, this.currentIndex, this.totalResolutions, this.currentResolutionIndex, this.currentResolutionWidth, this.currentResolutionHeight});
  factory _BenchmarkProgress.fromJson(Map<String, dynamic> json) => _$BenchmarkProgressFromJson(json);

@override final  bool running;
@override final  String? startedAt;
@override final  int? totalEncoders;
@override final  int? completed;
@override final  String? currentEncoder;
@override final  String? currentStep;
@override final  int? currentIndex;
/// Matrix-mode counters.  ``totalResolutions`` is the size of the
/// operator's resolution list (1 for single-resolution runs);
/// ``currentResolutionIndex`` is 1-based so the UI can render
/// "Resolution N of M" without subtracting; the width/height pair
/// names the resolution currently being measured.  All four are
/// null in the idle state and populated as soon as ``running``
/// flips to true.
@override final  int? totalResolutions;
@override final  int? currentResolutionIndex;
@override final  int? currentResolutionWidth;
@override final  int? currentResolutionHeight;

/// Create a copy of BenchmarkProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BenchmarkProgressCopyWith<_BenchmarkProgress> get copyWith => __$BenchmarkProgressCopyWithImpl<_BenchmarkProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BenchmarkProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BenchmarkProgress&&(identical(other.running, running) || other.running == running)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.totalEncoders, totalEncoders) || other.totalEncoders == totalEncoders)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.currentEncoder, currentEncoder) || other.currentEncoder == currentEncoder)&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.totalResolutions, totalResolutions) || other.totalResolutions == totalResolutions)&&(identical(other.currentResolutionIndex, currentResolutionIndex) || other.currentResolutionIndex == currentResolutionIndex)&&(identical(other.currentResolutionWidth, currentResolutionWidth) || other.currentResolutionWidth == currentResolutionWidth)&&(identical(other.currentResolutionHeight, currentResolutionHeight) || other.currentResolutionHeight == currentResolutionHeight));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,running,startedAt,totalEncoders,completed,currentEncoder,currentStep,currentIndex,totalResolutions,currentResolutionIndex,currentResolutionWidth,currentResolutionHeight);

@override
String toString() {
  return 'BenchmarkProgress(running: $running, startedAt: $startedAt, totalEncoders: $totalEncoders, completed: $completed, currentEncoder: $currentEncoder, currentStep: $currentStep, currentIndex: $currentIndex, totalResolutions: $totalResolutions, currentResolutionIndex: $currentResolutionIndex, currentResolutionWidth: $currentResolutionWidth, currentResolutionHeight: $currentResolutionHeight)';
}


}

/// @nodoc
abstract mixin class _$BenchmarkProgressCopyWith<$Res> implements $BenchmarkProgressCopyWith<$Res> {
  factory _$BenchmarkProgressCopyWith(_BenchmarkProgress value, $Res Function(_BenchmarkProgress) _then) = __$BenchmarkProgressCopyWithImpl;
@override @useResult
$Res call({
 bool running, String? startedAt, int? totalEncoders, int? completed, String? currentEncoder, String? currentStep, int? currentIndex, int? totalResolutions, int? currentResolutionIndex, int? currentResolutionWidth, int? currentResolutionHeight
});




}
/// @nodoc
class __$BenchmarkProgressCopyWithImpl<$Res>
    implements _$BenchmarkProgressCopyWith<$Res> {
  __$BenchmarkProgressCopyWithImpl(this._self, this._then);

  final _BenchmarkProgress _self;
  final $Res Function(_BenchmarkProgress) _then;

/// Create a copy of BenchmarkProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? running = null,Object? startedAt = freezed,Object? totalEncoders = freezed,Object? completed = freezed,Object? currentEncoder = freezed,Object? currentStep = freezed,Object? currentIndex = freezed,Object? totalResolutions = freezed,Object? currentResolutionIndex = freezed,Object? currentResolutionWidth = freezed,Object? currentResolutionHeight = freezed,}) {
  return _then(_BenchmarkProgress(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as bool,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String?,totalEncoders: freezed == totalEncoders ? _self.totalEncoders : totalEncoders // ignore: cast_nullable_to_non_nullable
as int?,completed: freezed == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int?,currentEncoder: freezed == currentEncoder ? _self.currentEncoder : currentEncoder // ignore: cast_nullable_to_non_nullable
as String?,currentStep: freezed == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as String?,currentIndex: freezed == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int?,totalResolutions: freezed == totalResolutions ? _self.totalResolutions : totalResolutions // ignore: cast_nullable_to_non_nullable
as int?,currentResolutionIndex: freezed == currentResolutionIndex ? _self.currentResolutionIndex : currentResolutionIndex // ignore: cast_nullable_to_non_nullable
as int?,currentResolutionWidth: freezed == currentResolutionWidth ? _self.currentResolutionWidth : currentResolutionWidth // ignore: cast_nullable_to_non_nullable
as int?,currentResolutionHeight: freezed == currentResolutionHeight ? _self.currentResolutionHeight : currentResolutionHeight // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
