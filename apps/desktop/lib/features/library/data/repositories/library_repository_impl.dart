import 'package:dio/dio.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/domain/entities/library.dart' as desktop;
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  const LibraryRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Resolve server-relative `cover_urls` entries (e.g.
  /// `/api/v1/files/<id>/thumbnail?v=...`) to absolute URLs so Flutter's
  /// `Image.network` can fetch them.  Absolute URLs (TMDB
  /// `https://image.tmdb.org/...`) pass through unchanged.  Plan 27 ship
  /// missed this because cover_urls were TMDB-only before — every URL
  /// was already absolute.
  Map<String, dynamic> _resolveCoverUrls(Map<String, dynamic> json) {
    final raw = json['cover_urls'];
    if (raw is! List) return json;
    final base = _apiClient.localBaseUrl;
    if (base == null || base.isEmpty) return json;
    // Trim a trailing slash so we don't end up with `base//api/v1/...`.
    final trimmedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final resolved = <String>[];
    for (final entry in raw) {
      if (entry is! String) continue;
      if (entry.startsWith('/')) {
        resolved.add('$trimmedBase$entry');
      } else {
        resolved.add(entry);
      }
    }
    return {...json, 'cover_urls': resolved};
  }

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
            libraries.add(Library.fromJson(_resolveCoverUrls(json)));
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
        fromJson: (data) =>
            Library.fromJson(_resolveCoverUrls(data as Map<String, dynamic>)),
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
      fromJson: (data) =>
          Library.fromJson(_resolveCoverUrls(data as Map<String, dynamic>)),
    );
  }

  @override
  Future<void> deleteLibrary(
    String libraryId, {
    bool deleteSidecars = true,
  }) =>
      _apiClient.delete(
        '${Endpoints.library}/$libraryId',
        queryParameters: {'delete_sidecars': deleteSidecars},
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
  Future<int> regenerateThumbnails(String libraryId) =>
      _apiClient.post<int>(
        Endpoints.libraryRegenerateThumbnails(libraryId),
        fromJson: (data) {
          if (data is Map<String, dynamic>) {
            final v = data['queued'];
            if (v is int) return v;
            if (v is num) return v.toInt();
          }
          return 0;
        },
      );

  @override
  Future<BrowseResponse> browseLibrary({
    required String libraryId,
    String path = '',
    bool showHidden = false,
  }) =>
      _apiClient.get<BrowseResponse>(
        Endpoints.libraryBrowse(libraryId),
        queryParameters: {
          if (path.isNotEmpty) 'path': path,
          // Always send the flag explicitly so we don't accidentally
          // get the server default when the operator toggled OFF after
          // browsing with hidden visible.
          'show_hidden': showHidden ? 'true' : 'false',
        },
        fromJson: (data) =>
            BrowseResponse.fromJson(data as Map<String, dynamic>),
      );

  @override
  Future<IndexFileResult> indexFile({
    required String libraryId,
    required String relativePath,
  }) =>
      _apiClient.post<IndexFileResult>(
        Endpoints.libraryIndexFile(libraryId),
        queryParameters: {'path': relativePath},
        fromJson: (data) {
          final json = data as Map<String, dynamic>;
          return IndexFileResult(
            fileId: json['file_id'] as String,
            alreadyIndexed: (json['already_indexed'] as bool?) ?? false,
            enriched: (json['enriched'] as bool?) ?? false,
          );
        },
      );

  @override
  Future<void> regenerateFileThumbnail(String fileId) =>
      _apiClient.post<void>(
        Endpoints.fileRegenerateThumbnail(fileId),
        fromJson: (_) {},
      );

  @override
  Future<int> scanSubtree({
    required String libraryId,
    required String relativePath,
  }) =>
      _apiClient.post<int>(
        Endpoints.libraryScanSubtree(libraryId),
        queryParameters: {'path': relativePath},
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
  Future<FolderSize> folderSize({
    required String libraryId,
    required String relativePath,
  }) =>
      _apiClient.get<FolderSize>(
        Endpoints.libraryFolderSize(libraryId),
        queryParameters: {
          if (relativePath.isNotEmpty) 'path': relativePath,
        },
        fromJson: (data) {
          final json = data as Map<String, dynamic>;
          final bytes = json['size_bytes'];
          final count = json['file_count'];
          return FolderSize(
            sizeBytes: bytes is int
                ? bytes
                : (bytes is num ? bytes.toInt() : 0),
            fileCount: count is int
                ? count
                : (count is num ? count.toInt() : 0),
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
