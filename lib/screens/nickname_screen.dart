import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/chat_service.dart';
import '../theme/retro.dart';
import 'chat_screen.dart';

class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  /// Boot readout, revealed one line at a time on first paint.
  static const _boot = <List<String>>[
    ['local node', 'ok'],
    ['mdns discovery', 'ready'],
    ['ws transport', 'ready'],
    ['accounts', 'none'],
  ];
  int _revealed = 0;
  Timer? _bootTimer;

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

    _bootTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_revealed >= _boot.length) {
        t.cancel();
        return;
      }
      setState(() => _revealed++);
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
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
            content: Text(
              'failed to start: $e',
              style: Retro.text(size: 11.5, color: Retro.accent),
            ),
            backgroundColor: Retro.panelHi,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const RetroTitleBar(title: 'LANCHAT'),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Wordmark(),
                              const SizedBox(height: 18),
                              // All four lines are always laid out; only
                              // their visibility is gated. Growing into the
                              // space instead would drift the wordmark up
                              // and the (autofocused) field down for the
                              // first 600ms.
                              ...List<Widget>.generate(
                                _boot.length,
                                (i) => Opacity(
                                  opacity: i < _revealed ? 1.0 : 0.0,
                                  child: _BootLine(
                                    label: _boot[i][0],
                                    value: _boot[i][1],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              const RetroRule(caption: 'IDENTITY'),
                              const SizedBox(height: 14),
                              Text('NICKNAME', style: Retro.label()),
                              const SizedBox(height: 7),
                              _NickField(
                                controller: _controller,
                                onSubmitted: _join,
                                enabled: !_loading,
                              ),
                              const SizedBox(height: 20),
                              if (_loading)
                                const _ProgressBar()
                              else
                                RetroButton(
                                  label: 'JOIN',
                                  expand: true,
                                  onPressed: _join,
                                ),
                              const SizedBox(height: 22),
                              Text(
                                'no account. no internet. no server.\n'
                                'everyone on this Wi-Fi finds you automatically.',
                                style: Retro.text(
                                  size: 10.5,
                                  color: Retro.inkFaint,
                                  height: 1.85,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Positioned.fill(child: ScanlineOverlay()),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'LANCHAT',
              style: Retro.text(
                size: 26,
                color: Retro.accent,
                weight: FontWeight.w900,
                spacing: 7,
                height: 1.1,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 5, left: 2),
              child: BlinkingCursor(width: 9, height: 18),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(height: 1, color: Retro.rule),
        const SizedBox(height: 6),
        Text(
          'local area transport / v1.0',
          style: Retro.label(color: Retro.inkFaint, size: 9),
        ),
      ],
    );
  }
}

/// `> mdns discovery ............ ready` — the dot leader is painted, not
/// spelled, so it fills the exact remaining width on every platform.
class _BootLine extends StatelessWidget {
  final String label;
  final String value;

  const _BootLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            '>',
            style: Retro.text(size: 10.5, color: Retro.accentDim),
          ),
          const SizedBox(width: 7),
          Text(label, style: Retro.text(size: 10.5, color: Retro.inkDim)),
          const SizedBox(width: 6),
          const Expanded(
            child: SizedBox(
              height: 10,
              child: CustomPaint(painter: _DotLeaderPainter()),
            ),
          ),
          const SizedBox(width: 6),
          Text(value, style: Retro.text(size: 10.5, color: Retro.live)),
        ],
      ),
    );
  }
}

class _DotLeaderPainter extends CustomPainter {
  const _DotLeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Retro.inkGhost;
    final y = size.height - 3;
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DotLeaderPainter oldDelegate) => false;
}

class _NickField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final bool enabled;

  const _NickField({
    required this.controller,
    required this.onSubmitted,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Retro.panel, border: Retro.box),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Row(
        children: [
          Text(
            '@',
            style: Retro.text(
              size: 14,
              color: Retro.accent,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              autofocus: true,
              maxLength: 24,
              cursorWidth: 8,
              cursorRadius: Radius.zero,
              cursorColor: Retro.accent,
              style: Retro.text(size: 14, spacing: 0.5),
              decoration: const InputDecoration.collapsed(hintText: '')
                  .copyWith(counterText: ''),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
        ],
      ),
    );
  }
}

/// `[####      ]` — a blocky determinate-looking bar that is really just
/// marching cells. Round spinners have no place here.
class _ProgressBar extends StatefulWidget {
  const _ProgressBar();

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  static const int _cells = 14;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final head = (_c.value * _cells).floor();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(border: Retro.boxOf(Retro.accentDim)),
                child: Row(
                  children: List<Widget>.generate(_cells, (i) {
                    // A 4-cell comet chasing its tail.
                    final d = (head - i) % _cells;
                    final on = d >= 0 && d < 4;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 1,
                          vertical: 6,
                        ),
                        color: on ? Retro.accent : Retro.inkGhost,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'opening socket / announcing service',
                style: Retro.text(size: 10, color: Retro.inkDim),
              ),
            ],
          );
        },
      ),
    );
  }
}
