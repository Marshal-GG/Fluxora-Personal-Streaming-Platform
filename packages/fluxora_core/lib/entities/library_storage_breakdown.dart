import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_storage_breakdown.freezed.dart';
part 'library_storage_breakdown.g.dart';

/// Breakdown of storage usage across the media library.
///
/// Returned by `GET /api/v1/library/storage-breakdown`.
/// Backs the Dashboard Storage Overview card.
@freezed
abstract class LibraryStorageBreakdown with _$LibraryStorageBreakdown {
  const factory LibraryStorageBreakdown({
    required int totalBytes,
    required int capacityBytes,
    required StorageByType byType,
  }) = _LibraryStorageBreakdown;

  factory LibraryStorageBreakdown.fromJson(Map<String, dynamic> json) =>
      _$LibraryStorageBreakdownFromJson(json);
}

/// Per-category byte counts within a [LibraryStorageBreakdown].
@freezed
abstract class StorageByType with _$StorageByType {
  const factory StorageByType({
    @Default(0) int movies,
    @Default(0) int tv,
    @Default(0) int music,
    @Default(0) int files,
  }) = _StorageByType;

  factory StorageByType.fromJson(Map<String, dynamic> json) =>
      _$StorageByTypeFromJson(json);
}
