// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'encoder_advice.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EncoderAdvice {

 String? get recommendedEncoder; String get reasonCode; String get reasonText; String get severity;
/// Create a copy of EncoderAdvice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EncoderAdviceCopyWith<EncoderAdvice> get copyWith => _$EncoderAdviceCopyWithImpl<EncoderAdvice>(this as EncoderAdvice, _$identity);

  /// Serializes this EncoderAdvice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EncoderAdvice&&(identical(other.recommendedEncoder, recommendedEncoder) || other.recommendedEncoder == recommendedEncoder)&&(identical(other.reasonCode, reasonCode) || other.reasonCode == reasonCode)&&(identical(other.reasonText, reasonText) || other.reasonText == reasonText)&&(identical(other.severity, severity) || other.severity == severity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,recommendedEncoder,reasonCode,reasonText,severity);

@override
String toString() {
  return 'EncoderAdvice(recommendedEncoder: $recommendedEncoder, reasonCode: $reasonCode, reasonText: $reasonText, severity: $severity)';
}


}

/// @nodoc
abstract mixin class $EncoderAdviceCopyWith<$Res>  {
  factory $EncoderAdviceCopyWith(EncoderAdvice value, $Res Function(EncoderAdvice) _then) = _$EncoderAdviceCopyWithImpl;
@useResult
$Res call({
 String? recommendedEncoder, String reasonCode, String reasonText, String severity
});




}
/// @nodoc
class _$EncoderAdviceCopyWithImpl<$Res>
    implements $EncoderAdviceCopyWith<$Res> {
  _$EncoderAdviceCopyWithImpl(this._self, this._then);

  final EncoderAdvice _self;
  final $Res Function(EncoderAdvice) _then;

/// Create a copy of EncoderAdvice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? recommendedEncoder = freezed,Object? reasonCode = null,Object? reasonText = null,Object? severity = null,}) {
  return _then(_self.copyWith(
recommendedEncoder: freezed == recommendedEncoder ? _self.recommendedEncoder : recommendedEncoder // ignore: cast_nullable_to_non_nullable
as String?,reasonCode: null == reasonCode ? _self.reasonCode : reasonCode // ignore: cast_nullable_to_non_nullable
as String,reasonText: null == reasonText ? _self.reasonText : reasonText // ignore: cast_nullable_to_non_nullable
as String,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [EncoderAdvice].
extension EncoderAdvicePatterns on EncoderAdvice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EncoderAdvice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EncoderAdvice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EncoderAdvice value)  $default,){
final _that = this;
switch (_that) {
case _EncoderAdvice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EncoderAdvice value)?  $default,){
final _that = this;
switch (_that) {
case _EncoderAdvice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? recommendedEncoder,  String reasonCode,  String reasonText,  String severity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EncoderAdvice() when $default != null:
return $default(_that.recommendedEncoder,_that.reasonCode,_that.reasonText,_that.severity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? recommendedEncoder,  String reasonCode,  String reasonText,  String severity)  $default,) {final _that = this;
switch (_that) {
case _EncoderAdvice():
return $default(_that.recommendedEncoder,_that.reasonCode,_that.reasonText,_that.severity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? recommendedEncoder,  String reasonCode,  String reasonText,  String severity)?  $default,) {final _that = this;
switch (_that) {
case _EncoderAdvice() when $default != null:
return $default(_that.recommendedEncoder,_that.reasonCode,_that.reasonText,_that.severity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EncoderAdvice implements EncoderAdvice {
  const _EncoderAdvice({this.recommendedEncoder, required this.reasonCode, required this.reasonText, required this.severity});
  factory _EncoderAdvice.fromJson(Map<String, dynamic> json) => _$EncoderAdviceFromJson(json);

@override final  String? recommendedEncoder;
@override final  String reasonCode;
@override final  String reasonText;
@override final  String severity;

/// Create a copy of EncoderAdvice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EncoderAdviceCopyWith<_EncoderAdvice> get copyWith => __$EncoderAdviceCopyWithImpl<_EncoderAdvice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EncoderAdviceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EncoderAdvice&&(identical(other.recommendedEncoder, recommendedEncoder) || other.recommendedEncoder == recommendedEncoder)&&(identical(other.reasonCode, reasonCode) || other.reasonCode == reasonCode)&&(identical(other.reasonText, reasonText) || other.reasonText == reasonText)&&(identical(other.severity, severity) || other.severity == severity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,recommendedEncoder,reasonCode,reasonText,severity);

@override
String toString() {
  return 'EncoderAdvice(recommendedEncoder: $recommendedEncoder, reasonCode: $reasonCode, reasonText: $reasonText, severity: $severity)';
}


}

/// @nodoc
abstract mixin class _$EncoderAdviceCopyWith<$Res> implements $EncoderAdviceCopyWith<$Res> {
  factory _$EncoderAdviceCopyWith(_EncoderAdvice value, $Res Function(_EncoderAdvice) _then) = __$EncoderAdviceCopyWithImpl;
@override @useResult
$Res call({
 String? recommendedEncoder, String reasonCode, String reasonText, String severity
});




}
/// @nodoc
class __$EncoderAdviceCopyWithImpl<$Res>
    implements _$EncoderAdviceCopyWith<$Res> {
  __$EncoderAdviceCopyWithImpl(this._self, this._then);

  final _EncoderAdvice _self;
  final $Res Function(_EncoderAdvice) _then;

/// Create a copy of EncoderAdvice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? recommendedEncoder = freezed,Object? reasonCode = null,Object? reasonText = null,Object? severity = null,}) {
  return _then(_EncoderAdvice(
recommendedEncoder: freezed == recommendedEncoder ? _self.recommendedEncoder : recommendedEncoder // ignore: cast_nullable_to_non_nullable
as String?,reasonCode: null == reasonCode ? _self.reasonCode : reasonCode // ignore: cast_nullable_to_non_nullable
as String,reasonText: null == reasonText ? _self.reasonText : reasonText // ignore: cast_nullable_to_non_nullable
as String,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
