class Peer {
  final String id;
  final String nickname;
  final String host;
  final int port;
  final String? authToken;

  const Peer({
    required this.id,
    required this.nickname,
    required this.host,
    required this.port,
    this.authToken,
  });
}
