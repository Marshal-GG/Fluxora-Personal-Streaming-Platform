import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_state.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';

class GroupsCubit extends Cubit<GroupsState> {
  GroupsCubit({
    required GroupsRepository repository,
    required LibraryRepository libraryRepository,
  })  : _repository = repository,
        _libraryRepository = libraryRepository,
        super(const GroupsInitial());

  final GroupsRepository _repository;
  final LibraryRepository _libraryRepository;
  static final _log = Logger();

  /// Fetch libraries best-effort.  An empty list is fine — the picker shows
  /// a placeholder, the detail panel falls back to raw ids.  Failures here
  /// must NOT block the groups load itself.
  Future<List<Library>> _safeLoadLibraries() async {
    try {
      return await _libraryRepository.getLibraries();
    } catch (e, st) {
      _log.w('Group library fetch failed', error: e, stackTrace: st);
      return const <Library>[];
    }
  }

  Future<void> load() async {
    emit(const GroupsLoading());
    try {
      final results = await Future.wait([
        _repository.list(),
        _safeLoadLibraries(),
      ]);
      final groups = results[0] as List<Group>;
      final libraries = results[1] as List<Library>;
      emit(GroupsLoaded(
        groups: groups,
        selectedGroup: groups.isNotEmpty ? groups.first : null,
        libraries: libraries,
      ));
      if (groups.isNotEmpty) {
        await loadMembers(groups.first.id);
      }
    } on ApiException catch (e, st) {
      _log.e('Groups load failed', error: e, stackTrace: st);
      emit(GroupsFailure(e.message));
    } catch (e, st) {
      _log.e('Groups load failed', error: e, stackTrace: st);
      emit(const GroupsFailure('Unable to load groups.'));
    }
  }

  Future<void> selectGroup(Group group) async {
    final current = state;
    if (current is! GroupsLoaded) return;
    emit(current.copyWith(
      selectedGroup: () => group,
      members: [],
      membersLoading: true,
    ));
    await loadMembers(group.id);
  }

  Future<void> loadMembers(
    String groupId, {
    bool includePinState = false,
  }) async {
    final current = state;
    if (current is! GroupsLoaded) return;
    emit(current.copyWith(membersLoading: true));
    try {
      final members = await _repository.listMembers(
        groupId,
        includePinState: includePinState,
      );
      emit(current.copyWith(members: members, membersLoading: false));
    } catch (e, st) {
      _log.e('Group members load failed', error: e, stackTrace: st);
      emit(current.copyWith(members: [], membersLoading: false));
    }
  }

  Future<void> createGroup({
    required String name,
    String? description,
    GroupRestrictions? restrictions,
    String? pin,
    PinMode? pinMode,
    PinModel? pinModel,
    String? icon,
    String? color,
    int? maxConcurrentStreams,
  }) async {
    try {
      await _repository.create(
        name: name,
        description: description,
        restrictions: restrictions,
        pin: pin,
        pinMode: pinMode ?? PinMode.session,
        pinModel: pinModel ?? PinModel.shared,
        icon: icon,
        color: color,
        maxConcurrentStreams: maxConcurrentStreams,
      );
      await load();
    } on ApiException catch (e, st) {
      _log.e('Group create failed', error: e, stackTrace: st);
      emit(GroupsFailure(e.message));
    } catch (e, st) {
      _log.e('Group create failed', error: e, stackTrace: st);
      emit(const GroupsFailure('Failed to create group.'));
    }
  }

  Future<void> updateGroup(
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
  }) async {
    try {
      await _repository.update(
        id,
        name: name,
        description: description,
        status: status,
        restrictions: restrictions,
        pin: pin,
        pinMode: pinMode,
        pinModel: pinModel,
        icon: icon,
        color: color,
        maxConcurrentStreams: maxConcurrentStreams,
      );
      await load();
    } on ApiException catch (e, st) {
      _log.e('Group update failed', error: e, stackTrace: st);
      emit(GroupsFailure(e.message));
    } catch (e, st) {
      _log.e('Group update failed', error: e, stackTrace: st);
      emit(const GroupsFailure('Failed to update group.'));
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      await _repository.delete(id);
      await load();
    } on ApiException catch (e, st) {
      _log.e('Group delete failed', error: e, stackTrace: st);
      emit(GroupsFailure(e.message));
    } catch (e, st) {
      _log.e('Group delete failed', error: e, stackTrace: st);
      emit(const GroupsFailure('Failed to delete group.'));
    }
  }

  Future<void> addMember(String groupId, String clientId) async {
    try {
      await _repository.addMember(groupId, clientId);
      await loadMembers(groupId);
    } catch (e, st) {
      _log.e('Add member failed', error: e, stackTrace: st);
    }
  }

  /// Bulk variant — adds [clientIds] to [groupId] sequentially and refreshes
  /// the visible member list once at the end.  Sequential (not
  /// `Future.wait`) so individual failures stay logged in order and the
  /// final `loadMembers` reflects the actually-applied state.  Same pattern
  /// as the F9 Profile Sessions tab's bulk-revoke.  Per-call failures are
  /// swallowed with a log so one bad insert doesn't abort the rest of the
  /// batch — operator picks 5 devices, server rejects 1 (e.g. unknown id),
  /// the other 4 still land.
  Future<void> addMembers(String groupId, List<String> clientIds) async {
    for (final clientId in clientIds) {
      try {
        await _repository.addMember(groupId, clientId);
      } catch (e, st) {
        _log.w(
          'Bulk add member failed: group=$groupId client=$clientId',
          error: e,
          stackTrace: st,
        );
      }
    }
    await loadMembers(groupId);
  }

  Future<void> removeMember(String groupId, String clientId) async {
    try {
      await _repository.removeMember(groupId, clientId);
      await loadMembers(groupId);
    } catch (e, st) {
      _log.e('Remove member failed', error: e, stackTrace: st);
    }
  }

  /// Operator action — drop a member's per-client PIN enrollment so
  /// they re-enroll on next access.  Server also drops any active grant
  /// so visibility flips immediately.  Refreshes the members list with
  /// pin_state so the UI reflects the cleared row without a manual
  /// reload.
  Future<void> clearMemberPin(String groupId, String clientId) async {
    try {
      await _repository.clearMemberPin(groupId, clientId);
      await loadMembers(groupId, includePinState: true);
    } catch (e, st) {
      _log.e('Clear member PIN failed', error: e, stackTrace: st);
      rethrow; // surface to the caller for snackbar feedback
    }
  }

  @override
  void emit(GroupsState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
