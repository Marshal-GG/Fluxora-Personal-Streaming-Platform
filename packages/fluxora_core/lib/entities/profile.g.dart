// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Profile _$ProfileFromJson(Map<String, dynamic> json) => _Profile(
  displayName: json['display_name'] as String?,
  email: json['email'] as String?,
  avatarLetter: json['avatar_letter'] as String,
  avatarPath: json['avatar_path'] as String?,
  createdAt: json['created_at'] as String?,
  lastLoginAt: json['last_login_at'] as String?,
);

Map<String, dynamic> _$ProfileToJson(_Profile instance) => <String, dynamic>{
  'display_name': instance.displayName,
  'email': instance.email,
  'avatar_letter': instance.avatarLetter,
  'avatar_path': instance.avatarPath,
  'created_at': instance.createdAt,
  'last_login_at': instance.lastLoginAt,
};
