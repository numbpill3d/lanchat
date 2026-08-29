import 'dart:convert';

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
      expect(restored.senderId, 'device-1');
      expect(restored.content, 'hello world');
      expect(restored.timestamp, msg.timestamp);
    });

    test('image round-trip preserves the mimeType and base64 payload', () {
      final payload = base64Encode(List<int>.generate(16, (i) => i));
      final msg = Message(
        type: MessageType.image,
        senderNickname: 'bob',
        senderId: 'device-2',
        content: payload,
        mimeType: 'image/png',
      );

      final restored = Message.fromJson(msg.toJson());

      expect(restored.type, MessageType.image);
      expect(restored.mimeType, 'image/png');
      expect(restored.content, payload);
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

    test('missing mimeType is tolerated', () {
      final json = {
        'id': 'abc',
        'type': 'image',
        'senderNickname': 'x',
        'senderId': 'y',
        'content': 'data',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final msg = Message.fromJson(json);
      expect(msg.mimeType, isNull);
    });

    test('json is single-line and parseable by the chat service', () {
      final msg = Message(
        type: MessageType.join,
        senderNickname: 'eve',
        senderId: 'device-3',
        content: 'eve joined',
      );
      final encoded = jsonEncode(msg.toJson());
      expect(encoded, isNot(contains('\n')));
      final restored = Message.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
      expect(restored.type, MessageType.join);
    });
  });
}
