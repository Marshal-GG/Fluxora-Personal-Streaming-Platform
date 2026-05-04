import 'package:freezed_annotation/freezed_annotation.dart';

part 'hardware_devices.freezed.dart';
part 'hardware_devices.g.dart';

/// CPU info from `/api/v1/transcoding/devices`.
@freezed
abstract class CpuInfo with _$CpuInfo {
  const factory CpuInfo({
    required String vendor,
    required String model,
    required int threads,
  }) = _CpuInfo;

  factory CpuInfo.fromJson(Map<String, dynamic> json) =>
      _$CpuInfoFromJson(json);
}

/// One detected GPU + the encoders FFmpeg *could* drive on this OS.
///
/// Pair with `TranscodingStatus.availableEncoders` to know what *actually*
/// works — `encoderSupport` is registry-derived (vendor + platform), not
/// probed.
@freezed
abstract class GpuInfo with _$GpuInfo {
  const factory GpuInfo({
    required String vendor, // nvidia | intel | amd | apple | unknown
    required String model,
    int? vramMb,
    String? driverVersion,
    /// VAAPI render-node path on Linux; null on other platforms.
    String? devPath,
    @Default([]) List<String> encoderSupport,
  }) = _GpuInfo;

  factory GpuInfo.fromJson(Map<String, dynamic> json) =>
      _$GpuInfoFromJson(json);
}

@freezed
abstract class HardwareDevices with _$HardwareDevices {
  const factory HardwareDevices({
    @Default([]) List<CpuInfo> cpus,
    @Default([]) List<GpuInfo> gpus,
  }) = _HardwareDevices;

  factory HardwareDevices.fromJson(Map<String, dynamic> json) =>
      _$HardwareDevicesFromJson(json);
}
