import 'dart:convert';

/// 游戏阶段枚举
enum GamePhase {
  preparing,   // 准备中 (0)
  description, // 描述发言阶段 (1)
  voting,      // 白天公投表决阶段 (2)
  nightAction, // 黑夜暗杀阶段 (3)
  settlement,  // 终局战报结算阶段 (4)
  blankGuess,  // 白板终局逆袭猜词阶段 (5)
}

extension GamePhaseExt on GamePhase {
  int get code => index;

  String get label {
    switch (this) {
      case GamePhase.preparing:
        return '准备阶段';
      case GamePhase.description:
        return '描述发言';
      case GamePhase.voting:
        return '公投表决';
      case GamePhase.nightAction:
        return '黑夜行动';
      case GamePhase.settlement:
        return '战报结算';
      case GamePhase.blankGuess:
        return '白板逆袭';
    }
  }

  static GamePhase fromInt(int val) {
    if (val >= 0 && val < GamePhase.values.length) {
      return GamePhase.values[val];
    }
    return GamePhase.preparing;
  }
}

/// 身份常量
class GameRoles {
  static const String good = 'GOOD';         // 好人平民
  static const String spy = 'SPY';           // 卧底
  static const String angel = 'ANGEL';       // 天使 (获知双词)
  static const String blank = 'BLANK';       // 白板 (获知提示)
  static const String agent = 'AGENT';       // 特工盲盒展示
  static const String spectator = 'SPECTATOR'; // 观战者

  static String getRoleLabel(String? role) {
    switch (role) {
      case good:
        return '好人特工';
      case spy:
        return '潜伏卧底';
      case angel:
        return '双面天使';
      case blank:
        return '暗号白板';
      case agent:
        return '特工';
      case spectator:
        return '观战者';
      default:
        return '未确认';
    }
  }
}

/// 单个玩家基础信息与在局状态
class Player {
  final String id;
  final String name;
  final String avatar;
  final String? role;
  final String? word;
  final String? hint;
  final bool isAlive;
  final bool isBot;
  final String? mark; // 本地玩家推测标记

  const Player({
    required this.id,
    required this.name,
    required this.avatar,
    this.role,
    this.word,
    this.hint,
    this.isAlive = true,
    this.isBot = false,
    this.mark,
  });

  Player copyWith({
    String? id,
    String? name,
    String? avatar,
    String? role,
    String? word,
    String? hint,
    bool? isAlive,
    bool? isBot,
    String? mark,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      word: word ?? this.word,
      hint: hint ?? this.hint,
      isAlive: isAlive ?? this.isAlive,
      isBot: isBot ?? this.isBot,
      mark: mark ?? this.mark,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'role': role,
      'word': word,
      'hint': hint,
      'is_alive': isAlive,
      'is_bot': isBot,
      'mark': mark,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '特工',
      avatar: map['avatar']?.toString() ?? 'agent',
      role: map['role']?.toString(),
      word: map['word']?.toString(),
      hint: map['hint']?.toString(),
      isAlive: map['is_alive'] as bool? ?? true,
      isBot: map['is_bot'] as bool? ?? false,
      mark: map['mark']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());
  factory Player.fromJson(String source) => Player.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// 身份单播盲盒下发载荷
class IdentityAssignment {
  final String role;
  final String word;
  final String hint;

  const IdentityAssignment({
    required this.role,
    required this.word,
    required this.hint,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'word': word,
      'hint': hint,
    };
  }

  factory IdentityAssignment.fromMap(Map<String, dynamic> map) {
    return IdentityAssignment(
      role: map['role']?.toString() ?? GameRoles.good,
      word: map['word']?.toString() ?? '',
      hint: map['hint']?.toString() ?? '',
    );
  }
}

/// 战报揭秘单人明细
class PlayerReveal {
  final String id;
  final String name;
  final String avatar;
  final String role;
  final String word;
  final String hint;
  final bool isAlive;

  const PlayerReveal({
    required this.id,
    required this.name,
    required this.avatar,
    required this.role,
    required this.word,
    required this.hint,
    required this.isAlive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'role': role,
      'word': word,
      'hint': hint,
      'is_alive': isAlive,
    };
  }

  factory PlayerReveal.fromMap(Map<String, dynamic> map) {
    return PlayerReveal(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      avatar: map['avatar']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      word: map['word']?.toString() ?? '',
      hint: map['hint']?.toString() ?? '',
      isAlive: map['is_alive'] as bool? ?? false,
    );
  }
}

/// 战报结算明细详情
class SettlementDetails {
  final String winnerCamp;
  final String goodWord;
  final String spyWord;
  final String hint;
  final List<PlayerReveal> playerReveals;

  const SettlementDetails({
    required this.winnerCamp,
    required this.goodWord,
    required this.spyWord,
    required this.hint,
    required this.playerReveals,
  });

  Map<String, dynamic> toMap() {
    return {
      'winner_camp': winnerCamp,
      'good_word': goodWord,
      'spy_word': spyWord,
      'hint': hint,
      'player_reveals': playerReveals.map((x) => x.toMap()).toList(),
    };
  }

  factory SettlementDetails.fromMap(Map<String, dynamic> map) {
    return SettlementDetails(
      winnerCamp: map['winner_camp']?.toString() ?? '',
      goodWord: map['good_word']?.toString() ?? '',
      spyWord: map['spy_word']?.toString() ?? '',
      hint: map['hint']?.toString() ?? '',
      playerReveals: (map['player_reveals'] as List<dynamic>? ?? [])
          .map((e) => PlayerReveal.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 局域网探针发现的房间信息
class DiscoveredRoom {
  final String roomId;
  final String hostName;
  final String hostAvatar;
  final String ip;
  final int port;
  final int playerCount;
  final int maxPlayers;
  final int phase;
  final String phaseTitle;
  final DateTime lastSeen;

  DiscoveredRoom({
    required this.roomId,
    required this.hostName,
    required this.hostAvatar,
    required this.ip,
    required this.port,
    required this.playerCount,
    required this.maxPlayers,
    required this.phase,
    required this.phaseTitle,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'host_name': hostName,
      'host_avatar': hostAvatar,
      'ip': ip,
      'port': port,
      'player_count': playerCount,
      'max_players': maxPlayers,
      'phase': phase,
      'phase_title': phaseTitle,
    };
  }

  factory DiscoveredRoom.fromMap(Map<String, dynamic> map, String ip) {
    return DiscoveredRoom(
      roomId: map['room_id']?.toString() ?? '',
      hostName: map['host_name']?.toString() ?? '房主',
      hostAvatar: map['host_avatar']?.toString() ?? 'agent',
      ip: ip,
      port: (map['port'] as num?)?.toInt() ?? 8888,
      playerCount: (map['player_count'] as num?)?.toInt() ?? 1,
      maxPlayers: (map['max_players'] as num?)?.toInt() ?? 12,
      phase: (map['phase'] as num?)?.toInt() ?? 0,
      phaseTitle: map['phase_title']?.toString() ?? '准备中',
      lastSeen: DateTime.now(),
    );
  }
}
