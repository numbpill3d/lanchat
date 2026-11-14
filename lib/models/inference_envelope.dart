import 'dart:convert';

import 'message.dart';
import 'distributed_execution_plan.dart';

class InferenceEnvelope {
  final MessageType type;
  final String requestId;
  final String? senderId;
  final String? targetId;
  final String? prompt;
  final String? modelName;
  final String? chunk;
  final String? error;
  final DistributedExecutionPlan? executionPlan;

  const InferenceEnvelope({
    required this.type,
    required this.requestId,
    this.senderId,
    this.targetId,
    this.prompt,
    this.modelName,
    this.chunk,
    this.error,
    this.executionPlan,
  });

  String encode() => jsonEncode({
        'requestId': requestId,
        if (targetId != null) 'targetId': targetId,
        if (prompt != null) 'prompt': prompt,
        if (modelName != null) 'modelName': modelName,
        if (chunk != null) 'chunk': chunk,
        if (error != null) 'error': error,
        if (executionPlan != null) 'executionPlan': executionPlan!.toJson(),
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
      modelName: json['modelName'] as String?,
      chunk: json['chunk'] as String?,
      error: json['error'] as String?,
      executionPlan: json['executionPlan'] is Map<String, dynamic>
          ? DistributedExecutionPlan.fromJson(
              json['executionPlan'] as Map<String, dynamic>)
          : null,
    );
  }
}
