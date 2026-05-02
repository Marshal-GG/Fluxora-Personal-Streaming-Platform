// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcoding_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EncoderLoad {

 String get encoder; int get activeSessions; double? get gpuUtilizationPercent; int? get vramUsedMb; double? get cpuUtilizationPercent;
/// Create a copy of EncoderLoad
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EncoderLoadCopyWith<EncoderLoad> get copyWith => _$EncoderLoadCopyWithImpl<EncoderLoad>(this as EncoderLoad, _$identity);

  /// Serializes this EncoderLoad to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EncoderLoad&&(identical(other.encoder, encoder) || other.encoder == encoder)&&(identical(other.activeSessions, activeSessions) || other.activeSessions == activeSessions)&&(identical(other.gpuUtilizationPercent, gpuUtilizationPercent) || other.gpuUtilizationPercent == gpuUtilizationPercent)&&(identical(other.vramUsedMb, vramUsedMb) || other.vramUsedMb == vramUsedMb)&&(identical(other.cpuUtilizationPercent, cpuUtilizationPercent) || other.cpuUtilizationPercent == cpuUtilizationPercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,encoder,activeSessions,gpuUtilizationPercent,vramUsedMb,cpuUtilizationPercent);

@override
String toString() {
  return 'EncoderLoad(encoder: $encoder, activeSessions: $activeSessions, gpuUtilizationPercent: $gpuUtilizationPercent, vramUsedMb: $vramUsedMb, cpuUtilizationPercent: $cpuUtilizationPercent)';
}


}

