abstract class AuthRepository {
  Future<void> requestPair({
    required String clientId,
    required String deviceName,
    required String platform,
    required String appVersion,
  });

  /// Returns the auth token when approved, null when still pending.
  /// Throws [PairRejectedException] when the server rejects the request.
  Future<String?> pollStatus(String clientId);

  Future<void> saveCredentials({
    required String serverUrl,
    required String authToken,
    required String clientId,
  });
}

class PairRejectedException implements Exception {
  const PairRejectedException();
}
