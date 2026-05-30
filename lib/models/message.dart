import 'package:uuid/uuid.dart';

enum MessageType { text, image, join, leave }

class Message {
  final String id;
  final MessageType type;
  final String senderNickname;
  final String senderId;
  final String content; // text, or base64-encoded image bytes
  final String? mimeType;
  final DateTime timestamp;

  Message({
    String? id,
    required this.type,
    required this.senderNickname,
    required this.senderId,
    required this.content,
    this.mimeType,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'senderNickname': senderNickname,
        'senderId': senderId,
        'content': content,
        if (mimeType != null) 'mimeType': mimeType,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        type: MessageType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MessageType.text,
        ),
        senderNickname: json['senderNickname'] as String,
        senderId: json['senderId'] as String,
        content: json['content'] as String,
        mimeType: json['mimeType'] as String?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      );
}
