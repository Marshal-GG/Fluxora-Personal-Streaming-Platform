// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encoder_advice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EncoderAdvice _$EncoderAdviceFromJson(Map<String, dynamic> json) =>
    _EncoderAdvice(
      recommendedEncoder: json['recommended_encoder'] as String?,
      reasonCode: json['reason_code'] as String,
      reasonText: json['reason_text'] as String,
      severity: json['severity'] as String,
    );

Map<String, dynamic> _$EncoderAdviceToJson(_EncoderAdvice instance) =>
    <String, dynamic>{
      'recommended_encoder': instance.recommendedEncoder,
      'reason_code': instance.reasonCode,
      'reason_text': instance.reasonText,
      'severity': instance.severity,
    };
