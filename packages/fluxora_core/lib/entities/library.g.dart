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
  fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
  totalSizeBytes: (json['total_size_bytes'] as num?)?.toInt() ?? 0,
  coverUrls:
      (json['cover_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  tmdbEnabled: json['tmdb_enabled'] as bool? ?? true,
);

Map<String, dynamic> _$LibraryToJson(_Library instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$LibraryTypeEnumMap[instance.type]!,
  'root_paths': instance.rootPaths,
  'last_scanned': utcDateTimeOrNullToJson(instance.lastScanned),
  'created_at': utcDateTimeToJson(instance.createdAt),
  'file_count': instance.fileCount,
  'total_size_bytes': instance.totalSizeBytes,
  'cover_urls': instance.coverUrls,
  'tmdb_enabled': instance.tmdbEnabled,
};

const _$LibraryTypeEnumMap = {
  LibraryType.movies: 'movies',
  LibraryType.tv: 'tv',
  LibraryType.music: 'music',
  LibraryType.files: 'files',
};
