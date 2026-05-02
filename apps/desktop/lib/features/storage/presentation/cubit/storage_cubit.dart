import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/storage/domain/repositories/storage_repository.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_state.dart';

class StorageCubit extends Cubit<StorageState> {
  StorageCubit({required StorageRepository repository})
      : _repository = repository,
        super(const StorageInitial());

  final StorageRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    emit(const StorageLoading());
    try {
      final breakdown = await _repository.fetch();
      emit(StorageLoaded(breakdown));
    } on ApiException catch (e, st) {
      _log.e('Storage load failed', error: e, stackTrace: st);
      emit(StorageFailure(e.message));
    } catch (e, st) {
      _log.e('Storage load failed', error: e, stackTrace: st);
      emit(const StorageFailure('Unable to load storage data.'));
    }
  }
}
