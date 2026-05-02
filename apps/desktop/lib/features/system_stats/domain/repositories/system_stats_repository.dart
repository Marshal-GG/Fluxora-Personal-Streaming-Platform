import 'package:fluxora_core/entities/system_stats.dart';

abstract class SystemStatsRepository {
  Future<SystemStats> fetch();
}
