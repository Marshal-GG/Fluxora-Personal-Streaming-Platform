// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClientProfile _$ClientProfileFromJson(Map<String, dynamic> json) =>
    _ClientProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      platform: $enumDecode(_$ClientPlatformEnumMap, json['platform']),
      pairedAt: utcDateTimeOrNullFromJson(json['paired_at'] as String?),
      lastSeen: utcDateTimeFromJson(json['last_seen'] as String),
      tier: $enumDecode(_$SubscriptionTierEnumMap, json['tier']),
    );

Map<String, dynamic> _$ClientProfileToJson(_ClientProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'email': instance.email,
      'platform': _$ClientPlatformEnumMap[instance.platform]!,
      'paired_at': utcDateTimeOrNullToJson(instance.pairedAt),
      'last_seen': utcDateTimeToJson(instance.lastSeen),
      'tier': _$SubscriptionTierEnumMap[instance.tier]!,
    };

const _$ClientPlatformEnumMap = {
  ClientPlatform.android: 'android',
  ClientPlatform.ios: 'ios',
  ClientPlatform.windows: 'windows',
  ClientPlatform.macos: 'macos',
  ClientPlatform.linux: 'linux',
};

const _$SubscriptionTierEnumMap = {
  SubscriptionTier.free: 'free',
  SubscriptionTier.plus: 'plus',
  SubscriptionTier.pro: 'pro',
  SubscriptionTier.ultimate: 'ultimate',
};
