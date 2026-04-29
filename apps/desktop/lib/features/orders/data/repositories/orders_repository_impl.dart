import 'package:fluxora_core/entities/polar_order.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_desktop/features/orders/domain/repositories/orders_repository.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<PolarOrder>> getOrders() => _apiClient.get(
        Endpoints.orders,
        fromJson: (json) => (json['orders'] as List<dynamic>)
            .map((e) => PolarOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
