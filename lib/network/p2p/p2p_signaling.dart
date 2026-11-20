import 'dart:convert';
import 'mini_mqtt_client.dart';

class P2PSignaling {
  static const List<Map<String, dynamic>> defaultIceServers = [
    {'urls': 'stun:stun.chat.bilibili.com:3478'},
    {'urls': 'stun:stun.qq.com:3478'},
    {'urls': 'stun:stun.miwifi.com:3478'},
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  static const List<String> defaultSignalingUrls = [
    'wss://broker.emqx.io:8084/mqtt',
    'wss://broker-cn.emqx.io:8084/mqtt',
  ];

  static const String defaultSignalingUrl = 'wss://broker.emqx.io:8084/mqtt';

  final String roomCode;
  final String selfId;
  final String? _customBrokerUrl;
  String? _activeBrokerUrl;
  MiniMqttClient? _client;
  bool _disposed = false;

  String get brokerUrl => _activeBrokerUrl ?? _customBrokerUrl ?? defaultSignalingUrl;

  P2PSignaling({
    required this.roomCode,
    required this.selfId,
    String? brokerUrl,
  }) : _customBrokerUrl = (brokerUrl != null && brokerUrl.trim().isNotEmpty)
            ? brokerUrl.trim()
            : null;

  Future<void> init({
    Function(Map<String, dynamic> data)? onJoin,
    Function(Map<String, dynamic> data)? onOffer,
    Function(Map<String, dynamic> data)? onAnswer,
    Function(Map<String, dynamic> data)? onIce,
  }) async {
    _disposed = false;
    final candidates = _customBrokerUrl != null
        ? <String>[_customBrokerUrl]
        : defaultSignalingUrls;

    Object? lastError;

    for (final url in candidates) {
      if (_disposed) {
        throw StateError('信令连接已取消');
      }

      final client = MiniMqttClient(
        url,
        '${selfId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      _client = client;

      client.onMessage((msg) {
        try {
          final data = json.decode(msg.payload) as Map<String, dynamic>;
          final topicPrefix = 'wga/room/$roomCode/';
          if (!msg.topic.startsWith(topicPrefix)) return;

          final subTopic = msg.topic.substring(topicPrefix.length);

          if (subTopic == 'join' && onJoin != null) {
            if (data['clientId'] != selfId) {
              onJoin(data);
            }
          } else if (subTopic.startsWith('offer/') && onOffer != null) {
            final targetId = subTopic.substring('offer/'.length);
            if (targetId == selfId) {
              onOffer(data);
            }
          } else if (subTopic.startsWith('answer/') && onAnswer != null) {
            final hostId = subTopic.substring('answer/'.length);
            if (hostId == selfId) {
              onAnswer(data);
            }
          } else if (subTopic.startsWith('ice/') && onIce != null) {
            final targetId = subTopic.substring('ice/'.length);
            if (targetId == selfId) {
              onIce(data);
            }
          }
        } catch (_) {}
      });

      try {
        await client.connect();
        if (_disposed) {
          client.disconnect();
          throw StateError('信令连接已取消');
        }
        await client.subscribe('wga/room/$roomCode/#');
        if (_disposed) {
          client.disconnect();
          throw StateError('信令连接已取消');
        }
        _activeBrokerUrl = url;
        return;
      } catch (e) {
        lastError = e;
        client.disconnect();
        if (identical(_client, client)) {
          _client = null;
        }
      }
    }

    throw StateError('无法连接信令服务器，请检查网络后重试 ($lastError)');
  }

  void sendJoin(String playerName, String avatar) {
    if (_client == null || !_client!.isConnected) return;
    final payload = {
      'clientId': selfId,
      'playerName': playerName,
      'avatar': avatar,
    };
    _client!.publish('wga/room/$roomCode/join', json.encode(payload));
  }

  void sendOffer({
    required String targetClientId,
    required dynamic sdp,
  }) {
    if (_client == null || !_client!.isConnected) return;
    final payload = {
      'sdp': sdp,
      'targetClientId': targetClientId,
      'fromHostId': selfId,
    };
    _client!.publish('wga/room/$roomCode/offer/$targetClientId', json.encode(payload));
  }

  void sendAnswer({
    required String targetHostId,
    required dynamic sdp,
  }) {
    if (_client == null || !_client!.isConnected) return;
    final payload = {
      'sdp': sdp,
      'clientId': selfId,
      'targetHostId': targetHostId,
    };
    _client!.publish('wga/room/$roomCode/answer/$targetHostId', json.encode(payload));
  }

  void sendIce({
    required String targetId,
    required dynamic candidate,
  }) {
    if (_client == null || !_client!.isConnected) return;
    final payload = {
      'candidate': candidate,
      'targetId': targetId,
      'fromId': selfId,
    };
    _client!.publish('wga/room/$roomCode/ice/$targetId', json.encode(payload));
  }

  void disconnect() {
    _disposed = true;
    _client?.disconnect();
    _client = null;
  }
}
