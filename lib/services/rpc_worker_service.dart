import 'dart:async';
import 'dart:io';

/// Owns an optional llama.cpp RPC worker process on desktop-class nodes.
///
/// The RPC protocol is deliberately kept behind this small service so iOS and
/// Android can advertise no endpoint while Linux/macOS/Windows hosts can opt
/// in when `ggml-rpc-server` is installed. The server itself must stay on a
/// trusted LAN or VPN; MeshMind's WebSocket token does not secure raw RPC.
class RpcWorkerService {
  final String executable;
  Process? _process;
  String? _endpoint;

  RpcWorkerService({this.executable = 'ggml-rpc-server'});

  String? get endpoint => _endpoint;
  bool get isRunning => _process != null;

  Future<bool> isAvailable() async {
    if (!(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      return false;
    }
    try {
      final result = await Process.run(executable, const ['--help']);
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  Future<String> start({
    int port = 50052,
    String host = '0.0.0.0',
    String? advertisedHost,
  }) async {
    if (_process != null && _endpoint != null) return _endpoint!;
    final process = await Process.start(executable, [
      '--host',
      host,
      '-p',
      '$port',
      '--cache',
    ]);
    _process = process;
    _endpoint = '${advertisedHost ?? host}:$port';
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    final startupResult = await Future.any<dynamic>([
      process.exitCode,
      Future<void>.delayed(const Duration(milliseconds: 250)),
    ]);
    if (startupResult is int) {
      _process = null;
      _endpoint = null;
      throw StateError('$executable exited during startup ($startupResult)');
    }
    process.exitCode.then((_) {
      if (identical(_process, process)) {
        _process = null;
        _endpoint = null;
      }
    });
    return _endpoint!;
  }

  Future<void> stop() async {
    final process = _process;
    _process = null;
    _endpoint = null;
    process?.kill(ProcessSignal.sigterm);
    await process?.exitCode;
  }
}
