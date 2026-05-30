import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/chat_service.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'ONLINE — ${service.peerCount}',
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 2.5,
                color: Color(0xFF666666),
              ),
            ),
          ),
          if (service.peers.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Text(
                'no peers found yet.\nmake sure everyone is on the same Wi-Fi.',
                style: TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            )
          else
            ...service.peers.values.map(
              (p) => ListTile(
                dense: true,
                leading: const Icon(
                  Icons.circle,
                  size: 7,
                  color: Color(0xFF4CAF50),
                ),
                title: Text(
                  p.nickname,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  '${p.host}:${p.port}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF444444),
                  ),
                ),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatService>(
      builder: (ctx, service, _) {
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                const Text(
                  'LANCHAT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xFFE53935),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 10),
                _OnlineBadge(count: service.peerCount),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.people_outline, size: 20),
                tooltip: 'peers',
                onPressed: _showPeers,
              ),
              IconButton(
                icon: const Icon(Icons.power_settings_new, size: 20),
                tooltip: 'leave',
                onPressed: _leave,
              ),
              const SizedBox(width: 4),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: Color(0xFF1E1E1E)),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: service.messages.isEmpty
                    ? _EmptyState(nickname: service.nickname ?? '')
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: service.messages.length,
                        itemBuilder: (_, i) {
                          final msg = service.messages[i];
                          return MessageBubble(
                            message: msg,
                            isLocal: msg.senderId == service.deviceId,
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
        );
      },
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  final int count;
  const _OnlineBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final haspeers = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: haspeers ? const Color(0xFF1B3A1B) : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count == 0 ? 'alone' : '$count online',
        style: TextStyle(
          fontSize: 10,
          color: haspeers ? const Color(0xFF81C784) : const Color(0xFF444444),
          letterSpacing: 0.5,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi, size: 40, color: Color(0xFF1E1E1E)),
          const SizedBox(height: 16),
          Text(
            'you\'re in as $nickname',
            style: const TextStyle(color: Color(0xFF444444), fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'waiting for others on this network...',
            style: TextStyle(color: Color(0xFF2A2A2A), fontSize: 11),
          ),
        ],
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
        8, 8, 8, 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, size: 20),
            color: const Color(0xFF444444),
            tooltip: 'attach image',
            onPressed: onImage,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'message...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send, size: 18),
            color: const Color(0xFFE53935),
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
