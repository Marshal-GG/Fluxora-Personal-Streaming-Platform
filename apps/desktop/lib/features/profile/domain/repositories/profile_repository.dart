import 'package:fluxora_core/entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile> get();
  Future<Profile> update({String? displayName, String? email});
}
