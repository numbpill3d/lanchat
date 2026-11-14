import 'dart:convert';

class SessionHandshake {
  const SessionHandshake._();

  static String encode({required String nickname, required String token}) =>
      jsonEncode({'nickname': nickname, 'token': token});

  static String? tokenFrom(String content) {
    try {
      final payload = jsonDecode(content);
      return payload is Map<String, dynamic> && payload['token'] is String
          ? payload['token'] as String
          : null;
    } on FormatException {
      return null;
    }
  }
}
