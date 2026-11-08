import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/game_engine.dart';
import '../core/mock_bots.dart';
import '../models/game_models.dart';
import '../models/protocol_messages.dart';
import '../network/game_transport.dart';
import '../network/lan/lan_transport.dart';
import '../network/p2p/webrtc_transport.dart';

/// 房间与博弈全局响应式状态模型
class RoomState {
  final Player selfPlayer;
  final String networkMode; // "p2p" | "lan"
  final String roomId;
  final bool isHost;
  final bool isInRoom;
  final bool isConnecting;
  final String? errorMessage;

  final GamePhase currentPhase;
  final String phaseExtraInfo;
  final int currentRound;
  final IdentityAssignment? myIdentity;
  final List<Player> players;
  final List<GameMessage> chatMessages;
  final SettlementDetails? settlementDetails;
  final String? winner;
  final Map<String, String> playerMarks; // playerId -> mark
  final List<DiscoveredRoom> discoveredRooms;
  final bool isDiscovering;

  const RoomState({
    required this.selfPlayer,
    this.networkMode = 'p2p',
    this.roomId = '',
    this.isHost = false,
    this.isInRoom = false,
    this.isConnecting = false,
    this.errorMessage,
    this.currentPhase = GamePhase.preparing,
    this.phaseExtraInfo = '等待特工集结并由房主开启游戏',
    this.currentRound = 1,
    this.myIdentity,
    this.players = const [],
    this.chatMessages = const [],
    this.settlementDetails,
    this.winner,
    this.playerMarks = const {},
    this.discoveredRooms = const [],
    this.isDiscovering = false,
  });

  RoomState copyWith({
    Player? selfPlayer,
    String? networkMode,
    String? roomId,
    bool? isHost,
    bool? isInRoom,
    bool? isConnecting,
    String? errorMessage,
    GamePhase? currentPhase,
    String? phaseExtraInfo,
    int? currentRound,
    IdentityAssignment? myIdentity,
    bool clearIdentity = false,
    List<Player>? players,
    List<GameMessage>? chatMessages,
    SettlementDetails? settlementDetails,
    bool clearSettlement = false,
    String? winner,
    bool clearWinner = false,
    Map<String, String>? playerMarks,
    List<DiscoveredRoom>? discoveredRooms,
    bool? isDiscovering,
  }) {
    return RoomState(
      selfPlayer: selfPlayer ?? this.selfPlayer,
      networkMode: networkMode ?? this.networkMode,
      roomId: roomId ?? this.roomId,
      isHost: isHost ?? this.isHost,
      isInRoom: isInRoom ?? this.isInRoom,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: errorMessage,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseExtraInfo: phaseExtraInfo ?? this.phaseExtraInfo,
      currentRound: currentRound ?? this.currentRound,
      myIdentity: clearIdentity ? null : (myIdentity ?? this.myIdentity),
      players: players ?? this.players,
      chatMessages: chatMessages ?? this.chatMessages,
      settlementDetails: clearSettlement ? null : (settlementDetails ?? this.settlementDetails),
      winner: clearWinner ? null : (winner ?? this.winner),
      playerMarks: playerMarks ?? this.playerMarks,
      discoveredRooms: discoveredRooms ?? this.discoveredRooms,
      isDiscovering: isDiscovering ?? this.isDiscovering,
    );
  }
}

/// 全局 Riverpod Provider
final gameControllerProvider =
    StateNotifierProvider<GameController, RoomState>((ref) {
  return GameController();
});

/// 核心控制器
class GameController extends StateNotifier<RoomState> {
  GameEngine? _hostEngine;
  GameTransport? _transport;
  LanDiscovery? _lanDiscovery;

  StreamSubscription? _msgSub;
  StreamSubscription? _peerJoinedSub;
  StreamSubscription? _peerLeftSub;
  StreamSubscription? _lanDiscoverySub;

