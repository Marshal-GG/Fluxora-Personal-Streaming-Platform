import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/converters.dart';
import 'package:fluxora_core/entities/enums.dart';

part 'library.freezed.dart';
part 'library.g.dart';

@freezed
abstract class Library with _$Library {
  const factory Library({
    required String id,
    required String name,
    required LibraryType type,
    required List<String> rootPaths,
    @JsonKey(
      fromJson: utcDateTimeOrNullFromJson,
      toJson: utcDateTimeOrNullToJson,
    )
    DateTime? lastScanned,
    @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
    required DateTime createdAt,
    @Default(0) int fileCount,
    @Default(0) int totalSizeBytes,
    @Default(<String>[]) List<String> coverUrls,
    /// Per-library TMDB-enrichment toggle (server migration 040).
    /// Default `true` so pre-flag libraries continue behaving as
    /// before.  When `false`, the server (a) skips future TMDB
    /// enrichment for this library and (b) masks already-persisted
    /// TMDB columns (poster_url / title / overview / tmdb_id) out of
    /// every read-path response without dropping the underlying
    /// rows — re-enabling restores the data instantly.
    @Default(true) bool tmdbEnabled,
  }) = _Library;

  factory Library.fromJson(Map<String, dynamic> json) =>
      _$LibraryFromJson(json);
}
