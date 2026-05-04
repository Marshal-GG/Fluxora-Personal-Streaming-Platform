// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hardware_devices.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CpuInfo {

 String get vendor; String get model; int get threads;
/// Create a copy of CpuInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpuInfoCopyWith<CpuInfo> get copyWith => _$CpuInfoCopyWithImpl<CpuInfo>(this as CpuInfo, _$identity);

  /// Serializes this CpuInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpuInfo&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.model, model) || other.model == model)&&(identical(other.threads, threads) || other.threads == threads));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,vendor,model,threads);

@override
String toString() {
  return 'CpuInfo(vendor: $vendor, model: $model, threads: $threads)';
}


}

/// @nodoc
abstract mixin class $CpuInfoCopyWith<$Res>  {
  factory $CpuInfoCopyWith(CpuInfo value, $Res Function(CpuInfo) _then) = _$CpuInfoCopyWithImpl;
@useResult
$Res call({
 String vendor, String model, int threads
});




}
/// @nodoc
class _$CpuInfoCopyWithImpl<$Res>
    implements $CpuInfoCopyWith<$Res> {
  _$CpuInfoCopyWithImpl(this._self, this._then);

  final CpuInfo _self;
  final $Res Function(CpuInfo) _then;

/// Create a copy of CpuInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? vendor = null,Object? model = null,Object? threads = null,}) {
  return _then(_self.copyWith(
vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,threads: null == threads ? _self.threads : threads // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CpuInfo].
extension CpuInfoPatterns on CpuInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpuInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpuInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpuInfo value)  $default,){
final _that = this;
switch (_that) {
case _CpuInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpuInfo value)?  $default,){
final _that = this;
switch (_that) {
case _CpuInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String vendor,  String model,  int threads)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpuInfo() when $default != null:
return $default(_that.vendor,_that.model,_that.threads);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String vendor,  String model,  int threads)  $default,) {final _that = this;
switch (_that) {
case _CpuInfo():
return $default(_that.vendor,_that.model,_that.threads);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String vendor,  String model,  int threads)?  $default,) {final _that = this;
switch (_that) {
case _CpuInfo() when $default != null:
return $default(_that.vendor,_that.model,_that.threads);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CpuInfo implements CpuInfo {
  const _CpuInfo({required this.vendor, required this.model, required this.threads});
  factory _CpuInfo.fromJson(Map<String, dynamic> json) => _$CpuInfoFromJson(json);

@override final  String vendor;
@override final  String model;
@override final  int threads;

/// Create a copy of CpuInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpuInfoCopyWith<_CpuInfo> get copyWith => __$CpuInfoCopyWithImpl<_CpuInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CpuInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpuInfo&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.model, model) || other.model == model)&&(identical(other.threads, threads) || other.threads == threads));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,vendor,model,threads);

@override
String toString() {
  return 'CpuInfo(vendor: $vendor, model: $model, threads: $threads)';
}


}

/// @nodoc
abstract mixin class _$CpuInfoCopyWith<$Res> implements $CpuInfoCopyWith<$Res> {
  factory _$CpuInfoCopyWith(_CpuInfo value, $Res Function(_CpuInfo) _then) = __$CpuInfoCopyWithImpl;
@override @useResult
$Res call({
 String vendor, String model, int threads
});




}
/// @nodoc
class __$CpuInfoCopyWithImpl<$Res>
    implements _$CpuInfoCopyWith<$Res> {
  __$CpuInfoCopyWithImpl(this._self, this._then);

  final _CpuInfo _self;
  final $Res Function(_CpuInfo) _then;

/// Create a copy of CpuInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? vendor = null,Object? model = null,Object? threads = null,}) {
  return _then(_CpuInfo(
vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,threads: null == threads ? _self.threads : threads // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$GpuInfo {

 String get vendor;// nvidia | intel | amd | apple | unknown
 String get model; int? get vramMb; String? get driverVersion;/// VAAPI render-node path on Linux; null on other platforms.
 String? get devPath; List<String> get encoderSupport;
/// Create a copy of GpuInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpuInfoCopyWith<GpuInfo> get copyWith => _$GpuInfoCopyWithImpl<GpuInfo>(this as GpuInfo, _$identity);

  /// Serializes this GpuInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpuInfo&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.model, model) || other.model == model)&&(identical(other.vramMb, vramMb) || other.vramMb == vramMb)&&(identical(other.driverVersion, driverVersion) || other.driverVersion == driverVersion)&&(identical(other.devPath, devPath) || other.devPath == devPath)&&const DeepCollectionEquality().equals(other.encoderSupport, encoderSupport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,vendor,model,vramMb,driverVersion,devPath,const DeepCollectionEquality().hash(encoderSupport));

@override
String toString() {
  return 'GpuInfo(vendor: $vendor, model: $model, vramMb: $vramMb, driverVersion: $driverVersion, devPath: $devPath, encoderSupport: $encoderSupport)';
}


}

/// @nodoc
abstract mixin class $GpuInfoCopyWith<$Res>  {
  factory $GpuInfoCopyWith(GpuInfo value, $Res Function(GpuInfo) _then) = _$GpuInfoCopyWithImpl;
@useResult
$Res call({
 String vendor, String model, int? vramMb, String? driverVersion, String? devPath, List<String> encoderSupport
});




}
/// @nodoc
class _$GpuInfoCopyWithImpl<$Res>
    implements $GpuInfoCopyWith<$Res> {
  _$GpuInfoCopyWithImpl(this._self, this._then);

  final GpuInfo _self;
  final $Res Function(GpuInfo) _then;

/// Create a copy of GpuInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? vendor = null,Object? model = null,Object? vramMb = freezed,Object? driverVersion = freezed,Object? devPath = freezed,Object? encoderSupport = null,}) {
  return _then(_self.copyWith(
vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,vramMb: freezed == vramMb ? _self.vramMb : vramMb // ignore: cast_nullable_to_non_nullable
as int?,driverVersion: freezed == driverVersion ? _self.driverVersion : driverVersion // ignore: cast_nullable_to_non_nullable
as String?,devPath: freezed == devPath ? _self.devPath : devPath // ignore: cast_nullable_to_non_nullable
as String?,encoderSupport: null == encoderSupport ? _self.encoderSupport : encoderSupport // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [GpuInfo].
extension GpuInfoPatterns on GpuInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpuInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpuInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpuInfo value)  $default,){
final _that = this;
switch (_that) {
case _GpuInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpuInfo value)?  $default,){
final _that = this;
switch (_that) {
case _GpuInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String vendor,  String model,  int? vramMb,  String? driverVersion,  String? devPath,  List<String> encoderSupport)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpuInfo() when $default != null:
return $default(_that.vendor,_that.model,_that.vramMb,_that.driverVersion,_that.devPath,_that.encoderSupport);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String vendor,  String model,  int? vramMb,  String? driverVersion,  String? devPath,  List<String> encoderSupport)  $default,) {final _that = this;
switch (_that) {
case _GpuInfo():
return $default(_that.vendor,_that.model,_that.vramMb,_that.driverVersion,_that.devPath,_that.encoderSupport);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String vendor,  String model,  int? vramMb,  String? driverVersion,  String? devPath,  List<String> encoderSupport)?  $default,) {final _that = this;
switch (_that) {
case _GpuInfo() when $default != null:
return $default(_that.vendor,_that.model,_that.vramMb,_that.driverVersion,_that.devPath,_that.encoderSupport);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GpuInfo implements GpuInfo {
  const _GpuInfo({required this.vendor, required this.model, this.vramMb, this.driverVersion, this.devPath, final  List<String> encoderSupport = const []}): _encoderSupport = encoderSupport;
  factory _GpuInfo.fromJson(Map<String, dynamic> json) => _$GpuInfoFromJson(json);

@override final  String vendor;
// nvidia | intel | amd | apple | unknown
@override final  String model;
@override final  int? vramMb;
@override final  String? driverVersion;
/// VAAPI render-node path on Linux; null on other platforms.
@override final  String? devPath;
 final  List<String> _encoderSupport;
@override@JsonKey() List<String> get encoderSupport {
  if (_encoderSupport is EqualUnmodifiableListView) return _encoderSupport;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_encoderSupport);
}


/// Create a copy of GpuInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpuInfoCopyWith<_GpuInfo> get copyWith => __$GpuInfoCopyWithImpl<_GpuInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GpuInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpuInfo&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.model, model) || other.model == model)&&(identical(other.vramMb, vramMb) || other.vramMb == vramMb)&&(identical(other.driverVersion, driverVersion) || other.driverVersion == driverVersion)&&(identical(other.devPath, devPath) || other.devPath == devPath)&&const DeepCollectionEquality().equals(other._encoderSupport, _encoderSupport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,vendor,model,vramMb,driverVersion,devPath,const DeepCollectionEquality().hash(_encoderSupport));

@override
String toString() {
  return 'GpuInfo(vendor: $vendor, model: $model, vramMb: $vramMb, driverVersion: $driverVersion, devPath: $devPath, encoderSupport: $encoderSupport)';
}


}

/// @nodoc
abstract mixin class _$GpuInfoCopyWith<$Res> implements $GpuInfoCopyWith<$Res> {
  factory _$GpuInfoCopyWith(_GpuInfo value, $Res Function(_GpuInfo) _then) = __$GpuInfoCopyWithImpl;
@override @useResult
$Res call({
 String vendor, String model, int? vramMb, String? driverVersion, String? devPath, List<String> encoderSupport
});




}
/// @nodoc
class __$GpuInfoCopyWithImpl<$Res>
    implements _$GpuInfoCopyWith<$Res> {
  __$GpuInfoCopyWithImpl(this._self, this._then);

  final _GpuInfo _self;
  final $Res Function(_GpuInfo) _then;

/// Create a copy of GpuInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? vendor = null,Object? model = null,Object? vramMb = freezed,Object? driverVersion = freezed,Object? devPath = freezed,Object? encoderSupport = null,}) {
  return _then(_GpuInfo(
vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,vramMb: freezed == vramMb ? _self.vramMb : vramMb // ignore: cast_nullable_to_non_nullable
as int?,driverVersion: freezed == driverVersion ? _self.driverVersion : driverVersion // ignore: cast_nullable_to_non_nullable
as String?,devPath: freezed == devPath ? _self.devPath : devPath // ignore: cast_nullable_to_non_nullable
as String?,encoderSupport: null == encoderSupport ? _self._encoderSupport : encoderSupport // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$HardwareDevices {

 List<CpuInfo> get cpus; List<GpuInfo> get gpus;
/// Create a copy of HardwareDevices
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HardwareDevicesCopyWith<HardwareDevices> get copyWith => _$HardwareDevicesCopyWithImpl<HardwareDevices>(this as HardwareDevices, _$identity);

  /// Serializes this HardwareDevices to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HardwareDevices&&const DeepCollectionEquality().equals(other.cpus, cpus)&&const DeepCollectionEquality().equals(other.gpus, gpus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(cpus),const DeepCollectionEquality().hash(gpus));

@override
String toString() {
  return 'HardwareDevices(cpus: $cpus, gpus: $gpus)';
}


}

/// @nodoc
abstract mixin class $HardwareDevicesCopyWith<$Res>  {
  factory $HardwareDevicesCopyWith(HardwareDevices value, $Res Function(HardwareDevices) _then) = _$HardwareDevicesCopyWithImpl;
@useResult
$Res call({
 List<CpuInfo> cpus, List<GpuInfo> gpus
});




}
/// @nodoc
class _$HardwareDevicesCopyWithImpl<$Res>
    implements $HardwareDevicesCopyWith<$Res> {
  _$HardwareDevicesCopyWithImpl(this._self, this._then);

  final HardwareDevices _self;
  final $Res Function(HardwareDevices) _then;

/// Create a copy of HardwareDevices
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cpus = null,Object? gpus = null,}) {
  return _then(_self.copyWith(
cpus: null == cpus ? _self.cpus : cpus // ignore: cast_nullable_to_non_nullable
as List<CpuInfo>,gpus: null == gpus ? _self.gpus : gpus // ignore: cast_nullable_to_non_nullable
as List<GpuInfo>,
  ));
}

}


/// Adds pattern-matching-related methods to [HardwareDevices].
extension HardwareDevicesPatterns on HardwareDevices {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HardwareDevices value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HardwareDevices() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HardwareDevices value)  $default,){
final _that = this;
switch (_that) {
case _HardwareDevices():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HardwareDevices value)?  $default,){
final _that = this;
switch (_that) {
case _HardwareDevices() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CpuInfo> cpus,  List<GpuInfo> gpus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HardwareDevices() when $default != null:
return $default(_that.cpus,_that.gpus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CpuInfo> cpus,  List<GpuInfo> gpus)  $default,) {final _that = this;
switch (_that) {
case _HardwareDevices():
return $default(_that.cpus,_that.gpus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CpuInfo> cpus,  List<GpuInfo> gpus)?  $default,) {final _that = this;
switch (_that) {
case _HardwareDevices() when $default != null:
return $default(_that.cpus,_that.gpus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HardwareDevices implements HardwareDevices {
  const _HardwareDevices({final  List<CpuInfo> cpus = const [], final  List<GpuInfo> gpus = const []}): _cpus = cpus,_gpus = gpus;
  factory _HardwareDevices.fromJson(Map<String, dynamic> json) => _$HardwareDevicesFromJson(json);

 final  List<CpuInfo> _cpus;
@override@JsonKey() List<CpuInfo> get cpus {
  if (_cpus is EqualUnmodifiableListView) return _cpus;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cpus);
}

 final  List<GpuInfo> _gpus;
@override@JsonKey() List<GpuInfo> get gpus {
  if (_gpus is EqualUnmodifiableListView) return _gpus;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gpus);
}


/// Create a copy of HardwareDevices
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HardwareDevicesCopyWith<_HardwareDevices> get copyWith => __$HardwareDevicesCopyWithImpl<_HardwareDevices>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HardwareDevicesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HardwareDevices&&const DeepCollectionEquality().equals(other._cpus, _cpus)&&const DeepCollectionEquality().equals(other._gpus, _gpus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_cpus),const DeepCollectionEquality().hash(_gpus));

@override
String toString() {
  return 'HardwareDevices(cpus: $cpus, gpus: $gpus)';
}


}

/// @nodoc
abstract mixin class _$HardwareDevicesCopyWith<$Res> implements $HardwareDevicesCopyWith<$Res> {
  factory _$HardwareDevicesCopyWith(_HardwareDevices value, $Res Function(_HardwareDevices) _then) = __$HardwareDevicesCopyWithImpl;
@override @useResult
$Res call({
 List<CpuInfo> cpus, List<GpuInfo> gpus
});




}
/// @nodoc
class __$HardwareDevicesCopyWithImpl<$Res>
    implements _$HardwareDevicesCopyWith<$Res> {
  __$HardwareDevicesCopyWithImpl(this._self, this._then);

  final _HardwareDevices _self;
  final $Res Function(_HardwareDevices) _then;

/// Create a copy of HardwareDevices
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cpus = null,Object? gpus = null,}) {
  return _then(_HardwareDevices(
cpus: null == cpus ? _self._cpus : cpus // ignore: cast_nullable_to_non_nullable
as List<CpuInfo>,gpus: null == gpus ? _self._gpus : gpus // ignore: cast_nullable_to_non_nullable
as List<GpuInfo>,
  ));
}


}

// dart format on
