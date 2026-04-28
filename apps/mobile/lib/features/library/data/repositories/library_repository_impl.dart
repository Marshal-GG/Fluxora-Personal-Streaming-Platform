import 'package:logger/logger.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;
  static final _log = Logger();

  @override
  Future<List<Library>> listLibraries() async {
    _log.d('Fetching libraries');
    return _apiClient.get<List<Library>>(
      Endpoints.library,
      fromJson: (data) => (data as List<dynamic>)
          .map((item) => Library.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<MediaFile>> listFiles({String? libraryId}) async {
    _log.d('Fetching files${libraryId != null ? ' for $libraryId' : ''}');
    return _apiClient.get<List<MediaFile>>(
      Endpoints.files,
      queryParameters:
          libraryId != null ? {'library_id': libraryId} : null,
      fromJson: (data) => (data as List<dynamic>)
          .map((item) =>
              MediaFile.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