  GameController()
      : super(RoomState(
          selfPlayer: Player(
            id: 'agent_${Random().nextInt(899999) + 100000}',
            name: '特工_${Random().nextInt(8999) + 1000}',
            avatar: 'agent_1',
          ),
        )) {
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('wga_player_id');
      final savedName = prefs.getString('wga_player_name');
      final savedAvatar = prefs.getString('wga_player_avatar');

      final id = savedId ?? state.selfPlayer.id;
      final name = savedName ?? state.selfPlayer.name;
      final avatar = savedAvatar ?? state.selfPlayer.avatar;

      if (savedId == null) await prefs.setString('wga_player_id', id);

      state = state.copyWith(
        selfPlayer: state.selfPlayer.copyWith(
          id: id,
          name: name,
          avatar: avatar,
        ),
      );
    } catch (_) {}
  }

  Future<void> updateProfile({required String name, required String avatar}) async {
    state = state.copyWith(
      selfPlayer: state.selfPlayer.copyWith(name: name, avatar: avatar),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wga_player_name', name);
      await prefs.setString('wga_player_avatar', avatar);
    } catch (_) {}
  }

  /// 创建房间（房主模式）
  Future<void> createRoom({
    required String mode, // "p2p" | "lan"
    String? customRoomId,
    int? port,
  }) async {
    state = state.copyWith(isConnecting: true, errorMessage: null);

    try {
      await leaveRoom();

      final roomId = customRoomId?.trim().isNotEmpty == true
          ? customRoomId!.trim()
          : (1000 + Random().nextInt(9000)).toString();

      _hostEngine = GameEngine();
      _hostEngine!.addPlayer(state.selfPlayer);

      if (mode == 'p2p') {
        _transport = WebRtcP2PTransport(selfId: state.selfPlayer.id);
        await _transport!.hostRoom(roomId);
      } else {
        _transport = LanTransport(selfId: state.selfPlayer.id);
        await _transport!.hostRoom(roomId, port: port ?? 8888);

        // 启动局域网 UDP 探针广播
        _lanDiscovery = LanDiscovery();
        await _lanDiscovery!.startAdvertising(
          roomId: roomId,
          hostName: state.selfPlayer.name,
          hostAvatar: state.selfPlayer.avatar,
          port: port ?? 8888,
          playerCountGetter: () => _hostEngine?.players.length ?? 1,
          phaseGetter: () => _hostEngine?.phase.index ?? 0,
        );
      }

      _listenTransport();

      state = state.copyWith(
        isHost: true,
        isInRoom: true,
        isConnecting: false,
        roomId: roomId,
        networkMode: mode,
        currentPhase: GamePhase.preparing,
        phaseExtraInfo: '房间已就绪，当前可邀请其他特工或加入机器人',
        players: _hostEngine!.players.values.toList(),
        chatMessages: [
          GameMessage.chat(
            senderId: 'SYSTEM',
            text: '【系统提示】特工房间已开启，房间号：$roomId。等待特工入局。',
            isSystem: true,
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: '创建房间失败: $e',
      );
    }
  }

  /// 加入房间（客户端模式）
  Future<void> joinRoom({
    required String mode,
    required String roomId,
    String? host,
    int? port,
  }) async {
    state = state.copyWith(isConnecting: true, errorMessage: null);

    try {
      await leaveRoom();

      if (mode == 'p2p') {
        _transport = WebRtcP2PTransport(selfId: state.selfPlayer.id);
        await _transport!.joinRoom(
          roomId,
          playerId: state.selfPlayer.id,
          playerName: state.selfPlayer.name,
          avatar: state.selfPlayer.avatar,
        );
      } else {
        _transport = LanTransport(selfId: state.selfPlayer.id);
        await _transport!.joinRoom(
          roomId,
          host: host,
          port: port ?? 8888,
          playerId: state.selfPlayer.id,
          playerName: state.selfPlayer.name,
          avatar: state.selfPlayer.avatar,
        );
      }

      _listenTransport();

      state = state.copyWith(
        isHost: false,
        isInRoom: true,
        isConnecting: false,
        roomId: roomId,
        networkMode: mode,
        players: [state.selfPlayer],
        chatMessages: [
          GameMessage.chat(
            senderId: 'SYSTEM',
            text: '【系统提示】已成功潜入房间：$roomId。等待房主启动博弈。',
            isSystem: true,
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: '加入房间失败: $e',
      );
    }
  }

  /// 退出房间并释放连接
  Future<void> leaveRoom() async {
    if (state.isInRoom && _transport != null) {
      try {
        if (!state.isHost) {
          await _transport!.sendToHost(GameMessage.leave(playerId: state.selfPlayer.id));
        }
        await _transport!.disconnect();
      } catch (_) {}
    }

    _lanDiscovery?.stopAdvertising();
    _lanDiscovery?.dispose();
    _lanDiscovery = null;

    _msgSub?.cancel();
    _peerJoinedSub?.cancel();
    _peerLeftSub?.cancel();

    _hostEngine = null;
    _transport = null;

    state = state.copyWith(
      isInRoom: false,
      isHost: false,
      roomId: '',
      currentPhase: GamePhase.preparing,
      clearIdentity: true,
      clearSettlement: true,
      clearWinner: true,
      players: [],
      chatMessages: [],
    );
  }

  void _listenTransport() {
    _msgSub?.cancel();
    _peerJoinedSub?.cancel();
    _peerLeftSub?.cancel();

    _msgSub = _transport?.onMessage.listen((msg) {
      _handleInboundMessage(msg);
    });

    _peerJoinedSub = _transport?.onPeerJoined.listen((peerId) {
      // 房主感知到新连接，若房主有权威快照可全量下发
      if (state.isHost && _hostEngine != null) {
        _syncHostStateToPeer(peerId);
      }
    });

    _peerLeftSub = _transport?.onPeerLeft.listen((peerId) {
      if (state.isHost && _hostEngine != null) {
        _hostEngine!.removePlayer(peerId);
        _syncHostStateToAll();
      }
    });
  }

  /// 集中处理接收到的网络消息
  void _handleInboundMessage(GameMessage msg) {
    if (state.isHost) {
      _handleInboundAsHost(msg);
    } else {
      _handleInboundAsClient(msg);
    }
  }

  // --- 房主视角消息路由 ---

  void _handleInboundAsHost(GameMessage msg) {
    final payload = msg.payload;

    switch (msg.type) {
      case GameMessageType.joinReq:
        final pid = payload['player_id']?.toString() ?? '';
        final pname = payload['player_name']?.toString() ?? '特工';
        final pavatar = payload['avatar']?.toString() ?? 'agent_1';
        if (pid.isNotEmpty) {
          final newPlayer = Player(id: pid, name: pname, avatar: pavatar);
          _hostEngine?.addPlayer(newPlayer);
          _syncHostStateToAll();
          _broadcastSystemChat('特工【$pname】潜入房间。');
        }
        break;

      case GameMessageType.leaveReq:
        final pid = payload['player_id']?.toString() ?? '';
        if (pid.isNotEmpty) {
          final p = _hostEngine?.players[pid];
          _hostEngine?.removePlayer(pid);
          _syncHostStateToAll();
          if (p != null) {
            _broadcastSystemChat('特工【${p.name}】撤出房间。');
          }
        }
        break;

      case GameMessageType.chat:
        // 房主公屏转发
        _broadcastMessage(msg);
        _appendLocalChat(msg);
        break;

      case GameMessageType.vote:
        final voterId = payload['voter_id']?.toString() ?? '';
        final targetId = payload['target_id']?.toString() ?? '';
        if (voterId.isNotEmpty && targetId.isNotEmpty && _hostEngine != null) {
          final res = _hostEngine!.submitVote(voterId, targetId);
          if (res.success) {
            _broadcastSystemChat('【公投表决】投票进度：${res.currentVotes}/${res.totalAlive}');
            if (res.allVoted) {
              advancePhase();
            }
          }
        }
        break;

      case GameMessageType.night:
        final actorId = payload['actor_id']?.toString() ?? '';
        final targetId = payload['target_id']?.toString() ?? '';
        if (actorId.isNotEmpty && targetId.isNotEmpty && _hostEngine != null) {
          final res = _hostEngine!.submitNightAction(actorId, targetId);
          // 单播私密反馈给行动者
          _transport?.sendToPeer(
            actorId,
            GameMessage.chat(
              senderId: 'SYSTEM',
              text: '【行动反馈】${res.feedback}',
              isSystem: true,
            ),
          );
        }
        break;

      case GameMessageType.blankGuess:
        final playerId = payload['player_id']?.toString() ?? '';
        final wordA = payload['word_a']?.toString() ?? '';
        final wordB = payload['word_b']?.toString() ?? '';
        if (playerId.isNotEmpty && _hostEngine != null) {
          final res = _hostEngine!.submitBlankGuess(
            playerId: playerId,
            guessA: wordA,
            guessB: wordB,
          );
          _broadcastSystemChat(res.message);
          _syncHostStateToAll();
        }
        break;

      default:
        break;
    }
  }

  // --- 客户端视角消息路由 ---

  void _handleInboundAsClient(GameMessage msg) {
    switch (msg.type) {
      case GameMessageType.syncState:
        final payload = msg.payload;
        final phase = GamePhaseExt.fromInt((payload['phase'] as num?)?.toInt() ?? 0);
        final round = (payload['round'] as num?)?.toInt() ?? 1;
        final winner = payload['winner']?.toString();
        final rawPlayers = payload['players'] as Map<String, dynamic>? ?? {};

        final updatedPlayers = rawPlayers.values
            .map((e) => Player.fromMap(e as Map<String, dynamic>))
            .toList();

        SettlementDetails? details;
        if (payload['settlement_details'] != null) {
          details = SettlementDetails.fromMap(
            payload['settlement_details'] as Map<String, dynamic>,
          );
        }

        // 同步自身存活状态
        final mySelf = updatedPlayers.firstWhere(
          (p) => p.id == state.selfPlayer.id,
          orElse: () => state.selfPlayer,
        );

        state = state.copyWith(
          currentPhase: phase,
          currentRound: round,
          winner: winner,
          players: updatedPlayers,
          selfPlayer: mySelf,
          settlementDetails: details,
        );
        break;

      case GameMessageType.syncPhase:
        final phaseCode = (msg.payload['new_phase'] as num?)?.toInt() ?? 0;
        final extraInfo = msg.payload['extra_info']?.toString() ?? '';
        state = state.copyWith(
          currentPhase: GamePhaseExt.fromInt(phaseCode),
          phaseExtraInfo: extraInfo,
        );
        break;

      case GameMessageType.identity:
        final role = msg.payload['role']?.toString() ?? GameRoles.good;
        final word = msg.payload['word']?.toString() ?? '';
        final hint = msg.payload['hint']?.toString() ?? '';
        state = state.copyWith(
          myIdentity: IdentityAssignment(role: role, word: word, hint: hint),
        );
        break;

      case GameMessageType.chat:
        _appendLocalChat(msg);
        break;

      default:
        break;
    }
  }

  // --- 游戏流程交互动作 ---

  /// 房主：开始游戏
  Future<void> startGame({String? theme, String? similarity}) async {
    if (!state.isHost || _hostEngine == null) return;

    try {
      final assignments = _hostEngine!.startGame(
        customTheme: theme,
        customSimilarity: similarity,
      );

      // 单播下发身份词包
      for (final entry in assignments.entries) {
        final pid = entry.key;
        final assignment = entry.value;

        if (pid == state.selfPlayer.id) {
          state = state.copyWith(myIdentity: assignment);
        } else {
          _transport?.sendToPeer(
            pid,
            GameMessage.identity(
              role: assignment.role,
              word: assignment.word,
              hint: assignment.hint,
            ),
          );
        }
      }

      _syncHostStateToAll();
      _broadcastSystemChat('【系统提示】博弈正式启动！请存活特工查阅「我的身份」，第一轮描述发言开始。');
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// 房主：推进至下一阶段
  Future<void> advancePhase() async {
    if (!state.isHost || _hostEngine == null) return;

    final res = _hostEngine!.advancePhase();
    _broadcastSystemChat(res.announcement);

    // 机器人行为自动驱动
    if (res.phase == GamePhase.voting) {
      _driveBotVotes();
    } else if (res.phase == GamePhase.nightAction) {
      _driveBotNightActions();
    } else if (res.phase == GamePhase.description) {
      _driveBotSpeeches();
    }

    _syncHostStateToAll();
  }

  /// 提交白天投票
  Future<void> submitVote(String targetId) async {
    if (state.currentPhase != GamePhase.voting) return;

    if (state.isHost && _hostEngine != null) {
      final res = _hostEngine!.submitVote(state.selfPlayer.id, targetId);
      if (res.success) {
        _broadcastSystemChat('【公投表决】投票进度：${res.currentVotes}/${res.totalAlive}');
        if (res.allVoted) {
          advancePhase();
        } else {
          _syncHostStateToAll();
        }
      } else {
        state = state.copyWith(errorMessage: res.message);
      }
    } else {
      // 客户端发往房主
      await _transport?.sendToHost(GameMessage.vote(
        voterId: state.selfPlayer.id,
        targetId: targetId,
      ));
    }
  }

  /// 提交黑夜暗杀行动
  Future<void> submitNightAction(String targetId) async {
    if (state.currentPhase != GamePhase.nightAction) return;

    if (state.isHost && _hostEngine != null) {
      final res = _hostEngine!.submitNightAction(state.selfPlayer.id, targetId);
      _appendLocalChat(GameMessage.chat(
        senderId: 'SYSTEM',
        text: '【行动反馈】${res.feedback}',
        isSystem: true,
      ));
    } else {
      await _transport?.sendToHost(GameMessage.night(
        actorId: state.selfPlayer.id,
        targetId: targetId,
      ));
    }
  }

  /// 提交白板双词逆袭
  Future<void> submitBlankGuess(String wordA, String wordB) async {
    if (state.currentPhase != GamePhase.blankGuess) return;

    if (state.isHost && _hostEngine != null) {
      final res = _hostEngine!.submitBlankGuess(
        playerId: state.selfPlayer.id,
        guessA: wordA,
        guessB: wordB,
      );
      _broadcastSystemChat(res.message);
      _syncHostStateToAll();
    } else {
      await _transport?.sendToHost(GameMessage.blankGuess(
        playerId: state.selfPlayer.id,
        wordA: wordA,
        wordB: wordB,
      ));
    }
  }

  /// 房主：一键填充虚拟特工机器人（最多至 12 人）
  void addMockBots(int count) {
    if (!state.isHost || _hostEngine == null) return;
    if (_hostEngine!.phase != GamePhase.preparing) return;

    final currentTotal = _hostEngine!.players.length;
    final availableSlots = 12 - currentTotal;
    final addCount = min(count, availableSlots);
    if (addCount <= 0) return;

    final existingIds = _hostEngine!.players.keys.toList();
    final newBots = MockBots.generateBots(addCount, excludeIds: existingIds);
    for (final b in newBots) {
      _hostEngine!.addPlayer(b);
    }

    _syncHostStateToAll();
    _broadcastSystemChat('【特工局召集】已成功指派 $addCount 名虚拟特工加入房间！');
  }

  /// 房主：清空所有机器人
  void clearMockBots() {
    if (!state.isHost || _hostEngine == null) return;
    if (_hostEngine!.phase != GamePhase.preparing) return;

    final botIds = _hostEngine!.players.values
        .where((p) => p.isBot)
        .map((p) => p.id)
        .toList();

    for (final id in botIds) {
      _hostEngine!.removePlayer(id);
    }

    _syncHostStateToAll();
    _broadcastSystemChat('【特工局召集】已解散全部虚拟特工。');
  }

  /// 房主：重置游戏至准备状态
  void resetGame() {
    if (!state.isHost || _hostEngine == null) return;

    _hostEngine!.reset();
    _syncHostStateToAll();
    _broadcastSystemChat('【系统提示】房主已重置游戏，等待重新发词。');
  }

  /// 发送聊天消息
  Future<void> sendChatMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final msg = GameMessage.chat(
      senderId: state.selfPlayer.name,
      text: trimmed,
      isSystem: false,
    );

    if (state.isHost) {
      _broadcastMessage(msg);
      _appendLocalChat(msg);
    } else {
      await _transport?.sendToHost(msg);
      _appendLocalChat(msg);
    }
  }

  /// 标记某玩家推理身份
  void markPlayer(String playerId, String roleMark) {
    final updated = Map<String, String>.from(state.playerMarks);
    if (roleMark.isEmpty) {
      updated.remove(playerId);
    } else {
      updated[playerId] = roleMark;
    }
    state = state.copyWith(playerMarks: updated);
  }

  /// 开启局域网房间雷达扫描
  void startLanDiscovery() {
    if (state.isDiscovering) return;
    _lanDiscovery ??= LanDiscovery();

    _lanDiscoverySub?.cancel();
    _lanDiscoverySub = _lanDiscovery!.onRoomsDiscovered.listen((rooms) {
      state = state.copyWith(discoveredRooms: rooms);
    });

    _lanDiscovery!.startDiscovery();
    state = state.copyWith(isDiscovering: true);
  }

  /// 停止局域网雷达扫描
  void stopLanDiscovery() {
    _lanDiscoverySub?.cancel();
    _lanDiscoverySub = null;
    _lanDiscovery?.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
  }

  // --- 机器人自动行为调度器 ---

  void _driveBotVotes() {
    if (_hostEngine == null) return;
    final botVotes = MockBots.simulateBotVotes(_hostEngine!);
    for (final entry in botVotes.entries) {
      _hostEngine!.submitVote(entry.key, entry.value);
    }
  }

  void _driveBotNightActions() {
    if (_hostEngine == null) return;
    final botActions = MockBots.simulateBotNightActions(_hostEngine!);
    for (final entry in botActions.entries) {
      _hostEngine!.submitNightAction(entry.key, entry.value);
    }
  }

  void _driveBotSpeeches() {
    if (_hostEngine == null) return;
    final aliveBots = _hostEngine!.players.values.where((p) => p.isAlive && p.isBot).toList();
    for (final bot in aliveBots) {
      final speech = MockBots.generateBotSpeech(bot, _hostEngine!.theme);
      final chat = GameMessage.chat(
        senderId: bot.name,
        text: speech,
        isSystem: false,
      );
      _broadcastMessage(chat);
      _appendLocalChat(chat);
    }
  }

  // --- 辅助方法 ---

  void _syncHostStateToAll() {
    if (_hostEngine == null) return;
    final snapshot = _hostEngine!.toSnapshotMap();
    final syncMsg = GameMessage.syncState(snapshot);
    _broadcastMessage(syncMsg);

    // 房主本地同步更新
    final phase = _hostEngine!.phase;
    final round = _hostEngine!.round;
    final list = _hostEngine!.players.values.toList();
    final mySelf = _hostEngine!.players[state.selfPlayer.id] ?? state.selfPlayer;

    state = state.copyWith(
      currentPhase: phase,
      currentRound: round,
      winner: _hostEngine!.winner,
      settlementDetails: _hostEngine!.settlementDetails,
      players: list,
      selfPlayer: mySelf,
    );
  }

  void _syncHostStateToPeer(String peerId) {
    if (_hostEngine == null) return;
    final snapshot = _hostEngine!.toSnapshotMap();
    final syncMsg = GameMessage.syncState(snapshot);
    _transport?.sendToPeer(peerId, syncMsg);
  }

  void _broadcastMessage(GameMessage msg) {
    _transport?.broadcast(msg);
  }

  void _broadcastSystemChat(String text) {
    final chat = GameMessage.chat(
      senderId: 'SYSTEM',
      text: text,
      isSystem: true,
    );
    _broadcastMessage(chat);
    _appendLocalChat(chat);
  }

  void _appendLocalChat(GameMessage msg) {
    final updated = List<GameMessage>.from(state.chatMessages)..add(msg);
    if (updated.length > 200) {
      updated.removeRange(0, updated.length - 200);
    }
    state = state.copyWith(chatMessages: updated);
  }

  @override
  void dispose() {
    leaveRoom();
    super.dispose();
  }
}
