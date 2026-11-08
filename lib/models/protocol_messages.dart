import 'dart:convert';
import 'dart:typed_data';

/// 统一网络消息类型
enum GameMessageType {
  joinReq,      // 玩家加入房间申请
  leaveReq,     // 玩家离开房间通知
  identity,     // 个人身份词语单播
  chat,         // 聊天与系统客观播报
  vote,         // 白天公投行动
  night,        // 黑夜行动
  blankGuess,   // 白板双词逆袭
  syncPhase,    // 阶段流转广播
  syncState,    // 全量快照同步（用于新入房、观战与断线重连）
  heartbeat,    // 心跳保活
}

extension GameMessageTypeExt on GameMessageType {
  String get wireName {
    switch (this) {
      case GameMessageType.joinReq:
        return 'join_req';
      case GameMessageType.leaveReq:
        return 'leave_req';
      case GameMessageType.identity:
        return 'identity';
      case GameMessageType.chat:
        return 'chat';
      case GameMessageType.vote:
        return 'vote';
      case GameMessageType.night:
        return 'night';
      case GameMessageType.blankGuess:
        return 'blank_guess';
      case GameMessageType.syncPhase:
        return 'sync_phase';
      case GameMessageType.syncState:
        return 'sync_state';
      case GameMessageType.heartbeat:
        return 'heartbeat';
    }
  }

  static GameMessageType fromWireName(String name) {
    for (final t in GameMessageType.values) {
      if (t.wireName == name) return t;
    }
    return GameMessageType.chat;
  }
}

/// 统一游戏网络数据包结构
class GameMessage {
  final GameMessageType type;
  final Map<String, dynamic> payload;
  final int timestamp;

  GameMessage({
    required this.type,
    required this.payload,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'type': type.wireName,
      'payload': payload,
      'timestamp': timestamp,
    };
  }

  factory GameMessage.fromMap(Map<String, dynamic> map) {
    return GameMessage(
      type: GameMessageTypeExt.fromWireName(map['type']?.toString() ?? ''),
      payload: (map['payload'] as Map<String, dynamic>?) ?? {},
      timestamp: (map['timestamp'] as num?)?.toInt(),
    );
  }

  String toJson() => json.encode(toMap());
  factory GameMessage.fromJson(String source) =>
      GameMessage.fromMap(json.decode(source) as Map<String, dynamic>);

  // 便捷工厂构造函数
  factory GameMessage.join({
    required String playerId,
    required String playerName,
    required String avatar,
  }) {
    return GameMessage(
      type: GameMessageType.joinReq,
      payload: {
        'player_id': playerId,
        'player_name': playerName,
        'avatar': avatar,
      },
    );
  }

  factory GameMessage.leave({required String playerId}) {
    return GameMessage(
      type: GameMessageType.leaveReq,
      payload: {'player_id': playerId},
    );
  }

  factory GameMessage.identity({
    required String role,
    required String word,
    required String hint,
  }) {
    return GameMessage(
      type: GameMessageType.identity,
      payload: {
        'role': role,
        'word': word,
        'hint': hint,
      },
    );
  }

  factory GameMessage.chat({
    required String senderId,
    required String text,
    bool isSystem = false,
  }) {
    return GameMessage(
      type: GameMessageType.chat,
      payload: {
        'sender_id': senderId,
        'text': text,
        'is_system': isSystem,
      },
    );
  }

  factory GameMessage.vote({
    required String voterId,
    required String targetId,
  }) {
    return GameMessage(
      type: GameMessageType.vote,
      payload: {
        'voter_id': voterId,
        'target_id': targetId,
      },
    );
  }

  factory GameMessage.night({
    required String actorId,
    required String targetId,
  }) {
    return GameMessage(
      type: GameMessageType.night,
      payload: {
        'actor_id': actorId,
        'target_id': targetId,
      },
    );
  }

  factory GameMessage.blankGuess({
    required String playerId,
    required String wordA,
    required String wordB,
  }) {
    return GameMessage(
      type: GameMessageType.blankGuess,
      payload: {
        'player_id': playerId,
        'word_a': wordA,
        'word_b': wordB,
      },
    );
  }

  factory GameMessage.syncPhase({
    required int newPhase,
    required String extraInfo,
  }) {
    return GameMessage(
      type: GameMessageType.syncPhase,
      payload: {
        'new_phase': newPhase,
        'extra_info': extraInfo,
      },
    );
  }

  factory GameMessage.syncState(Map<String, dynamic> stateMap) {
    return GameMessage(
      type: GameMessageType.syncState,
      payload: stateMap,
    );
  }
}

/// TCP 4 字节前缀编解码器，专门处理 TCP 粘包与半包
class TcpFrameCodec {
  static const int maxFrameSize = 16 * 1024 * 1024; // 16MB 保护阈值

  /// 将 GameMessage 编码为带 4 字节大端序长度头的二进制包
  static Uint8List encode(GameMessage message) {
    final body = utf8.encode(message.toJson());
    final length = body.length;
    final buffer = Uint8List(4 + length);
    final byteData = ByteData.sublistView(buffer);
    byteData.setUint32(0, length, Endian.big);
    buffer.setRange(4, 4 + length, body);
    return buffer;
  }
}

/// TCP 数据流帧解码器（管理字节缓冲区，支持多段拼包与连包拆分）
class MessageFrameDecoder {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// 喂入新的字节块，返回解析成功的全部 GameMessage 列表
  List<GameMessage> feed(Uint8List chunk) {
    _buffer.add(chunk);
    final messages = <GameMessage>[];

    var bytes = _buffer.toBytes();
    var offset = 0;

    while (bytes.length - offset >= 4) {
      final byteData = ByteData.sublistView(bytes, offset, offset + 4);
      final length = byteData.getUint32(0, Endian.big);

      if (length > TcpFrameCodec.maxFrameSize) {
        // 遇到超大非法帧，重置缓冲区以避免内存溢出
        _buffer.clear();
        throw FormatException('Frame length $length exceeds max frame size limit.');
      }

      if (bytes.length - offset < 4 + length) {
        // 半包：数据未接收完整，等待下一个 chunk
        break;
      }

      // 提取完整包体
      final bodyBytes = bytes.sublist(offset + 4, offset + 4 + length);
      offset += 4 + length;

      try {
        final jsonStr = utf8.decode(bodyBytes);
        final msg = GameMessage.fromJson(jsonStr);
        messages.add(msg);
      } catch (e) {
        // 单个包解析异常，不中断后续解析
      }
    }

    // 将剩余未消费的半包数据重新置入缓冲区
    _buffer.clear();
    if (offset < bytes.length) {
      _buffer.add(bytes.sublist(offset));
    }

    return messages;
  }

  void reset() {
    _buffer.clear();
  }
}
