import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_desktop/features/library/domain/entities/library.dart' as desktop;

/// Pair returned by [LibraryRepository.getLibraries] — the canonical core
/// `Library` shape plus the per-library codec passthrough overrides
/// (plan 19 §M8) that only the desktop edit form cares about.  Holding
/// the overrides as a sidecar map (keyed by library id) keeps the core
/// freezed Library entity untouched.
typedef LibrariesPayload = ({
  List<Library> libraries,
  Map<String, desktop.LibraryCodecOverrides> overrides,
});

abstract interface class LibraryRepository {
  /// Returns the libraries list plus per-library codec passthrough
  /// overrides (`av1_stream_copy_override` / `vp9_stream_copy_override`)
  /// extracted from the same response.  Older servers that don't return
  /// the override fields surface as `LibraryCodecOverrides.empty`.
  Future<LibrariesPayload> getLibrariesWithOverrides();

  /// Convenience — same as [getLibrariesWithOverrides] but discards
  /// overrides.  Existing call sites that don't care about overrides
  /// can keep their original shape; the cubit forwards the overrides
  /// onto the state separately.
  Future<List<Library>> getLibraries();

  Future<List<MediaFile>> getFiles({String? libraryId});
  Future<Library> createLibrary({required String name, required String type, required List<String> rootPaths});

  /// Update a library.  [av1Override] / [vp9Override] are 3-state — pass
  /// `null` to leave the field unchanged on the server, or use one of
  /// the explicit dedicated [updateLibraryOverrides] / clear methods to
  /// flip a field to NULL on the server.  Plan 19 §M8 distinguishes
  /// "unchanged" from "clear to null" using a sentinel-bearing helper
  /// rather than nullable bools, since `bool? = null` already means
  /// "use global".
  Future<Library> updateLibrary({
    required String libraryId,
    String? name,
    List<String>? rootPaths,
    LibraryOverrideUpdate? av1Override,
    LibraryOverrideUpdate? vp9Override,
  });

  /// Delete a library entry.  When [deleteSidecars] is true (the default
  /// per plan 19 §M8), the server also removes any transcoded H.264
  /// sidecars associated with files in this library — both the
  /// `media_files.transcoded_path` rows and the on-disk files.  When
  /// false the sidecar files are left in place (`media_files` rows are
  /// gone with the library either way).
  Future<void> deleteLibrary(String libraryId, {bool deleteSidecars = true});

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

  /// Queue every file in [libraryId] for thumbnail regeneration.  The
  /// server deletes the existing cached JPEGs and flips each
  /// `media_thumbnails` row back to `pending` so the BG worker re-
  /// renders at current settings (width, HDR tonemap, etc).  Returns
  /// the count of files queued.  Backed by
  /// `POST /api/v1/library/{id}/regenerate-thumbnails`.  Plan 27 M5.
  Future<int> regenerateThumbnails(String libraryId);

  Future<MediaFile> uploadFileToLibrary({required String libraryId, required String filePath});
}

/// 3-state update sentinel for the codec passthrough fields — disambiguates
/// the three meanings of "unchanged / clear to null / set to bool".  PATCH
/// callers mark a field as one of:
///
///   - `LibraryOverrideUpdate.unchanged` — the field is omitted from the
///     PATCH body (server keeps the existing value).
///   - `LibraryOverrideUpdate.clear`     — the field is sent as `null`
///     ("inherit global"). Server sets the column to NULL.
///   - `LibraryOverrideUpdate.value(true|false)` — the field is sent as
///     the bool ("always" / "never").
sealed class LibraryOverrideUpdate {
  const LibraryOverrideUpdate();
  const factory LibraryOverrideUpdate.unchanged() = _OverrideUnchanged;
  const factory LibraryOverrideUpdate.clear() = _OverrideClear;
  const factory LibraryOverrideUpdate.value(bool v) = _OverrideValue;
}

final class _OverrideUnchanged extends LibraryOverrideUpdate {
  const _OverrideUnchanged();
}

final class _OverrideClear extends LibraryOverrideUpdate {
  const _OverrideClear();
}

final class _OverrideValue extends LibraryOverrideUpdate {
  const _OverrideValue(this.value);
  final bool value;
}

/// Serialise a [LibraryOverrideUpdate] into the matching wire form.
/// Returns `(included, value)` — when `included` is false, callers omit
/// the field entirely; when true, send `value` (which may be null).
({bool included, bool? value}) overrideUpdateWireValue(
  LibraryOverrideUpdate update,
) {
  return switch (update) {
    _OverrideUnchanged() => (included: false, value: null),
    _OverrideClear() => (included: true, value: null),
    _OverrideValue(value: final v) => (included: true, value: v),
  };
}
