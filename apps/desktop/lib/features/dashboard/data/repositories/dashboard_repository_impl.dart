import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/server_info.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<ServerInfo> getServerInfo() => _apiClient.get(
        Endpoints.info,
        fromJson: (json) =>
            ServerInfo.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<List<ClientListItem>> getClients() => _apiClient.get(
        Endpoints.authClients,
        fromJson: (json) => (json['clients'] as List<dynamic>)
            .map((e) => ClientListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
