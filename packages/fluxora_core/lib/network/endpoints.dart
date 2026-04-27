class Endpoints {
  Endpoints._();

  static const String _base = '/api/v1';

  // Info
  static const String info = '$_base/info';

  // Auth
  static const String requestPair = '$_base/auth/request-pair';
  static String authStatus(String clientId) =>
      '$_base/auth/status/$clientId';

  // Files
  static const String files = '$_base/files';

  // Library
  static const String library = '$_base/library';
  static const String libraryScan = '$_base/library/scan';

  // Stream
  static String stream(String fileId) => '$_base/stream/$fileId';

  // HLS
  static String hlsPlaylist(String sessionId) =>
      '$_base/hls/$sessionId/playlist.m3u8';
  static String hlsSegment(String sessionId, String segment) =>
      '$_base/hls/$sessionId/$segment.ts';

  // WebSocket
  static const String wsSignal = '$_base/ws/signal';
  static const String wsStatus = '$_base/ws/status';
}
