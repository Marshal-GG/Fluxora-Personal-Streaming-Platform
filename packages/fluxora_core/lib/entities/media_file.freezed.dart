// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_file.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MediaFile {

 String get id; String get path; String get name; String get extension; int get sizeBytes; double? get durationSec; String? get libraryId; int? get tmdbId;// TMDB-enriched metadata
 String? get title; String? get overview; String? get posterUrl;// Resume playback position
@JsonKey(name: 'last_progress_sec') double get resumeSec;@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime get createdAt;@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime get updatedAt;
/// Create a copy of MediaFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaFileCopyWith<MediaFile> get copyWith => _$MediaFileCopyWithImpl<MediaFile>(this as MediaFile, _$identity);

  /// Serializes this MediaFile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaFile&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.extension, extension) || other.extension == extension)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.libraryId, libraryId) || other.libraryId == libraryId)&&(identical(other.tmdbId, tmdbId) || other.tmdbId == tmdbId)&&(identical(other.title, title) || other.title == title)&&(identical(other.overview, overview) || other.overview == overview)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.resumeSec, resumeSec) || other.resumeSec == resumeSec)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,path,name,extension,sizeBytes,durationSec,libraryId,tmdbId,title,overview,posterUrl,resumeSec,createdAt,updatedAt);

