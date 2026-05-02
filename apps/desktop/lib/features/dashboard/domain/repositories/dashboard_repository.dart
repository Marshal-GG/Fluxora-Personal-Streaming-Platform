import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/server_info.dart';

abstract class DashboardRepository {
  Future<ServerInfo> getServerInfo();
  Future<List<ClientListItem>> getClients();
  Future<int> getLibraryCount();
  Future<void> restartServer();
  Future<void> stopServer();
}
