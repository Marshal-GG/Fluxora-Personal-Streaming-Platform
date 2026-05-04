/// Parser for the QR-code pairing payload (Phase B QA round, 2026-05-04).
///
/// **Payload shape:** `fluxora://pair?host=<ip>&port=<int>&name=<string>`
///
/// - `host` is the LAN IP the desktop is listening on (mDNS-discovered or
///   manually entered on the desktop).
/// - `port` is the FastAPI port (8000 by default per `config.py`).
/// - `name` is the operator-friendly server name from `user_settings.
///   server_name`; falls back to `host` when missing.
///
/// **Why a custom URI scheme:** the QR is parsed in-app (camera scan from
/// `mobile_scanner`); we don't need an OS-level deep-link handler for v1.
/// A `fluxora://` URI keeps the format readable in error logs while
/// forbidding accidental launches from a browser link.
///
/// **What's NOT in the payload:** the bearer token.  Pairing still has
/// to go through the operator approve flow on the desktop — the QR
/// only skips mDNS discovery.  This keeps the security model of the
/// Phase A pairing flow intact: a stranger who photographs the QR
/// learns nothing useful, since `POST /auth/request-pair` still has
/// to be approved by a human at the operator's desktop.
library;

import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

class PairingUri {
  PairingUri._();

  static const String scheme = 'fluxora';
  static const String host = 'pair';

  /// Parse [raw] into a [DiscoveredServer].  Returns `null` for any
  /// malformed input — caller decides how to surface the error.
  ///
  /// Accepts either the canonical `fluxora://pair?host=&port=&name=`
  /// form or a plain `http://1.2.3.4:8000` URL (so a user who pastes
  /// the manual-entry URL into a QR generator still works).  Rejects
  /// anything else.
  static DiscoveredServer? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    if (uri.scheme == scheme && uri.host == host) {
      return _fromCustom(uri);
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return _fromHttp(uri);
    }
    return null;
  }

  static DiscoveredServer? _fromCustom(Uri uri) {
    final hostParam = uri.queryParameters['host']?.trim();
    final portRaw = uri.queryParameters['port']?.trim();
    final nameParam = uri.queryParameters['name']?.trim();
    if (hostParam == null || hostParam.isEmpty) return null;
    final port = int.tryParse(portRaw ?? '');
    if (port == null || port <= 0 || port > 65535) return null;
    final displayName =
        (nameParam == null || nameParam.isEmpty) ? hostParam : nameParam;
    return DiscoveredServer(
      name: displayName,
      ip: hostParam,
      port: port,
    );
  }

  static DiscoveredServer? _fromHttp(Uri uri) {
    if (uri.host.isEmpty) return null;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    return DiscoveredServer(
      name: uri.host,
      ip: uri.host,
      port: port,
    );
  }

  /// Build a canonical `fluxora://pair?...` URI.  Used by the desktop
  /// `qr_flutter` renderer.  Mirror this format exactly there so a
  /// future serialisation change touches both sides.
  static String build({
    required String hostIp,
    required int port,
    String? serverName,
  }) {
    final params = <String, String>{
      'host': hostIp,
      'port': '$port',
      if (serverName != null && serverName.isNotEmpty) 'name': serverName,
    };
    final uri = Uri(
      scheme: scheme,
      host: host,
      queryParameters: params,
    );
    return uri.toString();
  }
}
