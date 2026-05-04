import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_mobile/features/connect/domain/pairing_uri.dart';

void main() {
  group('PairingUri.tryParse', () {
    test('parses canonical fluxora://pair?host=&port=&name=', () {
      final s = PairingUri.tryParse(
        'fluxora://pair?host=192.168.0.162&port=8000&name=Marshal-PC',
      );
      expect(s, isNotNull);
      expect(s!.ip, '192.168.0.162');
      expect(s.port, 8000);
      expect(s.name, 'Marshal-PC');
    });

    test('falls back to host as name when name is missing', () {
      final s = PairingUri.tryParse(
        'fluxora://pair?host=10.0.0.5&port=8000',
      );
      expect(s, isNotNull);
      expect(s!.name, '10.0.0.5');
    });

    test('parses plain http://host:port URLs', () {
      final s = PairingUri.tryParse('http://192.168.1.10:8000');
      expect(s, isNotNull);
      expect(s!.ip, '192.168.1.10');
      expect(s.port, 8000);
    });

    test('rejects empty input', () {
      expect(PairingUri.tryParse(''), isNull);
      expect(PairingUri.tryParse('   '), isNull);
    });

    test('rejects unknown schemes', () {
      expect(PairingUri.tryParse('plex://pair?host=1.2.3.4'), isNull);
      expect(PairingUri.tryParse('ftp://1.2.3.4:8000'), isNull);
    });

    test('rejects fluxora URIs without host param', () {
      expect(PairingUri.tryParse('fluxora://pair?port=8000'), isNull);
      expect(
        PairingUri.tryParse('fluxora://pair?host=&port=8000'),
        isNull,
      );
    });

    test('rejects fluxora URIs with bad port', () {
      expect(
        PairingUri.tryParse('fluxora://pair?host=1.2.3.4&port=0'),
        isNull,
      );
      expect(
        PairingUri.tryParse('fluxora://pair?host=1.2.3.4&port=70000'),
        isNull,
      );
      expect(
        PairingUri.tryParse('fluxora://pair?host=1.2.3.4&port=abc'),
        isNull,
      );
    });

    test('rejects fluxora://other-host', () {
      expect(
        PairingUri.tryParse('fluxora://login?host=1.2.3.4&port=8000'),
        isNull,
      );
    });
  });

  group('PairingUri.build', () {
    test('emits a canonical URI that round-trips through tryParse', () {
      final raw = PairingUri.build(
        hostIp: '192.168.0.162',
        port: 8000,
        serverName: 'Marshal-PC',
      );
      expect(raw, contains('fluxora://pair'));
      expect(raw, contains('host=192.168.0.162'));
      expect(raw, contains('port=8000'));
      // `Uri` URL-encodes the dash-as-it-is — `-` is a sub-delim, kept literal.
      expect(raw, contains('name=Marshal-PC'));

      final parsed = PairingUri.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.ip, '192.168.0.162');
      expect(parsed.port, 8000);
      expect(parsed.name, 'Marshal-PC');
    });

    test('omits the name param when serverName is null/empty', () {
      final a = PairingUri.build(hostIp: '1.2.3.4', port: 8000);
      expect(a, isNot(contains('name=')));
      final b =
          PairingUri.build(hostIp: '1.2.3.4', port: 8000, serverName: '');
      expect(b, isNot(contains('name=')));
    });
  });
}
