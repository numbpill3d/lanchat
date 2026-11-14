import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/inference_envelope.dart';
import '../models/message.dart';
import '../models/node_capability.dart';
import 'chat_service.dart';

class InferenceResult {
  final String route;
  final String nodeName;
  final String text;
  const InferenceResult(
      {required this.route, required this.nodeName, required this.text});
}

abstract interface class LocalModelAdapter {
  String get modelName;
  Future<String> generate(String prompt,
      {required void Function(String chunk) onChunk, String? modelPath});
}

/// Honest fallback used until a platform-native GGUF/MLX adapter is linked.
/// It exercises the same streaming contract as a real model.
class OfflineFallbackAdapter implements LocalModelAdapter {
  @override
  String get modelName => 'fallback-router';

  @override
  Future<String> generate(String prompt,
      {required void Function(String chunk) onChunk, String? modelPath}) async {
    const chunks = [
      'The local pool received your request. ',
      'No cloud connection was used. ',
      'The next adapter can replace this fallback with GGUF or MLX inference.',
    ];
    final output = StringBuffer();
    for (final chunk in chunks) {
      await Future<void>.delayed(const Duration(milliseconds: 110));
      output.write(chunk);
      onChunk(chunk);
    }
    return output.toString();
  }
}

/// Boundary for a platform implementation backed by llama.cpp, MLX, or a
/// future iOS/Android runtime. The channel is deliberately small so native
/// code can be added without changing mesh routing.
class NativeInferenceAdapter implements LocalModelAdapter {
  static const _channel = MethodChannel('meshmind.inference');

  @override
  String get modelName => 'native-runtime';

  Future<RuntimeStatus> runtimeStatus() async {
    try {
      final status =
          await _channel.invokeMethod<Map<Object?, Object?>>('runtime_status');
      return RuntimeStatus.fromMap(status);
    } on MissingPluginException {
      return const RuntimeStatus.unavailable();
    } on PlatformException {
      return const RuntimeStatus.unavailable();
    } on StateError {
      return const RuntimeStatus.unavailable();
    } on FlutterError {
      return const RuntimeStatus.unavailable();
    }
  }

  Future<bool> isAvailable() async => (await runtimeStatus()).available;

  @override
  Future<String> generate(String prompt,
      {required void Function(String chunk) onChunk, String? modelPath}) async {
    final result = await _channel.invokeMethod<String>('generate', {
      'prompt': prompt,
      if (modelPath != null) 'modelPath': modelPath,
    });
    if (result == null || result.isEmpty) {
      throw StateError('native runtime returned no output');
    }
    onChunk(result);
    return result;
  }
}

/// Runs the official llama.cpp command-line worker when a legacy laptop or
/// desktop has it installed. This is intentionally a worker adapter, not a
/// cloud dependency: the model path and prompt stay on the local machine.
class LlamaCliAdapter implements LocalModelAdapter {
  final String executable;

  const LlamaCliAdapter({this.executable = 'llama-cli'});

  @override
  String get modelName => 'llama.cpp-cli';

