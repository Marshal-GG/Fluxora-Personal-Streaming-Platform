// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => _ServerInfo(
  serverName: json['server_name'] as String,
  version: json['version'] as String,
  tier: $enumDecode(_$SubscriptionTierEnumMap, json['tier']),
);

Map<String, dynamic> _$ServerInfoToJson(_ServerInfo instance) =>
    <String, dynamic>{
      'server_name': instance.serverName,
      'version': instance.version,
      'tier': _$SubscriptionTierEnumMap[instance.tier]!,
    };

const _$SubscriptionTierEnumMap = {
  SubscriptionTier.free: 'free',
  SubscriptionTier.plus: 'plus',
  SubscriptionTier.pro: 'pro',
  SubscriptionTier.ultimate: 'ultimate',
};
