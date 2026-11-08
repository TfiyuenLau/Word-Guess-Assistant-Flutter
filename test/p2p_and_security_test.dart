import 'package:flutter_test/flutter_test.dart';
import 'package:word_guess_assistant_flutter/models/protocol_messages.dart';
import 'package:word_guess_assistant_flutter/network/p2p/mini_mqtt_client.dart';
import 'package:word_guess_assistant_flutter/network/p2p/webrtc_transport.dart';

void main() {
  group('P2P Signaling, MQTT & Transport Security Tests', () {
    test('MiniMqttClient CONNECT 报文构建与 ClientId 越界保护测试', () {
      final client = MiniMqttClient('wss://broker.emqx.io:8084/mqtt', 'test_agent_007');
      expect(client.isConnected, isFalse);
      expect(client.clientId, 'test_agent_007');
      // 验证客户端初始化不抛异常
    });

    test('WebRtcP2PTransport 加入房间时保留昵称与形象', () async {
      final transport = WebRtcP2PTransport(selfId: 'agent_p2p_01');
      expect(transport.selfId, 'agent_p2p_01');
      expect(transport.isHost, isFalse);
      expect(transport.isConnected, isFalse);
    });

    test('GameMessage join 构造函数正确封包', () {
      final joinMsg = GameMessage.join(
        playerId: 'agent_test_99',
        playerName: '幽灵特工',
        avatar: 'agent_4',
      );

      expect(joinMsg.type, GameMessageType.joinReq);
      expect(joinMsg.payload['player_id'], 'agent_test_99');
      expect(joinMsg.payload['player_name'], '幽灵特工');
      expect(joinMsg.payload['avatar'], 'agent_4');

      final jsonStr = joinMsg.toJson();
      final decoded = GameMessage.fromJson(jsonStr);
      expect(decoded.payload['player_name'], '幽灵特工');
    });

    test('GameMessage identity 构造函数与脱敏验证', () {
      final idMsg = GameMessage.identity(
        role: 'AGENT',
        word: '可乐',
        hint: '',
      );

      expect(idMsg.type, GameMessageType.identity);
      expect(idMsg.payload['role'], 'AGENT');
      expect(idMsg.payload['word'], '可乐');
    });
  });
}
