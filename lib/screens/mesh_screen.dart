import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/node_capability.dart';
import '../models/peer.dart';
import '../services/chat_service.dart';
import '../services/inference_service.dart';
import '../services/rpc_worker_service.dart';

const _bg = Color(0xffd9dde0);
const _surface = Color(0xffe5e8ea);
const _well = Color(0xffc3c9ce);
const _ink = Color(0xff30363b);
const _muted = Color(0xff707980);
const _line = Color(0xffa8b0b6);
const _red = Color(0xffb83f45);
const _green = Color(0xff5c8b72);
const _blue = Color(0xff637f95);

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});
  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  final _prompt = TextEditingController();
  final _scroll = ScrollController();
  late final InferenceService _inference;
  late final Future<RuntimeStatus> _nativeRuntimeStatus;
  final RpcWorkerService _rpcWorker = RpcWorkerService();
  String? _answer;
  bool _active = false;
  bool _thinking = false;
  int _tab = 0;
  String? _selectedModel;
  String? _importedModel;
  int? _importedBytes;
  bool _importingModel = false;

  @override
  void initState() {
    super.initState();
    _inference = InferenceService(context.read<ChatService>())..enableWorker();
    _nativeRuntimeStatus = _loadRuntimeStatus();
    unawaited(_syncRuntimeHealth());
    WidgetsBinding.instance.addPostFrameCallback((_) => _activate());
  }

  @override
  void dispose() {
    _prompt.dispose();
    _scroll.dispose();
    unawaited(_inference.dispose());
    unawaited(_rpcWorker.stop());
    super.dispose();
  }

  Future<void> _activate() async {
    try {
      await context.read<ChatService>().start('iphone_coordinator');
    } finally {
      if (mounted) setState(() => _active = true);
    }
  }

  Future<void> _syncRuntimeHealth() async {
    final status = await _nativeRuntimeStatus;
    if (!mounted) return;
    final service = context.read<ChatService>();
    service.registerLocalHealth(status.batteryPercent, status.thermalState);
    service.registerLocalRuntime(status.available);
    final rpcAvailable =
        await _rpcWorker.isAvailable() && await LlamaCliAdapter().supportsRpc();
    if (!rpcAvailable || !mounted) {
      service.registerLocalDistributedRuntime(available: false);
      return;
    }
    try {
      final address = await _localIpv4Address();
      if (address == null) {
        service.registerLocalDistributedRuntime(available: false);
        return;
      }
      final endpoint = await _rpcWorker.start(
        advertisedHost: address,
      );
      service.registerLocalDistributedRuntime(
        available: true,
        rpcEndpoint: endpoint,
        tensorMemoryGb: service.localCapability.memoryGb,
      );
    } on Object {
      service.registerLocalDistributedRuntime(available: false);
    }
  }

  Future<String?> _localIpv4Address() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) return address.address;
        }
      }
    } on Object {
      // Some platforms do not expose interface enumeration to the app.
    }
    return null;
  }

  Future<RuntimeStatus> _loadRuntimeStatus() async {
    final native = await NativeInferenceAdapter().runtimeStatus();
    if (native.available) return native;
    final cliAvailable = await LlamaCliAdapter().isAvailable();
    if (!cliAvailable) return native;
    return RuntimeStatus(
      available: true,
      backend: 'llama.cpp-cli',
      batteryPercent: native.batteryPercent,
      thermalState: native.thermalState,
    );
  }

  Future<void> _importModel() async {
    if (_importingModel) return;
    setState(() => _importingModel = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['gguf'],
        withData: false,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      final storedPath = await _persistModel(file);
      if (!mounted) return;
      context.read<ChatService>().registerLocalModel(
            file.name,
            path: storedPath,
            sizeBytes: file.size,
          );
      setState(() {
        _importedModel = file.name;
        _importedBytes = file.size;
      });
    } finally {
      if (mounted) setState(() => _importingModel = false);
    }
  }

  Future<String?> _persistModel(PlatformFile file) async {
    final sourcePath = file.path;
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final support = await getApplicationSupportDirectory();
    final modelDirectory = Directory('${support.path}/models');
    await modelDirectory.create(recursive: true);
    final safeName = file.name.replaceAll(RegExp(r'[/\\]'), '_');
    final destination = File('${modelDirectory.path}/$safeName');
    if (sourcePath != destination.path) {
      await File(sourcePath).copy(destination.path);
    }
    return destination.path;
  }

  void _runPrompt() {
    final text = _prompt.text.trim();
    if (text.isEmpty || _thinking) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _thinking = true;
      _answer = null;
    });
    final service = context.read<ChatService>();
    final output = StringBuffer();
    _inference.generate(text, modelName: _selectedModel, onChunk: (chunk) {
      if (!mounted) return;
      output.write(chunk);
      setState(() => _answer = output.toString());
    }).then((_) {
      if (!mounted) return;
      setState(() => _thinking = false);
      service.sendText('[mesh request] $text');
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      }
    }).onError<Object>((error, stack) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _answer = 'WORKER ERROR  ·  $error';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatService>(
      builder: (context, service, _) {
        final peers = service.peers.values.toList();
        final remoteCapabilities = peers
            .map((peer) => service.capabilities[peer.id])
            .whereType<NodeCapability>()
            .toList();
        final totalMemoryGb = service.localCapability.memoryGb +
            remoteCapabilities.fold<int>(
                0, (sum, capability) => sum + capability.memoryGb);
        final readyWorkers = remoteCapabilities
            .where((capability) => capability.models.isNotEmpty)
            .length;
        final modelOptions = service.capabilities.values
            .expand((capability) => capability.models)
            .toSet()
            .toList()
          ..sort();
        final poolHealth =
            (0.42 + readyWorkers * 0.16).clamp(0.0, 1.0).toDouble();
        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(active: _active, peerCount: peers.length),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    children: [
                      if (_tab == 0) ...[
                        _HeroPanel(nodeCount: peers.length + 1),
                        const SizedBox(height: 14),
                        _SectionTitle(
                            'POOL CONTROL', '${peers.length + 1} NODES'),
                        const SizedBox(height: 8),
                        _PoolPanel(
                            nodeCount: peers.length + 1,
                            workerCount: readyWorkers,
                            memoryGb: totalMemoryGb,
                            health: poolHealth),
                        const SizedBox(height: 14),
                        const _SectionTitle('PROMPT ROUTER', 'PRIVATE MESH'),
                        const SizedBox(height: 8),
                        _PromptPanel(
                            controller: _prompt,
                            thinking: _thinking,
                            answer: _answer,
                            modelOptions: modelOptions,
                            selectedModel: modelOptions.contains(_selectedModel)
                                ? _selectedModel
                                : null,
                            onModelChanged: (value) =>
                                setState(() => _selectedModel = value),
                            onRun: _runPrompt),
                      ] else if (_tab == 1) ...[
                        _SectionTitle(
                            'DISCOVERED NODES', '${peers.length + 1} ONLINE'),
                        const SizedBox(height: 10),
                        _NodeTile(
                            name: 'iphone_coordinator',
                            detail: 'THIS DEVICE  /  CONTROL + FALLBACK',
                            memory: '4 GB',
                            accent: true,
                            online: _active),
                        ...peers.map((peer) =>
                            _peerTile(peer, service.capabilities[peer.id])),
                        if (peers.isEmpty) const _EmptyTile(),
                      ] else ...[
                        const _SectionTitle('MODEL BAY', 'ADAPTERS'),
                        const SizedBox(height: 10),
                        FutureBuilder<RuntimeStatus>(
                            future: _nativeRuntimeStatus,
                            builder: (context, snapshot) => _RuntimeTile(
                                status: snapshot.data,
                                loading: !snapshot.hasData)),
                        const SizedBox(height: 10),
                        _ActionButton(
                            label:
                                _importingModel ? 'IMPORTING…' : 'IMPORT MODEL',
                            icon: Icons.file_upload_outlined,
                            onPressed: _importingModel ? null : _importModel),
                        const SizedBox(height: 10),
                        if (_importedModel != null)
                          _ModelTile(
                              name: _importedModel!,
                              detail:
                                  'IMPORTED FROM FILES  /  ${_formatBytes(_importedBytes ?? 0)}  /  LOCAL PATH CAPTURED',
                              state: 'IMPORTED'),
                        ...service.capabilities.values
                            .where((capability) =>
                                capability.nodeId != service.deviceId)
                            .expand((capability) => capability.models.map(
                                  (model) => _ModelTile(
                                      name: model,
                                      detail:
                                          '${capability.displayName.toUpperCase()}  /  ${capability.platform.toUpperCase()} WORKER',
                                      state: 'REMOTE'),
                                )),
                        const _EmptyTile(
                            text:
                                'import a model or connect a worker with one'),
                      ],
                    ],
                  ),
                ),
                _BottomNav(
                    index: _tab,
                    onChanged: (value) => setState(() => _tab = value)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _peerTile(Peer peer, NodeCapability? capability) => _NodeTile(
      name: peer.nickname,
      detail: capability == null
          ? 'LAN WORKER  /  NEGOTIATING CAPABILITIES'
          : '${capability.platform.toUpperCase()} WORKER  /  ${capability.models.isEmpty ? 'NO MODEL' : capability.models.first}  /  ${capability.thermalState.toUpperCase()}',
      memory: capability == null ? '—' : '${capability.memoryGb} GB',
      online: true);

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _TopBar extends StatelessWidget {
  final bool active;
  final int peerCount;
  const _TopBar({required this.active, required this.peerCount});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: const BoxDecoration(
            color: _surface,
            border: Border(bottom: BorderSide(color: _line)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x55ffffff), offset: Offset(0, 2), blurRadius: 4)
            ]),
        child: Row(children: [
          _Led(on: active),
          const SizedBox(width: 9),
          const Expanded(
              child: Text('MESHMIND',
                  style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3))),
          _Pill(
              label: active ? '${peerCount + 1} ONLINE' : 'BOOTING',
              color: active ? _green : _red),
          const SizedBox(width: 8),
          const _IconButton(icon: Icons.settings_outlined),
        ]),
      );
}

