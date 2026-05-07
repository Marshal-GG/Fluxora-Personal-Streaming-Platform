/// State for [MobileGroupsCubit].
///
/// Plan: `docs/10_planning/13_groups_v2_content_spaces.md` §M6 + §M4 + §M8.
library;

import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_mobile/features/groups/domain/repositories/groups_repository.dart';

/// One row in the cubit's view of "groups my client is a member of".
/// Shape mirrors what the server's `_serialize_visible` emits in the
/// `groups` field; we keep it as a domain class so the UI doesn't reach
/// into raw maps.
class MobileGroupRow {
  const MobileGroupRow({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.isPublic,
    required this.isActive,
    required this.requiresPin,
    required this.pinModel,
    required this.pinMode,
    required this.isEnrolled,
    required this.inTimeWindow,
    required this.isUnlocked,
    this.grantExpiresAt,
  });

  final String id;
  final String name;
  final String? icon;
  final String? color;
  final bool isPublic;
  final bool isActive;
  final bool requiresPin;
  final PinModel pinModel;
  final PinMode pinMode;
  final bool isEnrolled;
  final bool inTimeWindow;
  final bool isUnlocked;
  final String? grantExpiresAt;

  /// Routing helper — drives the modal-picker on a locked-group tap.
  /// Mirrors the server's `enrollment_state` semantics so the cubit can
  /// pick the surface without fetching `/grant-status` first.
  GroupEnrollmentState get enrollmentState {
    if (!requiresPin) return GroupEnrollmentState.notRequired;
    if (pinModel == PinModel.shared) return GroupEnrollmentState.notRequired;
    return isEnrolled
        ? GroupEnrollmentState.enrolled
        : GroupEnrollmentState.enrollmentRequired;
  }

  /// True iff the group is gated AND the calling client doesn't have an
  /// active grant.  Drives the "Locked Groups" card on Profile.
  bool get isLocked => requiresPin && !isUnlocked;

  /// True iff the group has an active grant — drives the "Unlocked
  /// Groups" card with Lock buttons.
  bool get hasActiveGrant => requiresPin && isUnlocked;

  factory MobileGroupRow.fromJson(Map<String, dynamic> json) {
    return MobileGroupRow(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      requiresPin: json['requires_pin'] as bool? ?? false,
      pinModel: (json['pin_model'] as String?) == 'per-client'
          ? PinModel.perClient
          : PinModel.shared,
      pinMode: (json['pin_mode'] as String?) == 'per-entry'
          ? PinMode.perEntry
          : PinMode.session,
      isEnrolled: json['is_enrolled'] as bool? ?? false,
      inTimeWindow: json['in_time_window'] as bool? ?? true,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      grantExpiresAt: json['grant_expires_at'] as String?,
    );
  }
}

sealed class MobileGroupsState {
  const MobileGroupsState();
}

class MobileGroupsInitial extends MobileGroupsState {
  const MobileGroupsInitial();
}

class MobileGroupsLoading extends MobileGroupsState {
  const MobileGroupsLoading();
}

class MobileGroupsLoaded extends MobileGroupsState {
  const MobileGroupsLoaded({
    required this.groups,
    required this.libraryIds,
    required this.groupsContributing,
    this.actionInFlight,
    this.lastError,
  });

  /// Every group the calling client is a member of, in the server's
  /// emit order (membership added_at).
  final List<MobileGroupRow> groups;

  /// Libraries currently visible to the client.  Drives the "My
  /// Libraries" card on Profile.
  final List<String> libraryIds;

  /// `library_id` → list of `group_id` that contributed it.  Drives
  /// the "← granted by Public" provenance captions.
  final Map<String, List<String>> groupsContributing;

  /// id of a group whose action (enter / enroll / change / lock) is
  /// currently in-flight.  Drives per-row spinners.  null = idle.
  final String? actionInFlight;

  /// Last user-facing error string from a failed action, scoped to the
  /// modal that triggered it.  null = clean state.
  final String? lastError;

  /// Filtered views — keep them as getters so tests can inspect them
  /// directly without re-walking the cubit's source list.
  List<MobileGroupRow> get lockedGroups =>
      groups.where((g) => g.isActive && g.isLocked).toList();
  List<MobileGroupRow> get unlockedGroups =>
      groups.where((g) => g.isActive && g.hasActiveGrant).toList();

  MobileGroupsLoaded copyWith({
    List<MobileGroupRow>? groups,
    List<String>? libraryIds,
    Map<String, List<String>>? groupsContributing,
    String? actionInFlight,
    String? lastError,
    bool clearActionInFlight = false,
    bool clearLastError = false,
  }) {
    return MobileGroupsLoaded(
      groups: groups ?? this.groups,
      libraryIds: libraryIds ?? this.libraryIds,
      groupsContributing: groupsContributing ?? this.groupsContributing,
      actionInFlight:
          clearActionInFlight ? null : (actionInFlight ?? this.actionInFlight),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

class MobileGroupsFailure extends MobileGroupsState {
  const MobileGroupsFailure(this.message);
  final String message;
}
