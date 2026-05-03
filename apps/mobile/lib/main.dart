import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:fluxora_mobile/app.dart';
import 'package:fluxora_mobile/core/di/injector.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await setupInjector();
  // Phase A backfill: subscribe the router to ApiClient's unauthorized
  // stream so a dead bearer token mid-session reroutes to /reconnect.
  setupRouterUnauthorizedBridge();
  runApp(const FluxoraApp());
}
