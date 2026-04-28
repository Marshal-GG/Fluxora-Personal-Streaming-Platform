import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/converters.dart';

part 'media_file.freezed.dart';
part 'media_file.g.dart';

@freezed
class MediaFile with _$MediaFile {
  const factory MediaFile({
    required String id,
    required String path,
    required String name,
    required String extension,
    required int sizeBytes,
    double? durationSec,
    String? libraryId,
    int? tmdbId,
    // TMDB-enriched metadata
    String? title,
    String? overview,
    String? posterUrl,
    // Resume playback position
    @Default(0.0) double resumeSec,
    @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
    required DateTime createdAt,
    @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
    required DateTime updatedAt,
  }) = _MediaFile;

  factory MediaFile.fromJson(Map<String, dynamic> json) =>
      _$MediaFileFromJson(json);
}
