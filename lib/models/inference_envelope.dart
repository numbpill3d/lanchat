import 'dart:convert';

import 'message.dart';

class InferenceEnvelope {
  final MessageType type;
  final String requestId;
  final String? senderId;
  final String? targetId;
  final String? prompt;
  final String? chunk;
  final String? error;

  const InferenceEnvelope({
    required this.type,
    required this.requestId,
    this.senderId,
    this.targetId,
    this.prompt,
    this.chunk,
    this.error,
  });

  String encode() => jsonEncode({
        'requestId': requestId,
        if (targetId != null) 'targetId': targetId,
        if (prompt != null) 'prompt': prompt,
        if (chunk != null) 'chunk': chunk,
        if (error != null) 'error': error,
      });

  factory InferenceEnvelope.decode(MessageType type, String value,
      {String? senderId}) {
    final json = jsonDecode(value);
    if (json is! Map<String, dynamic> || json['requestId'] is! String) {
      throw const FormatException('invalid inference envelope');
    }
    return InferenceEnvelope(
      type: type,
      requestId: json['requestId'] as String,
      senderId: senderId,
      targetId: json['targetId'] as String?,
      prompt: json['prompt'] as String?,
      chunk: json['chunk'] as String?,
      error: json['error'] as String?,
    );
  }
}