class _HeroPanel extends StatelessWidget {
  final int nodeCount;
  const _HeroPanel({required this.nodeCount});
  @override
  Widget build(BuildContext context) => _Raised(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LOCAL AI',
              style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2)),
          const SizedBox(height: 6),
          const Text('REASSEMBLED.',
              style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text('$nodeCount devices · one private pool · zero cloud round-trips',
              style: const TextStyle(color: _muted, fontSize: 12)),
        ]),
      );
}

class _PoolPanel extends StatelessWidget {
  final int nodeCount;
  final int workerCount;
  final int memoryGb;
  final double health;
  const _PoolPanel(
      {required this.nodeCount,
      required this.workerCount,
      required this.memoryGb,
      required this.health});
  @override
  Widget build(BuildContext context) => _Raised(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          _Gauge(value: health),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('POOL HEALTH',
                    style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8)),
                const SizedBox(height: 9),
                Row(children: [
                  _Readout(value: '$nodeCount', label: 'NODES'),
                  const SizedBox(width: 18),
                  _Readout(value: '$memoryGb GB', label: 'MEMORY')
                ]),
                const SizedBox(height: 11),
                _InsetBar(value: health),
              ])),
        ]),
      );
}

class _PromptPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool thinking;
  final String? answer;
  final List<String> modelOptions;
  final String? selectedModel;
  final ValueChanged<String?> onModelChanged;
  final VoidCallback onRun;
  const _PromptPanel(
      {required this.controller,
      required this.thinking,
      required this.answer,
      required this.modelOptions,
      required this.selectedModel,
      required this.onModelChanged,
      required this.onRun});
  @override
  Widget build(BuildContext context) => _Raised(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Inset(
              child: TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 5,
                  style:
                      const TextStyle(color: _ink, fontSize: 13, height: 1.4),
                  decoration: const InputDecoration(
                      hintText: 'Ask the local pool something…',
                      hintStyle: TextStyle(color: _muted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12)))),
          const SizedBox(height: 10),
          Row(children: [
            const Text('MODEL',
                style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4)),
            const SizedBox(width: 12),
            Expanded(
                child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedModel,
                        hint: const Text('AUTO / BEST FIT',
                            style: TextStyle(color: _muted, fontSize: 11)),
                        icon: const Icon(Icons.expand_more, color: _muted),
                        dropdownColor: _surface,
                        style: const TextStyle(color: _ink, fontSize: 11),
                        items: modelOptions
                            .map((model) => DropdownMenuItem<String>(
                                value: model, child: Text(model)))
                            .toList(),
                        onChanged: onModelChanged))),
          ]),
          const SizedBox(height: 10),
          _ActionButton(
              label: thinking ? 'ROUTING…' : 'RUN LOCALLY',
              icon: Icons.play_arrow_rounded,
              onPressed: thinking ? null : onRun),
          if (answer != null) ...[
            const SizedBox(height: 13),
            const Divider(color: _line, height: 1),
            const SizedBox(height: 11),
            Text(answer!,
                style:
                    const TextStyle(color: _ink, fontSize: 11.5, height: 1.55)),
          ],
        ]),
      );
}

