import 'package:fluxora_core/entities/server_info.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

abstract class ServerDiscoveryRepository {
  Stream<DiscoveredServer> discoverViaMulticast();
  Future<ServerInfo> verifyServer(String url);
}
