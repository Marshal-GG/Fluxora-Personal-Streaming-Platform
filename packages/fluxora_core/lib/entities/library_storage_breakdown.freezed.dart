// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_storage_breakdown.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LibraryStorageBreakdown {

 int get totalBytes; int get capacityBytes; StorageByType get byType;
/// Create a copy of LibraryStorageBreakdown
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryStorageBreakdownCopyWith<LibraryStorageBreakdown> get copyWith => _$LibraryStorageBreakdownCopyWithImpl<LibraryStorageBreakdown>(this as LibraryStorageBreakdown, _$identity);

  /// Serializes this LibraryStorageBreakdown to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryStorageBreakdown&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.capacityBytes, capacityBytes) || other.capacityBytes == capacityBytes)&&(identical(other.byType, byType) || other.byType == byType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalBytes,capacityBytes,byType);

@override
String toString() {
  return 'LibraryStorageBreakdown(totalBytes: $totalBytes, capacityBytes: $capacityBytes, byType: $byType)';
}


}

/// @nodoc
abstract mixin class $LibraryStorageBreakdownCopyWith<$Res>  {
  factory $LibraryStorageBreakdownCopyWith(LibraryStorageBreakdown value, $Res Function(LibraryStorageBreakdown) _then) = _$LibraryStorageBreakdownCopyWithImpl;
@useResult
$Res call({
 int totalBytes, int capacityBytes, StorageByType byType
});


$StorageByTypeCopyWith<$Res> get byType;

}
/// @nodoc
class _$LibraryStorageBreakdownCopyWithImpl<$Res>
    implements $LibraryStorageBreakdownCopyWith<$Res> {
  _$LibraryStorageBreakdownCopyWithImpl(this._self, this._then);

  final LibraryStorageBreakdown _self;
  final $Res Function(LibraryStorageBreakdown) _then;

/// Create a copy of LibraryStorageBreakdown
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalBytes = null,Object? capacityBytes = null,Object? byType = null,}) {
  return _then(_self.copyWith(
totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,capacityBytes: null == capacityBytes ? _self.capacityBytes : capacityBytes // ignore: cast_nullable_to_non_nullable
as int,byType: null == byType ? _self.byType : byType // ignore: cast_nullable_to_non_nullable
as StorageByType,
  ));
}
/// Create a copy of LibraryStorageBreakdown
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StorageByTypeCopyWith<$Res> get byType {
  
  return $StorageByTypeCopyWith<$Res>(_self.byType, (value) {
    return _then(_self.copyWith(byType: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibraryStorageBreakdown].
extension LibraryStorageBreakdownPatterns on LibraryStorageBreakdown {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryStorageBreakdown value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryStorageBreakdown() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryStorageBreakdown value)  $default,){
final _that = this;
switch (_that) {
case _LibraryStorageBreakdown():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryStorageBreakdown value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryStorageBreakdown() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalBytes,  int capacityBytes,  StorageByType byType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryStorageBreakdown() when $default != null:
return $default(_that.totalBytes,_that.capacityBytes,_that.byType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalBytes,  int capacityBytes,  StorageByType byType)  $default,) {final _that = this;
switch (_that) {
case _LibraryStorageBreakdown():
return $default(_that.totalBytes,_that.capacityBytes,_that.byType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalBytes,  int capacityBytes,  StorageByType byType)?  $default,) {final _that = this;
switch (_that) {
case _LibraryStorageBreakdown() when $default != null:
return $default(_that.totalBytes,_that.capacityBytes,_that.byType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibraryStorageBreakdown implements LibraryStorageBreakdown {
  const _LibraryStorageBreakdown({required this.totalBytes, required this.capacityBytes, required this.byType});
  factory _LibraryStorageBreakdown.fromJson(Map<String, dynamic> json) => _$LibraryStorageBreakdownFromJson(json);

@override final  int totalBytes;
@override final  int capacityBytes;
@override final  StorageByType byType;

/// Create a copy of LibraryStorageBreakdown
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryStorageBreakdownCopyWith<_LibraryStorageBreakdown> get copyWith => __$LibraryStorageBreakdownCopyWithImpl<_LibraryStorageBreakdown>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibraryStorageBreakdownToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryStorageBreakdown&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.capacityBytes, capacityBytes) || other.capacityBytes == capacityBytes)&&(identical(other.byType, byType) || other.byType == byType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalBytes,capacityBytes,byType);

@override
String toString() {
  return 'LibraryStorageBreakdown(totalBytes: $totalBytes, capacityBytes: $capacityBytes, byType: $byType)';
}


}

/// @nodoc
abstract mixin class _$LibraryStorageBreakdownCopyWith<$Res> implements $LibraryStorageBreakdownCopyWith<$Res> {
  factory _$LibraryStorageBreakdownCopyWith(_LibraryStorageBreakdown value, $Res Function(_LibraryStorageBreakdown) _then) = __$LibraryStorageBreakdownCopyWithImpl;
@override @useResult
$Res call({
 int totalBytes, int capacityBytes, StorageByType byType
});


@override $StorageByTypeCopyWith<$Res> get byType;

}
/// @nodoc
class __$LibraryStorageBreakdownCopyWithImpl<$Res>
    implements _$LibraryStorageBreakdownCopyWith<$Res> {
  __$LibraryStorageBreakdownCopyWithImpl(this._self, this._then);

  final _LibraryStorageBreakdown _self;
  final $Res Function(_LibraryStorageBreakdown) _then;

/// Create a copy of LibraryStorageBreakdown
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalBytes = null,Object? capacityBytes = null,Object? byType = null,}) {
  return _then(_LibraryStorageBreakdown(
totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,capacityBytes: null == capacityBytes ? _self.capacityBytes : capacityBytes // ignore: cast_nullable_to_non_nullable
as int,byType: null == byType ? _self.byType : byType // ignore: cast_nullable_to_non_nullable
as StorageByType,
  ));
}

/// Create a copy of LibraryStorageBreakdown
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StorageByTypeCopyWith<$Res> get byType {
  
  return $StorageByTypeCopyWith<$Res>(_self.byType, (value) {
    return _then(_self.copyWith(byType: value));
  });
}
}


/// @nodoc
mixin _$StorageByType {

 int get movies; int get tv; int get music; int get files;
/// Create a copy of StorageByType
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageByTypeCopyWith<StorageByType> get copyWith => _$StorageByTypeCopyWithImpl<StorageByType>(this as StorageByType, _$identity);

  /// Serializes this StorageByType to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageByType&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.tv, tv) || other.tv == tv)&&(identical(other.music, music) || other.music == music)&&(identical(other.files, files) || other.files == files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,movies,tv,music,files);

@override
String toString() {
  return 'StorageByType(movies: $movies, tv: $tv, music: $music, files: $files)';
}


}

/// @nodoc
abstract mixin class $StorageByTypeCopyWith<$Res>  {
  factory $StorageByTypeCopyWith(StorageByType value, $Res Function(StorageByType) _then) = _$StorageByTypeCopyWithImpl;
@useResult
$Res call({
 int movies, int tv, int music, int files
});




}
/// @nodoc
class _$StorageByTypeCopyWithImpl<$Res>
    implements $StorageByTypeCopyWith<$Res> {
  _$StorageByTypeCopyWithImpl(this._self, this._then);

  final StorageByType _self;
  final $Res Function(StorageByType) _then;

/// Create a copy of StorageByType
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? movies = null,Object? tv = null,Object? music = null,Object? files = null,}) {
  return _then(_self.copyWith(
movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,tv: null == tv ? _self.tv : tv // ignore: cast_nullable_to_non_nullable
as int,music: null == music ? _self.music : music // ignore: cast_nullable_to_non_nullable
as int,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [StorageByType].
extension StorageByTypePatterns on StorageByType {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StorageByType value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StorageByType() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StorageByType value)  $default,){
final _that = this;
switch (_that) {
case _StorageByType():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StorageByType value)?  $default,){
final _that = this;
switch (_that) {
case _StorageByType() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int movies,  int tv,  int music,  int files)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StorageByType() when $default != null:
return $default(_that.movies,_that.tv,_that.music,_that.files);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int movies,  int tv,  int music,  int files)  $default,) {final _that = this;
switch (_that) {
case _StorageByType():
return $default(_that.movies,_that.tv,_that.music,_that.files);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int movies,  int tv,  int music,  int files)?  $default,) {final _that = this;
switch (_that) {
case _StorageByType() when $default != null:
return $default(_that.movies,_that.tv,_that.music,_that.files);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StorageByType implements StorageByType {
  const _StorageByType({this.movies = 0, this.tv = 0, this.music = 0, this.files = 0});
  factory _StorageByType.fromJson(Map<String, dynamic> json) => _$StorageByTypeFromJson(json);

@override@JsonKey() final  int movies;
@override@JsonKey() final  int tv;
@override@JsonKey() final  int music;
@override@JsonKey() final  int files;

/// Create a copy of StorageByType
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StorageByTypeCopyWith<_StorageByType> get copyWith => __$StorageByTypeCopyWithImpl<_StorageByType>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StorageByTypeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StorageByType&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.tv, tv) || other.tv == tv)&&(identical(other.music, music) || other.music == music)&&(identical(other.files, files) || other.files == files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,movies,tv,music,files);

@override
String toString() {
  return 'StorageByType(movies: $movies, tv: $tv, music: $music, files: $files)';
}


}

/// @nodoc
abstract mixin class _$StorageByTypeCopyWith<$Res> implements $StorageByTypeCopyWith<$Res> {
  factory _$StorageByTypeCopyWith(_StorageByType value, $Res Function(_StorageByType) _then) = __$StorageByTypeCopyWithImpl;
@override @useResult
$Res call({
 int movies, int tv, int music, int files
});




}
/// @nodoc
class __$StorageByTypeCopyWithImpl<$Res>
    implements _$StorageByTypeCopyWith<$Res> {
  __$StorageByTypeCopyWithImpl(this._self, this._then);

  final _StorageByType _self;
  final $Res Function(_StorageByType) _then;

/// Create a copy of StorageByType
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? movies = null,Object? tv = null,Object? music = null,Object? files = null,}) {
  return _then(_StorageByType(
movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,tv: null == tv ? _self.tv : tv // ignore: cast_nullable_to_non_nullable
as int,music: null == music ? _self.music : music // ignore: cast_nullable_to_non_nullable
as int,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
