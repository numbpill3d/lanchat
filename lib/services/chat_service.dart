import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import '../models/peer.dart';

class ChatService extends ChangeNotifier {
  static const _mdnsType = '_lanchat._tcp';
  static const _firstPort = 5700;
  static const _lastPort = 5800;
  static const _maxRememberedMessageIds = 4096;

  final String _deviceId = const Uuid().v4();
  String? _nickname;
  int _serverPort = 0;

  HttpServer? _httpServer;
  BonsoirBroadcast? _bonsoirBroadcast;
  BonsoirDiscovery? _bonsoirDiscovery;
  StreamSubscription<dynamic>? _discoverySubscription;

  // channels where peers connected to our server
  final Map<String, WebSocketChannel> _serverChannels = {};
  // channels where we connected to peers' servers
  final Map<String, WebSocketChannel> _clientChannels = {};

  final List<Message> _messages = [];
  final Map<String, Peer> _peers = {};
  final Set<String> _processedIds = {};
  final List<String> _processedIdOrder = [];
  final Set<String> _connectingPeers = {};
  bool _disposed = false;
  String? _startupWarning;

  List<Message> get messages => List.unmodifiable(_messages);
  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  String? get nickname => _nickname;
  String get deviceId => _deviceId;
  int get peerCount => _peers.length;
  bool get isRunning => _httpServer != null;
  String? get startupWarning => _startupWarning;

  Future<void> start(String nickname) async {
    if (isRunning) return;
    final cleaned = nickname.trim();
    if (cleaned.isEmpty || cleaned.length > 24) {
      throw ArgumentError('nickname must be between 1 and 24 characters');
    }
    _nickname = cleaned;
    try {
      await _startServer();
      _startupWarning = null;
      try {
        await _startBroadcast();
        await _startDiscovery();
      } catch (error) {
        // mDNS is optional for the local server. Linux installations without
        // a running Avahi daemon can still open the chat and recover once the
        // service is available again.
        _startupWarning =
            'mDNS discovery is unavailable. The local chat server is running, '
            'but peers cannot be found automatically.';
        debugPrint('lanchat: mDNS startup failed: $error');
        await _stopDiscoveryServices();
      }
      _notifyChanged();
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> _startServer() async {
    final handler = webSocketHandler((WebSocketChannel channel, String? _) {
      final connId = const Uuid().v4();
      _serverChannels[connId] = channel;

      channel.stream.listen(
        (raw) => _onData(raw, source: channel),
        onDone: () {
          _serverChannels.remove(connId);
          _notifyChanged();
        },
        onError: (_) => _serverChannels.remove(connId),
        cancelOnError: true,
      );
    });

    // try ports in range until one is free
    for (var port = _firstPort; port < _lastPort; port++) {
      try {
        _httpServer = await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          port,
        );
        _serverPort = port;
        return;
      } catch (_) {
        continue;
      }
    }
    throw Exception('no free port found in $_firstPort-${_lastPort - 1}');
  }

  Future<void> _startBroadcast() async {
    final nick = _nickname;
    if (nick == null) return;
    final service = BonsoirService(
      name: '${nick}_$_deviceId',
      type: _mdnsType,
      port: _serverPort,
      attributes: {
        'id': _deviceId,
        'nick': nick,
      },
    );
    _bonsoirBroadcast = BonsoirBroadcast(service: service);
    await _bonsoirBroadcast!.ready;
    await _bonsoirBroadcast!.start();
  }

  Future<void> _startDiscovery() async {
    _bonsoirDiscovery = BonsoirDiscovery(type: _mdnsType);
    await _bonsoirDiscovery!.ready;

    _discoverySubscription = _bonsoirDiscovery!.eventStream!.listen((event) {
      switch (event.type) {
        case BonsoirDiscoveryEventType.discoveryServiceFound:
          event.service?.resolve(_bonsoirDiscovery!.serviceResolver);

        case BonsoirDiscoveryEventType.discoveryServiceResolved:
          final svc = event.service;
          if (svc == null) return;

          final attrs = svc.attributes;
          final peerId = attrs['id'];
          final peerNick = attrs['nick'] ?? svc.name;

          if (peerId == null || peerId == _deviceId) return;
          if (_clientChannels.containsKey(peerId) ||
              _connectingPeers.contains(peerId)) return;

          final resolved = svc as ResolvedBonsoirService;
          final host = resolved.host;
          if (host == null) return;

          final peer = Peer(
            id: peerId,
            nickname: peerNick,
            host: host,
            port: svc.port,
          );
          _peers[peerId] = peer;
          _notifyChanged();

          _connectToPeer(peer);

        case BonsoirDiscoveryEventType.discoveryServiceLost:
          final peerId = event.service?.attributes['id'];
          if (peerId != null && peerId != _deviceId) {
            _peers.remove(peerId);
            _clientChannels[peerId]?.sink.close();
            _clientChannels.remove(peerId);
            _notifyChanged();
          }

        default:
          break;
      }
    });

    await _bonsoirDiscovery!.start();
  }

  Future<void> _connectToPeer(Peer peer) async {
    if (!_connectingPeers.add(peer.id)) return;
    final nick = _nickname;
    if (nick == null) {
      _connectingPeers.remove(peer.id);
      _peers.remove(peer.id);
      _notifyChanged();
      return;
    }
    final uri = Uri.parse('ws://${peer.host}:${peer.port}');
    final channel = WebSocketChannel.connect(uri);

    try {
      await channel.ready;
    } catch (e) {
      _connectingPeers.remove(peer.id);
      try { await channel.sink.close(); } catch (_) {}
      debugPrint('lanchat: connect to ${peer.nickname} failed: $e');
      _peers.remove(peer.id);
      _notifyChanged();
      return;
    }

    _connectingPeers.remove(peer.id);
    _clientChannels[peer.id] = channel;

    // announce ourselves
    final join = Message(
      type: MessageType.join,
      senderNickname: nick,
      senderId: _deviceId,
      content: '$nick joined',
    );
    // The remote side echoes the join through the mesh; remember it locally
    // so the sender does not render its own handshake as a chat event.
    _rememberMessageId(join.id);
    _sendOn(channel, join);

    channel.stream.listen(
      (raw) => _onData(raw, source: channel),
      onDone: () {
        if (identical(_clientChannels[peer.id], channel)) {
          _clientChannels.remove(peer.id);
        }
        _maybeRemovePeer(peer.id);
        _notifyChanged();
      },
      onError: (_) {
        if (identical(_clientChannels[peer.id], channel)) {
          _clientChannels.remove(peer.id);
        }
        _maybeRemovePeer(peer.id);
        _notifyChanged();
      },
      cancelOnError: true,
    );
  }

  void _onData(dynamic raw, {WebSocketChannel? source}) {
    if (raw is! String) return;
    if (raw.length > 12 * 1024 * 1024) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final msg = Message.fromJson(json);
      if (_processedIds.contains(msg.id)) return;
      _rememberMessageId(msg.id);
      _messages.add(msg);
      if (msg.type == MessageType.leave) {
        _dropPeer(msg.senderId);
      }
      _broadcastMessage(msg, except: source);
      _notifyChanged();
    } catch (e) {
      debugPrint('lanchat: bad message: $e');
    }
  }

