import 'package:flutter_test/flutter_test.dart';
import 'package:lanchat/models/distributed_execution_plan.dart';
import 'package:lanchat/models/inference_envelope.dart';
import 'package:lanchat/models/message.dart';
import 'package:lanchat/models/node_capability.dart';
import 'package:lanchat/services/chat_service.dart';

void main() {
  test('node capability survives a protocol round-trip', () {
    const original = NodeCapability(
      nodeId: 'node-1',
      displayName: 'old-laptop',
      platform: 'linux',
      memoryGb: 8,
      models: ['tinyllama-1.1b-q4'],
      features: ['offline', 'text-generation'],
      batteryPercent: 74,
      thermalState: 'nominal',
    );

    final restored = NodeCapability.decode(original.encode());

    expect(restored.nodeId, original.nodeId);
    expect(restored.memoryGb, 8);
    expect(restored.models, contains('tinyllama-1.1b-q4'));
    expect(restored.features, contains('offline'));
    expect(restored.batteryPercent, 74);
    expect(restored.thermalState, 'nominal');
  });

  test('imported model keeps its executable local path', () {
    final mesh = ChatService();
    mesh.registerLocalModel('old-model.gguf',
        path: '/models/old-model.gguf', sizeBytes: 123);

    expect(mesh.preferredLocalModelPath, '/models/old-model.gguf');
    expect(mesh.localModelFiles.single.sizeBytes, 123);
    expect(mesh.localCapability.models, contains('old-model.gguf'));
    expect(mesh.localCapability.features, isNot(contains('text-generation')));

    mesh.registerLocalRuntime(true);
    expect(mesh.localCapability.features, contains('text-generation'));

    mesh.dispose();
  });

  test('distributed plan weights heterogeneous workers by tensor memory', () {
    final plan = DistributedExecutionPlan.fromCapabilities([
      const NodeCapability(
        nodeId: 'cpu',
        displayName: 'old laptop',
        platform: 'linux',
        memoryGb: 8,
        tensorMemoryGb: 4,
        models: ['model.gguf'],
        features: ['text-generation', 'distributed-entrypoint'],
        rpcEndpoint: '192.168.1.10:50052',
        supportsTensorSplit: true,
      ),
      const NodeCapability(
        nodeId: 'gpu',
        displayName: 'desktop gpu',
        platform: 'linux',
        memoryGb: 16,
        tensorMemoryGb: 12,
        models: ['model.gguf'],
        features: ['text-generation', 'distributed-entrypoint'],
        rpcEndpoint: '192.168.1.11:50052',
        supportsTensorSplit: true,
      ),
    ]);

    expect(plan, isNotNull);
    expect(plan!.rpcEndpoints, [
      '192.168.1.10:50052',
      '192.168.1.11:50052',
    ]);
    expect(plan.tensorSplit[0], closeTo(0.25, 0.0001));
    expect(plan.tensorSplit[1], closeTo(0.75, 0.0001));

    final restored = DistributedExecutionPlan.fromJson(plan.toJson());
    expect(restored.splitMode, 'layer');
    expect(restored.tensorSplit, plan.tensorSplit);
  });

  test('inference envelope carries the distributed plan to the entrypoint', () {
    const plan = DistributedExecutionPlan(
      rpcEndpoints: ['10.0.0.2:50052'],
      tensorSplit: [1],
    );
    const envelope = InferenceEnvelope(
      type: MessageType.inferenceRequest,
      requestId: 'request-1',
      targetId: 'host-1',
      prompt: 'hello',
      modelName: 'model.gguf',
      executionPlan: plan,
    );

    final restored = InferenceEnvelope.decode(
        MessageType.inferenceRequest, envelope.encode(),
        senderId: 'phone');
    expect(restored.senderId, 'phone');
    expect(restored.modelName, 'model.gguf');
    expect(restored.executionPlan!.rpcEndpoints, ['10.0.0.2:50052']);
    expect(restored.executionPlan!.tensorSplit, [1]);
  });
}