class _NodeTile extends StatelessWidget {
  final String name;
  final String detail;
  final String memory;
  final bool online;
  final bool accent;
  const _NodeTile(
      {required this.name,
      required this.detail,
      required this.memory,
      required this.online,
      this.accent = false});
  @override
  Widget build(BuildContext context) => _Raised(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          _Led(on: online),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(detail,
                    style: const TextStyle(
                        color: _muted, fontSize: 8, letterSpacing: .8))
              ])),
          Text(memory,
              style: const TextStyle(
                  color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 5),
          Icon(Icons.chevron_right, color: accent ? _red : _muted, size: 18),
        ]),
      );
}

class _ModelTile extends StatelessWidget {
  final String name;
  final String detail;
  final String state;
  const _ModelTile(
      {required this.name, required this.detail, required this.state});
  @override
  Widget build(BuildContext context) => _Raised(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          const _Knob(size: 34, red: true),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(detail,
                    style: const TextStyle(
                        color: _muted, fontSize: 8, letterSpacing: .6))
              ])),
          Text(state,
              style: const TextStyle(
                  color: _green,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ]),
      );
}

class _EmptyTile extends StatelessWidget {
  final String text;
  const _EmptyTile(
      {this.text =
          'nearby devices appear here automatically on the same Wi-Fi'});
  @override
  Widget build(BuildContext context) => _Inset(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Text(text, style: const TextStyle(color: _muted, fontSize: 11))));
}

