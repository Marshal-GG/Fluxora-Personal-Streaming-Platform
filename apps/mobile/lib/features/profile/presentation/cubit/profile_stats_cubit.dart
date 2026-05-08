/// Cubit backing the Profile tab stats row (Hours / Movies / Shows).
///
/// Phase B backfill (`docs/10_planning/08_real_data_backfill_plan.md`
/// §3 row 3): replaces the em-dash placeholder with `GET /auth/clients/
/// me/stats`.  Separate from `ProfileCubit` so a stats failure can't
/// blank the avatar header (and vice versa) — both load in parallel
/// and either may end in a `*Loaded` state independently.  Singleton-
/// scoped in GetIt for the same reason as `ProfileCubit`.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/client_stats.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';

sealed class ProfileStatsState {
  const ProfileStatsState();
}

class ProfileStatsInitial extends ProfileStatsState {
  const ProfileStatsInitial();
}

class ProfileStatsLoading extends ProfileStatsState {
  const ProfileStatsLoading();
}

class ProfileStatsLoaded extends ProfileStatsState {
  const ProfileStatsLoaded(this.stats);
  final ClientStats stats;
}

class ProfileStatsFailure extends ProfileStatsState {
  const ProfileStatsFailure(this.message);
  final String message;
}

class ProfileStatsCubit extends Cubit<ProfileStatsState> {
  ProfileStatsCubit({required AuthRepository repository})
      : _repository = repository,
        super(const ProfileStatsInitial());

  final AuthRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    if (state is ProfileStatsLoading) return;
    emit(const ProfileStatsLoading());
    await _fetch();
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    try {
      final stats = await _repository.getMyStats();
      emit(ProfileStatsLoaded(stats));
    } on ApiException catch (e, st) {
      _log.e('Profile stats load failed', error: e, stackTrace: st);
      emit(ProfileStatsFailure(e.message));
    } catch (e, st) {
      _log.e('Profile stats unexpected error', error: e, stackTrace: st);
      emit(const ProfileStatsFailure('Could not load watch stats.'));
    }
  }

  @override
  void emit(ProfileStatsState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
