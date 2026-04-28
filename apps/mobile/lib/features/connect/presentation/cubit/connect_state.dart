import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

sealed class ConnectState {
  const ConnectState();
}

class ConnectInitial extends ConnectState {
  const ConnectInitial();
}

class ConnectSearching extends ConnectState {
  const ConnectSearching();
}

class ConnectFound extends ConnectState {
  const ConnectFound(this.servers);

  final List<DiscoveredServer> servers;
}

class ConnectError extends ConnectState {
  const ConnectError(this.message);

  final String message;
}
