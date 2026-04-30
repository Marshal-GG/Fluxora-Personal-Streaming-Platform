import 'package:equatable/equatable.dart';

sealed class LogsState extends Equatable {
  const LogsState();

  @override
  List<Object?> get props => [];
}

class LogsInitial extends LogsState {}

class LogsLoading extends LogsState {}

class LogsLoaded extends LogsState {
  const LogsLoaded({required this.logs});
  final String logs;

  @override
  List<Object?> get props => [logs];
}

class LogsFailure extends LogsState {
  const LogsFailure({required this.message});
  final String message;

  @override
  List<Object?> get props => [message];
}
