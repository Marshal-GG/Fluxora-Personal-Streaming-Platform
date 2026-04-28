import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';

abstract class LibraryRepository {
  Future<List<Library>> listLibraries();
  Future<List<MediaFile>> listFiles({String? libraryId});
}
