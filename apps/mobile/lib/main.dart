import 'package:flutter/material.dart';
import 'package:fluxora_mobile/app.dart';
import 'package:fluxora_mobile/core/di/injector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupInjector();
  runApp(const FluxoraApp());
}
