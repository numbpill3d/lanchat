import 'package:flutter_test/flutter_test.dart';
import 'package:lanchat/models/distributed_execution_plan.dart';
import 'package:lanchat/services/inference_service.dart';

void main() {
  test('offline adapter streams an honest local fallback', () async {
    final chunks = <String>[];
    final adapter = OfflineFallbackAdapter();

    final result = await adapter.generate('hello', onChunk: chunks.add);

    expect(chunks, isNotEmpty);
    expect(result, contains('No cloud connection'));
    expect(adapter.modelName, 'fallback-router');
  });

  test('native-first adapter degrades when no platform runtime is registered',
      () async {
    final chunks = <String>[];
    final adapter = NativeFirstAdapter();

    final result = await adapter.generate('hello', onChunk: chunks.add);

    expect(result, contains('No cloud connection'));
    expect(chunks, isNotEmpty);
  });

  test('native runtime status is false without a platform implementation',
      () async {
    expect(await NativeInferenceAdapter().isAvailable(), isFalse);
  });

  test('llama.cpp command adapter streams a local worker response', () async {
    final chunks = <String>[];
    final adapter = LlamaCliAdapter(executable: '/bin/echo');

    expect(await adapter.isAvailable(), isTrue);
    final result = await adapter.generate(
      'hello mesh',
      modelPath: '/tmp/example.gguf',
      onChunk: chunks.add,
    );

    expect(result, contains('/tmp/example.gguf'));
    expect(chunks, isNotEmpty);
  });

  test('legacy llama.cpp binaries are not advertised as RPC entrypoints',
      () async {
    final adapter = LlamaCliAdapter(executable: '/bin/echo');

    expect(await adapter.supportsRpc(), isFalse);
  });

  test('native-first adapter uses a legacy command worker before demo fallback',
      () async {
    final adapter = NativeFirstAdapter(
      cli: LlamaCliAdapter(executable: '/bin/echo'),
    );

    final result = await adapter.generate(
      'mesh prompt',
      modelPath: '/tmp/worker.gguf',
      onChunk: (_) {},
    );

    expect(result, contains('/tmp/worker.gguf'));
    expect(result, isNot(contains('No cloud connection')));
  });

  test('llama.cpp CLI adds RPC and tensor split arguments', () {
    const plan = DistributedExecutionPlan(
      rpcEndpoints: ['10.0.0.2:50052', '10.0.0.3:50052'],
      tensorSplit: [0.25, 0.75],
    );
    final args = LlamaCliAdapter.buildArguments(
      prompt: 'hello',
      modelPath: '/tmp/model.gguf',
      executionPlan: plan,
    );

    expect(args, contains('--rpc'));
    expect(args, contains('10.0.0.2:50052,10.0.0.3:50052'));
    expect(args, contains('--tensor-split'));
    expect(args, contains('0.25,0.75'));
    expect(args, contains('--split-mode'));
    expect(args, contains('layer'));
  });
}
