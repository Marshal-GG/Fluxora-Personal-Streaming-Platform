import 'package:fluxora_core/entities/client_list_item.dart';

abstract class ClientsRepository {
  Future<List<ClientListItem>> getClients();
  Future<void> approveClient(String clientId);
  Future<void> rejectClient(String clientId);
}
