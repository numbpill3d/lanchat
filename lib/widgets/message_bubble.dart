import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/message.dart';

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
      return _SystemLine(text: message.content);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment:
            isLocal ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isLocal)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                message.senderNickname,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF666666),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isLocal
                    ? const Color(0xFFB71C1C)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isLocal ? 14 : 2),
                  bottomRight: Radius.circular(isLocal ? 2 : 14),
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: message.type == MessageType.image
                  ? _ImageContent(base64data: message.content)
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isLocal
                              ? Colors.white
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(
              _hhmm(message.timestamp),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF333333),
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

class _SystemLine extends StatelessWidget {
  final String text;
  const _SystemLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF3A3A3A),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final String base64data;
  const _ImageContent({required this.base64data});

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(base64data);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _ImageError(),
      );
    } catch (_) {
      return const _ImageError();
    }
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'image failed to load',
        style: TextStyle(color: Color(0xFF444444), fontSize: 12),
      ),
    );
  }
}
