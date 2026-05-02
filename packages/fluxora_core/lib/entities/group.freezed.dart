// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TimeWindow {

 int get startH; int get endH; List<int> get days;
/// Create a copy of TimeWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimeWindowCopyWith<TimeWindow> get copyWith => _$TimeWindowCopyWithImpl<TimeWindow>(this as TimeWindow, _$identity);

  /// Serializes this TimeWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeWindow&&(identical(other.startH, startH) || other.startH == startH)&&(identical(other.endH, endH) || other.endH == endH)&&const DeepCollectionEquality().equals(other.days, days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,startH,endH,const DeepCollectionEquality().hash(days));

@override
String toString() {
  return 'TimeWindow(startH: $startH, endH: $endH, days: $days)';
}


}

/// @nodoc
abstract mixin class $TimeWindowCopyWith<$Res>  {
  factory $TimeWindowCopyWith(TimeWindow value, $Res Function(TimeWindow) _then) = _$TimeWindowCopyWithImpl;
@useResult
$Res call({
 int startH, int endH, List<int> days
});




}
/// @nodoc
class _$TimeWindowCopyWithImpl<$Res>
    implements $TimeWindowCopyWith<$Res> {
  _$TimeWindowCopyWithImpl(this._self, this._then);

  final TimeWindow _self;
  final $Res Function(TimeWindow) _then;

/// Create a copy of TimeWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startH = null,Object? endH = null,Object? days = null,}) {
  return _then(_self.copyWith(
startH: null == startH ? _self.startH : startH // ignore: cast_nullable_to_non_nullable
as int,endH: null == endH ? _self.endH : endH // ignore: cast_nullable_to_non_nullable
as int,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [TimeWindow].
extension TimeWindowPatterns on TimeWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimeWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimeWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimeWindow value)  $default,){
final _that = this;
switch (_that) {
case _TimeWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimeWindow value)?  $default,){
final _that = this;
switch (_that) {
case _TimeWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startH,  int endH,  List<int> days)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimeWindow() when $default != null:
return $default(_that.startH,_that.endH,_that.days);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startH,  int endH,  List<int> days)  $default,) {final _that = this;
switch (_that) {
case _TimeWindow():
return $default(_that.startH,_that.endH,_that.days);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startH,  int endH,  List<int> days)?  $default,) {final _that = this;
switch (_that) {
case _TimeWindow() when $default != null:
return $default(_that.startH,_that.endH,_that.days);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TimeWindow implements TimeWindow {
  const _TimeWindow({required this.startH, required this.endH, required final  List<int> days}): _days = days;
  factory _TimeWindow.fromJson(Map<String, dynamic> json) => _$TimeWindowFromJson(json);

@override final  int startH;
@override final  int endH;
 final  List<int> _days;
@override List<int> get days {
  if (_days is EqualUnmodifiableListView) return _days;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_days);
}


/// Create a copy of TimeWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimeWindowCopyWith<_TimeWindow> get copyWith => __$TimeWindowCopyWithImpl<_TimeWindow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TimeWindowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimeWindow&&(identical(other.startH, startH) || other.startH == startH)&&(identical(other.endH, endH) || other.endH == endH)&&const DeepCollectionEquality().equals(other._days, _days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,startH,endH,const DeepCollectionEquality().hash(_days));

@override
String toString() {
  return 'TimeWindow(startH: $startH, endH: $endH, days: $days)';
}


}

/// @nodoc
abstract mixin class _$TimeWindowCopyWith<$Res> implements $TimeWindowCopyWith<$Res> {
  factory _$TimeWindowCopyWith(_TimeWindow value, $Res Function(_TimeWindow) _then) = __$TimeWindowCopyWithImpl;
@override @useResult
$Res call({
 int startH, int endH, List<int> days
});




}
/// @nodoc
class __$TimeWindowCopyWithImpl<$Res>
    implements _$TimeWindowCopyWith<$Res> {
  __$TimeWindowCopyWithImpl(this._self, this._then);

  final _TimeWindow _self;
  final $Res Function(_TimeWindow) _then;

/// Create a copy of TimeWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startH = null,Object? endH = null,Object? days = null,}) {
  return _then(_TimeWindow(
startH: null == startH ? _self.startH : startH // ignore: cast_nullable_to_non_nullable
as int,endH: null == endH ? _self.endH : endH // ignore: cast_nullable_to_non_nullable
as int,days: null == days ? _self._days : days // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}


/// @nodoc
mixin _$GroupRestrictions {

 List<String>? get allowedLibraries; int? get bandwidthCapMbps; TimeWindow? get timeWindow; String? get maxRating;
/// Create a copy of GroupRestrictions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupRestrictionsCopyWith<GroupRestrictions> get copyWith => _$GroupRestrictionsCopyWithImpl<GroupRestrictions>(this as GroupRestrictions, _$identity);

  /// Serializes this GroupRestrictions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupRestrictions&&const DeepCollectionEquality().equals(other.allowedLibraries, allowedLibraries)&&(identical(other.bandwidthCapMbps, bandwidthCapMbps) || other.bandwidthCapMbps == bandwidthCapMbps)&&(identical(other.timeWindow, timeWindow) || other.timeWindow == timeWindow)&&(identical(other.maxRating, maxRating) || other.maxRating == maxRating));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(allowedLibraries),bandwidthCapMbps,timeWindow,maxRating);

@override
String toString() {
  return 'GroupRestrictions(allowedLibraries: $allowedLibraries, bandwidthCapMbps: $bandwidthCapMbps, timeWindow: $timeWindow, maxRating: $maxRating)';
}


}

/// @nodoc
abstract mixin class $GroupRestrictionsCopyWith<$Res>  {
  factory $GroupRestrictionsCopyWith(GroupRestrictions value, $Res Function(GroupRestrictions) _then) = _$GroupRestrictionsCopyWithImpl;
@useResult
$Res call({
 List<String>? allowedLibraries, int? bandwidthCapMbps, TimeWindow? timeWindow, String? maxRating
});


$TimeWindowCopyWith<$Res>? get timeWindow;

}
/// @nodoc
class _$GroupRestrictionsCopyWithImpl<$Res>
    implements $GroupRestrictionsCopyWith<$Res> {
  _$GroupRestrictionsCopyWithImpl(this._self, this._then);

  final GroupRestrictions _self;
  final $Res Function(GroupRestrictions) _then;

/// Create a copy of GroupRestrictions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? allowedLibraries = freezed,Object? bandwidthCapMbps = freezed,Object? timeWindow = freezed,Object? maxRating = freezed,}) {
  return _then(_self.copyWith(
allowedLibraries: freezed == allowedLibraries ? _self.allowedLibraries : allowedLibraries // ignore: cast_nullable_to_non_nullable
as List<String>?,bandwidthCapMbps: freezed == bandwidthCapMbps ? _self.bandwidthCapMbps : bandwidthCapMbps // ignore: cast_nullable_to_non_nullable
as int?,timeWindow: freezed == timeWindow ? _self.timeWindow : timeWindow // ignore: cast_nullable_to_non_nullable
as TimeWindow?,maxRating: freezed == maxRating ? _self.maxRating : maxRating // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of GroupRestrictions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TimeWindowCopyWith<$Res>? get timeWindow {
    if (_self.timeWindow == null) {
    return null;
  }

  return $TimeWindowCopyWith<$Res>(_self.timeWindow!, (value) {
    return _then(_self.copyWith(timeWindow: value));
  });
}
}


/// Adds pattern-matching-related methods to [GroupRestrictions].
extension GroupRestrictionsPatterns on GroupRestrictions {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupRestrictions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupRestrictions() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupRestrictions value)  $default,){
final _that = this;
switch (_that) {
case _GroupRestrictions():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupRestrictions value)?  $default,){
final _that = this;
switch (_that) {
case _GroupRestrictions() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String>? allowedLibraries,  int? bandwidthCapMbps,  TimeWindow? timeWindow,  String? maxRating)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupRestrictions() when $default != null:
return $default(_that.allowedLibraries,_that.bandwidthCapMbps,_that.timeWindow,_that.maxRating);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String>? allowedLibraries,  int? bandwidthCapMbps,  TimeWindow? timeWindow,  String? maxRating)  $default,) {final _that = this;
switch (_that) {
case _GroupRestrictions():
return $default(_that.allowedLibraries,_that.bandwidthCapMbps,_that.timeWindow,_that.maxRating);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String>? allowedLibraries,  int? bandwidthCapMbps,  TimeWindow? timeWindow,  String? maxRating)?  $default,) {final _that = this;
switch (_that) {
case _GroupRestrictions() when $default != null:
return $default(_that.allowedLibraries,_that.bandwidthCapMbps,_that.timeWindow,_that.maxRating);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupRestrictions implements GroupRestrictions {
  const _GroupRestrictions({final  List<String>? allowedLibraries, this.bandwidthCapMbps, this.timeWindow, this.maxRating}): _allowedLibraries = allowedLibraries;
  factory _GroupRestrictions.fromJson(Map<String, dynamic> json) => _$GroupRestrictionsFromJson(json);

 final  List<String>? _allowedLibraries;
@override List<String>? get allowedLibraries {
  final value = _allowedLibraries;
  if (value == null) return null;
  if (_allowedLibraries is EqualUnmodifiableListView) return _allowedLibraries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  int? bandwidthCapMbps;
@override final  TimeWindow? timeWindow;
@override final  String? maxRating;

/// Create a copy of GroupRestrictions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupRestrictionsCopyWith<_GroupRestrictions> get copyWith => __$GroupRestrictionsCopyWithImpl<_GroupRestrictions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupRestrictionsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupRestrictions&&const DeepCollectionEquality().equals(other._allowedLibraries, _allowedLibraries)&&(identical(other.bandwidthCapMbps, bandwidthCapMbps) || other.bandwidthCapMbps == bandwidthCapMbps)&&(identical(other.timeWindow, timeWindow) || other.timeWindow == timeWindow)&&(identical(other.maxRating, maxRating) || other.maxRating == maxRating));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_allowedLibraries),bandwidthCapMbps,timeWindow,maxRating);

@override
String toString() {
  return 'GroupRestrictions(allowedLibraries: $allowedLibraries, bandwidthCapMbps: $bandwidthCapMbps, timeWindow: $timeWindow, maxRating: $maxRating)';
}


}

/// @nodoc
abstract mixin class _$GroupRestrictionsCopyWith<$Res> implements $GroupRestrictionsCopyWith<$Res> {
  factory _$GroupRestrictionsCopyWith(_GroupRestrictions value, $Res Function(_GroupRestrictions) _then) = __$GroupRestrictionsCopyWithImpl;
@override @useResult
$Res call({
 List<String>? allowedLibraries, int? bandwidthCapMbps, TimeWindow? timeWindow, String? maxRating
});


@override $TimeWindowCopyWith<$Res>? get timeWindow;

}
/// @nodoc
class __$GroupRestrictionsCopyWithImpl<$Res>
    implements _$GroupRestrictionsCopyWith<$Res> {
  __$GroupRestrictionsCopyWithImpl(this._self, this._then);

  final _GroupRestrictions _self;
  final $Res Function(_GroupRestrictions) _then;

/// Create a copy of GroupRestrictions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? allowedLibraries = freezed,Object? bandwidthCapMbps = freezed,Object? timeWindow = freezed,Object? maxRating = freezed,}) {
  return _then(_GroupRestrictions(
allowedLibraries: freezed == allowedLibraries ? _self._allowedLibraries : allowedLibraries // ignore: cast_nullable_to_non_nullable
as List<String>?,bandwidthCapMbps: freezed == bandwidthCapMbps ? _self.bandwidthCapMbps : bandwidthCapMbps // ignore: cast_nullable_to_non_nullable
as int?,timeWindow: freezed == timeWindow ? _self.timeWindow : timeWindow // ignore: cast_nullable_to_non_nullable
as TimeWindow?,maxRating: freezed == maxRating ? _self.maxRating : maxRating // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of GroupRestrictions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TimeWindowCopyWith<$Res>? get timeWindow {
    if (_self.timeWindow == null) {
    return null;
  }

  return $TimeWindowCopyWith<$Res>(_self.timeWindow!, (value) {
    return _then(_self.copyWith(timeWindow: value));
  });
}
}


/// @nodoc
mixin _$Group {

 String get id; String get name; String? get description; GroupStatus get status; String get createdAt; String get updatedAt; int get memberCount; GroupRestrictions? get restrictions;
/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupCopyWith<Group> get copyWith => _$GroupCopyWithImpl<Group>(this as Group, _$identity);

  /// Serializes this Group to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Group&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.restrictions, restrictions) || other.restrictions == restrictions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,status,createdAt,updatedAt,memberCount,restrictions);

@override
String toString() {
  return 'Group(id: $id, name: $name, description: $description, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, memberCount: $memberCount, restrictions: $restrictions)';
}


}

/// @nodoc
abstract mixin class $GroupCopyWith<$Res>  {
  factory $GroupCopyWith(Group value, $Res Function(Group) _then) = _$GroupCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, GroupStatus status, String createdAt, String updatedAt, int memberCount, GroupRestrictions? restrictions
});


$GroupRestrictionsCopyWith<$Res>? get restrictions;

}
/// @nodoc
class _$GroupCopyWithImpl<$Res>
    implements $GroupCopyWith<$Res> {
  _$GroupCopyWithImpl(this._self, this._then);

  final Group _self;
  final $Res Function(Group) _then;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? memberCount = null,Object? restrictions = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GroupStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,restrictions: freezed == restrictions ? _self.restrictions : restrictions // ignore: cast_nullable_to_non_nullable
as GroupRestrictions?,
  ));
}
/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupRestrictionsCopyWith<$Res>? get restrictions {
    if (_self.restrictions == null) {
    return null;
  }

  return $GroupRestrictionsCopyWith<$Res>(_self.restrictions!, (value) {
    return _then(_self.copyWith(restrictions: value));
  });
}
}


/// Adds pattern-matching-related methods to [Group].
extension GroupPatterns on Group {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Group value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Group() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Group value)  $default,){
final _that = this;
switch (_that) {
case _Group():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Group value)?  $default,){
final _that = this;
switch (_that) {
case _Group() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  GroupStatus status,  String createdAt,  String updatedAt,  int memberCount,  GroupRestrictions? restrictions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Group() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.status,_that.createdAt,_that.updatedAt,_that.memberCount,_that.restrictions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  GroupStatus status,  String createdAt,  String updatedAt,  int memberCount,  GroupRestrictions? restrictions)  $default,) {final _that = this;
switch (_that) {
case _Group():
return $default(_that.id,_that.name,_that.description,_that.status,_that.createdAt,_that.updatedAt,_that.memberCount,_that.restrictions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  GroupStatus status,  String createdAt,  String updatedAt,  int memberCount,  GroupRestrictions? restrictions)?  $default,) {final _that = this;
switch (_that) {
case _Group() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.status,_that.createdAt,_that.updatedAt,_that.memberCount,_that.restrictions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Group implements Group {
  const _Group({required this.id, required this.name, this.description, required this.status, required this.createdAt, required this.updatedAt, this.memberCount = 0, this.restrictions});
  factory _Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  GroupStatus status;
@override final  String createdAt;
@override final  String updatedAt;
@override@JsonKey() final  int memberCount;
@override final  GroupRestrictions? restrictions;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupCopyWith<_Group> get copyWith => __$GroupCopyWithImpl<_Group>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Group&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.restrictions, restrictions) || other.restrictions == restrictions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,status,createdAt,updatedAt,memberCount,restrictions);

@override
String toString() {
  return 'Group(id: $id, name: $name, description: $description, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, memberCount: $memberCount, restrictions: $restrictions)';
}


}

/// @nodoc
abstract mixin class _$GroupCopyWith<$Res> implements $GroupCopyWith<$Res> {
  factory _$GroupCopyWith(_Group value, $Res Function(_Group) _then) = __$GroupCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, GroupStatus status, String createdAt, String updatedAt, int memberCount, GroupRestrictions? restrictions
});


@override $GroupRestrictionsCopyWith<$Res>? get restrictions;

}
/// @nodoc
class __$GroupCopyWithImpl<$Res>
    implements _$GroupCopyWith<$Res> {
  __$GroupCopyWithImpl(this._self, this._then);

  final _Group _self;
  final $Res Function(_Group) _then;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? memberCount = null,Object? restrictions = freezed,}) {
  return _then(_Group(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GroupStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,restrictions: freezed == restrictions ? _self.restrictions : restrictions // ignore: cast_nullable_to_non_nullable
as GroupRestrictions?,
  ));
}

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupRestrictionsCopyWith<$Res>? get restrictions {
    if (_self.restrictions == null) {
    return null;
  }

  return $GroupRestrictionsCopyWith<$Res>(_self.restrictions!, (value) {
    return _then(_self.copyWith(restrictions: value));
  });
}
}

// dart format on
