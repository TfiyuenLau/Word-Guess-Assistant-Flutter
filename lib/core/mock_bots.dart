import 'dart:math';
import '../models/game_models.dart';
import 'game_engine.dart';

/// 机器人（Mock Bot）生成与行为模拟引擎
class MockBots {
  static int _botSeq = 0;

  static const List<String> botCodenames = [
    'Alpha',
    'Bravo',
    'Charlie',
    'Delta',
    'Echo',
    'Foxtrot',
    'Golf',
    'Hotel',
    'India',
    'Juliet',
    'Kilo',
    'Lima',
  ];

  static const List<String> botAvatars = [
    'characters/detective.svg',
    'characters/ninja.svg',
    'characters/robot.svg',
    'characters/hero.svg',
    'characters/wizard.svg',
    'animals/fox.svg',
    'animals/cat.svg',
    'animals/bear.svg',
    'animals/rabbit.svg',
    'animals/panda.svg',
    'cyber/agent.svg',
    'cyber/cyborg.svg',
    'cyber/hacker.svg',
    'cyber/neon.svg',
    'cyber/glitch.svg',
  ];

  /// 生成指定数量的机器人玩家（保证多次增量添加时 ID 与名称均不冲突）
  static List<Player> generateBots(
    int count, {
    List<String>? excludeIds,
    List<String>? excludeNames,
  }) {
    final bots = <Player>[];
    final random = Random();
    final excludedIdSet = <String>{...?excludeIds};
    final excludedNameSet = <String>{...?excludeNames};

    for (final codename in botCodenames) {
      if (bots.length >= count) break;
      final name = 'AI · $codename';
      if (excludedNameSet.contains(name)) continue;
      excludedNameSet.add(name);

      String id;
      do {
        _botSeq++;
        id = 'bot_${_botSeq}_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}';
      } while (excludedIdSet.contains(id));
      excludedIdSet.add(id);

      bots.add(Player(
        id: id,
        name: name,
        avatar: botAvatars[random.nextInt(botAvatars.length)],
        isBot: true,
        isAlive: true,
      ));
    }

    var fallbackIdx = 1;
    while (bots.length < count) {
      final name = 'AI · $fallbackIdx';
      fallbackIdx++;
      if (excludedNameSet.contains(name)) continue;
      excludedNameSet.add(name);

      String id;
      do {
        _botSeq++;
        id = 'bot_${_botSeq}_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}';
      } while (excludedIdSet.contains(id));
      excludedIdSet.add(id);

      bots.add(Player(
        id: id,
        name: name,
        avatar: botAvatars[random.nextInt(botAvatars.length)],
        isBot: true,
        isAlive: true,
      ));
    }

    return bots;
  }

  /// 模拟机器人自动发言
  static String generateBotSpeech(Player bot, String? topic) {
    final random = Random();
    final quotes = [
      '我认为这个事物在生活中很有辨识度。',
      '大家注意观察，它的用途比较专一且常见。',
      '从外观和使用场景来看，有些人的描述有点含糊。',
      '我的词让我联想到了它的材质和日常手感。',
      '感觉有人的发言稍微偏离了核心特征，值得留意。',
      '这个词在特定场合出现的频率比较高。',
    ];
    return quotes[random.nextInt(quotes.length)];
  }

  /// 模拟机器人自动投票（随机投给除自己之外的某位存活玩家）
  static Map<String, String> simulateBotVotes(GameEngine engine) {
    final botVotes = <String, String>{};
    final random = Random();
    final alivePlayers = engine.players.values.where((p) => p.isAlive).toList();

    for (final p in alivePlayers) {
      if (!p.isBot) continue;
      if (engine.votes.containsKey(p.id)) continue;

      final targets = alivePlayers.where((t) => t.id != p.id).toList();
      if (targets.isNotEmpty) {
        final target = targets[random.nextInt(targets.length)];
        botVotes[p.id] = target.id;
      }
    }
    return botVotes;
  }

  /// 模拟机器人夜晚行动（若是卧底，挑选一名存活的非卧底目标）
  static Map<String, String> simulateBotNightActions(GameEngine engine) {
    final actions = <String, String>{};
    final random = Random();
    final alivePlayers = engine.players.values.where((p) => p.isAlive).toList();

    for (final p in alivePlayers) {
      if (!p.isBot) continue;
      if (p.role == GameRoles.spy) {
        final targets = alivePlayers
            .where((t) => t.id != p.id && t.role != GameRoles.spy)
            .toList();
        if (targets.isNotEmpty) {
          final target = targets[random.nextInt(targets.length)];
          actions[p.id] = target.id;
        }
      }
    }
    return actions;
  }

  /// 模拟机器人白板猜词（被投出后触发）
  static Map<String, String>? simulateBotBlankGuess(GameEngine engine, String botId) {
    final bot = engine.players[botId];
    if (bot == null || !bot.isBot || bot.role != GameRoles.blank) return null;

    final random = Random();
    // 机器人白板有 30% 概率猜中词汇，其余情况猜偏
    if (random.nextInt(10) < 3) {
      return {
        'word_a': engine.wordA,
        'word_b': engine.wordB,
      };
    } else {
      return {
        'word_a': '猜测词A',
        'word_b': '猜测词B',
      };
    }
  }
}
