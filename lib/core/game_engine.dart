import 'dart:math';
import '../models/game_models.dart';
import '../models/word_bank.dart';

/// 权威博弈引擎（纯 Dart 逻辑单例与权威可信源）
class GameEngine {
  GamePhase phase = GamePhase.preparing;
  int round = 1;
  String wordA = '';
  String wordB = '';
  String hint = '';
  String theme = '全部主题';
  String similarityLevel = '极为接近';

  final Map<String, Player> players = {};
  final Map<String, String> votes = {}; // voterId -> targetId
  final List<String> nightCasualties = [];
  String? winner;
  SettlementDetails? settlementDetails;
  String? lastEliminatedPlayerId;

  GameEngine();

  /// 重置全局游戏状态
  void reset() {
    phase = GamePhase.preparing;
    round = 1;
    wordA = '';
    wordB = '';
    hint = '';
    votes.clear();
    nightCasualties.clear();
    winner = null;
    settlementDetails = null;
    lastEliminatedPlayerId = null;

    // 保留现有玩家基本信息，但重置在局状态与身份
    for (final id in players.keys.toList()) {
      final p = players[id]!;
      players[id] = p.copyWith(
        isAlive: true,
        role: null,
        word: null,
        hint: null,
      );
    }
  }

  /// 添加或更新玩家
  void addPlayer(Player player) {
    if (players.containsKey(player.id)) {
      // 既有玩家更新基本资料（名字/头像）
      players[player.id] = players[player.id]!.copyWith(
        name: player.name,
        avatar: player.avatar,
      );
      return;
    }

    if (phase == GamePhase.preparing) {
      players[player.id] = player.copyWith(isAlive: true);
    } else {
      // 游戏中途加入新玩家，自动转为观战者
      players[player.id] = player.copyWith(
        role: GameRoles.spectator,
        isAlive: false,
      );
    }
  }

  /// 移除玩家
  void removePlayer(String playerId) {
    if (phase == GamePhase.preparing) {
      players.remove(playerId);
    } else {
      // 游戏中退出标记为阵亡
      if (players.containsKey(playerId)) {
        players[playerId] = players[playerId]!.copyWith(isAlive: false);
      }
    }
    votes.remove(playerId);
  }

  /// 角色分配算法：支持 4 ~ 12 名玩家动态身份配比
  /// - 4人局： 1 卧底, 1 天使, 1 白板, 1 好人
  /// - 5人局： 1 卧底, 1 天使, 1 白板, 2 好人
  /// - 6人局： 2 卧底, 1 天使, 1 白板, 2 好人
  /// - 7人局： 2 卧底, 1 天使, 1 白板, 3 好人
  /// - 8人局： 2 卧底, 1 天使, 1 白板, 4 好人
  /// - 9人局： 3 卧底, 1 天使, 1 白板, 4 好人
  /// - 10人局：3 卧底, 1 天使, 1 白板, 5 好人
  /// - 11人局：3 卧底, 1 天使, 1 白板, 6 好人
  /// - 12人局：4 卧底, 1 天使, 1 白板, 6 好人
  static Map<String, String> assignRoles(List<String> playerIds) {
    final assignments = <String, String>{};
    final count = playerIds.length;
    if (count < 4) return assignments;

    final shuffled = List<String>.from(playerIds)..shuffle(Random());

    final int spyCount;
    if (count >= 12) {
      spyCount = 4;
    } else if (count >= 9) {
      spyCount = 3;
    } else if (count >= 6) {
      spyCount = 2;
    } else {
      spyCount = 1;
    }
    const angelCount = 1;
    const blankCount = 1;

    var idx = 0;
    // 1. 分配卧底
    for (var i = 0; i < spyCount && idx < count; i++) {
      assignments[shuffled[idx++]] = GameRoles.spy;
    }
    // 2. 分配天使
    for (var i = 0; i < angelCount && idx < count; i++) {
      assignments[shuffled[idx++]] = GameRoles.angel;
    }
    // 3. 分配白板
    for (var i = 0; i < blankCount && idx < count; i++) {
      assignments[shuffled[idx++]] = GameRoles.blank;
    }
    // 4. 其余全部分配为好人平民
    while (idx < count) {
      assignments[shuffled[idx++]] = GameRoles.good;
    }

    return assignments;
  }

