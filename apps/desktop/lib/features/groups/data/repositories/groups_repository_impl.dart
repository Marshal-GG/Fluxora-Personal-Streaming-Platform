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
    String? pin,
    PinMode pinMode = PinMode.session,
    PinModel pinModel = PinModel.shared,
    String? icon,
    String? color,
    int? maxConcurrentStreams,
  }) =>
      _apiClient.post(
        Endpoints.groups,
        data: {
          'name': name,
          'description': ?description,
          'restrictions': ?restrictions?.toJson(),
          'pin': ?pin,
          'pin_mode': pinMode == PinMode.perEntry ? 'per-entry' : 'session',
          'pin_model':
              pinModel == PinModel.perClient ? 'per-client' : 'shared',
          'icon': ?icon,
          'color': ?color,
          'max_concurrent_streams': ?maxConcurrentStreams,
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
    String? pin,
    PinMode? pinMode,
    PinModel? pinModel,
    String? icon,
    String? color,
    int? maxConcurrentStreams,
  }) =>
      _apiClient.patch(
        Endpoints.groupById(id),
        body: {
          'name': ?name,
          'description': ?description,
          'status': ?status?.name,
          'restrictions': ?restrictions?.toJson(),
          // PIN semantic: null = leave unchanged (key absent), "" =
          // remove (key present, empty string), "<digits>" = set.  The
          // null-aware `?pin` marker omits the key when pin is null
          // and includes it for any non-null value (including the
          // empty string used for "remove PIN").
          'pin': ?pin,
          'pin_mode': ?(pinMode == null
              ? null
              : (pinMode == PinMode.perEntry ? 'per-entry' : 'session')),
          'pin_model': ?(pinModel == null
              ? null
              : (pinModel == PinModel.perClient ? 'per-client' : 'shared')),
          'icon': ?icon,
          'color': ?color,
          'max_concurrent_streams': ?maxConcurrentStreams,
        },
        fromJson: (json) => Group.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<void> clearMemberPin(String groupId, String clientId) =>
      _apiClient.delete(Endpoints.groupMemberPin(groupId, clientId));

  @override
  Future<Map<String, dynamic>> visibleLibrariesAs(String clientId) =>
      _apiClient.get(
        Endpoints.authClientVisibleLibraries(clientId),
        fromJson: (json) => json as Map<String, dynamic>,
      );

  @override
  Future<int> resetAllGrants(String groupId) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      Endpoints.groupGrantsReset(groupId),
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return (result['dropped'] as int?) ?? 0;
  }

  @override
  Future<void> delete(String id) => _apiClient.delete(Endpoints.groupById(id));

  @override
  Future<List<Map<String, dynamic>>> listMembers(
    String id, {
    bool includePinState = false,
  }) {
    final base = Endpoints.groupMembers(id);
    final url = includePinState ? '$base?include=pin_state' : base;
    return _apiClient.get(
      url,
      fromJson: (json) => (json as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }

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
