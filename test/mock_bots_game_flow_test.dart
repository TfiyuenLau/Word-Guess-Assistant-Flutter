import 'package:flutter_test/flutter_test.dart';
import 'package:word_guess_assistant_flutter/core/game_engine.dart';
import 'package:word_guess_assistant_flutter/core/mock_bots.dart';
import 'package:word_guess_assistant_flutter/models/game_models.dart';

void main() {
  group('Mock Bots & Complete Game Flow Integration Tests', () {
    test('单人创建房间并填充 3 名 Mock Bot 跑通全闭环博弈流转', () {
      final engine = GameEngine();

      // 1. 房主进入
      final host = Player(id: 'host_01', name: '房主特工', avatar: 'agent_1');
      engine.addPlayer(host);
      expect(engine.players.length, 1);

      // 2. 填充 3 名机器人
      final bots = MockBots.generateBots(3, excludeIds: [host.id]);
      for (final b in bots) {
        engine.addPlayer(b);
      }
      expect(engine.players.length, 4);
      expect(engine.players.values.where((p) => p.isBot).length, 3);

      // 3. 启动博弈
      final assignments = engine.startGame();
      expect(engine.phase, GamePhase.description);
      expect(assignments.length, 4);

      // 4. 模拟描述发言阶段：机器人发言生成
      for (final p in engine.players.values) {
        if (p.isBot) {
          final speech = MockBots.generateBotSpeech(p, engine.theme);
          expect(speech, isNotEmpty);
        }
      }

      // 5. 推进至公投阶段
      final voteAdv = engine.advancePhase();
      expect(voteAdv.phase, GamePhase.voting);

      // 6. 机器人自动提交公投票
      final botVotes = MockBots.simulateBotVotes(engine);
      for (final entry in botVotes.entries) {
        engine.submitVote(entry.key, entry.value);
      }
      // 房主也投票
      final otherAlive = engine.players.values.firstWhere((p) => p.id != host.id && p.isAlive);
      engine.submitVote(host.id, otherAlive.id);

      // 7. 结算投票流转
      final afterVote = engine.advancePhase();
      expect(
        afterVote.phase == GamePhase.nightAction ||
            afterVote.phase == GamePhase.blankGuess ||
            afterVote.phase == GamePhase.settlement,
        isTrue,
      );

      // 8. 验证快照导出与反序列化完整性（支持断线重连/全量同步）
      final snapshot = engine.toSnapshotMap();
      expect(snapshot['phase'], engine.phase.index);
      expect(snapshot['round'], engine.round);
      expect((snapshot['players'] as Map).length, 4);

      final restoredEngine = GameEngine();
      restoredEngine.applySnapshot(snapshot);

      expect(restoredEngine.phase, engine.phase);
      expect(restoredEngine.round, engine.round);
      expect(restoredEngine.players.length, engine.players.length);
      expect(restoredEngine.wordA, engine.wordA);
      expect(restoredEngine.wordB, engine.wordB);
    });
  });
}
