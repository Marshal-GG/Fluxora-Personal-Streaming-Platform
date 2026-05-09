import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_desktop/features/library/domain/entities/library.dart' as desktop;

sealed class LibraryState {
  const LibraryState();
}

class LibraryInitial extends LibraryState {
  const LibraryInitial();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibraryLoaded extends LibraryState {
  const LibraryLoaded({
    required this.libraries,
    required this.files,
    this.selectedLibraryId,
    this.codecOverrides = const {},
  });

  final List<Library> libraries;
  final List<MediaFile> files;
  final String? selectedLibraryId;

  /// Per-library codec passthrough overrides — plan 19 §M8.  Keyed by
  /// library id; missing keys default to [LibraryCodecOverrides.empty].
  final Map<String, desktop.LibraryCodecOverrides> codecOverrides;

  /// Files currently displayed — all if no library selected, else filtered.
  List<MediaFile> get visibleFiles => selectedLibraryId == null
      ? files
      : files.where((f) => f.libraryId == selectedLibraryId).toList();

  int get resumingCount => files.where((f) => f.resumeSec > 0).length;

  int get enrichedCount => files.where((f) => f.posterUrl != null).length;

  /// Convenience accessor — returns the override pair for [libraryId],
  /// falling back to [LibraryCodecOverrides.empty] when missing.
  desktop.LibraryCodecOverrides overridesFor(String libraryId) =>
      codecOverrides[libraryId] ?? desktop.LibraryCodecOverrides.empty;
}

class LibraryFailure extends LibraryState {
  const LibraryFailure(this.message);
  final String message;
}
