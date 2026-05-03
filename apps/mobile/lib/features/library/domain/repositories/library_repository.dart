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
}
