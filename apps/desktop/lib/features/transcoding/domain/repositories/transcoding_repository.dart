import 'package:fluxora_core/entities/encoder_advice.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';

abstract class TranscodingRepository {
  Future<TranscodingStatus> status();
  Future<EncoderAdvice> advisor();
}