class _RuntimeTile extends StatelessWidget {
  final RuntimeStatus? status;
  final bool loading;
  const _RuntimeTile({required this.status, required this.loading});

  @override
  Widget build(BuildContext context) => _Inset(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _Led(on: status?.available == true),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('NATIVE RUNTIME',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 3),
                    Text(
                        loading
                            ? 'CHECKING PLATFORM ADAPTER…'
                            : status?.available == true
                                ? 'READY  /  ${status!.backend.toUpperCase()}'
                                : 'NOT INSTALLED  /  FALLBACK ROUTER READY',
                        style: TextStyle(
                            color: status?.available == true ? _green : _muted,
                            fontSize: 8,
                            letterSpacing: .55)),
                    if (!loading && status != null)
                      Text(
                          'battery ${status!.batteryPercent == null ? '—' : '${status!.batteryPercent}%'}  ·  thermal ${status!.thermalState}',
                          style: const TextStyle(
                              color: _muted, fontSize: 8, letterSpacing: .45)),
                  ])),
              Icon(
                  status?.available == true
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: status?.available == true ? _green : _muted,
                  size: 17),
            ])),
      );
}

class _Gauge extends StatelessWidget {
  final double value;
  const _Gauge({required this.value});
  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.center, children: [
        const _Knob(size: 88, red: false),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${(value * 100).round()}',
              style: const TextStyle(
                  color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('SCORE',
              style: TextStyle(color: _muted, fontSize: 8, letterSpacing: 1.4))
        ]),
      ]);
}

