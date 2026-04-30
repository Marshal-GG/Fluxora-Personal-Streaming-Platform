// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Library {

 String get id; String get name; LibraryType get type; List<String> get rootPaths;@JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) DateTime? get lastScanned;@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime get createdAt;
/// Create a copy of Library
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryCopyWith<Library> get copyWith => _$LibraryCopyWithImpl<Library>(this as Library, _$identity);

  /// Serializes this Library to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Library&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.rootPaths, rootPaths)&&(identical(other.lastScanned, lastScanned) || other.lastScanned == lastScanned)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,const DeepCollectionEquality().hash(rootPaths),lastScanned,createdAt);

@override
String toString() {
  return 'Library(id: $id, name: $name, type: $type, rootPaths: $rootPaths, lastScanned: $lastScanned, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $LibraryCopyWith<$Res>  {
  factory $LibraryCopyWith(Library value, $Res Function(Library) _then) = _$LibraryCopyWithImpl;
@useResult
$Res call({
 String id, String name, LibraryType type, List<String> rootPaths,@JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) DateTime? lastScanned,@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime createdAt
});




}
/// @nodoc
class _$LibraryCopyWithImpl<$Res>
    implements $LibraryCopyWith<$Res> {
  _$LibraryCopyWithImpl(this._self, this._then);

  final Library _self;
  final $Res Function(Library) _then;

/// Create a copy of Library
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? rootPaths = null,Object? lastScanned = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LibraryType,rootPaths: null == rootPaths ? _self.rootPaths : rootPaths // ignore: cast_nullable_to_non_nullable
as List<String>,lastScanned: freezed == lastScanned ? _self.lastScanned : lastScanned // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Library].
extension LibraryPatterns on Library {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Library value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Library() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Library value)  $default,){
final _that = this;
switch (_that) {
case _Library():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Library value)?  $default,){
final _that = this;
switch (_that) {
case _Library() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  LibraryType type,  List<String> rootPaths, @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)  DateTime? lastScanned, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Library() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.rootPaths,_that.lastScanned,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  LibraryType type,  List<String> rootPaths, @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)  DateTime? lastScanned, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Library():
return $default(_that.id,_that.name,_that.type,_that.rootPaths,_that.lastScanned,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  LibraryType type,  List<String> rootPaths, @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson)  DateTime? lastScanned, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Library() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.rootPaths,_that.lastScanned,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Library implements Library {
  const _Library({required this.id, required this.name, required this.type, required final  List<String> rootPaths, @JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) this.lastScanned, @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) required this.createdAt}): _rootPaths = rootPaths;
  factory _Library.fromJson(Map<String, dynamic> json) => _$LibraryFromJson(json);

@override final  String id;
@override final  String name;
@override final  LibraryType type;
 final  List<String> _rootPaths;
@override List<String> get rootPaths {
  if (_rootPaths is EqualUnmodifiableListView) return _rootPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rootPaths);
}

@override@JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) final  DateTime? lastScanned;
@override@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) final  DateTime createdAt;

/// Create a copy of Library
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryCopyWith<_Library> get copyWith => __$LibraryCopyWithImpl<_Library>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibraryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Library&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._rootPaths, _rootPaths)&&(identical(other.lastScanned, lastScanned) || other.lastScanned == lastScanned)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,const DeepCollectionEquality().hash(_rootPaths),lastScanned,createdAt);

@override
String toString() {
  return 'Library(id: $id, name: $name, type: $type, rootPaths: $rootPaths, lastScanned: $lastScanned, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LibraryCopyWith<$Res> implements $LibraryCopyWith<$Res> {
  factory _$LibraryCopyWith(_Library value, $Res Function(_Library) _then) = __$LibraryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, LibraryType type, List<String> rootPaths,@JsonKey(fromJson: utcDateTimeOrNullFromJson, toJson: utcDateTimeOrNullToJson) DateTime? lastScanned,@JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson) DateTime createdAt
});




}
/// @nodoc
class __$LibraryCopyWithImpl<$Res>
    implements _$LibraryCopyWith<$Res> {
  __$LibraryCopyWithImpl(this._self, this._then);

  final _Library _self;
  final $Res Function(_Library) _then;

/// Create a copy of Library
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? rootPaths = null,Object? lastScanned = freezed,Object? createdAt = null,}) {
  return _then(_Library(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LibraryType,rootPaths: null == rootPaths ? _self._rootPaths : rootPaths // ignore: cast_nullable_to_non_nullable
as List<String>,lastScanned: freezed == lastScanned ? _self.lastScanned : lastScanned // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
