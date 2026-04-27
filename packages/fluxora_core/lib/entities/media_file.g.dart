// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MediaFileImpl _$$MediaFileImplFromJson(Map<String, dynamic> json) =>
    _$MediaFileImpl(
      id: json['id'] as String,
      path: json['path'] as String,
      name: json['name'] as String,
      extension: json['extension'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      durationSec: (json['duration_sec'] as num?)?.toDouble(),
      libraryId: json['library_id'] as String?,
      tmdbId: (json['tmdb_id'] as num?)?.toInt(),
      createdAt: utcDateTimeFromJson(json['created_at'] as String),
      updatedAt: utcDateTimeFromJson(json['updated_at'] as String),
    );

Map<String, dynamic> _$$MediaFileImplToJson(_$MediaFileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'path': instance.path,
      'name': instance.name,
      'extension': instance.extension,
      'size_bytes': instance.sizeBytes,
      'duration_sec': instance.durationSec,
      'library_id': instance.libraryId,
      'tmdb_id': instance.tmdbId,
      'created_at': utcDateTimeToJson(instance.createdAt),
      'updated_at': utcDateTimeToJson(instance.updatedAt),
    };
