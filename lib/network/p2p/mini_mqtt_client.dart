import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class MqttMessage {
  final String topic;
  final String payload;

  const MqttMessage({required this.topic, required this.payload});
}

typedef MqttMessageHandler = void Function(MqttMessage message);

/// 极简零依赖纯 Dart MQTT 3.1.1 over WebSocket 客户端
/// 专用于 WebRTC P2P 瞬间信令交换（Offer/Answer/ICE）
class MiniMqttClient {
  final String url;
  final String clientId;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;

  bool _isConnected = false;
  int _packetId = 1;

  final List<MqttMessageHandler> _handlers = [];
  final Map<int, Completer<void>> _pendingSubscribes = {};

  bool get isConnected => _isConnected;

  MiniMqttClient(this.url, [String? clientId])
      : clientId = clientId ?? 'wga_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}';

  void onMessage(MqttMessageHandler handler) {
    _handlers.add(handler);
  }

  Future<void> connect({Duration timeout = const Duration(seconds: 8)}) async {
    final connectCompleter = Completer<void>();
    Timer? timeoutTimer;

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);

      timeoutTimer = Timer(timeout, () {
        if (!connectCompleter.isCompleted) {
          disconnect();
          connectCompleter.completeError(TimeoutException('连接信令服务器超时'));
        }
      });

      _subscription = _channel!.stream.listen(
        (dynamic rawData) {
          final Uint8List data;
          if (rawData is Uint8List) {
            data = rawData;
          } else if (rawData is List<int>) {
            data = Uint8List.fromList(rawData);
          } else if (rawData is String) {
            data = Uint8List.fromList(utf8.encode(rawData));
          } else {
            return;
          }

          _processIncomingBytes(data, connectCompleter);
        },
        onError: (dynamic err) {
          if (!connectCompleter.isCompleted) {
            connectCompleter.completeError(err);
          }
          disconnect();
        },
        onDone: () {
          disconnect();
        },
        cancelOnError: false,
      );

      // 发送 CONNECT 报文
      _sendConnect();

