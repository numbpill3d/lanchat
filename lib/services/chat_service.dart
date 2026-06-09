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
import 'database_service.dart';

class ChatService extends ChangeNotifier {
  static const _mdnsType = '_lanchat._tcp';
  static const _processedIdsMax = 10_000;

  final String _deviceId = const Uuid().v4();
  String? _nickname;
  int _serverPort = 0;

  HttpServer? _httpServer;
  BonsoirBroadcast? _bonsoirBroadcast;
  BonsoirDiscovery? _bonsoirDiscovery;

  // channels where peers connected to our server
  final Map<String, WebSocketChannel> _serverChannels = {};
  // channels where we connected to peers' servers
  final Map<String, WebSocketChannel> _clientChannels = {};

  final List<Message> _messages = [];
  final Map<String, Peer> _peers = {};
  final Set<String> _processedIds = {};

  List<Message> get messages => List.unmodifiable(_messages);
  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  String? get nickname => _nickname;
  String get deviceId => _deviceId;
  int get peerCount => _peers.length;
  bool get isRunning => _httpServer != null;

  Future<void> start(String nickname) async {
    _nickname = nickname;

    // load persisted messages
    try {
      final history = await DatabaseService.loadRecent();
      _messages.addAll(history);
      for (final msg in history) {
        _processedIds.add(msg.id);
      }
    } catch (e) {
      debugPrint('lanchat: failed to load history: $e');
    }

    await _startServer();
    await _startBroadcast();
    await _startDiscovery();
  }

  Future<void> _startServer() async {
    final handler = webSocketHandler((WebSocketChannel channel, String? _) {
      final connId = const Uuid().v4();
      _serverChannels[connId] = channel;

      channel.stream.listen(
        _onData,
        onDone: () {
          _serverChannels.remove(connId);
          notifyListeners();
        },
        onError: (_) => _serverChannels.remove(connId),
        cancelOnError: true,
      );
    });

    // try ports in range until one is free
    for (var port = 5700; port < 5800; port++) {
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
    throw Exception('no free port found in 5700-5800');
  }

  Future<void> _startBroadcast() async {
    final service = BonsoirService(
      name: '${_nickname}_$_deviceId',
      type: _mdnsType,
      port: _serverPort,
      attributes: {
        'id': _deviceId,
        'nick': _nickname!,
      },
    );
    _bonsoirBroadcast = BonsoirBroadcast(service: service);
    await _bonsoirBroadcast!.ready;
    await _bonsoirBroadcast!.start();
  }

  Future<void> _startDiscovery() async {
    _bonsoirDiscovery = BonsoirDiscovery(type: _mdnsType);
    await _bonsoirDiscovery!.ready;

    _bonsoirDiscovery!.eventStream!.listen((event) {
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
          if (_clientChannels.containsKey(peerId)) return;

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
          notifyListeners();

          _connectToPeer(peer);

        case BonsoirDiscoveryEventType.discoveryServiceLost:
          final peerId = event.service?.attributes['id'];
          if (peerId != null && peerId != _deviceId) {
            _peers.remove(peerId);
            _clientChannels[peerId]?.sink.close();
            _clientChannels.remove(peerId);
            notifyListeners();

            // auto-reconnect: re-trigger discovery
            _restartDiscovery();
          }

        default:
          break;
      }
    });

    await _bonsoirDiscovery!.start();
  }

  Future<void> _restartDiscovery() async {
    // brief delay to avoid reconnect storms
    await Future.delayed(const Duration(seconds: 2));
    try {
      await _bonsoirDiscovery?.stop();
      await _bonsoirDiscovery?.start();
    } catch (_) {}
  }

  /// Sorted peer list (by nickname, case-insensitive).
  List<Peer> get sortedPeers {
    final list = _peers.values.toList();
    list.sort((a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));
    return list;
  }

  Future<void> _connectToPeer(Peer peer) async {
    final uri = Uri.parse('ws://${peer.host}:${peer.port}');
    final channel = WebSocketChannel.connect(uri);

    try {
      await channel.ready;
    } catch (e) {
      debugPrint('lanchat: connect to ${peer.nickname} failed: $e');
      _peers.remove(peer.id);
      notifyListeners();
      return;
    }

    _clientChannels[peer.id] = channel;

    // announce ourselves
    _sendOn(
      channel,
      Message(
        type: MessageType.join,
        senderNickname: _nickname!,
        senderId: _deviceId,
        content: '${_nickname!} joined',
      ),
    );

    channel.stream.listen(
      _onData,
      onDone: () {
        _clientChannels.remove(peer.id);
        _peers.remove(peer.id);
        notifyListeners();
        _restartDiscovery();
      },
      onError: (_) {
        _clientChannels.remove(peer.id);
        _peers.remove(peer.id);
        notifyListeners();
        _restartDiscovery();
      },
      cancelOnError: true,
    );
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final msg = Message.fromJson(json);
      if (_processedIds.contains(msg.id)) return;

      _processedIds.add(msg.id);
      // prevent unbounded growth
      if (_processedIds.length > _processedIdsMax) {
        final toRemove = _processedIds.take((_processedIds.length - _processedIdsMax) ~/ 2).toSet();
        _processedIds.removeAll(toRemove);
      }

      _messages.add(msg);
      notifyListeners();

      // persist to database (non-blocking)
      DatabaseService.saveMessage(msg);
    } catch (e) {
      debugPrint('lanchat: bad message: $e');
    }
  }

  void _sendOn(WebSocketChannel channel, Message msg) {
    try {
      channel.sink.add(jsonEncode(msg.toJson()));
    } catch (_) {}
  }

  void _broadcastMessage(Message msg) {
    final raw = jsonEncode(msg.toJson());
    for (final ch in _serverChannels.values) {
      try { ch.sink.add(raw); } catch (_) {}
    }
    for (final ch in _clientChannels.values) {
      try { ch.sink.add(raw); } catch (_) {}
    }
  }

  void sendText(String text) {
    final msg = Message(
      type: MessageType.text,
      senderNickname: _nickname!,
      senderId: _deviceId,
      content: text,
    );
    _processedIds.add(msg.id);
    _messages.add(msg);
    notifyListeners();
    _broadcastMessage(msg);
    DatabaseService.saveMessage(msg);
  }

  Future<void> sendImage(Uint8List bytes, String mimeType) async {
    final msg = Message(
      type: MessageType.image,
      senderNickname: _nickname!,
      senderId: _deviceId,
      content: base64Encode(bytes),
      mimeType: mimeType,
    );
    _processedIds.add(msg.id);
    _messages.add(msg);
    notifyListeners();
    _broadcastMessage(msg);
    DatabaseService.saveMessage(msg);
  }

  Future<void> stop() async {
    if (_nickname != null && isRunning) {
      _broadcastMessage(Message(
        type: MessageType.leave,
        senderNickname: _nickname!,
        senderId: _deviceId,
        content: '${_nickname!} left',
      ));
    }

    await _bonsoirDiscovery?.stop();
    await _bonsoirBroadcast?.stop();

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
    _httpServer = null;
    _nickname = null;

    await DatabaseService.close();

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
