class DiscoveredServer {
  const DiscoveredServer({
    required this.name,
    required this.ip,
    required this.port,
  });

  final String name;
  final String ip;
  final int port;

  String get url => 'http://$ip:$port';
}
