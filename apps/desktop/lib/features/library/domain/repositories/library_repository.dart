import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/entities/library.dart';

abstract interface class LibraryRepository {
  Future<List<Library>> getLibraries();
  Future<List<MediaFile>> getFiles({String? libraryId});
  Future<Library> createLibrary({required String name, required String type, required List<String> rootPaths});
  Future<void> scanLibrary(String libraryId);
  Future<MediaFile> uploadFileToLibrary({required String libraryId, required String filePath});
}
