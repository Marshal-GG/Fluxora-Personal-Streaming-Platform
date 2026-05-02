// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SystemStats _$SystemStatsFromJson(Map<String, dynamic> json) => _SystemStats(
  uptimeSeconds: (json['uptime_seconds'] as num).toInt(),
  lanIp: json['lan_ip'] as String?,
  publicAddress: json['public_address'] as String?,
  internetConnected: json['internet_connected'] as bool,
  cpuPercent: (json['cpu_percent'] as num).toDouble(),
  ramPercent: (json['ram_percent'] as num).toDouble(),
  ramUsedBytes: (json['ram_used_bytes'] as num).toInt(),
  ramTotalBytes: (json['ram_total_bytes'] as num).toInt(),
  networkInMbps: (json['network_in_mbps'] as num).toDouble(),
  networkOutMbps: (json['network_out_mbps'] as num).toDouble(),
  activeStreams: (json['active_streams'] as num).toInt(),
);

Map<String, dynamic> _$SystemStatsToJson(_SystemStats instance) =>
    <String, dynamic>{
      'uptime_seconds': instance.uptimeSeconds,
      'lan_ip': instance.lanIp,
      'public_address': instance.publicAddress,
      'internet_connected': instance.internetConnected,
      'cpu_percent': instance.cpuPercent,
      'ram_percent': instance.ramPercent,
      'ram_used_bytes': instance.ramUsedBytes,
      'ram_total_bytes': instance.ramTotalBytes,
      'network_in_mbps': instance.networkInMbps,
      'network_out_mbps': instance.networkOutMbps,
      'active_streams': instance.activeStreams,
    };
