import 'package:equatable/equatable.dart';
import 'package:fluxora_desktop/features/logs/domain/log_record.dart';

sealed class LogsState extends Equatable {
  const LogsState();

  @override
  List<Object?> get props => [];
}

class LogsInitial extends LogsState {}

class LogsLoading extends LogsState {}

class LogsLoaded extends LogsState {
  const LogsLoaded({required this.records});
  final List<LogRecord> records;

  @override
  List<Object?> get props => [records];
}

class LogsFailure extends LogsState {
  const LogsFailure({required this.message});
  final String message;

  @override
  List<Object?> get props => [message];
}
