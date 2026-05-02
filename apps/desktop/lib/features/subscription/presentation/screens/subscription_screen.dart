/// Subscription screen — redesigned M7 surface.
///
/// Matches `docs/11_design/desktop_prototype/app/screens/subscription.jsx`
/// (Plans & Pricing tab) and `app/pages/billing.jsx` (Billing History tab).
/// The Manage tab opens the Polar customer portal URL or copies it to
/// clipboard when the desktop cannot launch a browser directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/polar_order.dart';

import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:fluxora_desktop/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:fluxora_desktop/features/orders/presentation/cubit/orders_state.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<OrdersCubit>(
          create: (_) => getIt<OrdersCubit>()..load(),
        ),
        BlocProvider<SettingsCubit>(
          create: (_) => getIt<SettingsCubit>()..loadSettings(),
        ),
      ],
      child: const _SubscriptionView(),
    );
  }
}

// ── Main view ─────────────────────────────────────────────────────────────────

class _SubscriptionView extends StatefulWidget {
  const _SubscriptionView();

  @override
  State<_SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<_SubscriptionView> {
  String _tab = 'plans';

  static const _tabs = [
    FluxTab(id: 'plans', label: 'Plans & Pricing', icon: Icons.workspace_premium_outlined),
    FluxTab(id: 'billing', label: 'Billing History', icon: Icons.receipt_long_outlined),
    FluxTab(id: 'manage', label: 'Manage', icon: Icons.manage_accounts_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Subscription',
            subtitle: 'Your Fluxora plan and billing',
          ),
          FluxTabBar(
            tabs: _tabs,
            activeId: _tab,
            onChange: (id) => setState(() => _tab = id),
          ),
          const SizedBox(height: AppSpacing.s20),
          Expanded(
            child: switch (_tab) {
              'billing' => const _BillingTab(),
              'manage' => const _ManageTab(),
              _ => const _PlansTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Plans & Pricing
// ─────────────────────────────────────────────────────────────────────────────

class _PlansTab extends StatelessWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan cards row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PlanCard(
                    tier: 'Free',
                    subtitle: 'Get started with basics',
                    price: r'$0',
                    color: Color(0xFF94A3B8),
                    icon: Icons.person_outline,
                    features: [
                      (text: 'Stream over LAN', enabled: true),
                      (text: 'Up to 2 clients', enabled: true),
                      (text: '1080p streaming', enabled: true),
                      (text: '5 libraries', enabled: true),
                      (text: 'Internet streaming', enabled: false),
                      (text: 'Hardware transcoding', enabled: false),
                      (text: 'Priority support', enabled: false),
                    ],
                    cta: 'Current Plan',
                    isCurrent: true,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _PlanCard(
                    tier: 'Plus',
                    subtitle: 'For personal use',
                    price: r'$4.99',
                    color: Color(0xFFA855F7),
                    icon: Icons.bolt_outlined,
                    popular: true,
                    features: [
                      (text: 'Everything in Free', enabled: true),
                      (text: 'Stream over Internet', enabled: true),
                      (text: 'Up to 5 clients', enabled: true),
                      (text: '1080p Full HD', enabled: true),
                      (text: 'Hardware transcoding', enabled: true),
                      (text: '50 libraries', enabled: true),
                      (text: 'Email support', enabled: true),
                    ],
                    cta: 'Upgrade to Plus',
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _PlanCard(
                    tier: 'Pro',
                    subtitle: 'For power users',
                    price: r'$9.99',
                    color: Color(0xFF3B82F6),
                    icon: Icons.workspace_premium_outlined,
                    features: [
                      (text: 'Everything in Plus', enabled: true),
                      (text: 'Up to 20 clients', enabled: true),
                      (text: '4K Ultra HD', enabled: true),
                      (text: 'Advanced transcoding', enabled: true),
                      (text: 'Unlimited libraries', enabled: true),
                      (text: 'Custom access control', enabled: true),
                      (text: 'Activity & analytics', enabled: true),
                    ],
                    cta: 'Upgrade to Pro',
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _PlanCard(
                    tier: 'Ultimate',
                    subtitle: 'For the ultimate experience',
                    price: r'$19.99',
                    color: Color(0xFFEC4899),
                    icon: Icons.diamond_outlined,
                    features: [
                      (text: 'Everything in Pro', enabled: true),
                      (text: 'Unlimited clients', enabled: true),
                      (text: '4K + HDR streaming', enabled: true),
                      (text: 'AI transcoding optimization', enabled: true),
                      (text: 'Advanced user roles', enabled: true),
                      (text: 'Real-time sync', enabled: true),
                      (text: 'Dedicated support', enabled: true),
                    ],
                    cta: 'Upgrade to Ultimate',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          // Feature comparison table
          _ComparisonTable(),
          SizedBox(height: AppSpacing.s28),
        ],
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

typedef _Feature = ({String text, bool enabled});

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.subtitle,
    required this.price,
    required this.color,
    required this.icon,
    required this.features,
    required this.cta,
    this.popular = false,
    this.isCurrent = false,
  });

  final String tier;
  final String subtitle;
  final String price;
  final Color color;
  final IconData icon;
  final List<_Feature> features;
  final String cta;
  final bool popular;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: popular
                ? const Color(0x1AA855F7)
                : const Color(0xB3140C26),
            border: Border.all(
              color: popular
                  ? const Color(0x80A855F7)
                  : const Color(0x0FFFFFFF),
              width: popular ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: popular
                ? const [
                    BoxShadow(
                      color: Color(0x2EA855F7),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 14),
              // Tier name
              Text(
                tier,
                style: AppTypography.h2.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textDim,
                ),
              ),
              const SizedBox(height: 14),
              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: AppTypography.displayV2.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02,
                      color: popular
                          ? Colors.white
                          : AppColors.textBright,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/month',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Features
              for (final f in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        f.enabled ? Icons.check : Icons.close,
                        size: 13,
                        color: f.enabled
                            ? AppColors.violet
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.text,
                          style: AppTypography.bodySmall.copyWith(
                            color: f.enabled
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              // CTA
              if (isCurrent)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    cta,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedV2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FluxButton(
                    variant: popular
                        ? FluxButtonVariant.primary
                        : FluxButtonVariant.outline,
                    fullWidth: true,
                    onPressed: () {},
                    child: Text(cta),
                  ),
                ),
            ],
          ),
        ),
        // "Most Popular" badge
        if (popular)
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  'MOST POPULAR',
                  style: AppTypography.eyebrow.copyWith(
                    fontSize: 10,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Comparison table ──────────────────────────────────────────────────────────

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  static const _rows = [
    ['LAN Streaming', true, true, true, true],
    ['Internet Streaming', false, true, true, true],
    ['Max Clients', '2', '5', '20', 'Unlimited'],
    ['Max Quality', '1080p', '1080p', '4K', '4K + HDR'],
    ['Hardware Transcoding', false, true, true, true],
    ['Support', 'Community', 'Email', 'Priority', 'Dedicated'],
  ];

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        children: [
          // Header
          const _TableRow(
            cells: ['Compare Plans', 'Free', 'Plus', 'Pro', 'Ultimate'],
            isHeader: true,
          ),
          for (int i = 0; i < _rows.length; i++)
            _ComparisonRow(rowData: _rows[i]),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.isHeader = false});
  final List<String> cells;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isHeader
            ? null
            : const Border(
                top: BorderSide(color: Color(0x08FFFFFF)),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Text(
                cells[0],
                style: isHeader
                    ? AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                      )
                    : AppTypography.bodySmall.copyWith(
                        color: AppColors.textMutedV2,
                      ),
              ),
            ),
          ),
          for (int i = 1; i < cells.length; i++)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  cells[i],
                  style: isHeader
                      ? AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBright,
                        )
                      : AppTypography.bodySmall.copyWith(
                          color: AppColors.textBody,
                          fontWeight: FontWeight.w500,
                        ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.rowData});
  final List<Object> rowData;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x08FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                rowData[0] as String,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMutedV2,
                ),
              ),
            ),
          ),
          for (int i = 1; i < rowData.length; i++)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _CellValue(value: rowData[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _CellValue extends StatelessWidget {
  const _CellValue({required this.value});
  final Object value;

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      final ok = value as bool;
      return Center(
        child: Icon(
          ok ? Icons.check : Icons.remove,
          size: 14,
          color: ok ? AppColors.violet : const Color(0xFF475569),
        ),
      );
    }
    return Text(
      value.toString(),
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.textBody,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Billing History
// ─────────────────────────────────────────────────────────────────────────────

class _BillingTab extends StatelessWidget {
  const _BillingTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        return switch (state) {
          OrdersInitial() || OrdersLoading() => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFA855F7),
              ),
            ),
          OrdersFailure(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textMutedV2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FluxButton(
                    variant: FluxButtonVariant.outline,
                    onPressed: () =>
                        context.read<OrdersCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          OrdersLoaded(:final orders) => _BillingContent(orders: orders),
        };
      },
    );
  }
}

