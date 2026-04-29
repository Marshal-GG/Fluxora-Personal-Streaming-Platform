import 'package:equatable/equatable.dart';
import 'package:fluxora_core/entities/polar_order.dart';

sealed class OrdersState extends Equatable {
  const OrdersState();
}

final class OrdersInitial extends OrdersState {
  const OrdersInitial();
  @override
  List<Object?> get props => [];
}

final class OrdersLoading extends OrdersState {
  const OrdersLoading();
  @override
  List<Object?> get props => [];
}

final class OrdersLoaded extends OrdersState {
  const OrdersLoaded({required this.orders});
  final List<PolarOrder> orders;
  @override
  List<Object?> get props => [orders];
}

final class OrdersFailure extends OrdersState {
  const OrdersFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
