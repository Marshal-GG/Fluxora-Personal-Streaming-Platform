class Endpoints {
  Endpoints._();

  static const String _base = '/api/v1';

  // Info
  static const String info = '$_base/info';
  static const String logs = '$_base/logs';
  static const String healthz = '$_base/healthz';
  static const String infoStats = '$_base/info/stats';
  static const String infoRestart = '$_base/info/restart';
  static const String infoStop = '$_base/info/stop';
  static const String infoSupportBundle = '$_base/info/support-bundle';
  static const String libraryStorageBreakdown = '$_base/library/storage-breakdown';

  // Auth
  static const String requestPair = '$_base/auth/request-pair';
  static String authStatus(String clientId) =>
      '$_base/auth/status/$clientId';
  static const String authClients = '$_base/auth/clients';
  static const String authClientsMe = '$_base/auth/clients/me';
  static const String authClientsMeStats = '$_base/auth/clients/me/stats';
  static const String authClientsMeContinueWatching =
      '$_base/auth/clients/me/continue-watching';
  static String authApprove(String clientId) =>
      '$_base/auth/approve/$clientId';
  static String authReject(String clientId) =>
      '$_base/auth/reject/$clientId';
  static String authRevoke(String clientId) =>
      '$_base/auth/revoke/$clientId';

  // Files
  static const String files = '$_base/files';
  static const String filesRecent = '$_base/files/recent';
  static const String filesSearch = '$_base/files/search';
  static String fileById(String fileId) => '$_base/files/$fileId';

  /// `POST /api/v1/files/{fileId}/reset-progress` — zero out the file's
  /// `last_progress_sec` (streaming pipeline plan §4.10).
  static String fileResetProgress(String fileId) =>
      '$_base/files/$fileId/reset-progress';

  // Library
  static const String library = '$_base/library';
  static const String libraryScan = '$_base/library/scan';
  static String libraryEnrichTmdb(String libraryId) =>
      '$_base/library/$libraryId/enrich-tmdb';
  static String libraryRegenerateThumbnails(String libraryId) =>
      '$_base/library/$libraryId/regenerate-thumbnails';
  static String libraryBrowse(String libraryId) =>
      '$_base/library/$libraryId/browse';

  /// `POST /api/v1/library/{libraryId}/index-file?path=<relative>` —
  /// index a single file by its `<root>/<relative>` path.  Backs the
  /// folder-browser right-click "Index this file" action.
  static String libraryIndexFile(String libraryId) =>
      '$_base/library/$libraryId/index-file';

  /// `POST /api/v1/library/{libraryId}/scan-subtree?path=<relative>` —
  /// rescan a single subdir under one of the library's root_paths.
  static String libraryScanSubtree(String libraryId) =>
      '$_base/library/$libraryId/scan-subtree';

  /// `POST /api/v1/files/{fileId}/regenerate-thumbnail` — per-file
  /// thumbnail regenerate (priority=10).  Right-click "Generate
  /// thumbnail" action.
  static String fileRegenerateThumbnail(String fileId) =>
      '$_base/files/$fileId/regenerate-thumbnail';

  // Stream
  static String streamStart(String fileId) => '$_base/stream/start/$fileId';
  static String streamSession(String sessionId) => '$_base/stream/$sessionId';
  static String streamProgress(String sessionId) =>
      '$_base/stream/$sessionId/progress';
  static String streamSeek(String sessionId) =>
      '$_base/stream/$sessionId/seek';

  // HLS
  static String hlsPlaylist(String sessionId) =>
      '$_base/hls/$sessionId/playlist.m3u8';
  static String hlsSegment(String sessionId, String segment) =>
      '$_base/hls/$sessionId/$segment.ts';

  // Settings (localhost-only)
  static const String serverSettings = '$_base/settings';

  // Orders / license keys (localhost-only, owner retrieval)
  static const String orders = '$_base/orders';

  // Activity event log
  static const String activity = '$_base/activity';

  // Groups
  static const String groups = '$_base/groups';
  static String groupById(String id) => '$_base/groups/$id';
  static String groupMembers(String id) => '$_base/groups/$id/members';
  static String groupMember(String groupId, String clientId) =>
      '$_base/groups/$groupId/members/$clientId';
  // M8 — clear a member's per-client PIN enrollment (operator action,
  // localhost-only on the server).  Forces re-enrollment on next access.
  static String groupMemberPin(String groupId, String clientId) =>
      '$_base/groups/$groupId/members/$clientId/pin';
  // M5 of `14_groups_management_page.md` — operator "View as" debug.
  // Localhost-only on the server.
  static String authClientVisibleLibraries(String clientId) =>
      '$_base/auth/clients/$clientId/visible-libraries';
  // M7 follow-up — bulk drop every active PIN grant for a group
  // (shared-mode "Reset all PINs" Danger Zone action).  Localhost-only.
  static String groupGrantsReset(String groupId) =>
      '$_base/groups/$groupId/grants/reset';

  // Mobile PIN-flow endpoints (M4 + M8 of
  // `13_groups_v2_content_spaces.md`).  Bearer-token only — the calling
  // client is the grant subject; operator-side master-override is a
  // separate localhost route.
  static String groupEnter(String groupId) =>
      '$_base/groups/$groupId/enter';
  static String groupEnroll(String groupId) =>
      '$_base/groups/$groupId/enroll';
  static String groupEnrollChange(String groupId) =>
      '$_base/groups/$groupId/enroll/change';
  static String groupGrant(String groupId) =>
      '$_base/groups/$groupId/grant';
  static String groupGrantStatus(String groupId) =>
      '$_base/groups/$groupId/grant-status';
  // Mobile-side "what does my client see right now" — same VisibleLibraries
  // shape the desktop View As tab uses, but scoped to the calling
  // client (no `client_id` path segment, the bearer identity drives it).
  // M6 of `13_groups_v2_content_spaces.md` Profile-screen polish.
  static const String authClientsMeVisibleLibraries =
      '$_base/auth/clients/me/visible-libraries';

  // Transcoding status
  static const String transcodingStatus = '$_base/transcoding/status';
  static const String transcodingAdvisor = '$_base/transcoding/advisor';
  static const String transcodingDevices = '$_base/transcoding/devices';
  static const String transcodingFallbackHistory =
      '$_base/transcoding/fallback-history';
  static const String transcodingBenchmark = '$_base/transcoding/benchmark';
  static const String transcodingBenchmarkProgress =
      '$_base/transcoding/benchmark/progress';
  static const String transcodingBenchmarkHistory =
      '$_base/transcoding/benchmark/history';
  static String transcodingBenchmarkHistoryEntry(int id) =>
      '$_base/transcoding/benchmark/history/$id';

  // Profile
  static const String profile = '$_base/profile';

  // Notifications
  static const String notifications = '$_base/notifications';
  static String notificationRead(String id) =>
      '$_base/notifications/$id/read';
  static const String notificationsReadAll = '$_base/notifications/read-all';
  static String notificationDismiss(String id) => '$_base/notifications/$id';

  // Orders portal URL
  static const String ordersPortalUrl = '$_base/orders/portal-url';

  // WebSocket
  static const String wsSignal = '$_base/ws/signal';
  static const String wsStatus = '$_base/ws/status';
  static const String wsNotifications = '$_base/ws/notifications';
}
