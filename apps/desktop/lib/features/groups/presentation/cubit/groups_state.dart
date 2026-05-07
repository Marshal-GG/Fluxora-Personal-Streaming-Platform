import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_core/entities/library.dart';

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
    this.libraries = const [],
  });

  final List<Group> groups;
  final Group? selectedGroup;
  final List<Map<String, dynamic>> members;
  final bool membersLoading;

  /// Cached library list for the restriction-editor dialogs and the detail
  /// panel's "allowed libraries" chip resolver.  Fetched once per cubit
  /// lifecycle in `GroupsCubit.load()`.  Empty list when the fetch failed
  /// or the operator has no libraries — the dialog falls back to a
  /// placeholder message + the detail panel shows the raw library id.
  final List<Library> libraries;

  GroupsLoaded copyWith({
    List<Group>? groups,
    Group? Function()? selectedGroup,
    List<Map<String, dynamic>>? members,
    bool? membersLoading,
    List<Library>? libraries,
  }) {
    return GroupsLoaded(
      groups: groups ?? this.groups,
      selectedGroup:
          selectedGroup != null ? selectedGroup() : this.selectedGroup,
      members: members ?? this.members,
      membersLoading: membersLoading ?? this.membersLoading,
      libraries: libraries ?? this.libraries,
    );
  }
}

final class GroupsFailure extends GroupsState {
  const GroupsFailure(this.message);
  final String message;
}
