import 'package:fluxora_core/entities/group.dart';

abstract class GroupsRepository {
  Future<List<Group>> list();
  Future<Group> get(String id);
  Future<Group> create({
    required String name,
    String? description,
    GroupRestrictions? restrictions,
    String? pin,
    PinMode pinMode,
    PinModel pinModel,
    String? icon,
    String? color,
    int? maxConcurrentStreams,
  });

  /// Update a group.  `pin` semantic mirrors the server (M4 of
  /// `13_groups_v2_content_spaces.md`):
  ///   * `null` → leave unchanged
  ///   * `""`   → remove the PIN; group becomes non-gated
  ///   * `"<digits>"` → set / change PIN; existing grants are cleared
  ///     and members must re-PIN on next access.
  ///
  /// `pinModel` (M8): null = leave unchanged.  Switching to `shared`
  /// requires `pin` in the same call (server rejects otherwise).
  Future<Group> update(
    String id, {
    String? name,
    String? description,
    GroupStatus? status,
    GroupRestrictions? restrictions,
    String? pin,
    PinMode? pinMode,
    PinModel? pinModel,
    String? icon,
    String? color,
    int? maxConcurrentStreams,
  });

  /// Operator action — clear a member's per-client PIN enrollment so
  /// they re-enroll on next access.  Localhost-only on the server side.
  Future<void> clearMemberPin(String groupId, String clientId);

  /// "View as" debug — return the [VisibleLibraries] snapshot for a
  /// target client right now.  Localhost-only on the server side; the
  /// returned shape mirrors `services/group_service.VisibleLibraries`
  /// with `library_ids` + `groups_contributing` provenance + locked-
  /// state buckets so the desktop tab can render the kid's library
  /// list as the kid sees it.
  Future<Map<String, dynamic>> visibleLibrariesAs(String clientId);

  /// Bulk-drop every active PIN grant for a group (M7 follow-up of
  /// `14_groups_management_page.md`).  Drives the shared-mode "Reset
  /// all PINs" Danger Zone action.  Returns the count of grants
  /// dropped.  Per-client mode uses [clearMemberPin] per member
  /// instead — this route only touches grants, not enrollments.
  Future<int> resetAllGrants(String groupId);
  Future<void> delete(String id);

  /// List members of a group.  When `includePinState=true` (M3 of
  /// `14_groups_management_page.md`), the server augments each row with
  /// `enrollment_state`, `has_active_grant`, `grant_expires_at`, and
  /// `recent_failed_attempts` so the desktop Members tab can render PIN
  /// status badges without fanning out N+1 calls per member.
  Future<List<Map<String, dynamic>>> listMembers(
    String id, {
    bool includePinState,
  });
  Future<void> addMember(String id, String clientId);
  Future<void> removeMember(String id, String clientId);
}