/// @nodoc
abstract mixin class $EncoderLoadCopyWith<$Res>  {
  factory $EncoderLoadCopyWith(EncoderLoad value, $Res Function(EncoderLoad) _then) = _$EncoderLoadCopyWithImpl;
@useResult
$Res call({
 String encoder, int activeSessions, double? gpuUtilizationPercent, int? vramUsedMb, double? cpuUtilizationPercent
});




}
/// @nodoc
class _$EncoderLoadCopyWithImpl<$Res>
    implements $EncoderLoadCopyWith<$Res> {
  _$EncoderLoadCopyWithImpl(this._self, this._then);

  final EncoderLoad _self;
  final $Res Function(EncoderLoad) _then;

/// Create a copy of EncoderLoad
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? encoder = null,Object? activeSessions = null,Object? gpuUtilizationPercent = freezed,Object? vramUsedMb = freezed,Object? cpuUtilizationPercent = freezed,}) {
  return _then(_self.copyWith(
encoder: null == encoder ? _self.encoder : encoder // ignore: cast_nullable_to_non_nullable
as String,activeSessions: null == activeSessions ? _self.activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as int,gpuUtilizationPercent: freezed == gpuUtilizationPercent ? _self.gpuUtilizationPercent : gpuUtilizationPercent // ignore: cast_nullable_to_non_nullable
as double?,vramUsedMb: freezed == vramUsedMb ? _self.vramUsedMb : vramUsedMb // ignore: cast_nullable_to_non_nullable
as int?,cpuUtilizationPercent: freezed == cpuUtilizationPercent ? _self.cpuUtilizationPercent : cpuUtilizationPercent // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [EncoderLoad].
extension EncoderLoadPatterns on EncoderLoad {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EncoderLoad value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EncoderLoad() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EncoderLoad value)  $default,){
final _that = this;
switch (_that) {
case _EncoderLoad():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EncoderLoad value)?  $default,){
final _that = this;
switch (_that) {
case _EncoderLoad() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String encoder,  int activeSessions,  double? gpuUtilizationPercent,  int? vramUsedMb,  double? cpuUtilizationPercent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EncoderLoad() when $default != null:
return $default(_that.encoder,_that.activeSessions,_that.gpuUtilizationPercent,_that.vramUsedMb,_that.cpuUtilizationPercent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String encoder,  int activeSessions,  double? gpuUtilizationPercent,  int? vramUsedMb,  double? cpuUtilizationPercent)  $default,) {final _that = this;
switch (_that) {
case _EncoderLoad():
return $default(_that.encoder,_that.activeSessions,_that.gpuUtilizationPercent,_that.vramUsedMb,_that.cpuUtilizationPercent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String encoder,  int activeSessions,  double? gpuUtilizationPercent,  int? vramUsedMb,  double? cpuUtilizationPercent)?  $default,) {final _that = this;
switch (_that) {
case _EncoderLoad() when $default != null:
return $default(_that.encoder,_that.activeSessions,_that.gpuUtilizationPercent,_that.vramUsedMb,_that.cpuUtilizationPercent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EncoderLoad implements EncoderLoad {
  const _EncoderLoad({required this.encoder, required this.activeSessions, this.gpuUtilizationPercent, this.vramUsedMb, this.cpuUtilizationPercent});
  factory _EncoderLoad.fromJson(Map<String, dynamic> json) => _$EncoderLoadFromJson(json);

@override final  String encoder;
@override final  int activeSessions;
@override final  double? gpuUtilizationPercent;
@override final  int? vramUsedMb;
@override final  double? cpuUtilizationPercent;

/// Create a copy of EncoderLoad
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EncoderLoadCopyWith<_EncoderLoad> get copyWith => __$EncoderLoadCopyWithImpl<_EncoderLoad>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EncoderLoadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EncoderLoad&&(identical(other.encoder, encoder) || other.encoder == encoder)&&(identical(other.activeSessions, activeSessions) || other.activeSessions == activeSessions)&&(identical(other.gpuUtilizationPercent, gpuUtilizationPercent) || other.gpuUtilizationPercent == gpuUtilizationPercent)&&(identical(other.vramUsedMb, vramUsedMb) || other.vramUsedMb == vramUsedMb)&&(identical(other.cpuUtilizationPercent, cpuUtilizationPercent) || other.cpuUtilizationPercent == cpuUtilizationPercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,encoder,activeSessions,gpuUtilizationPercent,vramUsedMb,cpuUtilizationPercent);

@override
String toString() {
  return 'EncoderLoad(encoder: $encoder, activeSessions: $activeSessions, gpuUtilizationPercent: $gpuUtilizationPercent, vramUsedMb: $vramUsedMb, cpuUtilizationPercent: $cpuUtilizationPercent)';
}


}

/// @nodoc
abstract mixin class _$EncoderLoadCopyWith<$Res> implements $EncoderLoadCopyWith<$Res> {
  factory _$EncoderLoadCopyWith(_EncoderLoad value, $Res Function(_EncoderLoad) _then) = __$EncoderLoadCopyWithImpl;
@override @useResult
$Res call({
 String encoder, int activeSessions, double? gpuUtilizationPercent, int? vramUsedMb, double? cpuUtilizationPercent
});




}
/// @nodoc
class __$EncoderLoadCopyWithImpl<$Res>
    implements _$EncoderLoadCopyWith<$Res> {
  __$EncoderLoadCopyWithImpl(this._self, this._then);

  final _EncoderLoad _self;
  final $Res Function(_EncoderLoad) _then;

/// Create a copy of EncoderLoad
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? encoder = null,Object? activeSessions = null,Object? gpuUtilizationPercent = freezed,Object? vramUsedMb = freezed,Object? cpuUtilizationPercent = freezed,}) {
  return _then(_EncoderLoad(
encoder: null == encoder ? _self.encoder : encoder // ignore: cast_nullable_to_non_nullable
as String,activeSessions: null == activeSessions ? _self.activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as int,gpuUtilizationPercent: freezed == gpuUtilizationPercent ? _self.gpuUtilizationPercent : gpuUtilizationPercent // ignore: cast_nullable_to_non_nullable
as double?,vramUsedMb: freezed == vramUsedMb ? _self.vramUsedMb : vramUsedMb // ignore: cast_nullable_to_non_nullable
as int?,cpuUtilizationPercent: freezed == cpuUtilizationPercent ? _self.cpuUtilizationPercent : cpuUtilizationPercent // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$ActiveTranscodeSession {

 String get id; String? get clientId; String? get clientName; String? get mediaTitle; String? get inputCodec; String? get outputCodec; double? get fps; double? get speedX; double? get progress;
/// Create a copy of ActiveTranscodeSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActiveTranscodeSessionCopyWith<ActiveTranscodeSession> get copyWith => _$ActiveTranscodeSessionCopyWithImpl<ActiveTranscodeSession>(this as ActiveTranscodeSession, _$identity);

  /// Serializes this ActiveTranscodeSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActiveTranscodeSession&&(identical(other.id, id) || other.id == id)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.clientName, clientName) || other.clientName == clientName)&&(identical(other.mediaTitle, mediaTitle) || other.mediaTitle == mediaTitle)&&(identical(other.inputCodec, inputCodec) || other.inputCodec == inputCodec)&&(identical(other.outputCodec, outputCodec) || other.outputCodec == outputCodec)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.speedX, speedX) || other.speedX == speedX)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,clientId,clientName,mediaTitle,inputCodec,outputCodec,fps,speedX,progress);

@override
String toString() {
  return 'ActiveTranscodeSession(id: $id, clientId: $clientId, clientName: $clientName, mediaTitle: $mediaTitle, inputCodec: $inputCodec, outputCodec: $outputCodec, fps: $fps, speedX: $speedX, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $ActiveTranscodeSessionCopyWith<$Res>  {
  factory $ActiveTranscodeSessionCopyWith(ActiveTranscodeSession value, $Res Function(ActiveTranscodeSession) _then) = _$ActiveTranscodeSessionCopyWithImpl;
@useResult
$Res call({
 String id, String? clientId, String? clientName, String? mediaTitle, String? inputCodec, String? outputCodec, double? fps, double? speedX, double? progress
});




}
/// @nodoc
class _$ActiveTranscodeSessionCopyWithImpl<$Res>
    implements $ActiveTranscodeSessionCopyWith<$Res> {
  _$ActiveTranscodeSessionCopyWithImpl(this._self, this._then);

  final ActiveTranscodeSession _self;
  final $Res Function(ActiveTranscodeSession) _then;

/// Create a copy of ActiveTranscodeSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? clientId = freezed,Object? clientName = freezed,Object? mediaTitle = freezed,Object? inputCodec = freezed,Object? outputCodec = freezed,Object? fps = freezed,Object? speedX = freezed,Object? progress = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,clientName: freezed == clientName ? _self.clientName : clientName // ignore: cast_nullable_to_non_nullable
as String?,mediaTitle: freezed == mediaTitle ? _self.mediaTitle : mediaTitle // ignore: cast_nullable_to_non_nullable
as String?,inputCodec: freezed == inputCodec ? _self.inputCodec : inputCodec // ignore: cast_nullable_to_non_nullable
as String?,outputCodec: freezed == outputCodec ? _self.outputCodec : outputCodec // ignore: cast_nullable_to_non_nullable
as String?,fps: freezed == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double?,speedX: freezed == speedX ? _self.speedX : speedX // ignore: cast_nullable_to_non_nullable
as double?,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ActiveTranscodeSession].
extension ActiveTranscodeSessionPatterns on ActiveTranscodeSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActiveTranscodeSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActiveTranscodeSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActiveTranscodeSession value)  $default,){
final _that = this;
switch (_that) {
case _ActiveTranscodeSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActiveTranscodeSession value)?  $default,){
final _that = this;
switch (_that) {
case _ActiveTranscodeSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? clientId,  String? clientName,  String? mediaTitle,  String? inputCodec,  String? outputCodec,  double? fps,  double? speedX,  double? progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActiveTranscodeSession() when $default != null:
return $default(_that.id,_that.clientId,_that.clientName,_that.mediaTitle,_that.inputCodec,_that.outputCodec,_that.fps,_that.speedX,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? clientId,  String? clientName,  String? mediaTitle,  String? inputCodec,  String? outputCodec,  double? fps,  double? speedX,  double? progress)  $default,) {final _that = this;
switch (_that) {
case _ActiveTranscodeSession():
return $default(_that.id,_that.clientId,_that.clientName,_that.mediaTitle,_that.inputCodec,_that.outputCodec,_that.fps,_that.speedX,_that.progress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? clientId,  String? clientName,  String? mediaTitle,  String? inputCodec,  String? outputCodec,  double? fps,  double? speedX,  double? progress)?  $default,) {final _that = this;
switch (_that) {
case _ActiveTranscodeSession() when $default != null:
return $default(_that.id,_that.clientId,_that.clientName,_that.mediaTitle,_that.inputCodec,_that.outputCodec,_that.fps,_that.speedX,_that.progress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActiveTranscodeSession implements ActiveTranscodeSession {
  const _ActiveTranscodeSession({required this.id, this.clientId, this.clientName, this.mediaTitle, this.inputCodec, this.outputCodec, this.fps, this.speedX, this.progress});
  factory _ActiveTranscodeSession.fromJson(Map<String, dynamic> json) => _$ActiveTranscodeSessionFromJson(json);

@override final  String id;
@override final  String? clientId;
@override final  String? clientName;
@override final  String? mediaTitle;
@override final  String? inputCodec;
@override final  String? outputCodec;
@override final  double? fps;
@override final  double? speedX;
@override final  double? progress;

/// Create a copy of ActiveTranscodeSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActiveTranscodeSessionCopyWith<_ActiveTranscodeSession> get copyWith => __$ActiveTranscodeSessionCopyWithImpl<_ActiveTranscodeSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActiveTranscodeSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActiveTranscodeSession&&(identical(other.id, id) || other.id == id)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.clientName, clientName) || other.clientName == clientName)&&(identical(other.mediaTitle, mediaTitle) || other.mediaTitle == mediaTitle)&&(identical(other.inputCodec, inputCodec) || other.inputCodec == inputCodec)&&(identical(other.outputCodec, outputCodec) || other.outputCodec == outputCodec)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.speedX, speedX) || other.speedX == speedX)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,clientId,clientName,mediaTitle,inputCodec,outputCodec,fps,speedX,progress);

@override
String toString() {
  return 'ActiveTranscodeSession(id: $id, clientId: $clientId, clientName: $clientName, mediaTitle: $mediaTitle, inputCodec: $inputCodec, outputCodec: $outputCodec, fps: $fps, speedX: $speedX, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$ActiveTranscodeSessionCopyWith<$Res> implements $ActiveTranscodeSessionCopyWith<$Res> {
  factory _$ActiveTranscodeSessionCopyWith(_ActiveTranscodeSession value, $Res Function(_ActiveTranscodeSession) _then) = __$ActiveTranscodeSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String? clientId, String? clientName, String? mediaTitle, String? inputCodec, String? outputCodec, double? fps, double? speedX, double? progress
});




}
/// @nodoc
class __$ActiveTranscodeSessionCopyWithImpl<$Res>
    implements _$ActiveTranscodeSessionCopyWith<$Res> {
  __$ActiveTranscodeSessionCopyWithImpl(this._self, this._then);

  final _ActiveTranscodeSession _self;
  final $Res Function(_ActiveTranscodeSession) _then;

/// Create a copy of ActiveTranscodeSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? clientId = freezed,Object? clientName = freezed,Object? mediaTitle = freezed,Object? inputCodec = freezed,Object? outputCodec = freezed,Object? fps = freezed,Object? speedX = freezed,Object? progress = freezed,}) {
  return _then(_ActiveTranscodeSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,clientName: freezed == clientName ? _self.clientName : clientName // ignore: cast_nullable_to_non_nullable
as String?,mediaTitle: freezed == mediaTitle ? _self.mediaTitle : mediaTitle // ignore: cast_nullable_to_non_nullable
as String?,inputCodec: freezed == inputCodec ? _self.inputCodec : inputCodec // ignore: cast_nullable_to_non_nullable
as String?,outputCodec: freezed == outputCodec ? _self.outputCodec : outputCodec // ignore: cast_nullable_to_non_nullable
as String?,fps: freezed == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double?,speedX: freezed == speedX ? _self.speedX : speedX // ignore: cast_nullable_to_non_nullable
as double?,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$TranscodingStatus {

 String get activeEncoder; List<String> get availableEncoders; List<EncoderLoad> get encoderLoads; List<ActiveTranscodeSession> get activeSessions;
/// Create a copy of TranscodingStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscodingStatusCopyWith<TranscodingStatus> get copyWith => _$TranscodingStatusCopyWithImpl<TranscodingStatus>(this as TranscodingStatus, _$identity);

  /// Serializes this TranscodingStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscodingStatus&&(identical(other.activeEncoder, activeEncoder) || other.activeEncoder == activeEncoder)&&const DeepCollectionEquality().equals(other.availableEncoders, availableEncoders)&&const DeepCollectionEquality().equals(other.encoderLoads, encoderLoads)&&const DeepCollectionEquality().equals(other.activeSessions, activeSessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,activeEncoder,const DeepCollectionEquality().hash(availableEncoders),const DeepCollectionEquality().hash(encoderLoads),const DeepCollectionEquality().hash(activeSessions));

@override
String toString() {
  return 'TranscodingStatus(activeEncoder: $activeEncoder, availableEncoders: $availableEncoders, encoderLoads: $encoderLoads, activeSessions: $activeSessions)';
}


}

/// @nodoc
abstract mixin class $TranscodingStatusCopyWith<$Res>  {
  factory $TranscodingStatusCopyWith(TranscodingStatus value, $Res Function(TranscodingStatus) _then) = _$TranscodingStatusCopyWithImpl;
@useResult
$Res call({
 String activeEncoder, List<String> availableEncoders, List<EncoderLoad> encoderLoads, List<ActiveTranscodeSession> activeSessions
});




}
/// @nodoc
class _$TranscodingStatusCopyWithImpl<$Res>
    implements $TranscodingStatusCopyWith<$Res> {
  _$TranscodingStatusCopyWithImpl(this._self, this._then);

  final TranscodingStatus _self;
  final $Res Function(TranscodingStatus) _then;

/// Create a copy of TranscodingStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? activeEncoder = null,Object? availableEncoders = null,Object? encoderLoads = null,Object? activeSessions = null,}) {
  return _then(_self.copyWith(
activeEncoder: null == activeEncoder ? _self.activeEncoder : activeEncoder // ignore: cast_nullable_to_non_nullable
as String,availableEncoders: null == availableEncoders ? _self.availableEncoders : availableEncoders // ignore: cast_nullable_to_non_nullable
as List<String>,encoderLoads: null == encoderLoads ? _self.encoderLoads : encoderLoads // ignore: cast_nullable_to_non_nullable
as List<EncoderLoad>,activeSessions: null == activeSessions ? _self.activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as List<ActiveTranscodeSession>,
  ));
}

}


/// Adds pattern-matching-related methods to [TranscodingStatus].
extension TranscodingStatusPatterns on TranscodingStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TranscodingStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TranscodingStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TranscodingStatus value)  $default,){
final _that = this;
switch (_that) {
case _TranscodingStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TranscodingStatus value)?  $default,){
final _that = this;
switch (_that) {
case _TranscodingStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String activeEncoder,  List<String> availableEncoders,  List<EncoderLoad> encoderLoads,  List<ActiveTranscodeSession> activeSessions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TranscodingStatus() when $default != null:
return $default(_that.activeEncoder,_that.availableEncoders,_that.encoderLoads,_that.activeSessions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String activeEncoder,  List<String> availableEncoders,  List<EncoderLoad> encoderLoads,  List<ActiveTranscodeSession> activeSessions)  $default,) {final _that = this;
switch (_that) {
case _TranscodingStatus():
return $default(_that.activeEncoder,_that.availableEncoders,_that.encoderLoads,_that.activeSessions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String activeEncoder,  List<String> availableEncoders,  List<EncoderLoad> encoderLoads,  List<ActiveTranscodeSession> activeSessions)?  $default,) {final _that = this;
switch (_that) {
case _TranscodingStatus() when $default != null:
return $default(_that.activeEncoder,_that.availableEncoders,_that.encoderLoads,_that.activeSessions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TranscodingStatus implements TranscodingStatus {
  const _TranscodingStatus({required this.activeEncoder, required final  List<String> availableEncoders, required final  List<EncoderLoad> encoderLoads, required final  List<ActiveTranscodeSession> activeSessions}): _availableEncoders = availableEncoders,_encoderLoads = encoderLoads,_activeSessions = activeSessions;
  factory _TranscodingStatus.fromJson(Map<String, dynamic> json) => _$TranscodingStatusFromJson(json);

@override final  String activeEncoder;
 final  List<String> _availableEncoders;
@override List<String> get availableEncoders {
  if (_availableEncoders is EqualUnmodifiableListView) return _availableEncoders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableEncoders);
}

 final  List<EncoderLoad> _encoderLoads;
@override List<EncoderLoad> get encoderLoads {
  if (_encoderLoads is EqualUnmodifiableListView) return _encoderLoads;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_encoderLoads);
}

 final  List<ActiveTranscodeSession> _activeSessions;
@override List<ActiveTranscodeSession> get activeSessions {
  if (_activeSessions is EqualUnmodifiableListView) return _activeSessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_activeSessions);
}


/// Create a copy of TranscodingStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TranscodingStatusCopyWith<_TranscodingStatus> get copyWith => __$TranscodingStatusCopyWithImpl<_TranscodingStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TranscodingStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TranscodingStatus&&(identical(other.activeEncoder, activeEncoder) || other.activeEncoder == activeEncoder)&&const DeepCollectionEquality().equals(other._availableEncoders, _availableEncoders)&&const DeepCollectionEquality().equals(other._encoderLoads, _encoderLoads)&&const DeepCollectionEquality().equals(other._activeSessions, _activeSessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,activeEncoder,const DeepCollectionEquality().hash(_availableEncoders),const DeepCollectionEquality().hash(_encoderLoads),const DeepCollectionEquality().hash(_activeSessions));

@override
String toString() {
  return 'TranscodingStatus(activeEncoder: $activeEncoder, availableEncoders: $availableEncoders, encoderLoads: $encoderLoads, activeSessions: $activeSessions)';
}


}

/// @nodoc
abstract mixin class _$TranscodingStatusCopyWith<$Res> implements $TranscodingStatusCopyWith<$Res> {
  factory _$TranscodingStatusCopyWith(_TranscodingStatus value, $Res Function(_TranscodingStatus) _then) = __$TranscodingStatusCopyWithImpl;
@override @useResult
$Res call({
 String activeEncoder, List<String> availableEncoders, List<EncoderLoad> encoderLoads, List<ActiveTranscodeSession> activeSessions
});




}
/// @nodoc
class __$TranscodingStatusCopyWithImpl<$Res>
    implements _$TranscodingStatusCopyWith<$Res> {
  __$TranscodingStatusCopyWithImpl(this._self, this._then);

  final _TranscodingStatus _self;
  final $Res Function(_TranscodingStatus) _then;

/// Create a copy of TranscodingStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? activeEncoder = null,Object? availableEncoders = null,Object? encoderLoads = null,Object? activeSessions = null,}) {
  return _then(_TranscodingStatus(
activeEncoder: null == activeEncoder ? _self.activeEncoder : activeEncoder // ignore: cast_nullable_to_non_nullable
as String,availableEncoders: null == availableEncoders ? _self._availableEncoders : availableEncoders // ignore: cast_nullable_to_non_nullable
as List<String>,encoderLoads: null == encoderLoads ? _self._encoderLoads : encoderLoads // ignore: cast_nullable_to_non_nullable
as List<EncoderLoad>,activeSessions: null == activeSessions ? _self._activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as List<ActiveTranscodeSession>,
  ));
}


}

// dart format on
