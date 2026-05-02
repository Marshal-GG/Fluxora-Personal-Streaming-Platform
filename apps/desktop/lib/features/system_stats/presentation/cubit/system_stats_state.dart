part of 'system_stats_cubit.dart';

/// Latest system stats + a ring buffer of recent CPU/RAM/network samples
/// driving the sparklines.
///
/// The cubit holds the last [SystemStatsState.maxSamples] samples; new
/// ticks shift older entries out the front. `latest` is `null` until the
/// first poll lands.
class SystemStatsState extends Equatable {
  const SystemStatsState({
    this.latest,
    this.cpuSamples = const [],
    this.ramSamples = const [],
    this.netInSamples = const [],
    this.netOutSamples = const [],
    this.errorMessage,
  });

  static const int maxSamples = 30;

  final SystemStats? latest;
  final List<double> cpuSamples;
  final List<double> ramSamples;
  final List<double> netInSamples;
  final List<double> netOutSamples;
  final String? errorMessage;

  bool get isReady => latest != null;

  SystemStatsState pushSample(SystemStats sample) {
    return SystemStatsState(
      latest: sample,
      cpuSamples: _appendCapped(cpuSamples, sample.cpuPercent),
      ramSamples: _appendCapped(ramSamples, sample.ramPercent),
      netInSamples: _appendCapped(netInSamples, sample.networkInMbps),
      netOutSamples: _appendCapped(netOutSamples, sample.networkOutMbps),
    );
  }

  SystemStatsState withError(String message) {
    return SystemStatsState(
      latest: latest,
      cpuSamples: cpuSamples,
      ramSamples: ramSamples,
      netInSamples: netInSamples,
      netOutSamples: netOutSamples,
      errorMessage: message,
    );
  }

  static List<double> _appendCapped(List<double> existing, double next) {
    final updated = [...existing, next];
    if (updated.length > maxSamples) {
      return updated.sublist(updated.length - maxSamples);
    }
    return updated;
  }

  @override
  List<Object?> get props => [
        latest,
        cpuSamples,
        ramSamples,
        netInSamples,
        netOutSamples,
        errorMessage,
      ];
}
