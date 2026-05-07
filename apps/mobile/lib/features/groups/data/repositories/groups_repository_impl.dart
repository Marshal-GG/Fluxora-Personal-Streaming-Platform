/// REST impl of [GroupsRepository].  All routes go through the shared
/// [ApiClient]; auth is the bearer token (stored at pair time + restored
/// from secure storage on app start).
///
/// Plan: `docs/10_planning/13_groups_v2_content_spaces.md` §M4 + §M8 +
/// §M6 (Profile UX).
library;

import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_mobile/features/groups/domain/repositories/groups_repository.dart';

class GroupsRepositoryImpl implements GroupsRepository {
  GroupsRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> myVisibleLibraries() => _apiClient.get(
        Endpoints.authClientsMeVisibleLibraries,
        fromJson: (json) => json as Map<String, dynamic>,
      );

  @override
  Future<GroupGrantStatus?> grantStatus(String groupId) async {
    try {
      return await _apiClient.get<GroupGrantStatus>(
        Endpoints.groupGrantStatus(groupId),
        fromJson: (json) => GroupGrantStatus.fromJson(
          groupId,
          json as Map<String, dynamic>,
        ),
      );
    } on ApiException catch (e) {
      // Group deleted while mobile was looking at it → null tells the
      // cubit to drop the row from its locked-groups list silently.
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<GroupGrantIssued> enter(String groupId, String pin) =>
      _apiClient.post<GroupGrantIssued>(
        Endpoints.groupEnter(groupId),
        data: {'pin': pin},
        fromJson: (json) =>
            GroupGrantIssued.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<GroupGrantIssued> enroll(String groupId, String pin) =>
      _apiClient.post<GroupGrantIssued>(
        Endpoints.groupEnroll(groupId),
        data: {'pin': pin},
        fromJson: (json) =>
            GroupGrantIssued.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<void> changePin(
    String groupId,
    String oldPin,
    String newPin,
  ) =>
      _apiClient.post<void>(
        Endpoints.groupEnrollChange(groupId),
        data: {'old_pin': oldPin, 'new_pin': newPin},
      );

  @override
  Future<void> lock(String groupId) =>
      _apiClient.delete(Endpoints.groupGrant(groupId));
}
