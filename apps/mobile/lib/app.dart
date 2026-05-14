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
      builder: (context, child) {
        // M14 polish: clamp the system text scaler to 1.3x so a user with
        // extra-large system font size doesn't blow out our tight typographic
        // grid (mobile redesign plan §7 M14).  The clamp wraps every route
        // — including the player chrome and the bottom-tab shell.  Keep the
        // existing BackgroundGradient inside so the gradient still paints
        // edge-to-edge behind the clamped child.
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: BackgroundGradient(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