  /// 启动游戏：生成词汇、分配身份，并返回单播给每个玩家的 IdentityAssignment
  Map<String, IdentityAssignment> startGame({
    String? customTheme,
    String? customSimilarity,
  }) {
    final playerList = players.values.where((p) => p.role != GameRoles.spectator).toList();
    if (playerList.length < 4) {
      throw StateError('游戏人数不足，至少需要 4 名特工（当前 ${playerList.length} 人）');
    }
    if (playerList.length > 12) {
      throw StateError('游戏人数超限，单局最多支持 12 名特工（当前 ${playerList.length} 人）');
    }

    reset();
    theme = customTheme ?? '全部主题';
    similarityLevel = customSimilarity ?? '极为接近';

    final pair = WordBank.generateWords(theme: theme, similarity: similarityLevel);
    wordA = pair.wordA;
    wordB = pair.wordB;
    hint = pair.hint;

    final roleMap = assignRoles(playerList.map((p) => p.id).toList());
    final assignments = <String, IdentityAssignment>{};
    final random = Random();

    for (final p in playerList) {
      final realRole = roleMap[p.id] ?? GameRoles.good;
      final String assignmentRole;
      final String displayWord;
      final String displayHint;

      switch (realRole) {
        case GameRoles.good:
          assignmentRole = GameRoles.agent; // 好人发词盲盒特工
          displayWord = wordA;
          displayHint = '';
          break;
        case GameRoles.spy:
          assignmentRole = GameRoles.agent; // 卧底发词盲盒特工
          displayWord = wordB;
          displayHint = '';
          break;
        case GameRoles.angel:
          // 天使获知好坏两词，顺序随机混淆
          final words = random.nextBool() ? [wordA, wordB] : [wordB, wordA];
          assignmentRole = GameRoles.angel;
          displayWord = '${words[0]} / ${words[1]}';
          displayHint = '您同时感知到两方词语，请在不暴露自身的前提下引导好人！';
          break;
        case GameRoles.blank:
          assignmentRole = GameRoles.blank;
          displayWord = '【无词】';
          displayHint = hint;
          break;
        default:
          assignmentRole = GameRoles.agent;
          displayWord = wordA;
          displayHint = '';
      }

      players[p.id] = p.copyWith(
        role: realRole,
        word: displayWord,
        hint: displayHint,
        isAlive: true,
      );

      assignments[p.id] = IdentityAssignment(
        role: assignmentRole,
        word: displayWord,
        hint: displayHint,
      );
    }

    phase = GamePhase.description;
    round = 1;
    return assignments;
  }

  /// 提交白天公投投票
  VoteResult submitVote(String voterId, String targetId) {
    if (phase != GamePhase.voting) {
      return VoteResult(success: false, message: '当前不是公投表决阶段');
    }

    final voter = players[voterId];
    if (voter == null || !voter.isAlive) {
      return VoteResult(success: false, message: '出局特工无法参与公投');
    }

    final target = players[targetId];
    if (target == null || !target.isAlive) {
      return VoteResult(success: false, message: '不可投票给已出局特工');
    }

    if (votes.containsKey(voterId)) {
      return VoteResult(success: false, message: '您已提交过表决，不可重复投票');
    }

    votes[voterId] = targetId;

    final aliveCount = players.values.where((p) => p.isAlive).length;
    final votedCount = votes.length;
    final allVoted = votedCount >= aliveCount && aliveCount > 0;

    return VoteResult(
      success: true,
      message: '投票已秘密记录',
      currentVotes: votedCount,
      totalAlive: aliveCount,
      allVoted: allVoted,
    );
  }

