import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/entities/library.dart';

abstract interface class LibraryRepository {
  Future<List<Library>> getLibraries();
  Future<List<MediaFile>> getFiles({String? libraryId});
  Future<Library> createLibrary({required String name, required String type, required List<String> rootPaths});
  Future<Library> updateLibrary({required String libraryId, String? name, List<String>? rootPaths});
  Future<void> deleteLibrary(String libraryId);
  Future<int> scanLibrary(String libraryId);

  /// Re-run TMDB enrichment for files in [libraryId] that lack a
  /// `tmdb_id`.  Returns `(matched, enriched, skippedDvr)` so the UI
  /// can render an exact "X of N enriched" toast.  When [includeDvr]
  /// is true the server skips the DVR-filename heuristic and searches
  /// capture-style filenames anyway.
  Future<({int matched, int enriched, int skippedDvr})> enrichLibraryTmdb(
    String libraryId, {
    bool includeDvr = false,
  });

  Future<MediaFile> uploadFileToLibrary({required String libraryId, required String filePath});
}
