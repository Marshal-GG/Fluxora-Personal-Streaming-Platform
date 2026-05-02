import 'package:fluxora_core/entities/activity_event.dart';

sealed class RecentActivityState {
  const RecentActivityState();
}

class RecentActivityInitial extends RecentActivityState {
  const RecentActivityInitial();
}

class RecentActivityLoading extends RecentActivityState {
  const RecentActivityLoading();
}

class RecentActivityLoaded extends RecentActivityState {
  const RecentActivityLoaded(this.events);

  final List<ActivityEvent> events;
}

class RecentActivityFailure extends RecentActivityState {
  const RecentActivityFailure(this.message);

  final String message;
}
