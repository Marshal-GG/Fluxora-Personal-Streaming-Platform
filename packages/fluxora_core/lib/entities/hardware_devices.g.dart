// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hardware_devices.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CpuInfo _$CpuInfoFromJson(Map<String, dynamic> json) => _CpuInfo(
  vendor: json['vendor'] as String,
  model: json['model'] as String,
  threads: (json['threads'] as num).toInt(),
);

Map<String, dynamic> _$CpuInfoToJson(_CpuInfo instance) => <String, dynamic>{
  'vendor': instance.vendor,
  'model': instance.model,
  'threads': instance.threads,
};

_GpuInfo _$GpuInfoFromJson(Map<String, dynamic> json) => _GpuInfo(
  vendor: json['vendor'] as String,
  model: json['model'] as String,
  vramMb: (json['vram_mb'] as num?)?.toInt(),
  driverVersion: json['driver_version'] as String?,
  devPath: json['dev_path'] as String?,
  encoderSupport:
      (json['encoder_support'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$GpuInfoToJson(_GpuInfo instance) => <String, dynamic>{
  'vendor': instance.vendor,
  'model': instance.model,
  'vram_mb': instance.vramMb,
  'driver_version': instance.driverVersion,
  'dev_path': instance.devPath,
  'encoder_support': instance.encoderSupport,
};

_HardwareDevices _$HardwareDevicesFromJson(Map<String, dynamic> json) =>
    _HardwareDevices(
      cpus:
          (json['cpus'] as List<dynamic>?)
              ?.map((e) => CpuInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      gpus:
          (json['gpus'] as List<dynamic>?)
              ?.map((e) => GpuInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$HardwareDevicesToJson(_HardwareDevices instance) =>
    <String, dynamic>{
      'cpus': instance.cpus.map((e) => e.toJson()).toList(),
      'gpus': instance.gpus.map((e) => e.toJson()).toList(),
    };
