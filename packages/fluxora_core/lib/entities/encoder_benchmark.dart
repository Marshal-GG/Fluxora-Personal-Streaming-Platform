import 'package:freezed_annotation/freezed_annotation.dart';

part 'encoder_benchmark.freezed.dart';
part 'encoder_benchmark.g.dart';

/// Per-encoder result from `POST /api/v1/transcoding/benchmark`.
///
/// `passed=false` rows still carry [error] (and possibly [elapsedSec] when the
/// failure was a timeout).  Perf fields are null on failure; the registry-
/// derived [vendor] / [codec] / [concurrentSessionCap] are populated even on
/// failure so the UI can still group + label the row.
///
/// [realtimeMultiplier] = source duration / wall-clock elapsed.  Values > 1
/// mean the encoder runs faster than realtime (i.e. could drive a live stream
/// at the source rate); values < 1 mean the encoder would underrun.
///
/// [initMs] is wall-clock from FFmpeg spawn to first encoded frame — the
/// operator's "stream-start latency" budget.  Includes CUDA context init,
/// encoder session creation, hwaccel device probe etc.
///
/// [gpuUtilizationPercent] + [vramUsedMb] are sampled once at the midpoint
/// of the run via the same per-vendor probes the live status panel uses.
/// Null for software encoders, on probe-binary-missing systems, or on
/// probe failure.
///
/// [concurrentSessionCap] mirrors the registry value (NVENC consumer cards
/// = 3; software/QSV/VAAPI/VideoToolbox have no enforced cap).  Treat it as
/// a vendor-documented default — driver 530+ removed the consumer NVENC cap
/// on RTX 40-series, and community patches lift it on older cards.
///
/// [verifiedConcurrent] is the empirical answer from the cap-probe.  Only
/// populated when the request set `verify_caps=true` AND the encoder has a
/// registry cap to verify.  When present, [recommendedConcurrent] above was
/// re-derived against this number rather than the registry default.
///
/// [recommendedConcurrent] is `min(effective_cap, floor(speed_x))` — the
/// practical "how many streams can I sustain at realtime" answer the UI
/// surfaces as a chip per row.
@freezed
abstract class EncoderBenchmarkResult with _$EncoderBenchmarkResult {
  const factory EncoderBenchmarkResult({
    required String encoder,
    required String vendor,
    required String codec,
    required bool passed,
    String? error,
    double? fps,
    double? speedX,
    double? bitrateKbps,
    int? encodedFrames,
    double? elapsedSec,
    double? realtimeMultiplier,
    int? initMs,
    double? gpuUtilizationPercent,
    int? vramUsedMb,
    int? concurrentSessionCap,
    int? recommendedConcurrent,
    int? verifiedConcurrent,
  }) = _EncoderBenchmarkResult;

  factory EncoderBenchmarkResult.fromJson(Map<String, dynamic> json) =>
      _$EncoderBenchmarkResultFromJson(json);
}

/// Top-level benchmark response.  [results] is one row per encoder the server
/// detected as available, in the same order the server walked them.
///
/// [fps], [width], [height] echo the source workload the server actually used
/// (after the router clamp + resolution-tier snap) so the desktop can label
/// the result set + the cached history with the workload that produced the
/// numbers.  [verifyCaps] echoes whether the cap probe ran.
@freezed
abstract class EncoderBenchmarkRun with _$EncoderBenchmarkRun {
  const factory EncoderBenchmarkRun({
    /// Autoincrement id from the server's ``benchmark_runs`` table.  The
    /// desktop uses it to keep the visible "current run" highlighted in
    /// the history sidebar + to fetch / delete the run by id.
    required int id,
    required String startedAt,
    required String finishedAt,
    required int durationSec,
    required int fps,
    required int width,
    required int height,
    required bool verifyCaps,
    required List<EncoderBenchmarkResult> results,
  }) = _EncoderBenchmarkRun;

  factory EncoderBenchmarkRun.fromJson(Map<String, dynamic> json) =>
      _$EncoderBenchmarkRunFromJson(json);
}

/// One row in the benchmark history sidebar — summary only, no per-encoder
/// results.  Clicking a row triggers ``TranscodingRepository.benchmarkHistoryEntry``
/// to fetch the full body and render it in the main results pane.
///
/// Mirrors the server-side ``BenchmarkHistoryEntry`` Pydantic shape.
@freezed
abstract class BenchmarkHistoryEntry with _$BenchmarkHistoryEntry {
  const factory BenchmarkHistoryEntry({
    required int id,
    required String startedAt,
    required String finishedAt,
    required int durationSec,
    required int fps,
    required int width,
    required int height,
    required bool verifyCaps,
    required int encoderCount,
  }) = _BenchmarkHistoryEntry;

  factory BenchmarkHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$BenchmarkHistoryEntryFromJson(json);
}

/// List response wrapping the history entries.  Matches the server's
/// ``BenchmarkHistoryResponse``.
@freezed
abstract class BenchmarkHistory with _$BenchmarkHistory {
  const factory BenchmarkHistory({
    required List<BenchmarkHistoryEntry> entries,
  }) = _BenchmarkHistory;

  factory BenchmarkHistory.fromJson(Map<String, dynamic> json) =>
      _$BenchmarkHistoryFromJson(json);
}

/// Live progress snapshot for an in-flight benchmark run.
///
/// `running=false` is the idle state — every other field is null.  The
/// desktop polls `TranscodingRepository.benchmarkProgress` every ~500 ms
/// while its own POST is in flight so the operator sees per-encoder
/// status instead of a featureless "Running…" spinner for a minute.
///
/// `currentStep` values: `"starting"` (between trigger and first encoder
/// spawn), `"encoding"` (running the main per-encoder benchmark), or
/// `"verifying_cap"` (running the concurrent-stress probe for an hw
/// encoder that carries a registry session cap).
@freezed
abstract class BenchmarkProgress with _$BenchmarkProgress {
  const factory BenchmarkProgress({
    required bool running,
    String? startedAt,
    int? totalEncoders,
    int? completed,
    String? currentEncoder,
    String? currentStep,
    int? currentIndex,
  }) = _BenchmarkProgress;

  factory BenchmarkProgress.fromJson(Map<String, dynamic> json) =>
      _$BenchmarkProgressFromJson(json);
}
