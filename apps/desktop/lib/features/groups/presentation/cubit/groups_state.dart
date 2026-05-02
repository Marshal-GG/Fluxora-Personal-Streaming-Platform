import 'package:fluxora_core/entities/group.dart';

sealed class GroupsState {
  const GroupsState();
}

final class GroupsInitial extends GroupsState {
  const GroupsInitial();
}

final class GroupsLoading extends GroupsState {
  const GroupsLoading();
}

final class GroupsLoaded extends GroupsState {
  const GroupsLoaded({
    required this.groups,
    this.selectedGroup,
    this.members = const [],
    this.membersLoading = false,
  });

  final List<Group> groups;
  final Group? selectedGroup;
  final List<Map<String, dynamic>> members;
  final bool membersLoading;

  GroupsLoaded copyWith({
    List<Group>? groups,
    Group? Function()? selectedGroup,
    List<Map<String, dynamic>>? members,
    bool? membersLoading,
  }) {
    return GroupsLoaded(
      groups: groups ?? this.groups,
      selectedGroup:
          selectedGroup != null ? selectedGroup() : this.selectedGroup,
      members: members ?? this.members,
      membersLoading: membersLoading ?? this.membersLoading,
    );
  }
}

final class GroupsFailure extends GroupsState {
  const GroupsFailure(this.message);
  final String message;
}
