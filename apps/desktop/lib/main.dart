import 'package:flutter/material.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_desktop/app.dart';
import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:fluxora_desktop/features/clients/presentation/screens/clients_screen.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';
import 'package:get_it/get_it.dart';
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
  // Hydrate cross-restart UI prefs from secure storage so the first
  // mount of the folder browser sees the operator's last-saved
  // filters / sort / view / density instead of the defaults.  Awaited
  // here (not fire-and-forget) so `runApp` doesn't paint a frame
  // with the wrong values before the storage read lands.
  await hydrateLibraryBrowsePrefs(GetIt.I<SecureStorage>());
  // Same hydration pattern for the Clients-table column widths so
  // the operator's resizes survive an app restart.
  await hydrateClientsColumnPrefs(GetIt.I<SecureStorage>());
  runApp(const FluxoraDesktopApp());
}
