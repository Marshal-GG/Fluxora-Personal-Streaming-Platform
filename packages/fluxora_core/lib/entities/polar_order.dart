import 'package:equatable/equatable.dart';

/// Domain entity representing a single Polar order with its issued license key.
class PolarOrder extends Equatable {
  const PolarOrder({
    required this.orderId,
    this.customerEmail,
    required this.tier,
    required this.licenseKey,
    required this.processedAt,
  });

  factory PolarOrder.fromJson(Map<String, dynamic> json) => PolarOrder(
        orderId: json['order_id'] as String,
        customerEmail: json['customer_email'] as String?,
        tier: json['tier'] as String,
        licenseKey: json['license_key'] as String,
        processedAt: json['processed_at'] as String,
      );

  final String orderId;
  final String? customerEmail;
  final String tier;
  final String licenseKey;
  final String processedAt;

  /// Human-readable tier label for display in the UI.
  String get tierLabel => switch (tier) {
        'plus' => 'Plus',
        'pro' => 'Pro',
        'ultimate' => 'Ultimate',
        _ => tier,
      };

  @override
  List<Object?> get props =>
      [orderId, customerEmail, tier, licenseKey, processedAt];
}
