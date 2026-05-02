import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';

class GroupsRepositoryImpl implements GroupsRepository {
  GroupsRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<Group>> list() => _apiClient.get(
        Endpoints.groups,
        fromJson: (json) => (json as List<dynamic>)
            .map((e) => Group.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Future<Group> get(String id) => _apiClient.get(
        Endpoints.groupById(id),
        fromJson: (json) => Group.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<Group> create({
    required String name,
    String? description,
    GroupRestrictions? restrictions,
  }) =>
      _apiClient.post(
        Endpoints.groups,
        data: {
          'name': name,
          'description': ?description,
          'restrictions': ?restrictions?.toJson(),
        },
        fromJson: (json) => Group.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<Group> update(
    String id, {
    String? name,
    String? description,
    GroupStatus? status,
    GroupRestrictions? restrictions,
  }) =>
      _apiClient.patch(
        Endpoints.groupById(id),
        body: {
          'name': ?name,
          'description': ?description,
          'status': ?status?.name,
          'restrictions': ?restrictions?.toJson(),
        },
        fromJson: (json) => Group.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<void> delete(String id) => _apiClient.delete(Endpoints.groupById(id));

  @override
  Future<List<Map<String, dynamic>>> listMembers(String id) => _apiClient.get(
        Endpoints.groupMembers(id),
        fromJson: (json) => (json as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList(),
      );

  @override
  Future<void> addMember(String id, String clientId) => _apiClient.post(
        Endpoints.groupMembers(id),
        data: {'client_id': clientId},
        fromJson: (_) {},
      );

  @override
  Future<void> removeMember(String id, String clientId) =>
      _apiClient.delete(Endpoints.groupMember(id, clientId));
}
