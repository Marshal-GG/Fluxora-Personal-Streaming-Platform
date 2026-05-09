import 'package:dio/dio.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/library/domain/entities/library.dart' as desktop;
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  const LibraryRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<LibrariesPayload> getLibrariesWithOverrides() =>
      _apiClient.get<LibrariesPayload>(
        Endpoints.library,
        fromJson: (data) {
          final list = (data as List<dynamic>);
          final libraries = <Library>[];
          final overrides = <String, desktop.LibraryCodecOverrides>{};
          for (final raw in list) {
            final json = raw as Map<String, dynamic>;
            libraries.add(Library.fromJson(json));
            overrides[json['id'] as String] =
                desktop.LibraryCodecOverrides.fromJson(json);
          }
          return (libraries: libraries, overrides: overrides);
        },
      );

  @override
  Future<List<Library>> getLibraries() async {
    final payload = await getLibrariesWithOverrides();
    return payload.libraries;
  }

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
    LibraryOverrideUpdate? av1Override,
    LibraryOverrideUpdate? vp9Override,
  }) {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (rootPaths != null) body['root_paths'] = rootPaths;
    if (av1Override != null) {
      final wire = overrideUpdateWireValue(av1Override);
      if (wire.included) body['av1_stream_copy_override'] = wire.value;
    }
    if (vp9Override != null) {
      final wire = overrideUpdateWireValue(vp9Override);
      if (wire.included) body['vp9_stream_copy_override'] = wire.value;
    }
    return _apiClient.patch<Library>(
      '${Endpoints.library}/$libraryId',
      body: body,
      fromJson: (data) => Library.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<void> deleteLibrary(
    String libraryId, {
    bool deleteSidecars = true,
  }) =>
      // ApiClient.delete doesn't expose a query-param hook so we build the
      // URL by hand.  The boolean is wire-explicit on the server side
      // (see plan 19 §M8).
      _apiClient.delete(
        '${Endpoints.library}/$libraryId?delete_sidecars=$deleteSidecars',
      );

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
