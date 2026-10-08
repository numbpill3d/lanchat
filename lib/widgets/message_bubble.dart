import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/retro.dart';

/// One line of transcript.
///
/// No bubbles: this reads as a log — `14:32 │ <nick> text` — with a 1px rail
/// that goes accent for your own lines. Kept as `MessageBubble` so the chat
/// screen's call site is unchanged.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isLocal;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.join || message.type == MessageType.leave) {
      return _SystemLine(
        text: message.content,
        joined: message.type == MessageType.join,
      );
    }

    final rail = isLocal ? Retro.accent : Retro.rule;
    final nickColor = isLocal ? Retro.accent : Retro.live;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              _hhmm(message.timestamp),
              style: Retro.text(size: 10, color: Retro.inkFaint),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 9),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: rail, width: 1)),
              ),
              child: message.type == MessageType.image
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '<${message.senderNickname}> sent an image',
                          style: Retro.text(size: 12, color: nickColor),
                        ),
                        const SizedBox(height: 5),
                        _ImageFrame(base64data: message.content),
                      ],
                    )
                  : RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '<${message.senderNickname}> ',
                            style: Retro.text(
                              size: 12.5,
                              color: nickColor,
                              weight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                          TextSpan(
                            text: message.content,
                            style: Retro.text(
                              size: 12.5,
                              color: Retro.ink,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Join/leave notices: a captioned rule across the column.
class _SystemLine extends StatelessWidget {
  final String text;
  final bool joined;
  const _SystemLine({required this.text, required this.joined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        children: [
          Container(width: 10, height: 1, color: Retro.ruleDim),
          const SizedBox(width: 8),
          Text(
            joined ? '+' : '-',
            style: Retro.text(
              size: 11,
              color: joined ? Retro.live : Retro.inkFaint,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text.toLowerCase(),
              style: Retro.text(size: 10.5, color: Retro.inkDim, spacing: 0.4),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: Retro.ruleDim)),
        ],
      ),
    );
  }
}

/// Images sit in a hairline frame with a caption bar, like a dumped file.
class _ImageFrame extends StatelessWidget {
  final String base64data;
  const _ImageFrame({required this.base64data});

  @override
  Widget build(BuildContext context) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(base64data);
    } catch (_) {
      return const _ImageError();
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 240),
      decoration: const BoxDecoration(border: Retro.box),
      padding: const EdgeInsets.all(3),
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _ImageError(),
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(border: Retro.boxOf(Retro.inkFaint)),
      child: Text(
        '! image failed to decode',
        style: Retro.text(size: 11, color: Retro.inkFaint),
      ),
    );
  }
}
