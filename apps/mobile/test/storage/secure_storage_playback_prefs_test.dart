/// Round-trip + widget tests for the M3 playback prefs (settings
/// remediation §4 M3).
///
/// Two layers of coverage:
///   * Unit — the four new [SecureStorage] keys round-trip through a
///     map-backed [FlutterSecureStorage] fake.  Defaults documented in
///     `secure_storage.dart` are asserted explicitly so a future tweak
///     of "default true" → "default false" can't slip past CI.
///   * Widget — pumps the [PlaybackPrefsScreen], waits for the initial
///     async read to settle, asserts all five row labels render, taps
///     the Wi-Fi-only switch, and verifies the persisted value flips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluxora_mobile/features/profile/presentation/screens/playback_prefs_screen.dart';

/// Map-backed fake of [FlutterSecureStorage].  Only the four entry
/// points [SecureStorage] uses are implemented (read / write / delete /
/// deleteAll); every other call is `noSuchMethod`'d via [Mock].  Keeping
/// the implementation in-test means the round-trip exercises the real
/// [SecureStorage] class, not a stubbed pair.
class _FakeFlutterSecureStorage extends Mock implements FlutterSecureStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.clear();
  }
}

void main() {
  group('SecureStorage — playback prefs round-trip', () {
    late _FakeFlutterSecureStorage fake;
    late SecureStorage storage;

    setUp(() {
      fake = _FakeFlutterSecureStorage();
      storage = SecureStorage(fake);
    });

    test('wifiOnlyStreaming defaults to false, round-trips, deleteAll clears',
        () async {
      expect(await storage.getWifiOnlyStreaming(), isFalse);
      await storage.setWifiOnlyStreaming(true);
      expect(await storage.getWifiOnlyStreaming(), isTrue);
      await storage.setWifiOnlyStreaming(false);
      expect(await storage.getWifiOnlyStreaming(), isFalse);
      await storage.setWifiOnlyStreaming(true);
      await storage.deleteAll();
      expect(await storage.getWifiOnlyStreaming(), isFalse);
    });

    test(
        'maxStreamingQuality defaults to "auto", round-trips each allowed value',
        () async {
      expect(await storage.getMaxStreamingQuality(),
          SecureStorage.maxStreamingQualityDefault);
      for (final v in const ['auto', '1080p', '720p', '480p']) {
        await storage.setMaxStreamingQuality(v);
        expect(await storage.getMaxStreamingQuality(), v);
      }
      await storage.deleteAll();
      expect(await storage.getMaxStreamingQuality(), 'auto');
    });

    test('maxStreamingQuality rejects out-of-range values', () async {
      expect(
        () => storage.setMaxStreamingQuality('4k'),
        throwsA(isA<ArgumentError>()),
      );
      // Old persisted enum that's no longer in the allow-list should
      // round-trip back to the default rather than poison the player.
      await fake.write(key: 'max_streaming_quality', value: 'legacy_8k');
      expect(await storage.getMaxStreamingQuality(), 'auto');
    });

    test('autoplayNext defaults to true, round-trips, deleteAll resets',
        () async {
      expect(await storage.getAutoplayNext(), isTrue);
      await storage.setAutoplayNext(false);
      expect(await storage.getAutoplayNext(), isFalse);
      await storage.setAutoplayNext(true);
      expect(await storage.getAutoplayNext(), isTrue);
      await storage.setAutoplayNext(false);
      await storage.deleteAll();
      // Default-true means a fresh post-deleteAll read is true again.
      expect(await storage.getAutoplayNext(), isTrue);
    });

    test('subtitlesDefaultOn defaults to false, round-trips', () async {
      expect(await storage.getSubtitlesDefaultOn(), isFalse);
      await storage.setSubtitlesDefaultOn(true);
      expect(await storage.getSubtitlesDefaultOn(), isTrue);
      await storage.setSubtitlesDefaultOn(false);
      expect(await storage.getSubtitlesDefaultOn(), isFalse);
      await storage.setSubtitlesDefaultOn(true);
      await storage.deleteAll();
      expect(await storage.getSubtitlesDefaultOn(), isFalse);
    });
  });

  group('PlaybackPrefsScreen — widget pump', () {
    late _FakeFlutterSecureStorage fake;
    late SecureStorage storage;

    setUp(() {
      // Each test gets a fresh GetIt + fresh storage so toggle order
      // doesn't leak across cases.
      fake = _FakeFlutterSecureStorage();
      storage = SecureStorage(fake);
      if (GetIt.I.isRegistered<SecureStorage>()) {
        GetIt.I.unregister<SecureStorage>();
      }
      GetIt.I.registerSingleton<SecureStorage>(storage);
    });

    tearDown(() {
      if (GetIt.I.isRegistered<SecureStorage>()) {
        GetIt.I.unregister<SecureStorage>();
      }
    });

    Widget harness() => const MaterialApp(
          home: PlaybackPrefsScreen(),
        );

    testWidgets('renders all 5 rows after initial async read settles',
        (tester) async {
      await tester.pumpWidget(harness());
      // Two pumps: first builds the screen with `value: null` for every
      // row (loading), second flushes the Future.wait callback that
      // hydrates the toggles.
      await tester.pumpAndSettle();

      expect(find.text('Background playback'), findsOneWidget);
      expect(find.text('Wi-Fi only streaming'), findsOneWidget);
      expect(find.text('Max streaming quality'), findsOneWidget);
      expect(find.text('Autoplay next episode'), findsOneWidget);
      expect(find.text('Subtitles on by default'), findsOneWidget);
    });

    testWidgets('tapping Wi-Fi-only switch persists to SecureStorage',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // Default false → flipping should produce a true read.
      expect(await storage.getWifiOnlyStreaming(), isFalse);

      // Tap the row label rather than the platform switch widget — the
      // row's onTap also flips the value and is far more stable across
      // Switch.adaptive's iOS / Android variants.
      await tester.tap(find.text('Wi-Fi only streaming'));
      await tester.pumpAndSettle();

      expect(await storage.getWifiOnlyStreaming(), isTrue);
    });
  });
}
