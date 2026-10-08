import 'package:flutter/material.dart';

/// LanChat retro shell.
///
/// One system: a phosphor-terminal ground wearing Macintosh structure.
/// Everything is square — there is not a single rounded corner in here, and
/// there should not be one anywhere in the app.
class Retro {
  Retro._();

  // ── ground ────────────────────────────────────────────────────────────
  static const bg = Color(0xFF0A0A0A);
  static const panel = Color(0xFF101010);
  static const panelHi = Color(0xFF161616);

  // ── 1px rules ─────────────────────────────────────────────────────────
  static const rule = Color(0xFF2A2A2A);
  static const ruleDim = Color(0xFF1A1A1A);

  // ── ink ───────────────────────────────────────────────────────────────
  static const ink = Color(0xFFD6D6D6);
  static const inkDim = Color(0xFF6A6A6A);
  static const inkFaint = Color(0xFF3A3A3A);
  static const inkGhost = Color(0xFF242424);

  // ── signal ────────────────────────────────────────────────────────────
  static const accent = Color(0xFFE53935);
  static const accentDim = Color(0xFF6E1F1E);
  static const live = Color(0xFF5FA85F);
  static const liveDim = Color(0xFF223322);

  /// System monospace, resolved per platform. Nothing here depends on a
  /// bundled asset or on box-drawing glyphs — the gutter infographics are
  /// painted, not spelled — so this stack is safe on all six targets.
  static const String mono = 'monospace';
  static const List<String> monoFallback = <String>[
    'DejaVu Sans Mono',
    'Liberation Mono',
    'Noto Sans Mono',
    'Menlo',
    'SF Mono',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  static TextStyle text({
    double size = 12,
    Color color = ink,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    double? height,
    FontStyle? style,
  }) {
    return TextStyle(
      fontFamily: mono,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
      fontStyle: style,
    );
  }

  /// Small all-caps rubric used for every label in the UI.
  static TextStyle label({Color color = inkDim, double size = 9}) =>
      text(size: size, color: color, spacing: 2.0);

  static const Border box = Border.fromBorderSide(
    BorderSide(color: rule, width: 1),
  );

  static Border boxOf(Color c) =>
      Border.fromBorderSide(BorderSide(color: c, width: 1));
}

// ═══════════════════════════════════════════════════════════════════════════
// Title bar — Macintosh pinstripes, drawn inside the client area.
//
// The native title bar is deliberately left alone (see _kFrameless in
// main.dart): a cosmetic refactor should never be able to produce a window
// you cannot move.
// ═══════════════════════════════════════════════════════════════════════════

class RetroTitleBar extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;
  final String? closeTooltip;
  final List<Widget> actions;

  /// The surface this bar sits on. The title block and close box punch a
  /// hole in the pinstripes with this colour, so it must match the panel
  /// behind them or it shows as a patch.
  final Color ground;

  const RetroTitleBar({
    super.key,
    required this.title,
    this.onClose,
    this.closeTooltip,
    this.actions = const [],
    this.ground = Retro.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: ground,
        border: const Border(
          bottom: BorderSide(color: Retro.rule, width: 1),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _PinstripePainter()),
          ),
          Row(
            children: [
              const SizedBox(width: 6),
              _CloseBox(
                onPressed: onClose,
                tooltip: closeTooltip,
                ground: ground,
              ),
              const Spacer(),
              ...actions,
              const SizedBox(width: 6),
            ],
          ),
          Center(
            child: Container(
              color: ground,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                title,
                style: Retro.text(
                  size: 11,
                  color: Retro.ink,
                  weight: FontWeight.w700,
                  spacing: 3.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinstripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Retro.ruleDim
      ..strokeWidth = 1;
    for (double y = 4.5; y < size.height - 3; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PinstripePainter oldDelegate) => false;
}

class _CloseBox extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color ground;
  const _CloseBox({this.onPressed, this.tooltip, this.ground = Retro.bg});

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) {
      // Inert window: classic Mac simply omits the close box.
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: ground, border: Retro.box),
      );
    }
    return RetroGlyphButton(
      glyph: 'x',
      tooltip: tooltip,
      onPressed: onPressed,
      size: 14,
      ground: ground,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Controls — square, 1px, invert on hover/press.
// ═══════════════════════════════════════════════════════════════════════════

class RetroButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool expand;
  final EdgeInsets padding;

  const RetroButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = Retro.accent,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final active = enabled && (_hover || _down);
    final c = enabled ? widget.color : Retro.inkFaint;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.expand ? double.infinity : null,
          padding: widget.padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? c : Retro.bg,
            border: Retro.boxOf(c),
          ),
          child: Text(
            widget.label,
            style: Retro.text(
              size: 12,
              color: active ? Retro.bg : c,
              weight: FontWeight.w700,
              spacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1-character square button. Stands in for every Material icon that used
/// to be here — icons are the loudest anachronism in a terminal UI.
class RetroGlyphButton extends StatefulWidget {
  final String glyph;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;
  final double size;
  final Color ground;

  const RetroGlyphButton({
    super.key,
    required this.glyph,
    this.onPressed,
    this.tooltip,
    this.color = Retro.inkDim,
    this.size = 18,
    this.ground = Retro.bg,
  });

  @override
  State<RetroGlyphButton> createState() => _RetroGlyphButtonState();
}

class _RetroGlyphButtonState extends State<RetroGlyphButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final active = enabled && (_hover || _down);

    Widget box = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? widget.color : widget.ground,
            border: Retro.boxOf(active ? widget.color : Retro.rule),
          ),
          child: Text(
            widget.glyph,
            style: Retro.text(
              size: widget.size * 0.56,
              color: active ? widget.ground : widget.color,
              weight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      box = Tooltip(message: widget.tooltip!, child: box);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: box,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Flair
// ═══════════════════════════════════════════════════════════════════════════

/// Hard-edged block cursor. No fade — CRTs did not fade.
class BlinkingCursor extends StatefulWidget {
  final double width;
  final double height;
  final Color color;

  const BlinkingCursor({
    super.key,
    this.width = 7,
    this.height = 14,
    this.color = Retro.accent,
  });

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1060),
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
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          color: _c.value < 0.55 ? widget.color : Colors.transparent,
        ),
      ),
    );
  }
}

/// Static scanline texture. Deliberately not animated and never interactive.
class ScanlineOverlay extends StatelessWidget {
  const ScanlineOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ScanlinePainter(),
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    for (double y = 0.5; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => false;
}

/// A 1px horizontal rule with an optional inset caption, e.g. `── JOIN ──`.
class RetroRule extends StatelessWidget {
  final String? caption;
  final Color color;

  const RetroRule({super.key, this.caption, this.color = Retro.ruleDim});

  @override
  Widget build(BuildContext context) {
    if (caption == null) {
      return Container(height: 1, color: color);
    }
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(caption!, style: Retro.label(color: Retro.inkFaint)),
        ),
        Expanded(child: Container(height: 1, color: color)),
      ],
    );
  }
}
