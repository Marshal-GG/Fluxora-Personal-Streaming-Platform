// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TimeWindow _$TimeWindowFromJson(Map<String, dynamic> json) => _TimeWindow(
  startH: (json['start_h'] as num).toInt(),
  endH: (json['end_h'] as num).toInt(),
  days: (json['days'] as List<dynamic>).map((e) => (e as num).toInt()).toList(),
);

Map<String, dynamic> _$TimeWindowToJson(_TimeWindow instance) =>
    <String, dynamic>{
      'start_h': instance.startH,
      'end_h': instance.endH,
      'days': instance.days,
    };

_GroupRestrictions _$GroupRestrictionsFromJson(Map<String, dynamic> json) =>
    _GroupRestrictions(
      allowedLibraries: (json['allowed_libraries'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      bandwidthCapMbps: (json['bandwidth_cap_mbps'] as num?)?.toInt(),
      timeWindow: json['time_window'] == null
          ? null
          : TimeWindow.fromJson(json['time_window'] as Map<String, dynamic>),
      maxRating: json['max_rating'] as String?,
    );

Map<String, dynamic> _$GroupRestrictionsToJson(_GroupRestrictions instance) =>
    <String, dynamic>{
      'allowed_libraries': instance.allowedLibraries,
      'bandwidth_cap_mbps': instance.bandwidthCapMbps,
      'time_window': instance.timeWindow?.toJson(),
      'max_rating': instance.maxRating,
    };

_Group _$GroupFromJson(Map<String, dynamic> json) => _Group(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  status: $enumDecode(_$GroupStatusEnumMap, json['status']),
  createdAt: json['created_at'] as String,
  updatedAt: json['updated_at'] as String,
  memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
  restrictions: json['restrictions'] == null
      ? null
      : GroupRestrictions.fromJson(
          json['restrictions'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$GroupToJson(_Group instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'status': _$GroupStatusEnumMap[instance.status]!,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'member_count': instance.memberCount,
  'restrictions': instance.restrictions?.toJson(),
};

const _$GroupStatusEnumMap = {
  GroupStatus.active: 'active',
  GroupStatus.inactive: 'inactive',
};
