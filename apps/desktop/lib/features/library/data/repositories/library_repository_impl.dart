import 'package:dio/dio.dart';
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

  @override
  Future<Library> createLibrary({required String name, required String type, required List<String> rootPaths}) =>
      _apiClient.post<Library>(
        Endpoints.library,
        data: {'name': name, 'type': type, 'root_paths': rootPaths},
        fromJson: (data) => Library.fromJson(data as Map<String, dynamic>),
      );

  @override
  Future<Library> updateLibrary({
    required String libraryId,
    String? name,
    List<String>? rootPaths,
  }) {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (rootPaths != null) body['root_paths'] = rootPaths;
    return _apiClient.patch<Library>(
      '${Endpoints.library}/$libraryId',
      body: body,
      fromJson: (data) => Library.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<void> deleteLibrary(String libraryId) =>
      _apiClient.delete('${Endpoints.library}/$libraryId');

  @override
  Future<int> scanLibrary(String libraryId) => _apiClient.post<int>(
        '${Endpoints.library}/$libraryId/scan',
        fromJson: (data) {
          if (data is Map<String, dynamic>) {
            final v = data['files_added'];
            if (v is int) return v;
            if (v is num) return v.toInt();
          }
          return 0;
        },
      );

  @override
  Future<({int matched, int enriched, int skippedDvr})> enrichLibraryTmdb(
    String libraryId, {
    bool includeDvr = false,
  }) =>
      _apiClient.post<({int matched, int enriched, int skippedDvr})>(
        Endpoints.libraryEnrichTmdb(libraryId),
        queryParameters: includeDvr ? const {'include_dvr': 'true'} : null,
        fromJson: (data) {
          int readInt(String key) {
            if (data is Map<String, dynamic>) {
              final v = data[key];
              if (v is int) return v;
              if (v is num) return v.toInt();
            }
            return 0;
          }
          return (
            matched: readInt('matched'),
            enriched: readInt('enriched'),
            skippedDvr: readInt('skipped_dvr'),
          );
        },
      );

  @override
  Future<MediaFile> uploadFileToLibrary({required String libraryId, required String filePath}) async {
    final formData = FormData.fromMap({
      'library_id': libraryId,
      'file': await MultipartFile.fromFile(filePath),
    });
    return _apiClient.post<MediaFile>(
      '${Endpoints.files}/upload',
      data: formData,
      fromJson: (data) => MediaFile.fromJson(data as Map<String, dynamic>),
    );
  }
}
