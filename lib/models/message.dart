import 'package:uuid/uuid.dart';

enum MessageType { text, image, join, leave }

class Message {
  static const maxTextLength = 16 * 1024;
  static const maxImagePayloadLength = 8 * 1024 * 1024;

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
        timestamp = DateTime.fromMillisecondsSinceEpoch(
          (timestamp ?? DateTime.now()).millisecondsSinceEpoch,
          isUtc: timestamp?.isUtc ?? false,
        );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'senderNickname': senderNickname,
        'senderId': senderId,
        'content': content,
        if (mimeType != null) 'mimeType': mimeType,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory Message.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('message field "$key" is invalid');
      }
      return value;
    }

    final content = requiredString('content');
    final typeName = json['type'];
    final type = MessageType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => MessageType.text,
    );
    final timestamp = json['timestamp'];
    if (timestamp is! int) {
      throw const FormatException('message timestamp is invalid');
    }
    if (content.length >
        (type == MessageType.image ? maxImagePayloadLength : maxTextLength)) {
      throw const FormatException('message content is too large');
    }

    return Message(
      id: requiredString('id'),
      type: type,
      senderNickname: requiredString('senderNickname'),
      senderId: requiredString('senderId'),
      content: content,
      mimeType: json['mimeType'] is String ? json['mimeType'] as String : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}
