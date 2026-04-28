import 'package:fluxora_core/entities/library.dart';

sealed class LibraryState {
  const LibraryState();
}

class LibraryInitial extends LibraryState {
  const LibraryInitial();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibrarySuccess extends LibraryState {
  const LibrarySuccess(this.libraries);

  final List<Library> libraries;
}

class LibraryFailure extends LibraryState {
  const LibraryFailure(this.message);

  final String message;
}