  void _rememberMessageId(String id) {
    if (!_processedIds.add(id)) return;
    _processedIdOrder.add(id);
    if (_processedIdOrder.length > _maxRememberedMessageIds) {
      _processedIds.remove(_processedIdOrder.removeAt(0));
    }
  }

  void _sendOn(WebSocketChannel channel, Message msg) {
    try {
      channel.sink.add(jsonEncode(msg.toJson()));
    } catch (_) {}
  }

  void _broadcastMessage(Message msg, {WebSocketChannel? except}) {
    final raw = jsonEncode(msg.toJson());
    for (final ch in _serverChannels.values) {
      if (identical(ch, except)) continue;
      try { ch.sink.add(raw); } catch (_) {}
    }
    for (final ch in _clientChannels.values) {
      if (identical(ch, except)) continue;
      try { ch.sink.add(raw); } catch (_) {}
    }
  }

  void sendText(String text) {
    final nick = _nickname;
    final body = text.trim();
    if (nick == null || body.isEmpty || body.length > Message.maxTextLength) {
      return;
    }
    final msg = Message(
      type: MessageType.text,
      senderNickname: nick,
      senderId: _deviceId,
      content: body,
    );
    _rememberMessageId(msg.id);
    _messages.add(msg);
    _notifyChanged();
    _broadcastMessage(msg);
  }

  Future<void> sendImage(Uint8List bytes, String mimeType) async {
    final nick = _nickname;
    if (nick == null || bytes.isEmpty || bytes.length > 6 * 1024 * 1024) {
      return;
    }
    final msg = Message(
      type: MessageType.image,
      senderNickname: nick,
      senderId: _deviceId,
      content: base64Encode(bytes),
      mimeType: mimeType,
    );
    _rememberMessageId(msg.id);
    _messages.add(msg);
    _notifyChanged();
    _broadcastMessage(msg);
  }

  Future<void> stop() async {
    final nick = _nickname;
    if (nick != null && isRunning) {
      _broadcastMessage(Message(
        type: MessageType.leave,
        senderNickname: nick,
        senderId: _deviceId,
        content: '$nick left',
      ));
    }

    await _stopDiscoveryServices();

    final allChannels = [
      ..._serverChannels.values,
      ..._clientChannels.values,
    ];
    for (final ch in allChannels) {
      try { await ch.sink.close(); } catch (_) {}
    }

    await _httpServer?.close(force: true);

    _serverChannels.clear();
    _clientChannels.clear();
    _peers.clear();
    _messages.clear();
    _processedIds.clear();
    _processedIdOrder.clear();
    _connectingPeers.clear();
    _httpServer = null;
    _nickname = null;
    _startupWarning = null;

    _notifyChanged();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }

  void _notifyChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _stopDiscoveryServices() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    try {
      await _bonsoirDiscovery?.stop();
    } catch (_) {}
    try {
      await _bonsoirBroadcast?.stop();
    } catch (_) {}
    _bonsoirDiscovery = null;
    _bonsoirBroadcast = null;
  }

  void _removePeer(String peerId) {
    final removed = _peers.remove(peerId);
    if (removed != null) _notifyChanged();
  }

  void _dropPeer(String peerId) {
    final channel = _clientChannels.remove(peerId);
    if (channel != null) unawaited(channel.sink.close());
    _removePeer(peerId);
  }

  void _maybeRemovePeer(String peerId) {
    if (!_clientChannels.containsKey(peerId)) _removePeer(peerId);
  }
}
