import 'package:flutter_test/flutter_test.dart';
import 'package:lanchat/models/message.dart';

void main() {
  group('Message', () {
    test('serializes and deserializes round-trip', () {
      final msg = Message(
        type: MessageType.text,
        senderNickname: 'alice',
        senderId: 'device-1',
        content: 'hello world',
      );
      final json = msg.toJson();
      final restored = Message.fromJson(json);

      expect(restored.id, msg.id);
      expect(restored.type, MessageType.text);
      expect(restored.senderNickname, 'alice');
      expect(restored.content, 'hello world');
    });

    test('unknown type falls back to text', () {
      final json = {
        'id': 'abc',
        'type': 'bogus',
        'senderNickname': 'x',
        'senderId': 'y',
        'content': 'hi',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final msg = Message.fromJson(json);
      expect(msg.type, MessageType.text);
    });
  });
}
