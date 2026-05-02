import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/profile/domain/repositories/profile_repository.dart';
import 'package:fluxora_desktop/features/profile/presentation/cubit/profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required ProfileRepository repository})
      : _repository = repository,
        super(const ProfileInitial());

  final ProfileRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    emit(const ProfileLoading());
    try {
      final profile = await _repository.get();
      emit(ProfileLoaded(profile: profile));
    } on ApiException catch (e, st) {
      _log.e('Profile load failed', error: e, stackTrace: st);
      emit(ProfileFailure(e.message));
    } catch (e, st) {
      _log.e('Profile load failed', error: e, stackTrace: st);
      emit(const ProfileFailure('Unable to reach server.'));
    }
  }

  Future<void> save({String? displayName, String? email}) async {
    final current = state;
    if (current is! ProfileLoaded) return;
    emit(ProfileSaving(profile: current.profile));
    try {
      final updated =
          await _repository.update(displayName: displayName, email: email);
      emit(ProfileLoaded(profile: updated));
    } on ApiException catch (e, st) {
      _log.e('Profile save failed', error: e, stackTrace: st);
      emit(ProfileLoaded(profile: current.profile, dirty: true));
    } catch (e, st) {
      _log.e('Profile save failed', error: e, stackTrace: st);
      emit(ProfileLoaded(profile: current.profile, dirty: true));
    }
  }

  void markDirty() {
    final current = state;
    if (current is ProfileLoaded && !current.dirty) {
      emit(ProfileLoaded(profile: current.profile, dirty: true));
    }
  }
}
