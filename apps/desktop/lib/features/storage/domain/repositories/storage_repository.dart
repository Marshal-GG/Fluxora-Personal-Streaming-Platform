import 'package:fluxora_core/entities/library_storage_breakdown.dart';

abstract class StorageRepository {
  Future<LibraryStorageBreakdown> fetch();
}
