import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';

class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  static const _adj = [
    'swift', 'quiet', 'bold', 'dark', 'neon', 'ghost',
    'wild', 'frost', 'ash', 'iron', 'void', 'echo',
  ];
  static const _noun = [
    'hawk', 'wolf', 'fox', 'crow', 'lynx', 'pike',
    'bear', 'kite', 'moth', 'rook', 'veil', 'mist',
  ];

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _controller.text =
        '${_adj[rng.nextInt(_adj.length)]}_${_noun[rng.nextInt(_noun.length)]}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final nick = _controller.text.trim();
    if (nick.isEmpty) return;
    setState(() => _loading = true);
    try {
      await context.read<ChatService>().start(nick);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed to start: $e'),
            backgroundColor: const Color(0xFF1A1A1A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LANCHAT',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Color(0xFFE53935),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'no account · no internet required · local only',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF444444),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 52),
                  const Text(
                    'NICKNAME',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: 24,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(counterText: ''),
                    onSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE53935),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _join,
                      child: const Text(
                        'JOIN',
                        style: TextStyle(
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  const Text(
                    'everyone on the same Wi-Fi can find you automatically.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF333333),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
