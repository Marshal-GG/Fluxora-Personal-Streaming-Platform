part of 'activity_cubit.dart';

@freezed
abstract class ActivityState with _$ActivityState {
  const factory ActivityState.initial() = _Initial;
  const factory ActivityState.loading() = _Loading;
  const factory ActivityState.loaded(List<StreamSession> sessions) = _Loaded;
  const factory ActivityState.error(String message) = _Error;
}
