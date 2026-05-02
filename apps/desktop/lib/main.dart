import 'package:flutter/material.dart';
import 'package:fluxora_desktop/app.dart';
import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  // Frameless chrome — the v2 desktop redesign provides its own 36 px titlebar
  // (FluxTitlebar in flux_shell.dart) with logo, help/bell buttons, and window
  // controls. Min size matches the WM_GETMINMAXINFO floor in
  // windows/runner/win32_window.cpp (1332×720 logical px).
  const windowOptions = WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(1332, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await setupInjector();
  runApp(const FluxoraDesktopApp());
}
