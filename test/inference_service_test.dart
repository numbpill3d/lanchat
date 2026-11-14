import 'package:flutter_test/flutter_test.dart';
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
    const adapter = LlamaCliAdapter(executable: '/bin/echo');

    expect(await adapter.isAvailable(), isTrue);
    final result = await adapter.generate(
      'hello mesh',
      modelPath: '/tmp/example.gguf',
      onChunk: chunks.add,
    );

    expect(result, contains('/tmp/example.gguf'));
    expect(chunks, isNotEmpty);
  });

  test('native-first adapter uses a legacy command worker before demo fallback',
      () async {
    final adapter = NativeFirstAdapter(
      cli: const LlamaCliAdapter(executable: '/bin/echo'),
    );

    final result = await adapter.generate(
      'mesh prompt',
      modelPath: '/tmp/worker.gguf',
      onChunk: (_) {},
    );

    expect(result, contains('/tmp/worker.gguf'));
    expect(result, isNot(contains('No cloud connection')));
  });
}
