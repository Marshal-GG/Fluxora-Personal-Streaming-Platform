// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) {
  return _ServerInfo.fromJson(json);
}

/// @nodoc
mixin _$ServerInfo {
  String get serverName => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  SubscriptionTier get tier => throw _privateConstructorUsedError;

  /// Serializes this ServerInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ServerInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ServerInfoCopyWith<ServerInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServerInfoCopyWith<$Res> {
  factory $ServerInfoCopyWith(
          ServerInfo value, $Res Function(ServerInfo) then) =
      _$ServerInfoCopyWithImpl<$Res, ServerInfo>;
  @useResult
  $Res call({String serverName, String version, SubscriptionTier tier});
}

/// @nodoc
class _$ServerInfoCopyWithImpl<$Res, $Val extends ServerInfo>
    implements $ServerInfoCopyWith<$Res> {
  _$ServerInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ServerInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serverName = null,
    Object? version = null,
    Object? tier = null,
  }) {
    return _then(_value.copyWith(
      serverName: null == serverName
          ? _value.serverName
          : serverName // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as SubscriptionTier,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ServerInfoImplCopyWith<$Res>
    implements $ServerInfoCopyWith<$Res> {
  factory _$$ServerInfoImplCopyWith(
          _$ServerInfoImpl value, $Res Function(_$ServerInfoImpl) then) =
      __$$ServerInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String serverName, String version, SubscriptionTier tier});
}

/// @nodoc
class __$$ServerInfoImplCopyWithImpl<$Res>
    extends _$ServerInfoCopyWithImpl<$Res, _$ServerInfoImpl>
    implements _$$ServerInfoImplCopyWith<$Res> {
  __$$ServerInfoImplCopyWithImpl(
      _$ServerInfoImpl _value, $Res Function(_$ServerInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of ServerInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? serverName = null,
    Object? version = null,
    Object? tier = null,
  }) {
    return _then(_$ServerInfoImpl(
      serverName: null == serverName
          ? _value.serverName
          : serverName // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      tier: null == tier
          ? _value.tier
          : tier // ignore: cast_nullable_to_non_nullable
              as SubscriptionTier,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ServerInfoImpl implements _ServerInfo {
  const _$ServerInfoImpl(
      {required this.serverName, required this.version, required this.tier});

  factory _$ServerInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServerInfoImplFromJson(json);

  @override
  final String serverName;
  @override
  final String version;
  @override
  final SubscriptionTier tier;

  @override
  String toString() {
    return 'ServerInfo(serverName: $serverName, version: $version, tier: $tier)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServerInfoImpl &&
            (identical(other.serverName, serverName) ||
                other.serverName == serverName) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.tier, tier) || other.tier == tier));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, serverName, version, tier);

  /// Create a copy of ServerInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServerInfoImplCopyWith<_$ServerInfoImpl> get copyWith =>
      __$$ServerInfoImplCopyWithImpl<_$ServerInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ServerInfoImplToJson(
      this,
    );
  }
}

abstract class _ServerInfo implements ServerInfo {
  const factory _ServerInfo(
      {required final String serverName,
      required final String version,
      required final SubscriptionTier tier}) = _$ServerInfoImpl;

  factory _ServerInfo.fromJson(Map<String, dynamic> json) =
      _$ServerInfoImpl.fromJson;

  @override
  String get serverName;
  @override
  String get version;
  @override
  SubscriptionTier get tier;

  /// Create a copy of ServerInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServerInfoImplCopyWith<_$ServerInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
