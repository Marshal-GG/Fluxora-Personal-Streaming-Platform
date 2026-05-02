import 'package:fluxora_core/entities/group.dart';

abstract class GroupsRepository {
  Future<List<Group>> list();
  Future<Group> get(String id);
  Future<Group> create({
    required String name,
    String? description,
    GroupRestrictions? restrictions,
  });
  Future<Group> update(
    String id, {
    String? name,
    String? description,
    GroupStatus? status,
    GroupRestrictions? restrictions,
  });
  Future<void> delete(String id);
  Future<List<Map<String, dynamic>>> listMembers(String id);
  Future<void> addMember(String id, String clientId);
  Future<void> removeMember(String id, String clientId);
}
