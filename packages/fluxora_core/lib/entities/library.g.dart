// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Library _$LibraryFromJson(Map<String, dynamic> json) => _Library(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$LibraryTypeEnumMap, json['type']),
  rootPaths: (json['root_paths'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  lastScanned: utcDateTimeOrNullFromJson(json['last_scanned'] as String?),
  createdAt: utcDateTimeFromJson(json['created_at'] as String),
);

Map<String, dynamic> _$LibraryToJson(_Library instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$LibraryTypeEnumMap[instance.type]!,
  'root_paths': instance.rootPaths,
  'last_scanned': utcDateTimeOrNullToJson(instance.lastScanned),
  'created_at': utcDateTimeToJson(instance.createdAt),
};

const _$LibraryTypeEnumMap = {
  LibraryType.movies: 'movies',
  LibraryType.tv: 'tv',
  LibraryType.music: 'music',
  LibraryType.files: 'files',
};
