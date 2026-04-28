import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/entities/library.dart';

abstract interface class LibraryRepository {
  Future<List<Library>> getLibraries();
  Future<List<MediaFile>> getFiles({String? libraryId});
}
