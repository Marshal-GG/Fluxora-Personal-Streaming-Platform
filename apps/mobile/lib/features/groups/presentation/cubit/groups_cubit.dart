/// Mobile-side groups cubit.
///
/// Owns the Profile-screen view of "groups my client is a member of":
/// visible libraries + locked groups + unlocked groups with grant
/// expiry.  Wraps the [GroupsRepository] PIN-flow methods (enter,
/// enroll, change, lock) and refreshes the visibility snapshot after
/// each successful action so the UI reflects the new state without a
/// manual reload.
///
/// Plan: `docs/10_planning/13_groups_v2_content_spaces.md` §M4 + §M8 +
/// §M6.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_mobile/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_mobile/features/groups/presentation/cubit/groups_state.dart';

class MobileGroupsCubit extends Cubit<MobileGroupsState> {
  MobileGroupsCubit({required GroupsRepository repository})
      : _repository = repository,
        super(const MobileGroupsInitial());

  final GroupsRepository _repository;
  static final _log = Logger();

  /// First-load + reload-after-action hydrate.  Reads the rich
  /// visible-libraries response shape introduced in M6 — one
  /// round-trip gives us libraries + groups list + locked sets +
  /// grant expiries.
  Future<void> load() async {
    if (state is! MobileGroupsLoaded) {
      emit(const MobileGroupsLoading());
    }
    try {
      final json = await _repository.myVisibleLibraries();
      final groups = (json['groups'] as List<dynamic>? ?? const [])
          .map((e) => MobileGroupRow.fromJson(e as Map<String, dynamic>))
          .toList();
      final libraryIds =
          (json['library_ids'] as List<dynamic>? ?? const [])
              .cast<String>();
      final raw = json['groups_contributing'] as Map<String, dynamic>?;
      // Server emits `groups_contributing` as { group_id: [lib_ids] };
      // mobile renders it the other way ("for each lib_id, who granted
      // it").  Invert here once so the Profile UI doesn't have to.
      final byLib = <String, List<String>>{};
      if (raw != null) {
        for (final entry in raw.entries) {
          final libs = (entry.value as List<dynamic>).cast<String>();
          for (final lib in libs) {
            byLib.putIfAbsent(lib, () => []).add(entry.key);
          }
        }
      }
      emit(MobileGroupsLoaded(
        groups: groups,
        libraryIds: libraryIds,
        groupsContributing: byLib,
      ));
    } on ApiException catch (e, st) {
      _log.e('Mobile groups load failed', error: e, stackTrace: st);
      emit(MobileGroupsFailure(e.message));
    } catch (e, st) {
      _log.e('Mobile groups load failed', error: e, stackTrace: st);
      emit(const MobileGroupsFailure('Unable to load groups.'));
    }
  }

  /// Refresh-without-loading — preserves the current loaded state's
  /// data so the Profile screen doesn't flicker through a spinner on
  /// post-action refresh.
  Future<void> refreshSilent() async {
    final current = state;
    if (current is! MobileGroupsLoaded) {
      await load();
      return;
    }
    try {
      final json = await _repository.myVisibleLibraries();
      final groups = (json['groups'] as List<dynamic>? ?? const [])
          .map((e) => MobileGroupRow.fromJson(e as Map<String, dynamic>))
          .toList();
      final libraryIds =
          (json['library_ids'] as List<dynamic>? ?? const [])
              .cast<String>();
      final raw = json['groups_contributing'] as Map<String, dynamic>?;
      final byLib = <String, List<String>>{};
      if (raw != null) {
        for (final entry in raw.entries) {
          final libs = (entry.value as List<dynamic>).cast<String>();
          for (final lib in libs) {
            byLib.putIfAbsent(lib, () => []).add(entry.key);
          }
        }
      }
      emit(current.copyWith(
        groups: groups,
        libraryIds: libraryIds,
        groupsContributing: byLib,
        clearActionInFlight: true,
        clearLastError: true,
      ));
    } catch (e, st) {
      _log.w('Mobile groups silent refresh failed',
          error: e, stackTrace: st);
      // Preserve last-known-good state.  No emit on failure — the
      // operator's existing data stays on screen.
    }
  }

