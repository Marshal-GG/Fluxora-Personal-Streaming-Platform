import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/group.dart';

class ActiveSessionInfo {
  const ActiveSessionInfo({
    required this.sessionId,
    required this.startedAt,
    this.encoderUsed,
    this.mediaTitle,
  });

  final String sessionId;
  final DateTime startedAt;
  final String? encoderUsed;
  final String? mediaTitle;

  factory ActiveSessionInfo.fromJson(Map<String, dynamic> json) {
    return ActiveSessionInfo(
      sessionId: json['session_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String).toUtc(),
      encoderUsed: json['encoder_used'] as String?,
      mediaTitle: json['media_title'] as String?,
    );
  }
}

class ClientListItem {
  const ClientListItem({
    required this.id,
    required this.name,
    required this.platform,
    required this.status,
    required this.lastSeen,
    required this.isTrusted,
    this.lastIp,
    this.activeSession,
    this.groups = const <GroupSummary>[],
  });

  final String id;
  final String name;
  final ClientPlatform platform;
  final ClientStatus status;
  final DateTime lastSeen;
  final bool isTrusted;
  final String? lastIp;
  final ActiveSessionInfo? activeSession;

  /// Groups this client belongs to.  Populated server-side by the
  /// `auth_service.list_clients` `json_group_array` aggregation (M3,
  /// 2026-05-07).  Defaulted to `const []` so deserialising an older
  /// response shape (pre-M3) doesn't throw — older servers simply
  /// render an empty groups list in the Clients-screen detail panel.
  final List<GroupSummary> groups;

  factory ClientListItem.fromJson(Map<String, dynamic> json) {
    final activeJson = json['active_session'] as Map<String, dynamic>?;
    final groupsJson = json['groups'] as List<dynamic>?;
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
      lastIp: json['last_ip'] as String?,
      activeSession:
          activeJson == null ? null : ActiveSessionInfo.fromJson(activeJson),
      groups: groupsJson == null
          ? const <GroupSummary>[]
          : groupsJson
              .map((g) => GroupSummary.fromJson(g as Map<String, dynamic>))
              .toList(),
    );
  }
}