  /// 推进阶段（可由房主主动触发，或全员投票完成后自动流转）
  PhaseAdvanceResult advancePhase() {
    switch (phase) {
      case GamePhase.description:
        phase = GamePhase.voting;
        votes.clear();
        return PhaseAdvanceResult(
          phase: GamePhase.voting,
          announcement: '【公投开启】第 $round 轮描述结束，白天表决阶段开启，请秘密投票！',
        );

      case GamePhase.voting:
        return _tallyVotesAndAdvance();

      case GamePhase.blankGuess:
        // 白板超时或房主主动跳过猜词，进入黑夜
        final winCheck = checkWinner();
        if (winCheck != null) {
          phase = GamePhase.settlement;
          winner = winCheck;
          _finishGame(winCheck);
          return PhaseAdvanceResult(
            phase: GamePhase.settlement,
            announcement: '【终局结算】游戏结束，$winCheck 阵营获胜！',
            gameOver: true,
          );
        }
        phase = GamePhase.nightAction;
        return PhaseAdvanceResult(
          phase: GamePhase.nightAction,
          announcement: '【夜幕降临】白板猜词阶段结束，黑夜行动开启，潜伏卧底请行动。',
        );

      case GamePhase.nightAction:
        return _settleNightAndAdvance();

      case GamePhase.settlement:
      case GamePhase.preparing:
        return PhaseAdvanceResult(
          phase: phase,
          announcement: '当前处于 ${phase.label}。',
        );
    }
  }

  /// 统计公投票数并流转
  PhaseAdvanceResult _tallyVotesAndAdvance() {
    final tally = <String, int>{};
    for (final targetId in votes.values) {
      tally[targetId] = (tally[targetId] ?? 0) + 1;
    }
    votes.clear();

    var maxVotes = 0;
    var maxTargets = <String>[];
    for (final entry in tally.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        maxTargets = [entry.key];
      } else if (entry.value == maxVotes) {
        maxTargets.add(entry.key);
      }
    }

    if (maxVotes == 0 || maxTargets.length > 1) {
      // 平票或无人投票，无人出局直接入夜
      phase = GamePhase.nightAction;
      return PhaseAdvanceResult(
        phase: GamePhase.nightAction,
        announcement: maxTargets.length > 1
            ? '【公投决议】平票（最高得票 $maxVotes 票），本轮无人出局。天黑请闭眼...'
            : '【公投决议】本轮全员弃票，无人出局。天黑请闭眼...',
      );
    }

    // 单一最高票者出局
    final outId = maxTargets.first;
    final outPlayer = players[outId];
    if (outPlayer == null) {
      phase = GamePhase.nightAction;
      return PhaseAdvanceResult(
        phase: GamePhase.nightAction,
        announcement: '【公投决议】投票无效，无人出局。天黑请闭眼...',
      );
    }

    players[outId] = outPlayer.copyWith(isAlive: false);
    lastEliminatedPlayerId = outId;

    // 核心特色规则：若公投出局者为白板，立即触发白板逆袭猜词阶段！
    if (outPlayer.role == GameRoles.blank) {
      phase = GamePhase.blankGuess;
      return PhaseAdvanceResult(
        phase: GamePhase.blankGuess,
        eliminatedPlayerId: outId,
        announcement: '【公投决议】特工【${outPlayer.name}】得票最高（$maxVotes 票）公投出局（身份：暗号白板）！触发白板终局逆袭猜词！',
      );
    }

    // 检查是否有阵营提前获胜
    final winCheck = checkWinner();
    if (winCheck != null) {
      phase = GamePhase.settlement;
      winner = winCheck;
      _finishGame(winCheck);
      return PhaseAdvanceResult(
        phase: GamePhase.settlement,
        eliminatedPlayerId: outId,
        announcement: '【公投决议】特工【${outPlayer.name}】得票最高（$maxVotes 票）出局！对局触发胜负终局！',
        gameOver: true,
      );
    }

