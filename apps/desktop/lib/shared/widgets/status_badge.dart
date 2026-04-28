import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/entities/enums.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final ClientStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ClientStatus.approved => ('Approved', AppColors.success),
      ClientStatus.pending => ('Pending', AppColors.warning),
      ClientStatus.rejected => ('Rejected', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
