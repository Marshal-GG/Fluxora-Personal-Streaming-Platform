// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ServerInfoImpl _$$ServerInfoImplFromJson(Map<String, dynamic> json) =>
    _$ServerInfoImpl(
      serverName: json['server_name'] as String,
      version: json['version'] as String,
      tier: $enumDecode(_$SubscriptionTierEnumMap, json['tier']),
    );

Map<String, dynamic> _$$ServerInfoImplToJson(_$ServerInfoImpl instance) =>
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