    // 未结束，进入黑夜
    phase = GamePhase.nightAction;
    return PhaseAdvanceResult(
      phase: GamePhase.nightAction,
      eliminatedPlayerId: outId,
      announcement: '【公投决议】特工【${outPlayer.name}】得票最高（$maxVotes 票）公投出局。天黑请闭眼...',
    );
  }

  /// 结算黑夜伤亡并流转至下一轮描述或终局结算
  PhaseAdvanceResult _settleNightAndAdvance() {
    final casualtyNames = nightCasualties
        .map((id) => players[id]?.name)
        .whereType<String>()
        .toList();

    nightCasualties.clear();

    final nightReport = casualtyNames.isEmpty
        ? '【夜间战报】昨夜是平安夜，全员平安。'
        : '【夜间战报】天亮了，昨夜特工【${casualtyNames.join('、')}】出局。';

    final winCheck = checkWinner();
    if (winCheck != null) {
      phase = GamePhase.settlement;
      winner = winCheck;
      _finishGame(winCheck);
      return PhaseAdvanceResult(
        phase: GamePhase.settlement,
        announcement: '$nightReport 对局终结，$winCheck 阵营胜出！',
        gameOver: true,
      );
    }

    // 推进至下一轮描述
    round++;
    phase = GamePhase.description;
    return PhaseAdvanceResult(
      phase: GamePhase.description,
      announcement: '$nightReport 第 $round 轮描述发言开始，请存活特工依次阐明观点。',
    );
  }

  /// 黑夜行动裁决
  /// - 卧底执行暗杀：目标特工出局
  /// - 非卧底身份误动：误触自爆，自身出局
  NightActionResult submitNightAction(String actorId, String targetId) {
    if (phase != GamePhase.nightAction) {
      return NightActionResult(success: false, feedback: '当前不是黑夜行动阶段');
    }

    final actor = players[actorId];
    if (actor == null || !actor.isAlive) {
      return NightActionResult(success: false, feedback: '已出局特工无法在黑夜行动');
    }

    final target = players[targetId];
    if (target == null || !target.isAlive) {
      return NightActionResult(success: false, feedback: '行动目标已出局');
    }

    if (actor.role == GameRoles.spy) {
      // 卧底成功刺杀
      players[targetId] = target.copyWith(isAlive: false);
      if (!nightCasualties.contains(targetId)) {
        nightCasualties.add(targetId);
      }
      return NightActionResult(
        success: true,
        feedback: '夜间刺杀目标锁定完毕。',
      );
    } else {
      // 好人/天使/白板误动：自爆反噬
      players[actorId] = actor.copyWith(isAlive: false);
      if (!nightCasualties.contains(actorId)) {
        nightCasualties.add(actorId);
      }
      return NightActionResult(
        success: true,
        feedback: '您并非潜伏卧底，黑夜盲动导致触发防暴机关，自身误伤自爆！',
      );
    }
  }

  /// 白板猜词逆袭
  BlankGuessResult submitBlankGuess({
    required String playerId,
    required String guessA,
    required String guessB,
  }) {
    if (phase != GamePhase.blankGuess) {
      return BlankGuessResult(success: false, isCorrect: false, message: '当前不是白板猜词阶段');
    }

    final player = players[playerId];
    if (player == null || player.role != GameRoles.blank) {
      return BlankGuessResult(success: false, isCorrect: false, message: '仅被公投出局的暗号白板可发起猜词');
    }

    final g1 = guessA.trim();
    final g2 = guessB.trim();

    // 严格双向无序校验双方词
    final isHit = (g1.isNotEmpty && g2.isNotEmpty) &&
        ((g1 == wordA && g2 == wordB) || (g1 == wordB && g2 == wordA));

    if (isHit) {
      phase = GamePhase.settlement;
      winner = GameRoles.blank;
      _finishGame(GameRoles.blank);
      return BlankGuessResult(
        success: true,
        isCorrect: true,
        gameOver: true,
        message: '【白板绝杀】白板特工【${player.name}】精准猜中好人词【$wordA】与卧底词【$wordB】，白板阵营直接独赢！',
      );
    } else {
      // 猜错，白板彻底出局，检查游戏胜负或自动流转入夜
      final winCheck = checkWinner();
      if (winCheck != null) {
        phase = GamePhase.settlement;
        winner = winCheck;
        _finishGame(winCheck);
        return BlankGuessResult(
          success: true,
          isCorrect: false,
          gameOver: true,
          message: '【猜词未中】白板特工【${player.name}】未能命中双词，彻底出局！胜负已定！',
        );
      } else {
        phase = GamePhase.nightAction;
        return BlankGuessResult(
          success: true,
          isCorrect: false,
          gameOver: false,
          message: '【猜词未中】白板特工【${player.name}】未能命中双词（猜测：【$g1】与【$g2】），白板出局，夜幕降临...',
        );
      }
    }
  }

  /// 获取某个玩家的个人身份与词汇信息（用于断线重连恢复身份）
  IdentityAssignment? getIdentityAssignment(String playerId) {
    final p = players[playerId];
    if (p == null || p.role == null) return null;
    switch (p.role) {
      case GameRoles.good:
        return IdentityAssignment(role: GameRoles.agent, word: wordA, hint: '');
      case GameRoles.spy:
        return IdentityAssignment(role: GameRoles.agent, word: wordB, hint: '');
      case GameRoles.angel:
        return IdentityAssignment(role: GameRoles.angel, word: p.word ?? '', hint: p.hint ?? '');
      case GameRoles.blank:
        return IdentityAssignment(role: GameRoles.blank, word: '【无词】', hint: hint);
      case GameRoles.spectator:
        return const IdentityAssignment(role: GameRoles.spectator, word: '', hint: '');
      default:
        return IdentityAssignment(role: GameRoles.agent, word: p.word ?? '', hint: '');
    }
  }

  /// 胜负判定准则：
  /// 1. 卧底阵营获胜：存活卧底数大于等于好人存活数（平民好人+天使），且卧底数 > 0；或存活特工 ≤ 2 且有卧底在场；
  /// 2. 好人阵营获胜：所有卧底全部出局，且白板必须已出局（若局内有白板）；
  /// 3. 若白板尚存活且卧底出局，好人尚未找出白板，对局不可结束，必须继续；
  /// 4. 白板获胜：白板成功双词逆袭；或场上好人与卧底全灭，白板作为唯一存活阵营。
  String? checkWinner() {
    var aliveGood = 0;
    var aliveSpy = 0;
    var aliveBlank = 0;
    var hasBlank = false;

    for (final p in players.values) {
      if (p.role == GameRoles.spectator) continue;
      if (p.role == GameRoles.blank) hasBlank = true;

      if (p.isAlive) {
        switch (p.role) {
          case GameRoles.good:
          case GameRoles.angel:
            aliveGood++;
            break;
          case GameRoles.spy:
            aliveSpy++;
            break;
          case GameRoles.blank:
            aliveBlank++;
            break;
        }
      }
    }

    final totalAlive = aliveGood + aliveSpy + aliveBlank;

    // 1. 卧底获胜：卧底存活且数量大于等于好人存活数；或存活特工 ≤ 2 且有卧底在场
    if (aliveSpy > 0 && (aliveSpy >= aliveGood || totalAlive <= 2)) {
      return GameRoles.spy;
    }

    // 2. 好人获胜与白板独活分支
    if (aliveSpy == 0) {
      if (hasBlank && aliveBlank > 0) {
        if (aliveGood == 0) {
          // 好人与卧底全灭，白板唯一存活
          return GameRoles.blank;
        }
        return null; // 白板仍在潜伏，对局继续
      }
      return GameRoles.good;
    }

    return null;
  }

  /// 结算封盘并生成战报
  void _finishGame(String winnerCamp) {
    final reveals = players.values.map((p) {
      return PlayerReveal(
        id: p.id,
        name: p.name,
        avatar: p.avatar,
        role: p.role ?? GameRoles.good,
        word: p.word ?? '',
        hint: p.hint ?? '',
        isAlive: p.isAlive,
      );
    }).toList();

    settlementDetails = SettlementDetails(
      winnerCamp: winnerCamp,
      goodWord: wordA,
      spyWord: wordB,
      hint: hint,
      playerReveals: reveals,
    );
  }

  /// 获取用于网络快照同步的数据映射（支持脱敏保护，避免网络抓包泄题）
  Map<String, dynamic> toSnapshotMap({bool maskSecrets = false, String? forPlayerId}) {
    final bool revealAll = phase == GamePhase.settlement || !maskSecrets;

    final sanitizedPlayers = <String, dynamic>{};
    for (final entry in players.entries) {
      final p = entry.value;
      if (revealAll || p.id == forPlayerId || p.role == GameRoles.spectator) {
        sanitizedPlayers[entry.key] = p.toMap();
      } else {
        // 脱敏处理：隐藏其他特工真实身份与词汇，好人与卧底对外显示特工盲盒
        sanitizedPlayers[entry.key] = {
          'id': p.id,
          'name': p.name,
          'avatar': p.avatar,
          'role': p.role != null ? GameRoles.agent : null,
          'word': null,
          'hint': null,
          'is_alive': p.isAlive,
          'is_bot': p.isBot,
          'mark': p.mark,
        };
      }
    }

    return {
      'phase': phase.index,
      'round': round,
      'word_a': revealAll ? wordA : '',
      'word_b': revealAll ? wordB : '',
      'hint': revealAll ? hint : '',
      'theme': theme,
      'similarity_level': similarityLevel,
      'players': sanitizedPlayers,
      'votes': revealAll ? votes : {},
      'winner': winner,
      'settlement_details': settlementDetails?.toMap(),
      'last_eliminated_player_id': lastEliminatedPlayerId,
    };
  }

  /// 从网络全量快照恢复状态
  void applySnapshot(Map<String, dynamic> map) {
    phase = GamePhaseExt.fromInt((map['phase'] as num?)?.toInt() ?? 0);
    round = (map['round'] as num?)?.toInt() ?? 1;
    wordA = map['word_a']?.toString() ?? '';
    wordB = map['word_b']?.toString() ?? '';
    hint = map['hint']?.toString() ?? '';
    theme = map['theme']?.toString() ?? '全部主题';
    similarityLevel = map['similarity_level']?.toString() ?? '极为接近';
    winner = map['winner']?.toString();

    final playersMap = map['players'] as Map<String, dynamic>? ?? {};
    players.clear();
    playersMap.forEach((k, v) {
      players[k] = Player.fromMap(v as Map<String, dynamic>);
    });

    final votesMap = map['votes'] as Map<String, dynamic>? ?? {};
    votes.clear();
    votesMap.forEach((k, v) => votes[k] = v.toString());

    if (map['settlement_details'] != null) {
      settlementDetails = SettlementDetails.fromMap(
        map['settlement_details'] as Map<String, dynamic>,
      );
    } else {
      settlementDetails = null;
    }

    lastEliminatedPlayerId = map['last_eliminated_player_id']?.toString();
  }
}

/// 投票结果辅助类
class VoteResult {
  final bool success;
  final String message;
  final int currentVotes;
  final int totalAlive;
  final bool allVoted;

  const VoteResult({
    required this.success,
    required this.message,
    this.currentVotes = 0,
    this.totalAlive = 0,
    this.allVoted = false,
  });
}

/// 阶段流转结果辅助类
class PhaseAdvanceResult {
  final GamePhase phase;
  final String announcement;
  final String? eliminatedPlayerId;
  final bool gameOver;

  const PhaseAdvanceResult({
    required this.phase,
    required this.announcement,
    this.eliminatedPlayerId,
    this.gameOver = false,
  });
}

/// 黑夜行动结果辅助类
class NightActionResult {
  final bool success;
  final String feedback;

  const NightActionResult({
    required this.success,
    required this.feedback,
  });
}

/// 白板猜词结果辅助类
class BlankGuessResult {
  final bool success;
  final bool isCorrect;
  final String message;
  final bool gameOver;

  const BlankGuessResult({
    required this.success,
    required this.isCorrect,
    required this.message,
    this.gameOver = false,
  });
}
