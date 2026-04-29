class Endpoints {
  Endpoints._();

  static const String _base = '/api/v1';

  // Info
  static const String info = '$_base/info';

  // Auth
  static const String requestPair = '$_base/auth/request-pair';
  static String authStatus(String clientId) =>
      '$_base/auth/status/$clientId';
  static const String authClients = '$_base/auth/clients';
  static String authApprove(String clientId) =>
      '$_base/auth/approve/$clientId';
  static String authReject(String clientId) =>
      '$_base/auth/reject/$clientId';
  static String authRevoke(String clientId) =>
      '$_base/auth/revoke/$clientId';

  // Files
  static const String files = '$_base/files';

  // Library
  static const String library = '$_base/library';
  static const String libraryScan = '$_base/library/scan';

  // Stream
  static String streamStart(String fileId) => '$_base/stream/start/$fileId';
  static String streamSession(String sessionId) => '$_base/stream/$sessionId';
  static String streamProgress(String sessionId) =>
      '$_base/stream/$sessionId/progress';

  // HLS
  static String hlsPlaylist(String sessionId) =>
      '$_base/hls/$sessionId/playlist.m3u8';
  static String hlsSegment(String sessionId, String segment) =>
      '$_base/hls/$sessionId/$segment.ts';

  // Settings (localhost-only)
  static const String serverSettings = '$_base/settings';

  // Orders / license keys (localhost-only, owner retrieval)
  static const String orders = '$_base/orders';

  // WebSocket
  static const String wsSignal = '$_base/ws/signal';
  static const String wsStatus = '$_base/ws/status';
}
