import 'dart:math';
import '../models/game_models.dart';
import 'game_engine.dart';

/// 虚拟特工（Mock Bot）生成与行为模拟引擎
class MockBots {
  static const List<String> botCodenames = [
    '阿尔法 (Alpha)',
    '布拉沃 (Bravo)',
    '查理 (Charlie)',
    '三角洲 (Delta)',
    '回声 (Echo)',
    '狐步 (Foxtrot)',
    '高尔夫 (Golf)',
    '旅馆 (Hotel)',
    '印度 (India)',
    '朱丽叶 (Juliet)',
    '基洛 (Kilo)',
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

  /// 生成指定数量的机器人玩家
  static List<Player> generateBots(int count, {List<String>? excludeIds}) {
    final bots = <Player>[];
    final random = Random();
    final usedNames = <String>{};

    for (var i = 0; i < count && i < botCodenames.length; i++) {
      final name = '虚拟特工 · ${botCodenames[i]}';
      if (usedNames.contains(name)) continue;
      usedNames.add(name);

      final id = 'bot_${i + 1}_${DateTime.now().millisecondsSinceEpoch % 10000}';
      if (excludeIds != null && excludeIds.contains(id)) continue;

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
      '我认为这个事物具有非常显著的生活辨识度。',
      '大家注意观察，它的用途非常专一且常见。',
      '从外观和使用场景来推测，在场某些人的描述有些含糊。',
      '我的词让我联想到了它的材质和日常手感。',
      '感觉上一位特工的发言有点偏离核心特征，值得留意。',
      '这个词在特定季节或场合出现的频率很高。',
    ];
    return quotes[random.nextInt(quotes.length)];
  }

  /// 模拟机器人自动投票（随机投给除自己之外的某位存活特工）
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

  /// 模拟机器人黑夜行动（若是卧底，挑选一名存活的非卧底目标暗杀）
  static Map<String, String> simulateBotNightActions(GameEngine engine) {
    final actions = <String, String>{};
    final random = Random();
    final alivePlayers = engine.players.values.where((p) => p.isAlive).toList();

    for (final p in alivePlayers) {
      if (!p.isBot) continue;
      // 只有卧底机器人夜间会实施刺杀
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

  /// 模拟机器人白板猜词（被公投出局后触发）
  static Map<String, String>? simulateBotBlankGuess(GameEngine engine, String botId) {
    final bot = engine.players[botId];
    if (bot == null || !bot.isBot || bot.role != GameRoles.blank) return null;

    final random = Random();
    // 机器人白板有 30% 概率猜中词汇逆袭，其余情况放弃或猜偏
    if (random.nextInt(10) < 3) {
      return {
        'word_a': engine.wordA,
        'word_b': engine.wordB,
      };
    } else {
      return {
        'word_a': '推测暗号A',
        'word_b': '推测暗号B',
      };
    }
  }
}
