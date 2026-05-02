import 'package:fluxora_core/entities/transcoding_status.dart';

abstract class TranscodingRepository {
  Future<TranscodingStatus> status();
}
