import 'package:fluxora_core/entities/client_profile.dart';

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
}

class PairRejectedException implements Exception {
  const PairRejectedException();
}
