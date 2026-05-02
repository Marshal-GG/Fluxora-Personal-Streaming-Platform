import 'package:fluxora_core/entities/library_storage_breakdown.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/storage/domain/repositories/storage_repository.dart';

class StorageRepositoryImpl implements StorageRepository {
  StorageRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<LibraryStorageBreakdown> fetch() => _apiClient.get(
        Endpoints.libraryStorageBreakdown,
        fromJson: (json) =>
            LibraryStorageBreakdown.fromJson(json as Map<String, dynamic>),
      );
}
