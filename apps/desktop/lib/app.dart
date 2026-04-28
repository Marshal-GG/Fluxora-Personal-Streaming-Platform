import 'package:flutter/material.dart';
import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/shared/theme/app_theme.dart';

class FluxoraDesktopApp extends StatelessWidget {
  const FluxoraDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fluxora',
      theme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
