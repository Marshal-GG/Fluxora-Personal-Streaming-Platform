import 'package:fluxora_core/entities/enums.dart';

class ClientListItem {
  const ClientListItem({
    required this.id,
    required this.name,
    required this.platform,
    required this.status,
    required this.lastSeen,
    required this.isTrusted,
  });

  final String id;
  final String name;
  final ClientPlatform platform;
  final ClientStatus status;
  final DateTime lastSeen;
  final bool isTrusted;

  factory ClientListItem.fromJson(Map<String, dynamic> json) {
    return ClientListItem(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: ClientPlatform.values.firstWhere(
        (p) => p.name == (json['platform'] as String),
        orElse: () => ClientPlatform.android,
      ),
      status: ClientStatus.fromJson(json['status'] as String),
      lastSeen: DateTime.parse(json['last_seen'] as String).toUtc(),
      isTrusted: json['is_trusted'] as bool,
    );
  }
}
