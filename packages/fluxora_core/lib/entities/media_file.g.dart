// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MediaFile _$MediaFileFromJson(Map<String, dynamic> json) => _MediaFile(
  id: json['id'] as String,
  path: json['path'] as String,
  name: json['name'] as String,
  extension: json['extension'] as String,
  sizeBytes: (json['size_bytes'] as num).toInt(),
  durationSec: (json['duration_sec'] as num?)?.toDouble(),
  libraryId: json['library_id'] as String?,
  tmdbId: (json['tmdb_id'] as num?)?.toInt(),
  title: json['title'] as String?,
  overview: json['overview'] as String?,
  posterUrl: json['poster_url'] as String?,
  resumeSec: (json['last_progress_sec'] as num?)?.toDouble() ?? 0.0,
  createdAt: utcDateTimeFromJson(json['created_at'] as String),
  updatedAt: utcDateTimeFromJson(json['updated_at'] as String),
);

Map<String, dynamic> _$MediaFileToJson(_MediaFile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'path': instance.path,
      'name': instance.name,
      'extension': instance.extension,
      'size_bytes': instance.sizeBytes,
      'duration_sec': instance.durationSec,
      'library_id': instance.libraryId,
      'tmdb_id': instance.tmdbId,
      'title': instance.title,
      'overview': instance.overview,
      'poster_url': instance.posterUrl,
      'last_progress_sec': instance.resumeSec,
      'created_at': utcDateTimeToJson(instance.createdAt),
      'updated_at': utcDateTimeToJson(instance.updatedAt),
    };
