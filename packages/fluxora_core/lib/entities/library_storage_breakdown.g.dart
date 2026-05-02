// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_storage_breakdown.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LibraryStorageBreakdown _$LibraryStorageBreakdownFromJson(
  Map<String, dynamic> json,
) => _LibraryStorageBreakdown(
  totalBytes: (json['total_bytes'] as num).toInt(),
  capacityBytes: (json['capacity_bytes'] as num).toInt(),
  byType: StorageByType.fromJson(json['by_type'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LibraryStorageBreakdownToJson(
  _LibraryStorageBreakdown instance,
) => <String, dynamic>{
  'total_bytes': instance.totalBytes,
  'capacity_bytes': instance.capacityBytes,
  'by_type': instance.byType.toJson(),
};

_StorageByType _$StorageByTypeFromJson(Map<String, dynamic> json) =>
    _StorageByType(
      movies: (json['movies'] as num?)?.toInt() ?? 0,
      tv: (json['tv'] as num?)?.toInt() ?? 0,
      music: (json['music'] as num?)?.toInt() ?? 0,
      files: (json['files'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$StorageByTypeToJson(_StorageByType instance) =>
    <String, dynamic>{
      'movies': instance.movies,
      'tv': instance.tv,
      'music': instance.music,
      'files': instance.files,
    };
