import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';

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
  });

  final List<Library> libraries;
  final List<MediaFile> files;
  final String? selectedLibraryId;

  /// Files currently displayed — all if no library selected, else filtered.
  List<MediaFile> get visibleFiles => selectedLibraryId == null
      ? files
      : files.where((f) => f.libraryId == selectedLibraryId).toList();

  int get resumingCount => files.where((f) => f.resumeSec > 0).length;

  int get enrichedCount => files.where((f) => f.posterUrl != null).length;
}

class LibraryFailure extends LibraryState {
  const LibraryFailure(this.message);
  final String message;
}
