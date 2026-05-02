import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_state.dart';

class GroupsCubit extends Cubit<GroupsState> {
  GroupsCubit({required GroupsRepository repository})
      : _repository = repository,
        super(const GroupsInitial());

  final GroupsRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    emit(const GroupsLoading());
    try {
      final groups = await _repository.list();
      emit(GroupsLoaded(
        groups: groups,
        selectedGroup: groups.isNotEmpty ? groups.first : null,
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

  Future<void> loadMembers(String groupId) async {
    final current = state;
    if (current is! GroupsLoaded) return;
    emit(current.copyWith(membersLoading: true));
    try {
      final members = await _repository.listMembers(groupId);
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
  }) async {
    try {
      await _repository.create(
        name: name,
        description: description,
        restrictions: restrictions,
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
  }) async {
    try {
      await _repository.update(
        id,
        name: name,
        description: description,
        status: status,
        restrictions: restrictions,
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

  Future<void> removeMember(String groupId, String clientId) async {
    try {
      await _repository.removeMember(groupId, clientId);
      await loadMembers(groupId);
    } catch (e, st) {
      _log.e('Remove member failed', error: e, stackTrace: st);
    }
  }
}
