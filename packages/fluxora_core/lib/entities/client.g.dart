// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Client _$ClientFromJson(Map<String, dynamic> json) => _Client(
  id: json['id'] as String,
  name: json['name'] as String,
  platform: $enumDecode(_$ClientPlatformEnumMap, json['platform']),
  lastSeen: utcDateTimeFromJson(json['last_seen'] as String),
  isTrusted: json['is_trusted'] as bool,
  authToken: json['auth_token'] as String?,
);

Map<String, dynamic> _$ClientToJson(_Client instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'platform': _$ClientPlatformEnumMap[instance.platform]!,
  'last_seen': utcDateTimeToJson(instance.lastSeen),
  'is_trusted': instance.isTrusted,
  'auth_token': instance.authToken,
};

const _$ClientPlatformEnumMap = {
  ClientPlatform.android: 'android',
  ClientPlatform.ios: 'ios',
  ClientPlatform.windows: 'windows',
  ClientPlatform.macos: 'macos',
  ClientPlatform.linux: 'linux',
};
