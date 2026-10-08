import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/chat_service.dart';
import '../theme/retro.dart';
import '../widgets/gutters.dart';
import '../widgets/message_bubble.dart';
import 'nickname_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<ChatService>().addListener(_onUpdate);
  }

  @override
  void dispose() {
    context.read<ChatService>().removeListener(_onUpdate);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onUpdate() => _scrollToBottom();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (pos.maxScrollExtent - pos.pixels < 160) {
        _scrollCtrl.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    context.read<ChatService>().sendText(text);
    _focusNode.requestFocus();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || !mounted) return;

    final name = file.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.gif')
            ? 'image/gif'
            : 'image/jpeg';

    await context.read<ChatService>().sendImage(bytes, mime);
  }

  Future<void> _leave() async {
    await context.read<ChatService>().stop();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const NicknameScreen()),
      );
    }
  }

  void _showPeers() {
    final service = context.read<ChatService>();
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xB0000000),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Retro.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 360),
          decoration: const BoxDecoration(color: Retro.panel, border: Retro.box),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RetroTitleBar(
                title: 'NODES',
                onClose: () => Navigator.of(dialogCtx).pop(),
                closeTooltip: 'close',
                ground: Retro.panel,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Text(
                  'ONLINE / ${service.peerCount.toString().padLeft(2, '0')}',
                  style: Retro.label(),
                ),
              ),
              Flexible(
                child: service.peers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                        child: Text(
                          'no peers found yet.\n'
                          'everyone must be on the same Wi-Fi.',
                          style: Retro.text(
                            size: 11.5,
                            color: Retro.inkFaint,
                            height: 1.7,
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                        children: service.peers.values.map((p) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  color: Retro.live,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p.nickname,
                                    style: Retro.text(size: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${p.host}:${p.port}',
                                  style: Retro.text(
                                    size: 10,
                                    color: Retro.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatService>(
      builder: (ctx, service, _) {
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    RetroTitleBar(
                      title: 'LANCHAT',
                      onClose: _leave,
                      closeTooltip: 'disconnect',
                      actions: [
                        RetroGlyphButton(
                          glyph: '#',
                          tooltip: 'nodes',
                          onPressed: _showPeers,
                        ),
                      ],
                    ),
                    _StatusStrip(
                      nickname: service.nickname ?? '?',
                      peerCount: service.peerCount,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide =
                              constraints.maxWidth >= kGutterMinWidth;
                          final transcript = service.messages.isEmpty
                              ? _EmptyState(nickname: service.nickname ?? '')
                              : Scrollbar(
                                  controller: _scrollCtrl,
                                  child: ListView.builder(
                                    controller: _scrollCtrl,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    itemCount: service.messages.length,
                                    itemBuilder: (_, i) {
                                      final msg = service.messages[i];
                                      return MessageBubble(
                                        message: msg,
                                        isLocal:
                                            msg.senderId == service.deviceId,
                                      );
                                    },
                                  ),
                                );

                          if (!wide) return transcript;

                          return Row(
                            children: [
                              SignalGutter(
                                peerCount: service.peerCount,
                                messageCount: service.messages.length,
                              ),
                              Expanded(child: transcript),
                              StatsGutter(
                                peerCount: service.peerCount,
                                messageCount: service.messages.length,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    _InputBar(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      onSend: _send,
                      onImage: _pickImage,
                    ),
                  ],
                ),
                const Positioned.fill(child: ScanlineOverlay()),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The thin readout under the title bar: who you are, how many nodes, and a
/// carrier lamp that pulses only while peers are present.
class _StatusStrip extends StatelessWidget {
  final String nickname;
  final int peerCount;

  const _StatusStrip({required this.nickname, required this.peerCount});

  @override
  Widget build(BuildContext context) {
    final live = peerCount > 0;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Retro.panel,
        border: Border(bottom: BorderSide(color: Retro.ruleDim, width: 1)),
      ),
      child: Row(
        children: [
          Text('USER', style: Retro.label(color: Retro.inkGhost, size: 8)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              nickname,
              style: Retro.text(size: 11, color: Retro.accent),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          _CarrierLamp(live: live),
          const SizedBox(width: 7),
          Text(
            live
                ? '${peerCount.toString().padLeft(2, '0')} NODES'
                : 'NO CARRIER',
            style: Retro.label(
              color: live ? Retro.live : Retro.inkFaint,
              size: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarrierLamp extends StatefulWidget {
  final bool live;
  const _CarrierLamp({required this.live});

  @override
  State<_CarrierLamp> createState() => _CarrierLampState();
}

class _CarrierLampState extends State<_CarrierLamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.live) {
      return Container(width: 6, height: 6, color: Retro.inkGhost);
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 6,
          height: 6,
          color: _c.value < 0.5 ? Retro.live : Retro.liveDim,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String nickname;
  const _EmptyState({required this.nickname});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'session opened as $nickname',
              style: Retro.text(size: 12, color: Retro.inkDim),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'listening on this network',
                  style: Retro.text(size: 11, color: Retro.inkFaint),
                ),
                const SizedBox(width: 6),
                const BlinkingCursor(
                  width: 6,
                  height: 11,
                  color: Retro.inkFaint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onImage;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Retro.bg,
        border: Border(top: BorderSide(color: Retro.rule, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: RetroGlyphButton(
              glyph: '+',
              tooltip: 'attach image',
              onPressed: onImage,
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Retro.panel,
                border: Retro.box,
              ),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '>',
                      style: Retro.text(
                        size: 13,
                        color: Retro.accent,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 5,
                      cursorWidth: 7,
                      cursorRadius: Radius.zero,
                      cursorColor: Retro.accent,
                      style: Retro.text(size: 13, height: 1.35),
                      decoration: InputDecoration.collapsed(
                        hintText: 'type a message',
                        hintStyle: Retro.text(size: 13, color: Retro.inkGhost),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: RetroButton(
              label: 'SEND',
              onPressed: onSend,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
        ],
      ),
    );
  }
}