      await connectCompleter.future;
    } catch (e) {
      disconnect();
      rethrow;
    } finally {
      timeoutTimer?.cancel();
    }
  }

  void _processIncomingBytes(Uint8List data, Completer<void> connectCompleter) {
    var offset = 0;
    while (offset < data.length) {
      final header = data[offset++];
      final packetType = header >> 4;

      // 解码变长剩余长度
      var multiplier = 1;
      var remainingLength = 0;
      int digit;
      do {
        if (offset >= data.length) break;
        digit = data[offset++];
        remainingLength += (digit & 0x7f) * multiplier;
        multiplier *= 128;
      } while ((digit & 0x80) != 0 && offset < data.length);

      if (offset + remainingLength > data.length) {
        break;
      }

      final content = Uint8List.sublistView(data, offset, offset + remainingLength);
      offset += remainingLength;

      // CONNACK (Packet Type 2)
      if (packetType == 2) {
        _isConnected = true;
        _startPing();
        if (!connectCompleter.isCompleted) {
          connectCompleter.complete();
        }
      }
      // SUBACK (Packet Type 9)
      else if (packetType == 9) {
        if (content.length >= 2) {
          final pid = (content[0] << 8) | content[1];
          final comp = _pendingSubscribes.remove(pid);
          if (comp != null && !comp.isCompleted) {
            comp.complete();
          }
        }
      }
      // PUBLISH (Packet Type 3)
      else if (packetType == 3) {
        _handlePublish(header, content);
      }
    }
  }

  void _handlePublish(int header, Uint8List content) {
    try {
      final qos = (header >> 1) & 0x03;
      var offset = 0;

      final topicLen = (content[offset] << 8) | content[offset + 1];
      offset += 2;
      final topic = utf8.decode(content.sublist(offset, offset + topicLen));
      offset += topicLen;

      if (qos > 0) {
        offset += 2; // 跳过 PacketId
      }

      final payload = utf8.decode(content.sublist(offset));
      final msg = MqttMessage(topic: topic, payload: payload);
      for (final handler in _handlers) {
        handler(msg);
      }
    } catch (_) {}
  }

  Future<void> subscribe(String topic) async {
    if (_channel == null || !_isConnected) return;

    _packetId = (_packetId + 1) & 0xffff;
    if (_packetId == 0) _packetId = 1;
    final pid = _packetId;

    final completer = Completer<void>();
    _pendingSubscribes[pid] = completer;

    final topicBytes = utf8.encode(topic);
    final varHeaderAndPayload = Uint8List(2 + 2 + topicBytes.length + 1);

    varHeaderAndPayload[0] = (pid >> 8) & 0xff;
    varHeaderAndPayload[1] = pid & 0xff;
    varHeaderAndPayload[2] = (topicBytes.length >> 8) & 0xff;
    varHeaderAndPayload[3] = topicBytes.length & 0xff;
    varHeaderAndPayload.setRange(4, 4 + topicBytes.length, topicBytes);
    varHeaderAndPayload[4 + topicBytes.length] = 0x00; // QoS 0

    final packet = _buildPacket(0x82, varHeaderAndPayload);
    _channel?.sink.add(packet);

    // 4 秒保护超时
    Timer(const Duration(seconds: 4), () {
      if (_pendingSubscribes.containsKey(pid)) {
        _pendingSubscribes.remove(pid);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  void publish(String topic, String message) {
    if (_channel == null || !_isConnected) return;

    final topicBytes = utf8.encode(topic);
    final payloadBytes = utf8.encode(message);

    final content = Uint8List(2 + topicBytes.length + payloadBytes.length);
    content[0] = (topicBytes.length >> 8) & 0xff;
    content[1] = topicBytes.length & 0xff;
    content.setRange(2, 2 + topicBytes.length, topicBytes);
    content.setRange(2 + topicBytes.length, content.length, payloadBytes);

    final packet = _buildPacket(0x30, content);
    _channel?.sink.add(packet);
  }

  void disconnect() {
    _stopPing();
    for (final comp in _pendingSubscribes.values) {
      if (!comp.isCompleted) comp.complete();
    }
    _pendingSubscribes.clear();

    if (_channel != null) {
      if (_isConnected) {
        try {
          _channel?.sink.add(Uint8List.fromList([0xe0, 0x00])); // DISCONNECT
        } catch (_) {}
      }
      _subscription?.cancel();
      _subscription = null;
      _channel?.sink.close();
      _channel = null;
    }
    _isConnected = false;
  }

  void _sendConnect() {
    final clientBytes = utf8.encode(clientId);
    final protoName = utf8.encode('MQTT');

    final varAndPayloadLen = 2 + protoName.length + 1 + 1 + 2 + (2 + clientBytes.length);
    final content = Uint8List(varAndPayloadLen);

    var offset = 0;
    content[offset++] = (protoName.length >> 8) & 0xff;
    content[offset++] = protoName.length & 0xff;
    content.setRange(offset, offset + protoName.length, protoName);
    offset += protoName.length;

    content[offset++] = 0x04; // Level 4 (MQTT 3.1.1)
    content[offset++] = 0x02; // Clean Session
    content[offset++] = 0x00; // Keep Alive MSB
    content[offset++] = 0x3c; // Keep Alive LSB (60s)

    content[offset++] = (clientBytes.length >> 8) & 0xff;
    content[offset++] = clientBytes.length & 0xff;
    content.setRange(offset, offset + clientBytes.length, clientBytes);

    final packet = _buildPacket(0x10, content);
    _channel?.sink.add(packet);
  }

  void _startPing() {
    _stopPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_channel != null && _isConnected) {
        try {
          _channel?.sink.add(Uint8List.fromList([0xc0, 0x00])); // PINGREQ
        } catch (_) {}
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Uint8List _buildPacket(int header, Uint8List content) {
    var remLen = content.length;
    final lenBytes = <int>[];
    do {
      var digit = remLen % 128;
      remLen ~/= 128;
      if (remLen > 0) {
        digit |= 0x80;
      }
      lenBytes.add(digit);
    } while (remLen > 0);

    final packet = Uint8List(1 + lenBytes.length + content.length);
    packet[0] = header;
    packet.setRange(1, 1 + lenBytes.length, lenBytes);
    packet.setRange(1 + lenBytes.length, packet.length, content);
    return packet;
  }
}