class _BillingContent extends StatelessWidget {
  const _BillingContent({required this.orders});
  final List<PolarOrder> orders;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat tiles
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Total Orders ${orders.length}',
                  child: StatTile(
                    icon: Icons.credit_card_outlined,
                    label: 'Total Orders',
                    value: '${orders.length}',
                    sub: 'All time',
                    color: AppColors.violet,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  label: 'Active Licenses ${orders.length}',
                  child: StatTile(
                    icon: Icons.check_circle_outline,
                    label: 'Active Licenses',
                    value: '${orders.length}',
                    sub: 'Issued',
                    color: const Color(0xFF10B981),
                    accent: const Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  label:
                      'Current Tier ${orders.isNotEmpty ? orders.first.tierLabel : "Free"}',
                  child: StatTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Current Tier',
                    value: orders.isNotEmpty
                        ? orders.first.tierLabel
                        : 'Free',
                    sub: 'Active',
                    color: const Color(0xFF3B82F6),
                    accent: AppColors.textMutedV2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  label:
                      'Last Order ${orders.isNotEmpty ? _shortDate(orders.first.processedAt) : "none"}',
                  child: StatTile(
                    icon: Icons.history_outlined,
                    label: 'Last Order',
                    value: orders.isNotEmpty
                        ? _shortDate(orders.first.processedAt)
                        : '—',
                    sub: 'Most recent',
                    color: const Color(0xFFF59E0B),
                    accent: AppColors.textMutedV2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Invoice table
          FluxCard(
            padding: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Text(
                    'Order History',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBright,
                    ),
                  ),
                ),
                // Column headers
                _OrderTableHeader(),
                if (orders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No orders found.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                  )
                else
                  for (final order in orders) _OrderRow(order: order),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s28),
        ],
      ),
    );
  }

  static String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length > 10 ? iso.substring(0, 10) : iso;
    }
  }
}

