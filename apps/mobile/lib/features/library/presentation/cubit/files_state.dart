import 'package:fluxora_core/entities/media_file.dart';

sealed class FilesState {
  const FilesState();
}

class FilesInitial extends FilesState {
  const FilesInitial();
}

class FilesLoading extends FilesState {
  const FilesLoading();
}

class FilesSuccess extends FilesState {
  const FilesSuccess(this.files);

  final List<MediaFile> files;
}

class FilesFailure extends FilesState {
  const FilesFailure(this.message);

  final String message;
}
