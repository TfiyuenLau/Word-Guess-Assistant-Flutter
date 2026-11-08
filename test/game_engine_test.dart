import 'package:flutter_test/flutter_test.dart';
import 'package:word_guess_assistant_flutter/core/game_engine.dart';
import 'package:word_guess_assistant_flutter/models/game_models.dart';

void main() {
  group('GameEngine Core Rules & Matrix Tests', () {
    test('4~12 人动态身份配比矩阵完整性测试', () {
      // 期望配比矩阵：(总人数, 卧底, 天使, 白板, 好人)
      final expectedMatrix = [
        [4, 1, 1, 1, 1],
        [5, 1, 1, 1, 2],
        [6, 2, 1, 1, 2],
        [7, 2, 1, 1, 3],
        [8, 2, 1, 1, 4],
        [9, 3, 1, 1, 4],
        [10, 3, 1, 1, 5],
        [11, 3, 1, 1, 6],
        [12, 4, 1, 1, 6],
      ];

      for (final row in expectedMatrix) {
        final total = row[0];
        final expSpy = row[1];
        final expAngel = row[2];
        final expBlank = row[3];
        final expGood = row[4];

        final playerIds = List.generate(total, (i) => 'player_$i');
        final roles = GameEngine.assignRoles(playerIds);

        expect(roles.length, total, reason: '$total 人局总数匹配');

        final spies = roles.values.where((r) => r == GameRoles.spy).length;
        final angels = roles.values.where((r) => r == GameRoles.angel).length;
        final blanks = roles.values.where((r) => r == GameRoles.blank).length;
        final goods = roles.values.where((r) => r == GameRoles.good).length;

        expect(spies, expSpy, reason: '$total 人局卧底数量不符');
        expect(angels, expAngel, reason: '$total 人局天使数量不符');
        expect(blanks, expBlank, reason: '$total 人局白板数量不符');
        expect(goods, expGood, reason: '$total 人局好人数量不符');
      }
    });

    test('开局身份与词汇下发盲盒特性测试', () {
      final engine = GameEngine();
      for (var i = 1; i <= 6; i++) {
        engine.addPlayer(Player(
          id: 'p$i',
          name: '特工$i',
          avatar: 'agent_1',
        ));
      }

      final assignments = engine.startGame(
        customTheme: '美食饮品',
        customSimilarity: '极为接近',
      );

      expect(engine.phase, GamePhase.description);
      expect(engine.round, 1);
      expect(engine.wordA, isNotEmpty);
      expect(engine.wordB, isNotEmpty);
      expect(engine.hint, isNotEmpty);

      // 验证盲盒：好人和卧底拿到的 assignment.role 必须都是 AGENT，不得提前泄露
      for (final p in engine.players.values) {
        final idn = assignments[p.id]!;
        if (p.role == GameRoles.good) {
          expect(idn.role, GameRoles.agent);
          expect(idn.word, engine.wordA);
          expect(idn.hint, isEmpty);
        } else if (p.role == GameRoles.spy) {
          expect(idn.role, GameRoles.agent);
          expect(idn.word, engine.wordB);
          expect(idn.hint, isEmpty);
        } else if (p.role == GameRoles.angel) {
          expect(idn.role, GameRoles.angel);
          expect(idn.word.contains(engine.wordA), isTrue);
          expect(idn.word.contains(engine.wordB), isTrue);
          expect(idn.word.contains(' / '), isTrue);
        } else if (p.role == GameRoles.blank) {
          expect(idn.role, GameRoles.blank);
          expect(idn.word, '【无词】');
          expect(idn.hint, engine.hint);
        }
      }
    });

    test('白天秘密投票与平票入夜逻辑测试', () {
      final engine = GameEngine();
      for (var i = 1; i <= 4; i++) {
        engine.addPlayer(Player(id: 'p$i', name: '特工$i', avatar: 'agent_1'));
      }
      engine.startGame();

      // 推进至投票阶段
      final adv = engine.advancePhase();
      expect(adv.phase, GamePhase.voting);
      expect(engine.phase, GamePhase.voting);

      // 投票：p1, p2 投 p3 (2票)；p3, p4 投 p2 (2票) -> 平票
      engine.submitVote('p1', 'p3');
      engine.submitVote('p2', 'p3');
      engine.submitVote('p3', 'p2');
      final res = engine.submitVote('p4', 'p2');

      expect(res.allVoted, isTrue);

      // 平票结算推进
      final advRes = engine.advancePhase();
      expect(advRes.phase, GamePhase.nightAction);
      expect(advRes.announcement.contains('平票'), isTrue);

      // 所有人依然存活
      expect(engine.players.values.every((p) => p.isAlive), isTrue);
    });

    test('白板白天被公投出局后触发专属猜词与逆袭绝杀胜负测试', () {
      final engine = GameEngine();
      for (var i = 1; i <= 4; i++) {
        engine.addPlayer(Player(id: 'p$i', name: '特工$i', avatar: 'agent_1'));
      }
      engine.startGame();

      // 找出白板特工
      final blankPlayer = engine.players.values.firstWhere((p) => p.role == GameRoles.blank);

      // 推进至投票阶段
      engine.advancePhase();

      // 全员投给白板
      for (final p in engine.players.values) {
        engine.submitVote(p.id, blankPlayer.id);
      }

      final advRes = engine.advancePhase();
      // 必须进入 blankGuess 阶段
      expect(advRes.phase, GamePhase.blankGuess);
      expect(engine.phase, GamePhase.blankGuess);
      expect(engine.players[blankPlayer.id]!.isAlive, isFalse);

      // 1. 白板逆袭猜错
      final wrongRes = engine.submitBlankGuess(
        playerId: blankPlayer.id,
        guessA: '错误词1',
        guessB: '错误词2',
      );
      expect(wrongRes.isCorrect, isFalse);
      expect(wrongRes.gameOver, isFalse);
      expect(engine.phase, GamePhase.nightAction);

      // 2. 模拟白板猜中（顺序逆向亦可）
      engine.phase = GamePhase.blankGuess;
      final winRes = engine.submitBlankGuess(
        playerId: blankPlayer.id,
        guessA: engine.wordB,
        guessB: engine.wordA,
      );
      expect(winRes.isCorrect, isTrue);
      expect(winRes.gameOver, isTrue);
      expect(engine.phase, GamePhase.settlement);
      expect(engine.winner, GameRoles.blank);
      expect(engine.settlementDetails?.winnerCamp, GameRoles.blank);
    });

    test('黑夜刺杀与非卧底误动自爆反噬测试', () {
      final engine = GameEngine();
      for (var i = 1; i <= 4; i++) {
        engine.addPlayer(Player(id: 'p$i', name: '特工$i', avatar: 'agent_1'));
      }
      engine.startGame();

      final spy = engine.players.values.firstWhere((p) => p.role == GameRoles.spy);
      final good = engine.players.values.firstWhere((p) => p.role == GameRoles.good);

      // 设置为黑夜阶段
      engine.phase = GamePhase.nightAction;

      // 1. 真卧底刀好人：好人出局，卧底收到成功反馈
      final spyAct = engine.submitNightAction(spy.id, good.id);
      expect(spyAct.success, isTrue);
      expect(engine.players[good.id]!.isAlive, isFalse);
      expect(engine.nightCasualties.contains(good.id), isTrue);

      // 2. 好人以为自己是卧底盲动刀卧底：好人自爆出局，反噬自身
      final angel = engine.players.values.firstWhere((p) => p.role == GameRoles.angel);
      final misfireAct = engine.submitNightAction(angel.id, spy.id);
      expect(misfireAct.success, isTrue);
      expect(misfireAct.feedback.contains('自爆'), isTrue);
      expect(engine.players[angel.id]!.isAlive, isFalse);
      expect(engine.nightCasualties.contains(angel.id), isTrue);

      // 3. 推进出黑夜：战报统一客观播报伤亡，绝不泄露死因
      final nightAdv = engine.advancePhase();
      expect(nightAdv.announcement.contains('【夜间战报】'), isTrue);
      expect(nightAdv.announcement.contains(good.name), isTrue);
      expect(nightAdv.announcement.contains(angel.name), isTrue);
    });

    test('胜负判定：卧底击杀好人后人数占优胜出', () {
      final engine = GameEngine();
      for (var i = 1; i <= 4; i++) {
        engine.addPlayer(Player(id: 'p$i', name: '特工$i', avatar: 'agent_1'));
      }
      engine.startGame();

      final spy = engine.players.values.firstWhere((p) => p.role == GameRoles.spy);
      final good = engine.players.values.firstWhere((p) => p.role == GameRoles.good);
      final angel = engine.players.values.firstWhere((p) => p.role == GameRoles.angel);

      // 让平民好人和天使全部出局，此时存活好人=0，卧底存活=1
      expect(spy.isAlive, isTrue);
      engine.players[good.id] = good.copyWith(isAlive: false);
      engine.players[angel.id] = angel.copyWith(isAlive: false);

      final winner = engine.checkWinner();
      expect(winner, GameRoles.spy);
    });

    test('胜负判定：存活特工 <= 2 且有卧底在场直接判定卧底获胜', () {
      final engine = GameEngine();
      for (var i = 1; i <= 4; i++) {
        engine.addPlayer(Player(id: 'p$i', name: '特工$i', avatar: 'agent_1'));
      }
      engine.startGame();

      final spy = engine.players.values.firstWhere((p) => p.role == GameRoles.spy);
      final blank = engine.players.values.firstWhere((p) => p.role == GameRoles.blank);
      final others = engine.players.values.where((p) => p.id != spy.id && p.id != blank.id);

      for (final o in others) {
        engine.players[o.id] = o.copyWith(isAlive: false);
      }
      // 此时仅剩 spy 和 blank 存活 (总存活 = 2)
      final winner = engine.checkWinner();
      expect(winner, GameRoles.spy);
    });

    test('胜负判定：好人卧底全灭，白板唯一独活判定白板胜出', () {
      final engine = GameEngine();
      for (var i = 1; i <= 4; i++) {
        engine.addPlayer(Player(id: 'p$i', name: '特工$i', avatar: 'agent_1'));
      }
      engine.startGame();

      final blank = engine.players.values.firstWhere((p) => p.role == GameRoles.blank);
      final nonBlanks = engine.players.values.where((p) => p.id != blank.id);

      for (final nb in nonBlanks) {
        engine.players[nb.id] = nb.copyWith(isAlive: false);
      }

      final winner = engine.checkWinner();
      expect(winner, GameRoles.blank);
    });

    test('快照脱敏安全性与断线重连身份恢复测试', () {
      final engine = GameEngine();
      for (var i = 1; i <= 4; i++) {
        engine.addPlayer(Player(id: 'p$i', name: '特工$i', avatar: 'agent_1'));
      }
      engine.startGame();

      // 1. 游戏中阶段对外广播脱敏快照测试
      final maskedSnapshot = engine.toSnapshotMap(maskSecrets: true, forPlayerId: 'p1');
      expect(maskedSnapshot['word_a'], isEmpty, reason: '绝密好人词必须被隐藏');
      expect(maskedSnapshot['word_b'], isEmpty, reason: '绝密卧底词必须被隐藏');
      expect(maskedSnapshot['hint'], isEmpty, reason: '绝密提示必须被隐藏');
      expect(maskedSnapshot['votes'], isEmpty, reason: '秘密投票记录不可公开');

      final rawPlayers = maskedSnapshot['players'] as Map<String, dynamic>;
      // p1 自身应包含自身数据，其他玩家身份词汇必须脱敏
      for (final entry in rawPlayers.entries) {
        final map = entry.value as Map<String, dynamic>;
        if (entry.key != 'p1') {
          expect(map['word'], isNull, reason: '其他特工词汇必须为 null');
          expect(map['hint'], isNull, reason: '其他特工提示必须为 null');
          expect(map['role'], GameRoles.agent, reason: '好人与卧底对外显示特工盲盒');
        }
      }

      // 2. 既有玩家断线重连身份恢复测试
      final p2 = engine.players['p2']!;
      final recoveredIdn = engine.getIdentityAssignment(p2.id);
      expect(recoveredIdn, isNotNull);
      if (p2.role == GameRoles.good) {
        expect(recoveredIdn!.word, engine.wordA);
      } else if (p2.role == GameRoles.spy) {
        expect(recoveredIdn!.word, engine.wordB);
      } else if (p2.role == GameRoles.blank) {
        expect(recoveredIdn!.word, '【无词】');
        expect(recoveredIdn.hint, engine.hint);
      }

      // 3. 陌生人中途加入自动转为观战者测试
      final stranger = Player(id: 'stranger_99', name: '路人特工', avatar: 'agent_1');
      engine.addPlayer(stranger);
      expect(engine.players['stranger_99']!.role, GameRoles.spectator);
      expect(engine.players['stranger_99']!.isAlive, isFalse);
    });
  });
}
