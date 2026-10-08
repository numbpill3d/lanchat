import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/retro.dart';

/// Width of one margin column. Gutters only render on wide layouts — see
/// [kGutterMinWidth] — so they never compete with the transcript.
const double kGutterWidth = 46;

/// Below this logical width the transcript gets the whole window.
///
/// Deliberately well under the 680px default so the gutters survive a
/// comfortable drag inward — and so a non-1.0 device pixel ratio can't put
/// the app below the threshold on first launch — while still clearing the
/// 440px minimum window.
const double kGutterMinWidth = 520;

// Pre-mixed alphas, written as literals so this file needs no particular
// Flutter version (withOpacity/withValues have churned).
const Color _traceLive = Color(0xB8E53935);
const Color _traceIdle = Color(0x66E53935);

/// Deterministic noise bed for the scope trace. Generated once, scrolled
/// forever; no per-frame allocation.
final List<double> _noise = List<double>.generate(512, (i) {
  final x = i * 0.11;
  return math.sin(x) * 0.52 +
      math.sin(x * 2.31 + 1.1) * 0.30 +
      math.sin(x * 5.77 + 2.9) * 0.18;
});

/// Column header shared by both gutters.
class _GutterLabel extends StatelessWidget {
  final String text;
  const _GutterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Retro.ruleDim, width: 1)),
      ),
      child: Text(text, style: Retro.label(color: Retro.inkFaint, size: 8)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LEFT — signal scope
// ═══════════════════════════════════════════════════════════════════════════

class SignalGutter extends StatefulWidget {
  final int peerCount;
  final int messageCount;

  const SignalGutter({
    super.key,
    required this.peerCount,
    required this.messageCount,
  });

  @override
  State<SignalGutter> createState() => _SignalGutterState();
}

class _SignalGutterState extends State<SignalGutter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  /// 0..1, eased toward its target so the trace swells and settles rather
  /// than snapping.
  double _amp = 0.16;
  int _lastCount = 0;
  Timer? _sampler;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.messageCount;
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _sampler = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final delta = widget.messageCount - _lastCount;
      _lastCount = widget.messageCount;
      final target = (0.14 +
              (widget.peerCount.clamp(0, 8) / 8) * 0.34 +
              (delta.clamp(0, 4) / 4) * 0.52)
          .clamp(0.0, 1.0);
      // No setState: the controller repaints this subtree every frame
      // already, so mutating the value is enough and costs no rebuild.
      _amp += (target - _amp) * 0.34;
    });
  }

  @override
  void dispose() {
    _sampler?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kGutterWidth,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Retro.ruleDim, width: 1)),
        ),
        child: Column(
          children: [
            const _GutterLabel('SIG'),
            Expanded(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => CustomPaint(
                    size: Size.infinite,
                    painter: _ScopePainter(
                      phase: _c.value,
                      amplitude: _amp,
                      live: widget.peerCount > 0,
                    ),
                  ),
                ),
              ),
            ),
            const RetroRule(),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => _LevelStack(level: _amp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopePainter extends CustomPainter {
  final double phase;
  final double amplitude;
  final bool live;

  _ScopePainter({
    required this.phase,
    required this.amplitude,
    required this.live,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (h <= 4 || w <= 4) return;

    final cx = w / 2;
    final guide = Paint()
      ..color = Retro.inkGhost
      ..strokeWidth = 1;

    canvas.drawLine(Offset(cx, 0), Offset(cx, h), guide);

    // Ruler ticks down the right edge, every fifth one long.
    int tick = 0;
    for (double y = 0.5; y < h; y += 9) {
      final major = tick % 5 == 0;
      canvas.drawLine(Offset(w - 1, y), Offset(w - (major ? 7 : 3), y), guide);
      tick++;
    }

    // The trace: time runs down the column, amplitude across it.
    final scroll = phase * _noise.length;
    final path = Path();
    bool started = false;
    for (double y = 0; y <= h; y += 2) {
      final idx = ((scroll + y / 2) % _noise.length).floor();
      final x = cx + _noise[idx] * amplitude * (w * 0.40);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = live ? _traceLive : _traceIdle
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Sweep head: one bright cell riding the trace, faster than the scroll.
    final headY = (phase * 3 * h) % h;
    final headIdx = ((scroll + headY / 2) % _noise.length).floor();
    final headX = cx + _noise[headIdx] * amplitude * (w * 0.40);
    canvas.drawRect(
      Rect.fromLTWH(headX - 1.5, headY - 1.5, 3, 3),
      Paint()..color = live ? Retro.accent : Retro.inkDim,
    );
  }

  @override
  bool shouldRepaint(covariant _ScopePainter old) =>
      old.phase != phase || old.amplitude != amplitude || old.live != live;
}

/// Five stacked cells that fill from the bottom with signal level.
class _LevelStack extends StatelessWidget {
  final double level;
  const _LevelStack({required this.level});

  @override
  Widget build(BuildContext context) {
    const cells = 5;
    final filled = (level * cells).round().clamp(0, cells);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(cells, (row) {
          // row 0 is the top cell; fill rises from the bottom.
          final on = row >= cells - filled;
          return Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 2),
            color: on ? Retro.accent : Retro.inkGhost,
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RIGHT — node census, traffic histogram, uptime
// ═══════════════════════════════════════════════════════════════════════════

class StatsGutter extends StatefulWidget {
  final int peerCount;
  final int messageCount;

  const StatsGutter({
    super.key,
    required this.peerCount,
    required this.messageCount,
  });

  @override
  State<StatsGutter> createState() => _StatsGutterState();
}

class _StatsGutterState extends State<StatsGutter>
    with SingleTickerProviderStateMixin {
  static const int _buckets = 32;

  late final AnimationController _c;
  final List<double> _history = List<double>.filled(_buckets, 0);
  final DateTime _startedAt = DateTime.now();

  int _lastCount = 0;
  Timer? _sampler;
  String _uptime = '00:00:00';

  @override
  void initState() {
    super.initState();
    _lastCount = widget.messageCount;
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _sampler = Timer.periodic(const Duration(milliseconds: 700), (_) {
      final delta = widget.messageCount - _lastCount;
      _lastCount = widget.messageCount;

      // Shift the window left, newest sample at the end.
      for (int i = 0; i < _buckets - 1; i++) {
        _history[i] = _history[i + 1];
      }
      _history[_buckets - 1] = (delta / 3).clamp(0.0, 1.0);

      final up = DateTime.now().difference(_startedAt);
      final next = _fmt(up);
      if (next != _uptime && mounted) {
        setState(() => _uptime = next);
      }
    });
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  void dispose() {
    _sampler?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kGutterWidth,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Retro.ruleDim, width: 1)),
        ),
        child: Column(
          children: [
            const _GutterLabel('NET'),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
              child: _NodeGrid(count: widget.peerCount),
            ),
            const RetroRule(),
            Expanded(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => CustomPaint(
                    size: Size.infinite,
                    painter: _HistogramPainter(
                      history: _history,
                      phase: _c.value,
                    ),
                  ),
                ),
              ),
            ),
            const RetroRule(),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 8, 3, 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _uptime,
                  style: Retro.text(size: 9, color: Retro.inkDim),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('UP', style: Retro.label(color: Retro.inkGhost, size: 7)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3×4 census grid — one cell per discovered peer, the first cell is you.
class _NodeGrid extends StatelessWidget {
  final int count;
  const _NodeGrid({required this.count});

  @override
  Widget build(BuildContext context) {
    const cols = 3;
    const rows = 4;
    final lit = (count + 1).clamp(0, cols * rows);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(rows, (r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(cols, (c) {
              final i = r * cols + c;
              final on = i < lit;
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: on
                      ? (i == 0 ? Retro.accent : Retro.live)
                      : Colors.transparent,
                  border: Retro.boxOf(on ? Colors.transparent : Retro.inkGhost),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  final List<double> history;
  final double phase;

  _HistogramPainter({required this.history, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (h <= 4 || w <= 4) return;

    const padX = 7.0;
    final usable = w - padX * 2;
    final n = history.length;
    final slot = h / n;

    final bar = Paint()..color = Retro.live;
    final empty = Paint()..color = Retro.inkGhost;

    // Newest sample at the top, oldest at the bottom.
    for (int i = 0; i < n; i++) {
      final v = history[n - 1 - i];
      final y = i * slot;
      final len = (usable * v).clamp(0.0, usable);
      if (len < 1) {
        canvas.drawRect(Rect.fromLTWH(padX, y + slot * 0.35, 1, 1), empty);
      } else {
        canvas.drawRect(
          Rect.fromLTWH(padX, y + slot * 0.2, len, math.max(1, slot * 0.55)),
          bar,
        );
      }
    }

    // A slow scan bar sweeping the column — the only motion when idle.
    final scanY = phase * h;
    canvas.drawLine(
      Offset(0, scanY),
      Offset(w, scanY),
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter old) => true;
}