@override
String toString() {
  return 'MediaFile(id: $id, path: $path, name: $name, extension: $extension, sizeBytes: $sizeBytes, durationSec: $durationSec, libraryId: $libraryId, tmdbId: $tmdbId, title: $title, overview: $overview, posterUrl: $posterUrl, resumeSec: $resumeSec, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $MediaFileCopyWith<$Res>  {
  factory $MediaFileCopyWith(MediaFile value, $Res Function(MediaFile) _then) = _$MediaFileCopyWithImpl;
@useResult
$Res call({
 String id, String path, String name, String extension, int sizeBytes, double? durationSec, String? libraryId, int? tmdbId, String? title, String? overview, String? posterUrl,@JsonKey(name: 'last_progress_sec') double resumeSec,@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime createdAt,@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime updatedAt
});




}
/// @nodoc
class _$MediaFileCopyWithImpl<$Res>
    implements $MediaFileCopyWith<$Res> {
  _$MediaFileCopyWithImpl(this._self, this._then);

  final MediaFile _self;
  final $Res Function(MediaFile) _then;

/// Create a copy of MediaFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? path = null,Object? name = null,Object? extension = null,Object? sizeBytes = null,Object? durationSec = freezed,Object? libraryId = freezed,Object? tmdbId = freezed,Object? title = freezed,Object? overview = freezed,Object? posterUrl = freezed,Object? resumeSec = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,extension: null == extension ? _self.extension : extension // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,durationSec: freezed == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as double?,libraryId: freezed == libraryId ? _self.libraryId : libraryId // ignore: cast_nullable_to_non_nullable
as String?,tmdbId: freezed == tmdbId ? _self.tmdbId : tmdbId // ignore: cast_nullable_to_non_nullable
as int?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as String?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,resumeSec: null == resumeSec ? _self.resumeSec : resumeSec // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaFile].
extension MediaFilePatterns on MediaFile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaFile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaFile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaFile value)  $default,){
final _that = this;
switch (_that) {
case _MediaFile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaFile value)?  $default,){
final _that = this;
switch (_that) {
case _MediaFile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String path,  String name,  String extension,  int sizeBytes,  double? durationSec,  String? libraryId,  int? tmdbId,  String? title,  String? overview,  String? posterUrl, @JsonKey(name: 'last_progress_sec')  double resumeSec, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime createdAt, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaFile() when $default != null:
return $default(_that.id,_that.path,_that.name,_that.extension,_that.sizeBytes,_that.durationSec,_that.libraryId,_that.tmdbId,_that.title,_that.overview,_that.posterUrl,_that.resumeSec,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String path,  String name,  String extension,  int sizeBytes,  double? durationSec,  String? libraryId,  int? tmdbId,  String? title,  String? overview,  String? posterUrl, @JsonKey(name: 'last_progress_sec')  double resumeSec, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime createdAt, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _MediaFile():
return $default(_that.id,_that.path,_that.name,_that.extension,_that.sizeBytes,_that.durationSec,_that.libraryId,_that.tmdbId,_that.title,_that.overview,_that.posterUrl,_that.resumeSec,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String path,  String name,  String extension,  int sizeBytes,  double? durationSec,  String? libraryId,  int? tmdbId,  String? title,  String? overview,  String? posterUrl, @JsonKey(name: 'last_progress_sec')  double resumeSec, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime createdAt, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _MediaFile() when $default != null:
return $default(_that.id,_that.path,_that.name,_that.extension,_that.sizeBytes,_that.durationSec,_that.libraryId,_that.tmdbId,_that.title,_that.overview,_that.posterUrl,_that.resumeSec,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaFile implements MediaFile {
  const _MediaFile({required this.id, required this.path, required this.name, required this.extension, required this.sizeBytes, this.durationSec, this.libraryId, this.tmdbId, this.title, this.overview, this.posterUrl, @JsonKey(name: 'last_progress_sec') this.resumeSec = 0.0, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) required this.createdAt, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) required this.updatedAt});
  factory _MediaFile.fromJson(Map<String, dynamic> json) => _$MediaFileFromJson(json);

@override final  String id;
@override final  String path;
@override final  String name;
@override final  String extension;
@override final  int sizeBytes;
@override final  double? durationSec;
@override final  String? libraryId;
@override final  int? tmdbId;
// TMDB-enriched metadata
@override final  String? title;
@override final  String? overview;
@override final  String? posterUrl;
// Resume playback position
@override@JsonKey(name: 'last_progress_sec') final  double resumeSec;
@override@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) final  DateTime createdAt;
@override@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) final  DateTime updatedAt;

/// Create a copy of MediaFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaFileCopyWith<_MediaFile> get copyWith => __$MediaFileCopyWithImpl<_MediaFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaFileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaFile&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.extension, extension) || other.extension == extension)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.libraryId, libraryId) || other.libraryId == libraryId)&&(identical(other.tmdbId, tmdbId) || other.tmdbId == tmdbId)&&(identical(other.title, title) || other.title == title)&&(identical(other.overview, overview) || other.overview == overview)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.resumeSec, resumeSec) || other.resumeSec == resumeSec)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,path,name,extension,sizeBytes,durationSec,libraryId,tmdbId,title,overview,posterUrl,resumeSec,createdAt,updatedAt);

@override
String toString() {
  return 'MediaFile(id: $id, path: $path, name: $name, extension: $extension, sizeBytes: $sizeBytes, durationSec: $durationSec, libraryId: $libraryId, tmdbId: $tmdbId, title: $title, overview: $overview, posterUrl: $posterUrl, resumeSec: $resumeSec, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MediaFileCopyWith<$Res> implements $MediaFileCopyWith<$Res> {
  factory _$MediaFileCopyWith(_MediaFile value, $Res Function(_MediaFile) _then) = __$MediaFileCopyWithImpl;
@override @useResult
$Res call({
 String id, String path, String name, String extension, int sizeBytes, double? durationSec, String? libraryId, int? tmdbId, String? title, String? overview, String? posterUrl,@JsonKey(name: 'last_progress_sec') double resumeSec,@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime createdAt,@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime updatedAt
});




}
/// @nodoc
class __$MediaFileCopyWithImpl<$Res>
    implements _$MediaFileCopyWith<$Res> {
  __$MediaFileCopyWithImpl(this._self, this._then);

  final _MediaFile _self;
  final $Res Function(_MediaFile) _then;

/// Create a copy of MediaFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? path = null,Object? name = null,Object? extension = null,Object? sizeBytes = null,Object? durationSec = freezed,Object? libraryId = freezed,Object? tmdbId = freezed,Object? title = freezed,Object? overview = freezed,Object? posterUrl = freezed,Object? resumeSec = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_MediaFile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,extension: null == extension ? _self.extension : extension // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,durationSec: freezed == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as double?,libraryId: freezed == libraryId ? _self.libraryId : libraryId // ignore: cast_nullable_to_non_nullable
as String?,tmdbId: freezed == tmdbId ? _self.tmdbId : tmdbId // ignore: cast_nullable_to_non_nullable
as int?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as String?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,resumeSec: null == resumeSec ? _self.resumeSec : resumeSec // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
