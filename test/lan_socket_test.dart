import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_guess_assistant_flutter/models/protocol_messages.dart';

void main() {
  group('TCP Framing, Serialization & Codec Tests', () {
    test('单包正确编解码往返测试', () {
      final msg = GameMessage.chat(
        senderId: 'agent_99',
        text: '暗号已收到，立即执行行动！',
      );

      final encoded = TcpFrameCodec.encode(msg);
      expect(encoded.length >= 4, isTrue);

      final decoder = MessageFrameDecoder();
      final decoded = decoder.feed(encoded);

      expect(decoded.length, 1);
      expect(decoded.first.type, GameMessageType.chat);
      expect(decoded.first.payload['sender_id'], 'agent_99');
      expect(decoded.first.payload['text'], '暗号已收到，立即执行行动！');
    });

    test('TCP 粘包测试（多个数据包合并在单个底层 TCP chunk 中到达）', () {
      final msg1 = GameMessage.join(playerId: 'p1', playerName: '特工1', avatar: 'a1');
      final msg2 = GameMessage.vote(voterId: 'p1', targetId: 'p2');
      final msg3 = GameMessage.chat(senderId: 'SYSTEM', text: '阶段已流转', isSystem: true);

      final chunk1 = TcpFrameCodec.encode(msg1);
      final chunk2 = TcpFrameCodec.encode(msg2);
      final chunk3 = TcpFrameCodec.encode(msg3);

      final mergedChunk = Uint8List(chunk1.length + chunk2.length + chunk3.length);
      mergedChunk.setRange(0, chunk1.length, chunk1);
      mergedChunk.setRange(chunk1.length, chunk1.length + chunk2.length, chunk2);
      mergedChunk.setRange(chunk1.length + chunk2.length, mergedChunk.length, chunk3);

      final decoder = MessageFrameDecoder();
      final msgs = decoder.feed(mergedChunk);

      expect(msgs.length, 3);
      expect(msgs[0].type, GameMessageType.joinReq);
      expect(msgs[1].type, GameMessageType.vote);
      expect(msgs[2].type, GameMessageType.chat);
    });

    test('TCP 半包分片测试（单个数据包跨多个 chunk 分裂到达）', () {
      final msg = GameMessage.syncPhase(
        newPhase: 2,
        extraInfo: '非常长且详细的阶段流转说明文本内容' * 10,
      );

      final fullFrame = TcpFrameCodec.encode(msg);
      expect(fullFrame.length > 20, isTrue);

      final cutPoint1 = 7;
      final cutPoint2 = 25;

      final part1 = fullFrame.sublist(0, cutPoint1);
      final part2 = fullFrame.sublist(cutPoint1, cutPoint2);
      final part3 = fullFrame.sublist(cutPoint2);

      final decoder = MessageFrameDecoder();

      // 第一段（仅有前缀与少量字节）：无消息解码
      final r1 = decoder.feed(part1);
      expect(r1, isEmpty);

      // 第二段（半包中间部分）：仍无消息解码
      final r2 = decoder.feed(part2);
      expect(r2, isEmpty);

      // 第三段（拼接完成）：一次性成功解码出完整消息
      final r3 = decoder.feed(part3);
      expect(r3.length, 1);
      expect(r3.first.type, GameMessageType.syncPhase);
      expect(r3.first.payload['new_phase'], 2);
    });

    test('超大恶意包防御测试（超过 16MB 阈值抛出 FormatException）', () {
      final badHeader = Uint8List(4);
      ByteData.sublistView(badHeader).setUint32(0, 20 * 1024 * 1024, Endian.big); // 20MB

      final decoder = MessageFrameDecoder();
      expect(() => decoder.feed(badHeader), throwsFormatException);
    });
  });
}
