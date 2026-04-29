import 'package:fluxora_core/entities/polar_order.dart';

abstract class OrdersRepository {
  /// Fetch all Polar orders with their generated license keys.
  Future<List<PolarOrder>> getOrders();
}