  /// Submit a PIN to unlock a gated group.  Returns true on success
  /// (modal dismisses + snackbar shows expiry).  Failure paths leave
  /// the modal open with `lastError` populated for the operator to
  /// react.
  ///
  /// Errors caught + translated:
  ///   * 401 incorrect_pin — `Wrong PIN. N attempts remaining.`
  ///   * 429 rate_limited — `Too many failed attempts. Try in 60 s.`
  ///   * 400 strength — surfaced verbatim from server
  ///   * 400 `enrollment_required` — caller should swap modal
  Future<bool> enter(String groupId, String pin) async {
    final current = state;
    if (current is! MobileGroupsLoaded) return false;
    emit(current.copyWith(
      actionInFlight: groupId,
      clearLastError: true,
    ));
    try {
      await _repository.enter(groupId, pin);
      await refreshSilent();
      return true;
    } on ApiException catch (e, st) {
      _log.w('Group enter failed', error: e, stackTrace: st);
      emit(current.copyWith(lastError: e.message, clearActionInFlight: true));
      return false;
    } catch (e, st) {
      _log.e('Group enter failed', error: e, stackTrace: st);
      emit(current.copyWith(
        lastError: 'Unable to enter PIN.',
        clearActionInFlight: true,
      ));
      return false;
    }
  }

  /// First-time per-client enrollment.  Server issues a session-length
  /// grant on success so the user doesn't have to re-enter.  Same
  /// failure semantics as [enter].
  Future<bool> enroll(String groupId, String pin) async {
    final current = state;
    if (current is! MobileGroupsLoaded) return false;
    emit(current.copyWith(
      actionInFlight: groupId,
      clearLastError: true,
    ));
    try {
      await _repository.enroll(groupId, pin);
      await refreshSilent();
      return true;
    } on ApiException catch (e, st) {
      _log.w('Group enroll failed', error: e, stackTrace: st);
      emit(current.copyWith(lastError: e.message, clearActionInFlight: true));
      return false;
    } catch (e, st) {
      _log.e('Group enroll failed', error: e, stackTrace: st);
      emit(current.copyWith(
        lastError: 'Unable to enroll PIN.',
        clearActionInFlight: true,
      ));
      return false;
    }
  }

  /// Replace the calling client's per-client PIN (M8).  Existing grant
  /// carries — caller doesn't need to re-enter the new PIN immediately.
  Future<bool> changePin(
    String groupId,
    String oldPin,
    String newPin,
  ) async {
    final current = state;
    if (current is! MobileGroupsLoaded) return false;
    emit(current.copyWith(
      actionInFlight: groupId,
      clearLastError: true,
    ));
    try {
      await _repository.changePin(groupId, oldPin, newPin);
      // Grant carries; no refresh strictly needed but we do one anyway
      // so the cubit stays consistent with server state in case the
      // server's grant TTL changed.
      await refreshSilent();
      return true;
    } on ApiException catch (e, st) {
      _log.w('Group change PIN failed', error: e, stackTrace: st);
      emit(current.copyWith(lastError: e.message, clearActionInFlight: true));
      return false;
    } catch (e, st) {
      _log.e('Group change PIN failed', error: e, stackTrace: st);
      emit(current.copyWith(
        lastError: 'Unable to change PIN.',
        clearActionInFlight: true,
      ));
      return false;
    }
  }

  /// Drop the calling client's grant for a group.  Idempotent server-
  /// side; mobile UI shows the row moving from "Unlocked" to "Locked"
  /// after the refresh.
  Future<bool> lock(String groupId) async {
    final current = state;
    if (current is! MobileGroupsLoaded) return false;
    emit(current.copyWith(
      actionInFlight: groupId,
      clearLastError: true,
    ));
    try {
      await _repository.lock(groupId);
      await refreshSilent();
      return true;
    } on ApiException catch (e, st) {
      _log.w('Group lock failed', error: e, stackTrace: st);
      emit(current.copyWith(lastError: e.message, clearActionInFlight: true));
      return false;
    } catch (e, st) {
      _log.e('Group lock failed', error: e, stackTrace: st);
      emit(current.copyWith(
        lastError: 'Unable to lock group.',
        clearActionInFlight: true,
      ));
      return false;
    }
  }

  /// Mobile-side "Lock all" button — sequential (not Future.wait) so
  /// individual failures stay logged in order and a refresh doesn't
  /// fight the mid-walk grants we've already dropped.
  Future<void> lockAll() async {
    final current = state;
    if (current is! MobileGroupsLoaded) return;
    final unlocked = current.unlockedGroups.toList();
    for (final g in unlocked) {
      try {
        await _repository.lock(g.id);
      } catch (e, st) {
        _log.w(
          'Lock-all failed for group=${g.id}',
          error: e,
          stackTrace: st,
        );
      }
    }
    await refreshSilent();
  }

  @override
  void emit(MobileGroupsState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
