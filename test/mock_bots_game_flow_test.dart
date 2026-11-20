import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_guess_assistant_flutter/core/game_engine.dart';
import 'package:word_guess_assistant_flutter/core/mock_bots.dart';
import 'package:word_guess_assistant_flutter/models/game_models.dart';
import 'package:word_guess_assistant_flutter/models/word_bank.dart';

void main() {
  setUpAll(() {
    WordBank.loadFromJsonString(File('assets/word_bank.json').readAsStringSync());
  });

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

    test('机器人白板被投出时自动触发猜词行为模拟', () {
      final engine = GameEngine();
      final bots = MockBots.generateBots(4);
      for (final b in bots) {
        engine.addPlayer(b);
      }
      engine.startGame();

      final blankBot = engine.players.values.firstWhere((p) => p.role == GameRoles.blank);
      final guess = MockBots.simulateBotBlankGuess(engine, blankBot.id);
      expect(guess, isNotNull);
      expect(guess!['word_a'], isNotEmpty);
      expect(guess['word_b'], isNotEmpty);

      // 非白板特工无法触发
      final otherBot = engine.players.values.firstWhere((p) => p.id != blankBot.id);
      final invalidGuess = MockBots.simulateBotBlankGuess(engine, otherBot.id);
      expect(invalidGuess, isNull);
    });

    test('全机器人环境夜间刺杀与胜负流转闭环测试', () {
      final engine = GameEngine();
      final bots = MockBots.generateBots(4);
      for (final b in bots) {
        engine.addPlayer(b);
      }
      engine.startGame();

      // 进入黑夜阶段
      engine.phase = GamePhase.nightAction;

      // 机器人卧底执行暗杀
      final botActions = MockBots.simulateBotNightActions(engine);
      expect(botActions.isNotEmpty, isTrue);

      for (final entry in botActions.entries) {
        final res = engine.submitNightAction(entry.key, entry.value);
        expect(res.success, isTrue);
      }

      // 天亮结算
      final nextPhase = engine.advancePhase();
      expect(
        nextPhase.phase == GamePhase.description ||
            nextPhase.phase == GamePhase.settlement,
        isTrue,
      );
    });
  });
}
