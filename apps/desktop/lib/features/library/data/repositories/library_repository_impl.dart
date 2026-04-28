import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  const LibraryRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<Library>> getLibraries() => _apiClient.get<List<Library>>(
        Endpoints.library,
        fromJson: (data) => (data as List<dynamic>)
            .map((e) => Library.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Future<List<MediaFile>> getFiles({String? libraryId}) =>
      _apiClient.get<List<MediaFile>>(
        Endpoints.files,
        queryParameters:
            libraryId != null ? {'library_id': libraryId} : null,
        fromJson: (data) => (data as List<dynamic>)
            .map((e) => MediaFile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
