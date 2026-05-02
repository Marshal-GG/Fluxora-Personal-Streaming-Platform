import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

enum GroupStatus {
  @JsonValue('active')
  active,
  @JsonValue('inactive')
  inactive,
}

@freezed
abstract class TimeWindow with _$TimeWindow {
  const factory TimeWindow({
    required int startH,
    required int endH,
    required List<int> days,
  }) = _TimeWindow;

  factory TimeWindow.fromJson(Map<String, dynamic> json) =>
      _$TimeWindowFromJson(json);
}

@freezed
abstract class GroupRestrictions with _$GroupRestrictions {
  const factory GroupRestrictions({
    List<String>? allowedLibraries,
    int? bandwidthCapMbps,
    TimeWindow? timeWindow,
    String? maxRating,
  }) = _GroupRestrictions;

  factory GroupRestrictions.fromJson(Map<String, dynamic> json) =>
      _$GroupRestrictionsFromJson(json);
}

@freezed
abstract class Group with _$Group {
  const factory Group({
    required String id,
    required String name,
    String? description,
    required GroupStatus status,
    required String createdAt,
    required String updatedAt,
    @Default(0) int memberCount,
    GroupRestrictions? restrictions,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}