class _OrderTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Color(0xFF94A3B8),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0x08FFFFFF)),
          bottom: BorderSide(color: Color(0x08FFFFFF)),
        ),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Order ID', style: style)),
          Expanded(flex: 2, child: Text('Date', style: style)),
          Expanded(flex: 2, child: Text('Tier', style: style)),
          Expanded(flex: 4, child: Text('License Key', style: style)),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final PolarOrder order;

  static String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length > 10 ? iso.substring(0, 10) : iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x08FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              order.orderId,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _shortDate(order.processedAt),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Pill(
              order.tierLabel,
              color: PillColor.purple,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              order.licenseKey,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Copy license key button
          SizedBox(
            width: 40,
            child: _CopyBtn(text: order.licenseKey),
          ),
        ],
      ),
    );
  }
}

class _CopyBtn extends StatefulWidget {
  const _CopyBtn({required this.text});
  final String text;

  @override
  State<_CopyBtn> createState() => _CopyBtnState();
}

class _CopyBtnState extends State<_CopyBtn> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _copied ? 'Copied!' : 'Copy license key',
      child: GestureDetector(
        onTap: _copy,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _copied
                  ? const Color(0x1A10B981)
                  : const Color(0x08FFFFFF),
              border: Border.all(
                color: _copied
                    ? const Color(0x4D10B981)
                    : const Color(0x0DFFFFFF),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _copied ? Icons.check : Icons.copy_outlined,
              size: 12,
              color: _copied
                  ? const Color(0xFF10B981)
                  : AppColors.textMutedV2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Manage Subscription
// ─────────────────────────────────────────────────────────────────────────────

class _ManageTab extends StatelessWidget {
  const _ManageTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final tier = state is SettingsLoaded ? state.tier : 'free';
        final tierLabel = switch (tier) {
          'plus' => 'Plus',
          'pro' => 'Pro',
          'ultimate' => 'Ultimate',
          _ => 'Free',
        };

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current plan summary
              FluxCard(
                padding: 16,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bolt_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$tierLabel Plan',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active subscription',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMutedV2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Pill('Active', color: PillColor.success),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Open Customer Portal
              FluxCard(
                padding: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Portal',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage your subscription, update payment methods, and view invoices through the Polar customer portal.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMutedV2,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PortalButton(),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Actions (all deferred to portal)
              FluxCard(
                padding: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Actions',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final action in const [
                      (
                        icon: Icons.arrow_upward_outlined,
                        label: 'Upgrade Plan',
                        sub: 'Switch to a higher tier',
                        color: Color(0xFF3B82F6),
                      ),
                      (
                        icon: Icons.cancel_outlined,
                        label: 'Cancel Subscription',
                        sub: 'Active until end of billing period',
                        color: Color(0xFFF87171),
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ActionRow(
                          icon: action.icon,
                          label: action.label,
                          sub: action.sub,
                          color: action.color,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x0FF59E0B),
                  border: Border.all(color: const Color(0x33F59E0B)),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cancellations take effect at the end of your current billing period. You\'ll keep all plan features until then.',
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFFFBBF24),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s28),
            ],
          ),
        );
      },
    );
  }
}

class _PortalButton extends StatefulWidget {
  @override
  State<_PortalButton> createState() => _PortalButtonState();
}

class _PortalButtonState extends State<_PortalButton> {
  bool _loading = false;
  String? _status;

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _status = null;
    });
    final url = await context.read<OrdersCubit>().openPortal();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = url != null
          ? 'Portal URL copied to clipboard!'
          : 'Portal URL not configured on server.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FluxButton(
          variant: FluxButtonVariant.primary,
          icon: Icons.open_in_new_outlined,
          onPressed: _loading ? null : _open,
          child: Text(_loading ? 'Loading…' : 'Open Customer Portal'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 8),
          Text(
            _status!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {},  // TODO: open portal
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0x0AFFFFFF)
                : const Color(0x05FFFFFF),
            border: Border.all(color: const Color(0x0DFFFFFF)),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.sub,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textDim,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 11,
                color: Color(0xFF475569),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
