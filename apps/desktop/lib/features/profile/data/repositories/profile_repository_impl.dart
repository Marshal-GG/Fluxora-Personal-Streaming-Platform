import 'package:fluxora_core/entities/profile.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Profile> get() => _apiClient.get(
        Endpoints.profile,
        fromJson: (json) => Profile.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<Profile> update({String? displayName, String? email}) =>
      _apiClient.patch(
        Endpoints.profile,
        body: {
          'display_name': ?displayName,
          'email': ?email,
        },
        fromJson: (json) => Profile.fromJson(json as Map<String, dynamic>),
      );
}
