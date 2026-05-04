// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClientStats _$ClientStatsFromJson(Map<String, dynamic> json) => _ClientStats(
  hours: (json['hours'] as num).toInt(),
  movies: (json['movies'] as num).toInt(),
  shows: (json['shows'] as num).toInt(),
);

Map<String, dynamic> _$ClientStatsToJson(_ClientStats instance) =>
    <String, dynamic>{
      'hours': instance.hours,
      'movies': instance.movies,
      'shows': instance.shows,
    };
