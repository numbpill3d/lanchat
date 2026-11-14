import 'package:flutter_test/flutter_test.dart';
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
}
