import 'package:flutter_test/flutter_test.dart';
import 'package:lanchat/models/peer.dart';
import 'package:lanchat/models/session_handshake.dart';

void main() {
  group('Peer', () {
    test('round-trips constructor values', () {
      const peer = Peer(
        id: 'a',
        nickname: 'alice',
        host: '192.168.1.5',
        port: 5700,
        authToken: 'session-token',
      );
      expect(peer.id, 'a');
      expect(peer.nickname, 'alice');
      expect(peer.host, '192.168.1.5');
      expect(peer.port, 5700);
      expect(peer.authToken, 'session-token');
    });
  });

  test('session handshake round-trips and rejects malformed content', () {
    final payload = SessionHandshake.encode(
      nickname: 'old-laptop',
      token: 'session-token',
    );
    expect(SessionHandshake.tokenFrom(payload), 'session-token');
    expect(SessionHandshake.tokenFrom('not-json'), isNull);
    expect(SessionHandshake.tokenFrom('{"nickname":"missing"}'), isNull);
  });
}
