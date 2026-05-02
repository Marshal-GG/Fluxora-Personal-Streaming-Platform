import 'package:fluxora_core/entities/polar_order.dart';

abstract class OrdersRepository {
  /// Fetch all Polar orders with their generated license keys.
  Future<List<PolarOrder>> getOrders();

  /// Fetch the Polar customer portal URL.
  /// Returns `null` when the server has no portal URL configured (404).
  Future<String?> portalUrl();
}
