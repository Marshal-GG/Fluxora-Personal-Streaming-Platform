import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:fluxora_mobile/app.dart';
import 'package:fluxora_mobile/core/di/injector.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/player/data/services/fluxora_audio_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await setupInjector();

  // Player polish round — start the audio_service foreground service so
  // the OS lockscreen / notification card / Bluetooth-headset transport
  // controls work and the player process survives backgrounding.  The
  // returned handler is registered with GetIt so PlayerCubit can call
  // `bind` after each successful `startStream`.
  final audioHandler = await AudioService.init<FluxoraAudioHandler>(
    builder: () => FluxoraAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'dev.marshalx.fluxora.playback',
      androidNotificationChannelName: 'Fluxora playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_stat_fluxora',
    ),
  );
  GetIt.I.registerSingleton<FluxoraAudioHandler>(audioHandler);

  // Phase A backfill: subscribe the router to ApiClient's unauthorized
  // stream so a dead bearer token mid-session reroutes to /reconnect.
  setupRouterUnauthorizedBridge();
  runApp(const FluxoraApp());
}
