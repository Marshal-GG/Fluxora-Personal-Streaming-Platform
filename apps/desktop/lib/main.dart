import 'package:flutter/material.dart';
import 'package:fluxora_desktop/app.dart';
import 'package:fluxora_desktop/core/di/injector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupInjector();
  runApp(const FluxoraDesktopApp());
}
