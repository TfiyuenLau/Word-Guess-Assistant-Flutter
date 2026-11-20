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
  final BytesBuilder _rxBuffer = BytesBuilder(copy: false);
  Completer<void>? _connackCompleter;

  bool get isConnected => _isConnected;

  MiniMqttClient(this.url, [String? clientId])
      : clientId = clientId ?? 'wga_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}';

  void onMessage(MqttMessageHandler handler) {
    _handlers.add(handler);
  }

  Future<void> connect({Duration timeout = const Duration(seconds: 8)}) async {
    disconnect();
    _rxBuffer.clear();

    final sw = Stopwatch()..start();

    try {
      final uri = Uri.parse(url);
      final channel = WebSocketChannel.connect(uri, protocols: const ['mqtt']);
      _channel = channel;

      _subscription = channel.stream.listen(
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

          _processIncomingBytes(data);
        },
        onError: (Object err) {
          final comp = _connackCompleter;
          if (comp != null && !comp.isCompleted) {
            comp.completeError(err);
          }
          disconnect();
        },
        onDone: () {
          final comp = _connackCompleter;
          if (comp != null && !comp.isCompleted) {
            comp.completeError(StateError('信令连接已关闭'));
          }
          disconnect();
        },
        cancelOnError: false,
      );

      await channel.ready.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('连接信令服务器超时'),
      );

      if (_channel != channel) {
        throw StateError('信令连接已关闭');
      }

      final remaining = timeout - sw.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('连接信令服务器超时');
      }

      final connComp = Completer<void>();
      _connackCompleter = connComp;

      // 仅在 WebSocket 握手就绪后发送 CONNECT 报文
      _sendConnect();

      await connComp.future.timeout(
        remaining,
        onTimeout: () => throw TimeoutException('MQTT 握手超时'),
      );
    } catch (e) {
      _connackCompleter?.future.ignore();
      _connackCompleter = null;
      disconnect();
      rethrow;
    } finally {
      _connackCompleter = null;
    }
  }

  void _processIncomingBytes(Uint8List data) {
    if (data.isNotEmpty) {
      _rxBuffer.add(data);
    }

    final bytes = _rxBuffer.toBytes();
    var offset = 0;

    while (offset < bytes.length) {
      final packetStart = offset;
      final header = bytes[offset++];
      final packetType = header >> 4;

      // 解码变长剩余长度（MQTT 3.1.1 最多 4 字节）
      var multiplier = 1;
      var remainingLength = 0;
      var lengthComplete = false;
      var lengthBytes = 0;

      while (offset < bytes.length) {
        final digit = bytes[offset++];
        remainingLength += (digit & 0x7f) * multiplier;
        lengthBytes++;
        if ((digit & 0x80) == 0) {
          lengthComplete = true;
          break;
        }
        multiplier *= 128;
        if (lengthBytes >= 4) {
          // 异常报文长度，清空缓冲防止死循环
          _rxBuffer.clear();
          return;
        }
      }

      if (!lengthComplete || offset + remainingLength > bytes.length) {
        // 半包数据：回退到报文起点，等待后续分片
        offset = packetStart;
        break;
      }

      final content = Uint8List.sublistView(bytes, offset, offset + remainingLength);
      offset += remainingLength;

      // CONNACK (Packet Type 2)
      if (packetType == 2) {
        final comp = _connackCompleter;
        if (content.length >= 2 && content[1] != 0) {
          if (comp != null && !comp.isCompleted) {
            comp.completeError(StateError('MQTT 连接被拒绝 (code: ${content[1]})'));
          }
          disconnect();
          return;
        }
        _isConnected = true;
        _startPing();
        if (comp != null && !comp.isCompleted) {
          comp.complete();
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

    _rxBuffer.clear();
    if (offset < bytes.length) {
      _rxBuffer.add(Uint8List.sublistView(bytes, offset));
    }
  }

  void _handlePublish(int header, Uint8List content) {
    try {
      final qos = (header >> 1) & 0x03;
      var offset = 0;

      if (content.length < 2) return;
      final topicLen = (content[offset] << 8) | content[offset + 1];
      offset += 2;
      if (offset + topicLen > content.length) return;
      final topic = utf8.decode(content.sublist(offset, offset + topicLen));
      offset += topicLen;

      if (qos > 0) {
        offset += 2; // 跳过 PacketId
      }
      if (offset > content.length) return;

      final payload = utf8.decode(content.sublist(offset));
      final msg = MqttMessage(topic: topic, payload: payload);
      for (final handler in List<MqttMessageHandler>.of(_handlers)) {
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
    try {
      _channel?.sink.add(packet);
    } catch (_) {
      _pendingSubscribes.remove(pid);
      if (!completer.isCompleted) {
        completer.complete();
      }
      return completer.future;
    }

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
    try {
      _channel?.sink.add(packet);
    } catch (_) {}
  }

  void disconnect() {
    _stopPing();
    _rxBuffer.clear();

    final wasConnected = _isConnected;
    _isConnected = false;

    final connComp = _connackCompleter;
    _connackCompleter = null;
    if (connComp != null && !connComp.isCompleted) {
      connComp.future.ignore();
      connComp.completeError(StateError('连接已断开'));
    }

    for (final comp in _pendingSubscribes.values) {
      if (!comp.isCompleted) comp.complete();
    }
    _pendingSubscribes.clear();

    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      try {
        sub.cancel().catchError((_) {});
      } catch (_) {}
    }

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      if (wasConnected) {
        try {
          channel.sink.add(Uint8List.fromList([0xe0, 0x00])); // DISCONNECT
        } catch (_) {}
      }
      try {
        Future<void>.sync(() => channel.sink.close()).catchError((_) {});
      } catch (_) {}
    }
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
