import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../models/protocol_messages.dart';
import '../game_transport.dart';
export 'lan_discovery_io.dart';

/// 局域网 TCP 传输层实现（支持原生平台，采用 4 字节前缀粘包处理）
class LanTransport implements GameTransport {
  final String selfId;

  bool _isHost = false;
  bool _isConnected = false;

  ServerSocket? _serverSocket;
  final Map<String, Socket> _peerSockets = {};
  final Map<Socket, String> _socketToPeerId = {};
  final Map<Socket, MessageFrameDecoder> _decoders = {};

  Socket? _clientSocket;
  MessageFrameDecoder? _clientDecoder;

  final StreamController<GameMessage> _messageController =
      StreamController<GameMessage>.broadcast();
  final StreamController<String> _peerJoinedController =
      StreamController<String>.broadcast();
  final StreamController<String> _peerLeftController =
      StreamController<String>.broadcast();

  LanTransport({required this.selfId});

  @override
  bool get isHost => _isHost;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<GameMessage> get onMessage => _messageController.stream;

  @override
  Stream<String> get onPeerJoined => _peerJoinedController.stream;

  @override
  Stream<String> get onPeerLeft => _peerLeftController.stream;

  @override
  Future<void> hostRoom(String roomId, {int? port}) async {
    _isHost = true;
    final listenPort = port ?? 8888;

    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      listenPort,
      shared: true,
    );

    _serverSocket!.listen(
      (socket) {
        final decoder = MessageFrameDecoder();
        _decoders[socket] = decoder;

        socket.listen(
          (Uint8List chunk) {
            try {
              final msgs = decoder.feed(chunk);
              for (final msg in msgs) {
                // 如果是入房请求，登记 socket 对应的 peerId
                if (msg.type == GameMessageType.joinReq) {
                  final peerId = msg.payload['player_id']?.toString() ?? '';
                  if (peerId.isNotEmpty) {
                    _peerSockets[peerId] = socket;
                    _socketToPeerId[socket] = peerId;
                    _peerJoinedController.add(peerId);
                  }
                }
                _messageController.add(msg);
              }
            } catch (_) {}
          },
          onError: (dynamic _) => _handleSocketDisconnect(socket),
          onDone: () => _handleSocketDisconnect(socket),
          cancelOnError: false,
        );
      },
    );

    _isConnected = true;
  }

  void _handleSocketDisconnect(Socket socket) {
    final peerId = _socketToPeerId.remove(socket);
    if (peerId != null) {
      _peerSockets.remove(peerId);
      _peerLeftController.add(peerId);
    }
    _decoders.remove(socket);
    try {
      socket.destroy();
    } catch (_) {}
  }

  @override
  Future<void> joinRoom(
    String roomId, {
    String? host,
    int? port,
    required String playerId,
    required String playerName,
    required String avatar,
  }) async {
    _isHost = false;
    final targetHost = host ?? '127.0.0.1';
    final targetPort = port ?? 8888;

    _clientSocket = await Socket.connect(
      targetHost,
      targetPort,
      timeout: const Duration(seconds: 5),
    );

    _clientDecoder = MessageFrameDecoder();

    _clientSocket!.listen(
      (Uint8List chunk) {
        try {
          final msgs = _clientDecoder!.feed(chunk);
          for (final msg in msgs) {
            _messageController.add(msg);
          }
        } catch (_) {}
      },
      onError: (dynamic _) => disconnect(),
      onDone: () => disconnect(),
      cancelOnError: false,
    );

    _isConnected = true;

    // 发送 joinReq 给房主
    final joinMsg = GameMessage.join(
      playerId: playerId,
      playerName: playerName,
      avatar: avatar,
    );
    await sendToHost(joinMsg);
  }

  @override
  Future<void> sendToHost(GameMessage message) async {
    if (_clientSocket != null) {
      final frame = TcpFrameCodec.encode(message);
      _clientSocket!.add(frame);
    }
  }

  @override
  Future<void> sendToPeer(String peerId, GameMessage message) async {
    final socket = _peerSockets[peerId];
    if (socket != null) {
      final frame = TcpFrameCodec.encode(message);
      socket.add(frame);
    }
  }

  @override
  Future<void> broadcast(GameMessage message) async {
    final frame = TcpFrameCodec.encode(message);
    for (final socket in _peerSockets.values) {
      try {
        socket.add(frame);
      } catch (_) {}
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;

    for (final s in _peerSockets.values) {
      try {
        s.destroy();
      } catch (_) {}
    }
    _peerSockets.clear();
    _socketToPeerId.clear();
    _decoders.clear();

    await _serverSocket?.close();
    _serverSocket = null;

    try {
      _clientSocket?.destroy();
    } catch (_) {}
    _clientSocket = null;
    _clientDecoder = null;
  }
}
