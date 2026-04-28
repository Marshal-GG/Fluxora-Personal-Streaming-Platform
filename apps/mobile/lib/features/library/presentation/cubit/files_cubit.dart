import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/library/presentation/cubit/files_state.dart';

class FilesCubit extends Cubit<FilesState> {
  FilesCubit({required LibraryRepository repository})
      : _repository = repository,
        super(const FilesInitial());

  final LibraryRepository _repository;
  static final _log = Logger();

  Future<void> loadFiles(String libraryId) async {
    emit(const FilesLoading());
    try {
      final files = await _repository.listFiles(libraryId: libraryId);
      emit(FilesSuccess(files));
    } on ApiException catch (e, st) {
      _log.e('Failed to load files', error: e, stackTrace: st);
      emit(FilesFailure(e.message));
    } catch (e, st) {
      _log.e('Unexpected error loading files', error: e, stackTrace: st);
      emit(const FilesFailure('Failed to load files.'));
    }
  }
}
