import 'package:fluxora_core/entities/activity_event.dart';

abstract class RecentActivityRepository {
  Future<List<ActivityEvent>> fetch({int limit = 4});
}
