/// State for the upgrade cubit — plain sealed class, no code-gen needed.
library;

enum LicenseSubmitStatus { idle, loading, success, error }

class UpgradeState {
  const UpgradeState({
    this.licenseKey = '',
    this.status = LicenseSubmitStatus.idle,
    this.errorMessage = '',
    this.activatedTier,
  });

  final String licenseKey;
  final LicenseSubmitStatus status;
  final String errorMessage;

  /// The tier returned by the server after a successful key activation.
  final String? activatedTier;

  UpgradeState copyWith({
    String? licenseKey,
    LicenseSubmitStatus? status,
    String? errorMessage,
    String? activatedTier,
  }) {
    return UpgradeState(
      licenseKey: licenseKey ?? this.licenseKey,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      activatedTier: activatedTier ?? this.activatedTier,
    );
  }
}
