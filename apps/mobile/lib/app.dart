import 'package:flutter/material.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/shared/theme/app_theme.dart';
import 'package:fluxora_mobile/shared/widgets/background_gradient.dart';

class FluxoraApp extends StatelessWidget {
  const FluxoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fluxora',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      builder: (context, child) =>
          BackgroundGradient(child: child ?? const SizedBox.shrink()),
    );
  }
}
