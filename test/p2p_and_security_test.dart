import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_guess_assistant_flutter/models/protocol_messages.dart';
import 'package:word_guess_assistant_flutter/network/p2p/mini_mqtt_client.dart';
import 'package:word_guess_assistant_flutter/network/p2p/p2p_signaling.dart';
import 'package:word_guess_assistant_flutter/network/p2p/webrtc_transport.dart';

void main() {
  group('P2P Signaling, MQTT & Transport Security Tests', () {
    test('MiniMqttClient 初始化与 disconnect 幂等保护', () {
      final client =
          MiniMqttClient('wss://broker.emqx.io:8084/mqtt', 'test_agent_007');
      expect(client.isConnected, isFalse);
      expect(client.clientId, 'test_agent_007');

      // 未连接状态下多次调用 disconnect 不应抛异常
      expect(() {
        client.disconnect();
        client.disconnect();
      }, returnsNormally);
    });

    test('MiniMqttClient 连接不可达节点时干净抛错且零未捕获异步异常', () async {
      final unhandledErrors = <Object>[];

      await runZonedGuarded(() async {
        final client = MiniMqttClient('ws://127.0.0.1:1/mqtt', 'test_fail_01');
        Object? caught;
        try {
          await client.connect(timeout: const Duration(seconds: 2));
        } catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(client.isConnected, isFalse);

        // 失败后再次 disconnect 应安全幂等
        client.disconnect();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }, (error, stack) {
        unhandledErrors.add(error);
      });

      expect(unhandledErrors, isEmpty);
    });

    test('P2PSignaling 默认国际/国内 EMQX 故障切换列表与自定义节点失败回退', () async {
      expect(
        P2PSignaling.defaultSignalingUrl,
        equals('wss://broker.emqx.io:8084/mqtt'),
      );
      expect(
        P2PSignaling.defaultSignalingUrls,
        equals(const [
          'wss://broker.emqx.io:8084/mqtt',
          'wss://broker-cn.emqx.io:8084/mqtt',
        ]),
      );

      final unhandledErrors = <Object>[];
      await runZonedGuarded(() async {
        final signaling = P2PSignaling(
          roomCode: '9999',
          selfId: 'test_peer',
          brokerUrl: 'ws://127.0.0.1:1/mqtt',
        );
        expect(signaling.brokerUrl, equals('ws://127.0.0.1:1/mqtt'));

        Object? caught;
        try {
          await signaling.init();
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<StateError>());
        expect(caught.toString(), contains('无法连接信令服务器'));
        signaling.disconnect();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }, (error, stack) {
        unhandledErrors.add(error);
      });

      expect(unhandledErrors, isEmpty);
    });

    test('WebRtcP2PTransport 初始化状态与 disconnect 清理', () async {
      final transport = WebRtcP2PTransport(selfId: 'agent_p2p_01');
      expect(transport.selfId, 'agent_p2p_01');
      expect(transport.isHost, isFalse);
      expect(transport.isConnected, isFalse);
      await transport.disconnect();
      expect(transport.isConnected, isFalse);
    });

    test('GameMessage join 构造函数正确封包', () {
      final joinMsg = GameMessage.join(
        playerId: 'agent_test_99',
        playerName: '幽灵特工',
        avatar: 'characters/detective.svg',
      );

      expect(joinMsg.type, GameMessageType.joinReq);
      expect(joinMsg.payload['player_id'], 'agent_test_99');
      expect(joinMsg.payload['player_name'], '幽灵特工');
      expect(joinMsg.payload['avatar'], 'characters/detective.svg');

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
