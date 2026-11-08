import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/protocol_messages.dart';
import '../game_transport.dart';
import 'p2p_signaling.dart';

/// 基于 WebRTC DataChannel 的星型 P2P 传输层实现
class WebRtcP2PTransport implements GameTransport {
  final String selfId;
  final String? signalingBrokerUrl;

  bool _isHost = false;
  bool _isConnected = false;
  String? _roomId;

  P2PSignaling? _signaling;

  // 房主端：维护每个特工客户端的连接与数据通道
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};

  // 客户端端：指向房主的单条连接与数据通道
  RTCPeerConnection? _hostConnection;
  RTCDataChannel? _hostChannel;
  String? _hostId;
  String? _selfPlayerName;
  String? _selfAvatar;

  final StreamController<GameMessage> _messageController =
      StreamController<GameMessage>.broadcast();
  final StreamController<String> _peerJoinedController =
      StreamController<String>.broadcast();
  final StreamController<String> _peerLeftController =
      StreamController<String>.broadcast();

  WebRtcP2PTransport({
    required this.selfId,
    this.signalingBrokerUrl,
  });

  @override
  bool get isHost => _isHost;

  @override
  bool get isConnected => _isConnected;

  String? get roomId => _roomId;
  String? get hostId => _hostId;

  @override
  Stream<GameMessage> get onMessage => _messageController.stream;

  @override
  Stream<String> get onPeerJoined => _peerJoinedController.stream;

  @override
  Stream<String> get onPeerLeft => _peerLeftController.stream;

  Map<String, dynamic> get _rtcConfig => {
        'iceServers': P2PSignaling.defaultIceServers,
        'sdpSemantics': 'unified-plan',
      };

  @override
  Future<void> hostRoom(String roomId, {int? port}) async {
    _isHost = true;
    _roomId = roomId;

    _signaling = P2PSignaling(
      roomCode: roomId,
      selfId: selfId,
      brokerUrl: signalingBrokerUrl,
    );

    await _signaling!.init(
      onJoin: (data) => _handleClientJoin(data),
      onAnswer: (data) => _handleClientAnswer(data),
      onIce: (data) => _handleRemoteIce(data),
    );

    _isConnected = true;
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
    _roomId = roomId;
    _selfPlayerName = playerName;
    _selfAvatar = avatar;

    _signaling = P2PSignaling(
      roomCode: roomId,
      selfId: playerId,
      brokerUrl: signalingBrokerUrl,
    );

    final joinCompleter = Completer<void>();

    await _signaling!.init(
      onOffer: (data) async {
        try {
          await _handleHostOffer(data, playerName, avatar);
          if (!joinCompleter.isCompleted) {
            joinCompleter.complete();
          }
        } catch (e) {
          if (!joinCompleter.isCompleted) {
            joinCompleter.completeError(e);
          }
        }
      },
      onIce: (data) => _handleRemoteIce(data),
    );

    // 发送信令 Join 请求
    _signaling!.sendJoin(playerName, avatar);

    // 10 秒超时等待连接建立
    return joinCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        if (!_isConnected) {
          disconnect();
          throw TimeoutException('P2P 房间加入超时，请确认房间号是否正确');
        }
      },
    );
  }

  // --- 房主端处理流程 ---

  Future<void> _handleClientJoin(Map<String, dynamic> data) async {
    final clientId = data['clientId']?.toString();
    if (clientId == null || clientId.isEmpty) return;

    try {
      final pc = await createPeerConnection(_rtcConfig);
      _peerConnections[clientId] = pc;

      // 监听 ICE 候选发送给特工客户端
      pc.onIceCandidate = (candidate) {
        _signaling?.sendIce(
          targetId: clientId,
          candidate: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      };

      pc.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _removePeer(clientId);
        }
      };

      // 创建可靠有序 DataChannel
      final dcInit = RTCDataChannelInit()..ordered = true;
      final dc = await pc.createDataChannel('game_data', dcInit);
      _setupDataChannel(dc, clientId);
      _dataChannels[clientId] = dc;

      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      _signaling?.sendOffer(
        targetClientId: clientId,
        sdp: {'type': offer.type, 'sdp': offer.sdp},
      );
    } catch (_) {}
  }

  Future<void> _handleClientAnswer(Map<String, dynamic> data) async {
    final clientId = data['clientId']?.toString();
    final sdpMap = data['sdp'] as Map<String, dynamic>?;
    if (clientId == null || sdpMap == null) return;

    final pc = _peerConnections[clientId];
    if (pc != null) {
      final desc = RTCSessionDescription(
        sdpMap['sdp']?.toString(),
        sdpMap['type']?.toString(),
      );
      await pc.setRemoteDescription(desc);
    }
  }

  // --- 客户端端处理流程 ---

  Future<void> _handleHostOffer(
    Map<String, dynamic> data,
    String playerName,
    String avatar,
  ) async {
    final hostId = data['fromHostId']?.toString();
    final sdpMap = data['sdp'] as Map<String, dynamic>?;
    if (hostId == null || sdpMap == null) return;

    _hostId = hostId;
    final pc = await createPeerConnection(_rtcConfig);
    _hostConnection = pc;

    pc.onIceCandidate = (candidate) {
      _signaling?.sendIce(
        targetId: hostId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    pc.onDataChannel = (dc) {
      _hostChannel = dc;
      _setupDataChannel(dc, hostId);
    };

    final offerDesc = RTCSessionDescription(
      sdpMap['sdp']?.toString(),
      sdpMap['type']?.toString(),
    );
    await pc.setRemoteDescription(offerDesc);

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _signaling?.sendAnswer(
      targetHostId: hostId,
      sdp: {'type': answer.type, 'sdp': answer.sdp},
    );
  }

  Future<void> _handleRemoteIce(Map<String, dynamic> data) async {
    final candidateMap = data['candidate'] as Map<String, dynamic>?;
    final fromId = data['fromId']?.toString();
    if (candidateMap == null) return;

    final candidate = RTCIceCandidate(
      candidateMap['candidate']?.toString(),
      candidateMap['sdpMid']?.toString(),
      candidateMap['sdpMLineIndex'] as int?,
    );

    if (_isHost) {
      if (fromId != null && _peerConnections.containsKey(fromId)) {
        await _peerConnections[fromId]?.addCandidate(candidate);
      }
    } else {
      await _hostConnection?.addCandidate(candidate);
    }
  }

  void _setupDataChannel(RTCDataChannel dc, String peerId) {
    dc.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        if (_isHost) {
          _peerJoinedController.add(peerId);
        } else {
          _isConnected = true;
          // 连接建立后主动发送 joinReq
          sendToHost(GameMessage.join(
            playerId: selfId,
            playerName: _selfPlayerName ?? '特工',
            avatar: _selfAvatar ?? 'agent_1',
          ));
        }
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        if (_isHost) {
          _removePeer(peerId);
        } else {
          _isConnected = false;
        }
      }
    };

    dc.onMessage = (RTCDataChannelMessage msg) {
      if (msg.isBinary) {
        // 二进制帧
      } else {
        try {
          final gameMsg = GameMessage.fromJson(msg.text);
          _messageController.add(gameMsg);
        } catch (_) {}
      }
    };
  }

  void _removePeer(String peerId) {
    _peerConnections[peerId]?.close();
    _peerConnections.remove(peerId);
    _dataChannels[peerId]?.close();
    _dataChannels.remove(peerId);
    _peerLeftController.add(peerId);
  }

  @override
  Future<void> sendToHost(GameMessage message) async {
    if (_hostChannel != null &&
        _hostChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      await _hostChannel!.send(RTCDataChannelMessage(message.toJson()));
    }
  }

  @override
  Future<void> sendToPeer(String peerId, GameMessage message) async {
    final dc = _dataChannels[peerId];
    if (dc != null && dc.state == RTCDataChannelState.RTCDataChannelOpen) {
      await dc.send(RTCDataChannelMessage(message.toJson()));
    }
  }

  @override
  Future<void> broadcast(GameMessage message) async {
    final jsonStr = message.toJson();
    for (final dc in _dataChannels.values) {
      if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
        await dc.send(RTCDataChannelMessage(jsonStr));
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _signaling?.disconnect();
    _signaling = null;

    for (final dc in _dataChannels.values) {
      await dc.close();
    }
    _dataChannels.clear();

    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    await _hostChannel?.close();
    _hostChannel = null;

    await _hostConnection?.close();
    _hostConnection = null;
  }
}
