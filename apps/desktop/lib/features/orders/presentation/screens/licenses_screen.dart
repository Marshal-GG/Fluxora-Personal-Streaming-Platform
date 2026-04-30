import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/polar_order.dart';
import 'package:fluxora_desktop/features/orders/domain/repositories/orders_repository.dart';
import 'package:fluxora_desktop/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:fluxora_desktop/features/orders/presentation/cubit/orders_state.dart';

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrdersCubit>(
      create: (_) => OrdersCubit(
        repository: GetIt.I<OrdersRepository>(),
      )..load(),
      child: const _LicensesView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View
// ─────────────────────────────────────────────────────────────────────────────

class _LicensesView extends StatelessWidget {
  const _LicensesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Licenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<OrdersCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) => switch (state) {
          OrdersInitial() || OrdersLoading() =>
            const Center(child: CircularProgressIndicator()),
          OrdersLoaded(:final orders) => orders.isEmpty
              ? const _EmptyState()
              : _LoadedBody(orders: orders),
          OrdersFailure(:final message) => _ErrorBody(
              message: message,
              onRetry: () => context.read<OrdersCubit>().load(),
            ),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loaded state — summary banner + table
// ─────────────────────────────────────────────────────────────────────────────

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.orders});

  final List<PolarOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryBanner(total: orders.length),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _OrderTile(order: orders[i]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary banner
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withAlpha(50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vpn_key_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '$total license ${total == 1 ? 'key' : 'keys'} issued',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Copy a key to send to your customer.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single order tile
// ─────────────────────────────────────────────────────────────────────────────

class _OrderTile extends StatefulWidget {
  const _OrderTile({required this.order});

  final PolarOrder order;

  @override
  State<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<_OrderTile> {
  bool _copied = false;

  Future<void> _copyKey() async {
    await Clipboard.setData(ClipboardData(text: widget.order.licenseKey));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Color get _tierColor => switch (widget.order.tier) {
        'ultimate' => const Color(0xFFF59E0B),
        'pro' => AppColors.primary,
        _ => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────────────
            Row(
              children: [
                // Tier badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tierColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _tierColor.withAlpha(60)),
                  ),
                  child: Text(
                    'Fluxora ${order.tierLabel}',
                    style: AppTypography.caption.copyWith(
                      color: _tierColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order ${order.orderId}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(order.processedAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),

            if (order.customerEmail != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.mail_outline,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerEmail!,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // ── License key row ────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key,
                      size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      order.licenseKey,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? const Icon(Icons.check_circle_outline,
                            key: ValueKey('check'),
                            size: 20,
                            color: AppColors.success)
                        : IconButton(
                            key: const ValueKey('copy'),
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            color: AppColors.textSecondary,
                            tooltip: 'Copy to clipboard',
                            onPressed: _copyKey,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $h:$m';
    } catch (_) {
      return iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / Error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.vpn_key_outlined,
              color: AppColors.textMuted, size: 52),
          const SizedBox(height: 14),
          Text(
            'No licenses issued yet',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'License keys appear here after a successful Polar purchase.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
