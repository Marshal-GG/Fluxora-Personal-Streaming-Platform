/// Mobile-side groups repository.
///
/// Surfaces only the operations a paired client legitimately performs:
/// list groups it belongs to, fetch its visibility snapshot, submit a
/// PIN to unlock a gated group (M4), enroll a per-client PIN on first
/// access (M8), change its own per-client PIN, and lock (drop its own
/// grant).  Operator-side endpoints (create / update / delete / member
/// management / master-override / bulk grants reset / view-as) are NOT
/// exposed here — those live on the desktop CP.
///
/// Plan: `docs/10_planning/13_groups_v2_content_spaces.md` §M4 (mobile)
/// + §M8 (per-client enrollment surface) + §M6 (Profile UX).
library;

import 'package:fluxora_core/entities/group.dart';

/// Outcome of a `/grant-status` query for one group from the calling
/// client's perspective.  `enrollmentState` distinguishes the three
/// per-client states (M8) so the mobile UI can route to the right
/// surface (entry vs enrollment) without a failed `/enter` call.
class GroupGrantStatus {
  const GroupGrantStatus({
    required this.groupId,
    required this.unlocked,
    this.expiresAt,
    required this.pinModel,
    required this.enrollmentState,
  });

  /// Group id this status applies to.
  final String groupId;

  /// True iff a non-expired `group_pin_grants` row exists for the
  /// calling client.
  final bool unlocked;

  /// ISO timestamp when the grant expires; null when `unlocked == false`.
  final String? expiresAt;

  /// Group's PIN model: `'shared'` or `'per-client'`.  Drives whether
  /// the entry modal labels the field "Group PIN" (shared) or "Your PIN"
  /// (per-client).
  final PinModel pinModel;

  /// One of `'not_required'`, `'enrolled'`, `'enrollment_required'`.
  /// Mobile uses this to route shared / enrolled clients to the entry
  /// modal and not-yet-enrolled per-client clients to the enrollment
  /// modal.
  final GroupEnrollmentState enrollmentState;

  factory GroupGrantStatus.fromJson(String groupId, Map<String, dynamic> json) {
    return GroupGrantStatus(
      groupId: groupId,
      unlocked: json['unlocked'] as bool? ?? false,
      expiresAt: json['expires_at'] as String?,
      pinModel:
          (json['pin_model'] as String? ?? 'shared') == 'per-client'
              ? PinModel.perClient
              : PinModel.shared,
      enrollmentState: switch (json['enrollment_state'] as String?) {
        'enrolled' => GroupEnrollmentState.enrolled,
        'enrollment_required' => GroupEnrollmentState.enrollmentRequired,
        _ => GroupEnrollmentState.notRequired,
      },
    );
  }
}

/// Routing input for the mobile UI — keys off this enum to pick the
/// right surface for a locked-group tap.
enum GroupEnrollmentState {
  /// Shared-mode group, or a per-client group the calling client has
  /// already enrolled in, or a non-gated group.  PIN entry modal (if
  /// gated) or no surface (if not).
  notRequired,

  /// Per-client mode + this client has an enrollment row.  PIN entry
  /// modal labels the field "Your PIN".
  enrolled,

  /// Per-client mode + this client has NO enrollment row.  Enrollment
  /// modal — "Set up a PIN for this device."  Confirm-PIN re-entry to
  /// catch typos.
  enrollmentRequired,
}

/// Successful `/enter` or `/enroll` — drives the unlocked-group card on
/// Profile + the snackbar "Unlocked until 22:00" feedback.
class GroupGrantIssued {
  const GroupGrantIssued({
    required this.expiresAt,
    required this.pinMode,
  });

  /// ISO timestamp the grant expires.
  final String expiresAt;

  /// `'session'` (12 h) or `'per-entry'` (5 min).  Echo from server so
  /// the mobile snackbar can size copy ("12 hours" vs "5 minutes").
  final String pinMode;

  factory GroupGrantIssued.fromJson(Map<String, dynamic> json) {
    return GroupGrantIssued(
      expiresAt: json['expires_at'] as String? ?? '',
      pinMode: json['pin_mode'] as String? ?? 'session',
    );
  }
}

abstract class GroupsRepository {
  /// Visibility snapshot for the calling client right now — extended
  /// shape with a `groups` list carrying per-group metadata (name, icon,
  /// color, requires_pin, pin_model, is_active, is_unlocked,
  /// grant_expires_at) so the Profile screen can render visible /
  /// locked / unlocked / time-locked cards from one round-trip.
  Future<Map<String, dynamic>> myVisibleLibraries();

  /// Per-group `/grant-status`.  Returns null on 404 (group deleted
  /// while mobile was looking at it).
  Future<GroupGrantStatus?> grantStatus(String groupId);

  /// Submit a PIN to unlock a gated group.  Throws on 401 (incorrect
  /// PIN), 429 (rate-limited), 400 (strength violation), 404 (unknown
  /// group).  The mobile cubit translates the exception types into
  /// state for the entry modal.
  Future<GroupGrantIssued> enter(String groupId, String pin);

  /// First-time per-client PIN enrollment.  Issues an immediate
  /// session-length grant on success (server side — no need to call
  /// `/enter` afterward).  Throws on 400 (strength), 403 (not a
  /// member), 409 (already enrolled — caller should switch to
  /// `changePin` or `enter`), 404.
  Future<GroupGrantIssued> enroll(String groupId, String pin);

  /// Replace the calling client's per-client PIN.  Existing grant
  /// carries — caller doesn't need to re-enter the new PIN immediately.
  /// Throws on 401 (wrong old), 429 (rate-limited), 400 (strength).
  Future<void> changePin(String groupId, String oldPin, String newPin);

  /// Drop the calling client's grant for a group ("Lock" button).
  /// Idempotent — server returns 204 even if no grant existed.
  Future<void> lock(String groupId);
}
