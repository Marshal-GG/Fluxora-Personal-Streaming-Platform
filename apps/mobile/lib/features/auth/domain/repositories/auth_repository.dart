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

  /// `DELETE /api/v1/auth/clients/me` — self-revoke.  Server flips the
  /// calling client to `status='rejected'` + zeroes its `auth_token`
  /// so the bearer token stops working server-side immediately.  The
  /// mobile sign-out flow calls this *before* clearing local state so
  /// a stolen-and-not-yet-cleared token can't outlive the user's tap.
  /// Mobile redesign audit §17.3 #3.
  Future<void> revokeMe();

  /// `PATCH /api/v1/auth/clients/me` — self-rename.  Body
  /// `{display_name}`; server validates length 1–50 + rejects
  /// blank-after-trim + control characters.  Returns the fresh
  /// [ClientProfile] (same shape as [getMe]) so the Account screen
  /// can refresh without a follow-up GET.  Throws [ApiException] on
  /// 422 (invalid body) or 401 (missing/invalid bearer).  Mobile
  /// settings remediation plan §M2 (M2.5 server endpoint).
  Future<ClientProfile> updateMe({required String displayName});
}

class PairRejectedException implements Exception {
  const PairRejectedException();
}