  Future<bool> isAvailable() async {
    if (!(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      return false;
    }
    try {
      final result = await Process.run(executable, const ['--version']);
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  @override
  Future<String> generate(String prompt,
      {required void Function(String chunk) onChunk, String? modelPath}) async {
    if (modelPath == null || modelPath.isEmpty) {
      throw StateError('no local model file has been imported');
    }
    final process = await Process.start(executable, [
      '-m',
      modelPath,
      '-p',
      prompt,
      '-n',
      '256',
      '--no-display-prompt',
    ]);
    final output = StringBuffer();
    final stdoutFuture =
        process.stdout.transform(utf8.decoder).forEach((chunk) {
      output.write(chunk);
      onChunk(chunk);
    });
    final errorFuture = process.stderr.transform(utf8.decoder).join();
    final results = await Future.wait<dynamic>([
      process.exitCode,
      stdoutFuture,
      errorFuture,
    ]);
    final exitCode = results[0] as int;
    if (exitCode != 0) {
      final error = results[2] as String;
      throw StateError(
          'llama.cpp worker exited with $exitCode${error.trim().isEmpty ? '' : ': ${error.trim()}'}');
    }
    final result = output.toString();
    if (result.isEmpty) throw StateError('llama.cpp worker returned no output');
    return result;
  }
}

class RuntimeStatus {
  final bool available;
  final String backend;
  final int? batteryPercent;
  final String thermalState;

  const RuntimeStatus({
    required this.available,
    required this.backend,
    this.batteryPercent,
    this.thermalState = 'unknown',
  });

  const RuntimeStatus.unavailable()
      : available = false,
        backend = 'none',
        batteryPercent = null,
        thermalState = 'unknown';

  factory RuntimeStatus.fromMap(Map<Object?, Object?>? value) {
    final battery = value?['batteryPercent'];
    return RuntimeStatus(
      available: value?['available'] == true,
      backend:
          value?['backend'] is String ? value!['backend'] as String : 'none',
      batteryPercent: battery is num ? battery.round() : null,
      thermalState: value?['thermalState'] is String
          ? value!['thermalState'] as String
          : 'unknown',
    );
  }
}

class NativeFirstAdapter implements LocalModelAdapter {
  final NativeInferenceAdapter native;
  final LlamaCliAdapter cli;
  final OfflineFallbackAdapter fallback;

  NativeFirstAdapter({NativeInferenceAdapter? native, LlamaCliAdapter? cli})
      : native = native ?? NativeInferenceAdapter(),
        cli = cli ?? const LlamaCliAdapter(),
        fallback = OfflineFallbackAdapter();

  @override
  String get modelName => native.modelName;

  @override
  Future<String> generate(String prompt,
      {required void Function(String chunk) onChunk, String? modelPath}) async {
    try {
      return await native.generate(prompt,
          onChunk: onChunk, modelPath: modelPath);
    } on MissingPluginException {
      return _tryCli(prompt, onChunk, modelPath);
    } on PlatformException {
      return _tryCli(prompt, onChunk, modelPath);
    } on StateError {
      return _tryCli(prompt, onChunk, modelPath);
    } on FlutterError {
      return _tryCli(prompt, onChunk, modelPath);
    }
  }

  Future<String> _tryCli(
      String prompt, void Function(String) onChunk, String? modelPath) async {
    if (modelPath != null && await cli.isAvailable()) {
      try {
        return await cli.generate(prompt,
            onChunk: onChunk, modelPath: modelPath);
      } on Object {
        // A broken or incompatible local binary should not strand the UI.
      }
    }
    return fallback.generate(prompt, onChunk: onChunk, modelPath: modelPath);
  }
}

class _PendingRequest {
  final String route;
  final String nodeName;
  final StringBuffer output;
  final Completer<InferenceResult> completer;
  final void Function(String chunk) onChunk;
  _PendingRequest(
      {required this.route,
      required this.nodeName,
      required this.output,
      required this.completer,
      required this.onChunk});
}

class InferenceService {
  final ChatService mesh;
  final LocalModelAdapter fallback;
  final Map<String, _PendingRequest> _pending = {};
  StreamSubscription<InferenceEnvelope>? _events;
  int _workerCursor = 0;

  InferenceService(this.mesh, {LocalModelAdapter? fallback})
      : fallback = fallback ?? NativeFirstAdapter();

  void enableWorker() {
    _events ??= mesh.inferenceEvents.listen(_onEvent);
  }

  Future<void> dispose() async {
    await _events?.cancel();
    _events = null;
  }

  NodeCapability? _bestWorker() {
    final workers = mesh.capabilities.values
        .where((capability) => capability.nodeId != mesh.deviceId);
    final eligible = <NodeCapability>[];
    for (final worker in workers) {
      final tooHot =
          worker.thermalState == 'serious' || worker.thermalState == 'critical';
      final tooLow =
          worker.batteryPercent != null && worker.batteryPercent! < 15;
      if (tooHot || tooLow) continue;
      if (worker.features.contains('text-generation') &&
          worker.models.isNotEmpty) {
        eligible.add(worker);
      }
    }
    if (eligible.isEmpty) return null;

    eligible.sort((a, b) => _workerScore(b).compareTo(_workerScore(a)));
    final worker = eligible[_workerCursor % eligible.length];
    _workerCursor = (_workerCursor + 1) % eligible.length;
    return worker;
  }

  int _workerScore(NodeCapability worker) {
    final battery = worker.batteryPercent ?? 50;
    final thermal = switch (worker.thermalState) {
      'nominal' => 30,
      'fair' => 15,
      _ => 0,
    };
    return worker.memoryGb * 10 + battery + thermal;
  }

  Future<InferenceResult> generate(String prompt,
      {required void Function(String chunk) onChunk}) async {
    enableWorker();
    final worker = _bestWorker();
    if (worker == null) {
      const route = 'LOCAL FALLBACK';
      const nodeName = 'iphone_coordinator';
      const prefix = 'ROUTE  $route  ·  $nodeName\n\n';
      onChunk(prefix);
      final body = await fallback.generate(prompt,
          onChunk: onChunk, modelPath: mesh.preferredLocalModelPath);
      return InferenceResult(
          route: route, nodeName: nodeName, text: '$prefix$body');
    }

    final requestId = const Uuid().v4();
    const route = 'REMOTE WORKER';
    final prefix = 'ROUTE  $route  ·  ${worker.displayName}\n\n';
    final completer = Completer<InferenceResult>();
    final pending = _PendingRequest(
        route: route,
        nodeName: worker.displayName,
        output: StringBuffer(prefix),
        completer: completer,
        onChunk: onChunk);
    _pending[requestId] = pending;
    onChunk(prefix);
    mesh.sendInference(InferenceEnvelope(
        type: MessageType.inferenceRequest,
        requestId: requestId,
        targetId: worker.nodeId,
        prompt: prompt));

    try {
      return await completer.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      _pending.remove(requestId);
      return _retryLocally(
        prompt,
        pending,
        onChunk,
        reason: 'WORKER TIMEOUT',
      );
    } catch (error) {
      _pending.remove(requestId);
      return _retryLocally(
        prompt,
        pending,
        onChunk,
        reason: 'WORKER ERROR  ·  $error',
      );
    }
  }

  Future<InferenceResult> _retryLocally(
    String prompt,
    _PendingRequest pending,
    void Function(String chunk) onChunk, {
    required String reason,
  }) async {
    final message = '\n$reason  ·  RETRYING ON IPHONE FALLBACK\n\n';
    onChunk(message);
    final body = await fallback.generate(prompt,
        onChunk: onChunk, modelPath: mesh.preferredLocalModelPath);
    return InferenceResult(
      route: '$reason / LOCAL RETRY',
      nodeName: pending.nodeName,
      text: '${pending.output}$message$body',
    );
  }

  void _onEvent(InferenceEnvelope event) {
    if (event.type == MessageType.inferenceRequest &&
        event.targetId == mesh.deviceId &&
        event.prompt != null &&
        event.senderId != null) {
      unawaited(_serve(event));
      return;
    }
    final pending = _pending[event.requestId];
    if (pending == null) return;
    if (event.type == MessageType.inferenceChunk && event.chunk != null) {
      pending.output.write(event.chunk);
      pending.onChunk(event.chunk!);
      return;
    }
    if (event.type == MessageType.inferenceComplete) {
      _pending.remove(event.requestId);
      pending.completer.complete(InferenceResult(
          route: pending.route,
          nodeName: pending.nodeName,
          text: pending.output.toString()));
    } else if (event.type == MessageType.inferenceError) {
      _pending.remove(event.requestId);
      pending.completer
          .completeError(StateError(event.error ?? 'worker inference failed'));
    }
  }

  Future<void> _serve(InferenceEnvelope event) async {
    try {
      await fallback.generate(event.prompt!,
          modelPath: mesh.preferredLocalModelPath, onChunk: (chunk) {
        mesh.sendInference(InferenceEnvelope(
            type: MessageType.inferenceChunk,
            requestId: event.requestId,
            targetId: event.senderId,
            chunk: chunk));
      });
      mesh.sendInference(InferenceEnvelope(
          type: MessageType.inferenceComplete,
          requestId: event.requestId,
          targetId: event.senderId));
    } catch (error) {
      mesh.sendInference(InferenceEnvelope(
          type: MessageType.inferenceError,
          requestId: event.requestId,
          targetId: event.senderId,
          error: '$error'));
    }
  }
}
