import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/api_exception.dart';

void main() {
  group('ApiClient dual-base resolution', () {
    test('returns local base URL when LAN check is true', () async {
      final client = ApiClient(
        localBaseUrl: 'http://192.168.1.10:8080',
        remoteBaseUrl: 'https://fluxora-api.example.dev',
        lanCheck: (_) async => true,
      );
      expect(
        await client.resolveBaseUrlForTest(),
        'http://192.168.1.10:8080',
      );
    });

    test('returns remote base URL when LAN check is false', () async {
      final client = ApiClient(
        localBaseUrl: 'http://192.168.1.10:8080',
        remoteBaseUrl: 'https://fluxora-api.example.dev',
        lanCheck: (_) async => false,
      );
      expect(
        await client.resolveBaseUrlForTest(),
        'https://fluxora-api.example.dev',
      );
    });

    test('falls back to local when remote is null and LAN check is true',
        () async {
      final client = ApiClient(
        localBaseUrl: 'http://192.168.1.10:8080',
        lanCheck: (_) async => true,
      );
      expect(
        await client.resolveBaseUrlForTest(),
        'http://192.168.1.10:8080',
      );
    });

    test('throws NoRemoteConfiguredException when off-LAN with no remote',
        () async {
      final client = ApiClient(
        localBaseUrl: 'http://192.168.1.10:8080',
        lanCheck: (_) async => false,
      );
      expect(
        client.resolveBaseUrlForTest(),
        throwsA(isA<NoRemoteConfiguredException>()),
      );
    });

    test('throws when neither URL is configured', () async {
      final client = ApiClient(lanCheck: (_) async => true);
      expect(
        client.resolveBaseUrlForTest(),
        throwsA(isA<NoRemoteConfiguredException>()),
      );
    });

    test('returns remote when only remote is configured', () async {
      final client = ApiClient(
        remoteBaseUrl: 'https://fluxora-api.example.dev',
        lanCheck: (_) async => true,
      );
      expect(
        await client.resolveBaseUrlForTest(),
        'https://fluxora-api.example.dev',
      );
    });

    test('configure() updates both URLs and lanCheck', () async {
      final client = ApiClient(
        localBaseUrl: 'http://192.168.1.10:8080',
        lanCheck: (_) async => true,
      );
      client.configure(
        localBaseUrl: 'http://10.0.0.5:8080',
        remoteBaseUrl: 'https://fluxora-api.example.dev',
        lanCheck: (_) async => false,
      );
      expect(client.localBaseUrl, 'http://10.0.0.5:8080');
      expect(client.remoteBaseUrl, 'https://fluxora-api.example.dev');
      expect(
        await client.resolveBaseUrlForTest(),
        'https://fluxora-api.example.dev',
      );
    });

    test('clearRemoteBaseUrl removes the remote URL', () async {
      final client = ApiClient(
        localBaseUrl: 'http://192.168.1.10:8080',
        remoteBaseUrl: 'https://fluxora-api.example.dev',
        lanCheck: (_) async => false,
      );
      client.clearRemoteBaseUrl();
      expect(client.remoteBaseUrl, isNull);
      expect(
        client.resolveBaseUrlForTest(),
        throwsA(isA<NoRemoteConfiguredException>()),
      );
    });

    test('legacy baseUrl param maps to localBaseUrl', () async {
      // ignore: deprecated_member_use_from_same_package
      final client = ApiClient(
        // ignore: deprecated_member_use_from_same_package
        baseUrl: 'http://192.168.1.10:8080',
        lanCheck: (_) async => true,
      );
      expect(client.localBaseUrl, 'http://192.168.1.10:8080');
      expect(
        await client.resolveBaseUrlForTest(),
        'http://192.168.1.10:8080',
      );
    });
  });
}
