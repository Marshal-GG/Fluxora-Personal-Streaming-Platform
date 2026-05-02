import 'package:fluxora_core/entities/library_storage_breakdown.dart';

sealed class StorageState {
  const StorageState();
}

class StorageInitial extends StorageState {
  const StorageInitial();
}

class StorageLoading extends StorageState {
  const StorageLoading();
}

class StorageLoaded extends StorageState {
  const StorageLoaded(this.breakdown);

  final LibraryStorageBreakdown breakdown;
}

class StorageFailure extends StorageState {
  const StorageFailure(this.message);

  final String message;
}
