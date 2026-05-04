import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_desktop/features/logs/domain/repositories/logs_repository.dart';
import 'package:fluxora_desktop/features/logs/presentation/cubit/logs_state.dart';

class LogsCubit extends Cubit<LogsState> {
  LogsCubit({required LogsRepository repository})
      : _repository = repository,
        super(LogsInitial());

  final LogsRepository _repository;

  Future<void> load() async {
    if (isClosed) return;
    emit(LogsLoading());
    try {
      final records = await _repository.getLogs();
      if (isClosed) return;
      emit(LogsLoaded(records: records));
    } catch (e) {
      if (isClosed) return;
      emit(LogsFailure(message: e.toString()));
    }
  }
}