class _Knob extends StatelessWidget {
  final double size;
  final bool red;
  const _Knob({required this.size, required this.red});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _surface,
            border: Border.all(color: _line),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x88ffffff),
                  offset: Offset(-3, -3),
                  blurRadius: 5),
              BoxShadow(
                  color: Color(0x55242a2f), offset: Offset(3, 3), blurRadius: 5)
            ]),
        child: Center(
            child: Container(
                width: size * .64,
                height: size * .64,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surface,
                    border: Border.all(color: _line),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x55242a2f),
                          offset: Offset(2, 2),
                          blurRadius: 3),
                      BoxShadow(
                          color: Color(0x99ffffff),
                          offset: Offset(-2, -2),
                          blurRadius: 3)
                    ]),
                child: Align(
                    alignment: const Alignment(0.25, -0.65),
                    child: Container(
                        width: size * .09,
                        height: size * .09,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: red ? _red : _blue))))),
      );
}

class _Readout extends StatelessWidget {
  final String value;
  final String label;
  const _Readout({required this.value, required this.label});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: _muted, fontSize: 8, letterSpacing: 1.2))
      ]);
}

class _InsetBar extends StatelessWidget {
  final double value;
  const _InsetBar({required this.value});
  @override
  Widget build(BuildContext context) => _Inset(
      child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
              widthFactor: value,
              child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                      color: _blue, borderRadius: BorderRadius.circular(8))))));
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String trailing;
  const _SectionTitle(this.title, this.trailing);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: const TextStyle(
                color: _ink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        Text(trailing,
            style:
                const TextStyle(color: _muted, fontSize: 8, letterSpacing: 1))
      ]);
}

class _Raised extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  const _Raised(
      {required this.child, this.padding = EdgeInsets.zero, this.margin});
  @override
  Widget build(BuildContext context) => Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99ffffff),
                offset: Offset(-4, -4),
                blurRadius: 8),
            BoxShadow(
                color: Color(0x44242a2f), offset: Offset(4, 4), blurRadius: 8)
          ]),
      child: child);
}

class _Inset extends StatelessWidget {
  final Widget child;
  const _Inset({required this.child});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: _well,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x55242a2f), offset: Offset(2, 2), blurRadius: 4),
            BoxShadow(
                color: Color(0x99ffffff), offset: Offset(-2, -2), blurRadius: 4)
          ]),
      child: child);
}

class _Led extends StatelessWidget {
  final bool on;
  const _Led({required this.on});
  @override
  Widget build(BuildContext context) => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? _green : _red,
          boxShadow: [
            BoxShadow(
                color: (on ? _green : _red).withValues(alpha: .45),
                blurRadius: 5)
          ]));
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1)));
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  const _IconButton({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _surface,
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99ffffff),
                offset: Offset(-2, -2),
                blurRadius: 4),
            BoxShadow(
                color: Color(0x44242a2f), offset: Offset(2, 2), blurRadius: 4)
          ]),
      child: Icon(icon, color: _muted, size: 16));
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _ActionButton(
      {required this.label, required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? _muted : _red,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: const Color(0x55242a2f),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))));
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomNav({required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      decoration: const BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _line)),
          boxShadow: [
            BoxShadow(
                color: Color(0x55ffffff), offset: Offset(0, -2), blurRadius: 5)
          ]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'POOL',
            selected: index == 0,
            onTap: () => onChanged(0)),
        _NavItem(
            icon: Icons.hub_outlined,
            label: 'NODES',
            selected: index == 1,
            onTap: () => onChanged(1)),
        _NavItem(
            icon: Icons.memory_outlined,
            label: 'MODELS',
            selected: index == 2,
            onTap: () => onChanged(2)),
      ]));
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: selected ? _red : _muted),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: selected ? _red : _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1))
          ])));
}
