/// Cubit backing the title-detail screen.
///
/// Phase A backfill: replaces `MockData.findById(id)`.  Calls
/// `LibraryRepository.getFile(id)` once on cubit creation; rail content
/// (cast / crew / similar / episodes) lands later — Phase C / D.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';

sealed class DetailState {
  const DetailState();
}

class DetailLoading extends DetailState {
  const DetailLoading();
}

class DetailLoaded extends DetailState {
  const DetailLoaded(this.file);
  final MediaFile file;
}

class DetailFailure extends DetailState {
  const DetailFailure(this.message);
  final String message;
}

class DetailCubit extends Cubit<DetailState> {
  DetailCubit({
    required LibraryRepository repository,
    required this.fileId,
  })  : _repository = repository,
        super(const DetailLoading());

  final LibraryRepository _repository;
  final String fileId;
  static final _log = Logger();

  Future<void> load() async {
    if (state is! DetailLoading) emit(const DetailLoading());
    try {
      final file = await _repository.getFile(fileId);
      emit(DetailLoaded(file));
    } on ApiException catch (e, st) {
      _log.e('Detail load failed for $fileId', error: e, stackTrace: st);
      emit(DetailFailure(e.message));
    } catch (e, st) {
      _log.e('Detail unexpected error for $fileId',
          error: e, stackTrace: st);
      emit(const DetailFailure('Could not load this title.'));
    }
  }
}
