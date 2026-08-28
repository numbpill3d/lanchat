import 'package:flutter_test/flutter_test.dart';
import 'package:lanchat/models/peer.dart';

void main() {
  group('Peer', () {
    test('round-trips constructor values', () {
      const peer = Peer(id: 'a', nickname: 'alice', host: '192.168.1.5', port: 5700);
      expect(peer.id, 'a');
      expect(peer.nickname, 'alice');
      expect(peer.host, '192.168.1.5');
      expect(peer.port, 5700);
    });
  });
}
