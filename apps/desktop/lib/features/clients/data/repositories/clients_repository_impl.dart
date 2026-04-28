import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';

class ClientsRepositoryImpl implements ClientsRepository {
  ClientsRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ClientListItem>> getClients() => _apiClient.get(
        Endpoints.authClients,
        fromJson: (json) => (json['clients'] as List<dynamic>)
            .map((e) => ClientListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Future<void> approveClient(String clientId) =>
      _apiClient.post<void>(Endpoints.authApprove(clientId));

  @override
  Future<void> rejectClient(String clientId) =>
      _apiClient.post<void>(Endpoints.authReject(clientId));
}
