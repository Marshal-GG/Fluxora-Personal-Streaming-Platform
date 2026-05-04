import 'package:freezed_annotation/freezed_annotation.dart';

part 'encoder_advice.freezed.dart';
part 'encoder_advice.g.dart';

/// One advisor recommendation for the operator's current encoder choice.
///
/// `reasonCode == 'none'` means "no banner — the operator's choice is fine."
/// `severity` drives the banner colour (`info` = neutral nudge,
/// `warning` = "you're on a broken encoder, fix this").
@freezed
abstract class EncoderAdvice with _$EncoderAdvice {
  const factory EncoderAdvice({
    String? recommendedEncoder,
    required String reasonCode,
    required String reasonText,
    required String severity,
  }) = _EncoderAdvice;

  factory EncoderAdvice.fromJson(Map<String, dynamic> json) =>
      _$EncoderAdviceFromJson(json);
}
