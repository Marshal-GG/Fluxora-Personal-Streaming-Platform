// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encoder_benchmark.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EncoderBenchmarkResult _$EncoderBenchmarkResultFromJson(
  Map<String, dynamic> json,
) => _EncoderBenchmarkResult(
  encoder: json['encoder'] as String,
  vendor: json['vendor'] as String,
  codec: json['codec'] as String,
  passed: json['passed'] as bool,
  error: json['error'] as String?,
  fps: (json['fps'] as num?)?.toDouble(),
  speedX: (json['speed_x'] as num?)?.toDouble(),
  bitrateKbps: (json['bitrate_kbps'] as num?)?.toDouble(),
  encodedFrames: (json['encoded_frames'] as num?)?.toInt(),
  elapsedSec: (json['elapsed_sec'] as num?)?.toDouble(),
  realtimeMultiplier: (json['realtime_multiplier'] as num?)?.toDouble(),
  initMs: (json['init_ms'] as num?)?.toInt(),
  gpuUtilizationPercent: (json['gpu_utilization_percent'] as num?)?.toDouble(),
  vramUsedMb: (json['vram_used_mb'] as num?)?.toInt(),
  concurrentSessionCap: (json['concurrent_session_cap'] as num?)?.toInt(),
  recommendedConcurrent: (json['recommended_concurrent'] as num?)?.toInt(),
  verifiedConcurrent: (json['verified_concurrent'] as num?)?.toInt(),
);

Map<String, dynamic> _$EncoderBenchmarkResultToJson(
  _EncoderBenchmarkResult instance,
) => <String, dynamic>{
  'encoder': instance.encoder,
  'vendor': instance.vendor,
  'codec': instance.codec,
  'passed': instance.passed,
  'error': instance.error,
  'fps': instance.fps,
  'speed_x': instance.speedX,
  'bitrate_kbps': instance.bitrateKbps,
  'encoded_frames': instance.encodedFrames,
  'elapsed_sec': instance.elapsedSec,
  'realtime_multiplier': instance.realtimeMultiplier,
  'init_ms': instance.initMs,
  'gpu_utilization_percent': instance.gpuUtilizationPercent,
  'vram_used_mb': instance.vramUsedMb,
  'concurrent_session_cap': instance.concurrentSessionCap,
  'recommended_concurrent': instance.recommendedConcurrent,
  'verified_concurrent': instance.verifiedConcurrent,
};

_EncoderBenchmarkRun _$EncoderBenchmarkRunFromJson(Map<String, dynamic> json) =>
    _EncoderBenchmarkRun(
      id: (json['id'] as num).toInt(),
      startedAt: json['started_at'] as String,
      finishedAt: json['finished_at'] as String,
      durationSec: (json['duration_sec'] as num).toInt(),
      fps: (json['fps'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      verifyCaps: json['verify_caps'] as bool,
      results: (json['results'] as List<dynamic>)
          .map(
            (e) => EncoderBenchmarkResult.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$EncoderBenchmarkRunToJson(
  _EncoderBenchmarkRun instance,
) => <String, dynamic>{
  'id': instance.id,
  'started_at': instance.startedAt,
  'finished_at': instance.finishedAt,
  'duration_sec': instance.durationSec,
  'fps': instance.fps,
  'width': instance.width,
  'height': instance.height,
  'verify_caps': instance.verifyCaps,
  'results': instance.results.map((e) => e.toJson()).toList(),
};

_BenchmarkHistoryEntry _$BenchmarkHistoryEntryFromJson(
  Map<String, dynamic> json,
) => _BenchmarkHistoryEntry(
  id: (json['id'] as num).toInt(),
  startedAt: json['started_at'] as String,
  finishedAt: json['finished_at'] as String,
  durationSec: (json['duration_sec'] as num).toInt(),
  fps: (json['fps'] as num).toInt(),
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  verifyCaps: json['verify_caps'] as bool,
  encoderCount: (json['encoder_count'] as num).toInt(),
);

Map<String, dynamic> _$BenchmarkHistoryEntryToJson(
  _BenchmarkHistoryEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'started_at': instance.startedAt,
  'finished_at': instance.finishedAt,
  'duration_sec': instance.durationSec,
  'fps': instance.fps,
  'width': instance.width,
  'height': instance.height,
  'verify_caps': instance.verifyCaps,
  'encoder_count': instance.encoderCount,
};

_BenchmarkHistory _$BenchmarkHistoryFromJson(Map<String, dynamic> json) =>
    _BenchmarkHistory(
      entries: (json['entries'] as List<dynamic>)
          .map((e) => BenchmarkHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BenchmarkHistoryToJson(_BenchmarkHistory instance) =>
    <String, dynamic>{
      'entries': instance.entries.map((e) => e.toJson()).toList(),
    };

_BenchmarkProgress _$BenchmarkProgressFromJson(Map<String, dynamic> json) =>
    _BenchmarkProgress(
      running: json['running'] as bool,
      startedAt: json['started_at'] as String?,
      totalEncoders: (json['total_encoders'] as num?)?.toInt(),
      completed: (json['completed'] as num?)?.toInt(),
      currentEncoder: json['current_encoder'] as String?,
      currentStep: json['current_step'] as String?,
      currentIndex: (json['current_index'] as num?)?.toInt(),
    );

Map<String, dynamic> _$BenchmarkProgressToJson(_BenchmarkProgress instance) =>
    <String, dynamic>{
      'running': instance.running,
      'started_at': instance.startedAt,
      'total_encoders': instance.totalEncoders,
      'completed': instance.completed,
      'current_encoder': instance.currentEncoder,
      'current_step': instance.currentStep,
      'current_index': instance.currentIndex,
    };
