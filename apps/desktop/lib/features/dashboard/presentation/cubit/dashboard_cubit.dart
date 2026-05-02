import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required DashboardRepository repository})
      : _repository = repository,
        super(const DashboardInitial());

  final DashboardRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    emit(const DashboardLoading());
    try {
      final serverInfo = await _repository.getServerInfo();
      final clients = await _repository.getClients();
      // Library count is best-effort — the dashboard still loads if
      // /library 401s while clients are being approved.
      var libraryCount = 0;
      try {
        libraryCount = await _repository.getLibraryCount();
      } catch (e, st) {
        _log.w('Library count unavailable; defaulting to 0',
            error: e, stackTrace: st);
      }
      emit(DashboardLoaded(
        serverInfo: serverInfo,
        clients: clients,
        libraryCount: libraryCount,
      ));
    } on ApiException catch (e, st) {
      _log.e('Dashboard load failed', error: e, stackTrace: st);
      emit(DashboardFailure(e.message));
    } catch (e, st) {
      _log.e('Dashboard load failed', error: e, stackTrace: st);
      emit(const DashboardFailure('Unable to reach server. Is it running?'));
    }
  }
}
