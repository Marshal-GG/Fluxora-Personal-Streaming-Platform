import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';

abstract class LibraryRepository {
  Future<List<Library>> listLibraries();
  Future<List<MediaFile>> listFiles({String? libraryId});

  /// `GET /api/v1/files/recent?limit=N` (Phase A backfill).  Backs the
  /// mobile Home "Recently added" rail.  `limit` is clamped to `[1, 50]`
  /// at the server boundary; this layer trusts whatever it is handed.
  Future<List<MediaFile>> listRecentFiles({int limit = 20});

  /// `GET /api/v1/files/{file_id}` — single file by id.
  Future<MediaFile> getFile(String fileId);

  /// `GET /api/v1/files/search?q=...&limit=N` (Phase B backfill plan
  /// §3 row 2).  Backs the mobile Search tab.  Server uses SQL `LIKE`
  /// for v1 — FTS5 is the v2 swap-in (decision §5 row 1).
  Future<List<MediaFile>> searchFiles({required String query, int limit = 20});

  /// `GET /api/v1/auth/clients/me/continue-watching?limit=N` (Phase B
  /// backfill plan §3 row 1).  Backs the mobile Home "Continue watching"
  /// rail.  Returns files with non-zero resume position that aren't
  /// effectively complete (sorted by `updated_at DESC`).
  Future<List<MediaFile>> listContinueWatching({int limit = 12});
}
