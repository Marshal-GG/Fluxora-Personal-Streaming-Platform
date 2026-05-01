import 'dart:io' show NetworkInterface, InternetAddress, InternetAddressType;

import 'package:logger/logger.dart';

/// Detects whether a server URL is on the same local network (LAN) as the
/// device, or on the internet (WAN).
///
/// Strategy
/// ~~~~~~~~
/// 1. Parse the server URL to extract its host (IPv4 address or hostname).
/// 2. Enumerate the device's network interfaces to collect all assigned
///    IPv4 addresses.
/// 3. If the server host is a private-range IP AND falls within one of the
///    device's /24 subnets → LAN. Otherwise → WAN.
///
/// Private ranges covered: 10.x.x.x, 172.16-31.x.x, 192.168.x.x, 169.254.x.x.
///
/// Used by [ApiClient] to choose between the LAN and remote (Cloudflare
/// Tunnel) base URL on each request — see Phase 3 of the public-routing
/// plan in `docs/05_infrastructure/03_public_routing.md`.
class NetworkPathDetector {
  static final _log = Logger();

  /// Returns `true` if [serverUrl] resolves to a host on the local network.
  ///
  /// Fast (~< 5 ms) — pure in-process check, no DNS or ICMP. Falls back to
  /// `false` (treat as WAN) on any parse / IO error so that the remote URL
  /// is attempted rather than the request failing outright.
  static Future<bool> isLan(String serverUrl) async {
    try {
      final host = _extractHost(serverUrl);
      if (host == null) return false;

      // localhost / loopback → always LAN
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return true;
      }

      final serverAddr = InternetAddress.tryParse(host);
      if (serverAddr == null) {
        // Hostname — treat as WAN (mDNS names are handled at discovery time).
        return false;
      }

      if (!_isPrivateIpv4(serverAddr)) return false;

      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (_sameSubnet(addr, serverAddr)) {
            _log.d(
              '[NetPath] $host is LAN (iface ${iface.name} ${addr.address})',
            );
            return true;
          }
        }
      }

      _log.d('[NetPath] $host is WAN (private IP but not on any local subnet)');
      return false;
    } catch (e, st) {
      _log.w(
        '[NetPath] Detection failed — defaulting to WAN',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static String? _extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isEmpty ? null : uri.host;
    } catch (_) {
      return null;
    }
  }

  /// True for RFC-1918 private ranges + link-local.
  static bool _isPrivateIpv4(InternetAddress addr) {
    if (addr.type != InternetAddressType.IPv4) return false;
    final bytes = addr.rawAddress;
    if (bytes.length != 4) return false;

    final b0 = bytes[0];
    final b1 = bytes[1];

    return b0 == 10 || // 10.0.0.0/8
        (b0 == 172 && b1 >= 16 && b1 <= 31) || // 172.16-31.x.x/12
        (b0 == 192 && b1 == 168) || // 192.168.x.x/16
        (b0 == 169 && b1 == 254); // 169.254.x.x link-local
  }

  /// Checks whether [serverAddr] is in the same /24 subnet as [localAddr].
  ///
  /// /24 is a practical default because most home and office routers assign
  /// addresses in a single /24 block. A tighter check using the actual
  /// prefix length would require parsing the system routing table — not
  /// portable across Android / iOS / desktop.
  static bool _sameSubnet(
    InternetAddress localAddr,
    InternetAddress serverAddr,
  ) {
    if (localAddr.type != InternetAddressType.IPv4) return false;
    if (serverAddr.type != InternetAddressType.IPv4) return false;

    final l = localAddr.rawAddress;
    final s = serverAddr.rawAddress;
    if (l.length != 4 || s.length != 4) return false;

    return l[0] == s[0] && l[1] == s[1] && l[2] == s[2];
  }
}

/// Signature for the LAN-vs-WAN decision used by [ApiClient].
///
/// Default implementation is [NetworkPathDetector.isLan]. Tests pass a
/// mock function to drive the dual-base resolution deterministically.
typedef LanCheck = Future<bool> Function(String serverUrl);
