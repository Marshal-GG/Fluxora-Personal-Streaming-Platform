import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/converters.dart';
import 'package:fluxora_core/entities/enums.dart';

part 'library.freezed.dart';
part 'library.g.dart';

@freezed
class Library with _$Library {
  const factory Library({
    required String id,
    required String name,
    required LibraryType type,
    required List<String> rootPaths,
    @JsonKey(
      fromJson: utcDateTimeOrNullFromJson,
      toJson: utcDateTimeOrNullToJson,
    )
    DateTime? lastScanned,
    @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
    required DateTime createdAt,
  }) = _Library;

  factory Library.fromJson(Map<String, dynamic> json) =>
      _$LibraryFromJson(json);
}
