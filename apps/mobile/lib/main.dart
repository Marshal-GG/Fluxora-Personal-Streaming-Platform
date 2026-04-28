import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:fluxora_mobile/app.dart';
import 'package:fluxora_mobile/core/di/injector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await setupInjector();
  runApp(const FluxoraApp());
}
