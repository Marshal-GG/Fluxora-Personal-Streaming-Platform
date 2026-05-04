import 'package:fluxora_core/entities/client_profile.dart';
import 'package:fluxora_core/entities/client_stats.dart';

abstract class AuthRepository {
  Future<void> requestPair({
    required String clientId,
    required String deviceName,
    required String platform,
    required String appVersion,
    String? email,
  });

  /// Returns the auth token when approved, null when still pending.
  /// Throws [PairRejectedException] when the server rejects the request.
  Future<String?> pollStatus(String clientId);

  Future<void> saveCredentials({
    required String serverUrl,
    required String authToken,
    required String clientId,
  });

  /// `GET /api/v1/auth/clients/me` — calling client's own profile.
  /// Backs the mobile Profile tab (Phase A backfill).
  Future<ClientProfile> getMe();

  /// `GET /api/v1/auth/clients/me/stats` — per-client watch stats
  /// (Phase B backfill plan §3 row 3).  Returns `{hours, movies, shows}`
  /// aggregated from `stream_sessions` + `media_files` for the calling
  /// client.  All three values degrade gracefully — a fresh client
  /// returns `{0, 0, 0}` rather than 404.
  Future<ClientStats> getMyStats();
}

class PairRejectedException implements Exception {
  const PairRejectedException();
}
