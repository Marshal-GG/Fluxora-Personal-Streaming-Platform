/// Cubit backing the Profile tab header (display name + email + tier).
///
/// Phase A backfill: replaces the hardcoded "Alex Kowalski" / "alex@fluxora.io"
/// / "PLUS MEMBER" trio.  Stats row (Hours / Movies / Shows) stays empty-
/// stated until Phase B's `/clients/me/stats`.  Singleton-scoped in
/// GetIt so re-entries to the Profile tab don't refetch on every nav.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/client_profile.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.profile);
  final ClientProfile profile;
}

class ProfileFailure extends ProfileState {
  const ProfileFailure(this.message);
  final String message;
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required AuthRepository repository})
      : _repository = repository,
        super(const ProfileInitial());

  final AuthRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    if (state is ProfileLoading) return;
    emit(const ProfileLoading());
    await _fetch();
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    try {
      final profile = await _repository.getMe();
      emit(ProfileLoaded(profile));
    } on ApiException catch (e, st) {
      _log.e('Profile load failed', error: e, stackTrace: st);
      emit(ProfileFailure(e.message));
    } catch (e, st) {
      _log.e('Profile unexpected error', error: e, stackTrace: st);
      emit(const ProfileFailure('Could not load your profile.'));
    }
  }

  @override
  void emit(ProfileState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
