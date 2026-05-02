import 'package:equatable/equatable.dart';
import 'package:fluxora_core/entities/profile.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
  @override
  List<Object?> get props => [];
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
  @override
  List<Object?> get props => [];
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.profile, this.dirty = false});
  final Profile profile;
  final bool dirty;
  @override
  List<Object?> get props => [profile, dirty];
}

final class ProfileSaving extends ProfileState {
  const ProfileSaving({required this.profile});
  final Profile profile;
  @override
  List<Object?> get props => [profile];
}

final class ProfileFailure extends ProfileState {
  const ProfileFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
