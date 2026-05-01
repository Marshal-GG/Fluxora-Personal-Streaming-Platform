import 'package:logger/logger.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:fluxora_core/entities/server_info.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';
import 'package:fluxora_mobile/features/connect/domain/repositories/server_discovery_repository.dart';

class ServerDiscoveryRepositoryImpl implements ServerDiscoveryRepository {
  ServerDiscoveryRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;
  static final _log = Logger();

  static const String _serviceType = '_fluxora._tcp.local.';

  @override
  Stream<DiscoveredServer> discoverViaMulticast() async* {
    final client = MDnsClient();
    try {
      await client.start();
      await for (final PtrResourceRecord ptr
          in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_serviceType),
      )) {
        SrvResourceRecord? srv;
        await for (final SrvResourceRecord s
            in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          srv = s;
          break;
        }
        if (srv == null) continue;

        IPAddressResourceRecord? ipRecord;
        await for (final IPAddressResourceRecord ip
            in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        )) {
          ipRecord = ip;
          break;
        }
        if (ipRecord == null) continue;

        yield DiscoveredServer(
          name: ptr.domainName,
          ip: ipRecord.address.address,
          port: srv.port,
        );
      }
    } catch (e, st) {
      _log.e('mDNS discovery failed', error: e, stackTrace: st);
    } finally {
      client.stop();
    }
  }

  @override
  Future<ServerInfo> verifyServer(String url) async {
    _apiClient.configure(localBaseUrl: url);
    return _apiClient.get<ServerInfo>(
      Endpoints.info,
      fromJson: (data) =>
          ServerInfo.fromJson(data as Map<String, dynamic>),
    );
  }
}
