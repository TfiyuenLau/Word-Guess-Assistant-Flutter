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

  final bool hasVotedThisRound;
  final String? myVotedTargetId;
  final bool hasNightActedThisRound;

  final int phaseNoticeSeq;
  final String? phaseNoticeTitle;
  final String? phaseNoticeBody;

  const RoomState({
    required this.selfPlayer,
    this.networkMode = 'p2p',
    this.roomId = '',
    this.isHost = false,
    this.isInRoom = false,
    this.isConnecting = false,
    this.errorMessage,
    this.currentPhase = GamePhase.preparing,
    this.phaseExtraInfo = '等待玩家加入',
    this.currentRound = 1,
    this.myIdentity,
    this.players = const [],
    this.chatMessages = const [],
    this.settlementDetails,
    this.winner,
    this.playerMarks = const {},
    this.discoveredRooms = const [],
    this.isDiscovering = false,
    this.hasVotedThisRound = false,
    this.myVotedTargetId,
    this.hasNightActedThisRound = false,
    this.phaseNoticeSeq = 0,
    this.phaseNoticeTitle,
    this.phaseNoticeBody,
  });

  bool get isSpectator =>
      selfPlayer.role == GameRoles.spectator ||
      myIdentity?.role == GameRoles.spectator;

  bool get canSendChat =>
      !isSpectator &&
      (currentPhase == GamePhase.preparing ||
          (currentPhase == GamePhase.description &&
              currentRound == 1 &&
              selfPlayer.isAlive));

  bool get canVote =>
      !isSpectator &&
      currentPhase == GamePhase.voting &&
      selfPlayer.isAlive &&
      !hasVotedThisRound;

  bool get canNightAct =>
      !isSpectator &&
      currentPhase == GamePhase.nightAction &&
      selfPlayer.isAlive &&
      !hasNightActedThisRound;

  bool get canBlankGuess =>
      !isSpectator &&
      currentPhase == GamePhase.blankGuess &&
      myIdentity?.role == GameRoles.blank;

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
    bool? hasVotedThisRound,
    String? myVotedTargetId,
    bool clearMyVotedTarget = false,
    bool? hasNightActedThisRound,
    int? phaseNoticeSeq,
    String? phaseNoticeTitle,
    String? phaseNoticeBody,
    bool clearPhaseNotice = false,
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
      settlementDetails: clearSettlement
          ? null
          : (settlementDetails ?? this.settlementDetails),
      winner: clearWinner ? null : (winner ?? this.winner),
      playerMarks: playerMarks ?? this.playerMarks,
      discoveredRooms: discoveredRooms ?? this.discoveredRooms,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      hasVotedThisRound: hasVotedThisRound ?? this.hasVotedThisRound,
      myVotedTargetId: clearMyVotedTarget
          ? null
          : (myVotedTargetId ?? this.myVotedTargetId),
      hasNightActedThisRound:
          hasNightActedThisRound ?? this.hasNightActedThisRound,
      phaseNoticeSeq: phaseNoticeSeq ?? this.phaseNoticeSeq,
      phaseNoticeTitle:
          clearPhaseNotice ? null : (phaseNoticeTitle ?? this.phaseNoticeTitle),
      phaseNoticeBody:
          clearPhaseNotice ? null : (phaseNoticeBody ?? this.phaseNoticeBody),
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
            id: 'player_${Random().nextInt(899999) + 100000}',
            name: '玩家_${Random().nextInt(8999) + 1000}',
            avatar: 'characters/detective.svg',
          ),
        )) {
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || state.isInRoom) return;

      final savedId = prefs.getString('wga_player_id');
      final savedName = prefs.getString('wga_player_name');
      var savedAvatar = prefs.getString('wga_player_avatar');

      final id = savedId ?? state.selfPlayer.id;
      final name = savedName ?? state.selfPlayer.name;
      if (savedAvatar == null || savedAvatar.startsWith('agent_')) {
        savedAvatar = 'characters/detective.svg';
      }
      final avatar = savedAvatar;

      if (savedId == null) await prefs.setString('wga_player_id', id);
      if (!mounted || state.isInRoom) return;

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
      if (!mounted) return;

      final roomId = customRoomId?.trim().isNotEmpty == true
          ? customRoomId!.trim()
          : (1000 + Random().nextInt(9000)).toString();

      _hostEngine = GameEngine();
      _hostEngine!.addPlayer(state.selfPlayer);

      if (mode == 'p2p') {
        _transport = WebRtcP2PTransport(selfId: state.selfPlayer.id);
        _listenTransport();
        await _transport!.hostRoom(roomId);
      } else {
        _transport = LanTransport(selfId: state.selfPlayer.id);
        _listenTransport();
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

      if (!mounted) return;
      state = state.copyWith(
        isHost: true,
        isInRoom: true,
        isConnecting: false,
        roomId: roomId,
        networkMode: mode,
        currentPhase: GamePhase.preparing,
        currentRound: 1,
        phaseExtraInfo: '等待玩家加入，4~12 人可开局',
        players: _hostEngine!.players.values.toList(),
        playerMarks: const {},
        hasVotedThisRound: false,
        clearMyVotedTarget: true,
        hasNightActedThisRound: false,
        phaseNoticeSeq: 0,
        clearPhaseNotice: true,
        chatMessages: [
          GameMessage.chat(
            senderId: 'SYSTEM',
            text: '房间已创建（房间号：$roomId）。',
            isSystem: true,
          ),
        ],
      );
    } catch (e) {
      await _cleanupTransport();
      if (!mounted) return;
      state = state.copyWith(
        isHost: false,
        isInRoom: false,
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
      if (!mounted) return;

      _transport = mode == 'p2p'
          ? WebRtcP2PTransport(selfId: state.selfPlayer.id)
          : LanTransport(selfId: state.selfPlayer.id);

      // 先初始化客户端状态并挂载传输监听，再发起连接，避免快速本地回环下首帧 syncState 丢失
      state = state.copyWith(
        isHost: false,
        isInRoom: true,
        isConnecting: true,
        roomId: roomId,
        networkMode: mode,
        currentPhase: GamePhase.preparing,
        currentRound: 1,
        phaseExtraInfo: '等待房主开始',
        players: [state.selfPlayer],
        playerMarks: const {},
        hasVotedThisRound: false,
        clearMyVotedTarget: true,
        hasNightActedThisRound: false,
        phaseNoticeSeq: 0,
        clearPhaseNotice: true,
        chatMessages: [
          GameMessage.chat(
            senderId: 'SYSTEM',
            text: '已加入房间：$roomId。',
            isSystem: true,
          ),
        ],
      );

      _listenTransport();

      if (mode == 'p2p') {
        await _transport!.joinRoom(
          roomId,
          playerId: state.selfPlayer.id,
          playerName: state.selfPlayer.name,
          avatar: state.selfPlayer.avatar,
        );
      } else {
        await _transport!.joinRoom(
          roomId,
          host: host,
          port: port ?? 8888,
          playerId: state.selfPlayer.id,
          playerName: state.selfPlayer.name,
          avatar: state.selfPlayer.avatar,
        );
      }

      if (!mounted) return;
      state = state.copyWith(isConnecting: false);
    } catch (e) {
      await _cleanupTransport();
      if (!mounted) return;
      state = state.copyWith(
        isHost: false,
        isInRoom: false,
        isConnecting: false,
        roomId: '',
        players: const [],
        chatMessages: const [],
        errorMessage: '加入房间失败: $e',
      );
    }
  }

  Future<void> _cleanupTransport() async {
    try {
      await _transport?.disconnect();
    } catch (_) {}

    _lanDiscovery?.stopAdvertising();
    _lanDiscovery?.dispose();
    _lanDiscovery = null;

    _msgSub?.cancel();
    _msgSub = null;
    _peerJoinedSub?.cancel();
    _peerJoinedSub = null;
    _peerLeftSub?.cancel();
    _peerLeftSub = null;

    _hostEngine = null;
    _transport = null;
  }

  /// 退出房间并释放连接
  Future<void> leaveRoom() async {
    if (state.isInRoom && _transport != null) {
      try {
        if (!state.isHost) {
          await _transport!.sendToHost(
            GameMessage.leave(playerId: state.selfPlayer.id),
          );
        }
      } catch (_) {}
    }

    await _cleanupTransport();

    if (!mounted) return;
    state = state.copyWith(
      selfPlayer: state.selfPlayer.copyWith(
        isAlive: true,
        clearRole: true,
        clearWord: true,
        clearHint: true,
        clearMark: true,
      ),
      isInRoom: false,
      isHost: false,
      roomId: '',
      currentPhase: GamePhase.preparing,
      currentRound: 1,
      phaseExtraInfo: '',
      clearIdentity: true,
      clearSettlement: true,
      clearWinner: true,
      players: const [],
      chatMessages: const [],
      playerMarks: const {},
      hasVotedThisRound: false,
      clearMyVotedTarget: true,
      hasNightActedThisRound: false,
      phaseNoticeSeq: 0,
      clearPhaseNotice: true,
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
      // 房主感知到新连接，下发权威快照
      if (state.isHost && _hostEngine != null) {
        _syncHostStateToPeer(peerId);
      }
    });

    _peerLeftSub = _transport?.onPeerLeft.listen((peerId) {
      if (state.isHost && _hostEngine != null) {
        if (_hostEngine!.phase == GamePhase.preparing) {
          _hostEngine!.removePlayer(peerId);
          _syncHostStateToAll();
        }
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
        final pname = payload['player_name']?.toString() ?? '玩家';
        final pavatar =
            payload['avatar']?.toString() ?? 'characters/detective.svg';
        if (pid.isNotEmpty) {
          final existing = _hostEngine?.players[pid];
          final newPlayer = Player(id: pid, name: pname, avatar: pavatar);
          _hostEngine?.addPlayer(newPlayer);

          // 既有玩家断线重连恢复身份
          if (existing != null &&
              existing.role != null &&
              existing.role != GameRoles.spectator) {
            final assignment = _hostEngine?.getIdentityAssignment(pid);
            if (assignment != null) {
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
          _broadcastSystemChat('$pname 加入了房间。');
        }
        break;

      case GameMessageType.leaveReq:
        final pid = payload['player_id']?.toString() ?? '';
        if (pid.isNotEmpty) {
          final p = _hostEngine?.players[pid];
          _hostEngine?.removePlayer(pid);
          _syncHostStateToAll();
          if (p != null) {
            _broadcastSystemChat('${p.name} 离开了房间。');
          }
        }
        break;

      case GameMessageType.chat:
        if (_hostEngine == null) break;
        if (payload['is_system'] == true) break;

        final senderId = payload['sender_id']?.toString() ?? '';
        final sender = _hostEngine!.players[senderId];
        if (sender == null || sender.role == GameRoles.spectator) break;

        final phase = _hostEngine!.phase;
        final round = _hostEngine!.round;
        final canSpeak = phase == GamePhase.preparing ||
            (phase == GamePhase.description && round == 1 && sender.isAlive);
        if (!canSpeak) break;

        final isRound1Speech = phase == GamePhase.description && round == 1;
        final normalizedMsg = GameMessage(
          type: GameMessageType.chat,
          timestamp: msg.timestamp,
          payload: {
            'sender_id': senderId,
            'text': payload['text']?.toString() ?? '',
            'is_system': false,
            if (isRound1Speech) 'is_speech': true,
            if (isRound1Speech) 'speech_round': 1,
          },
        );
        _broadcastMessage(normalizedMsg);
        _appendLocalChat(normalizedMsg);
        break;

      case GameMessageType.vote:
        final voterId = payload['voter_id']?.toString() ?? '';
        final targetId = payload['target_id']?.toString() ?? '';
        if (voterId.isNotEmpty && targetId.isNotEmpty && _hostEngine != null) {
          final res = _hostEngine!.submitVote(voterId, targetId);
          if (res.success && res.allVoted) {
            advancePhase();
          }
        }
        break;

      case GameMessageType.night:
        final actorId = payload['actor_id']?.toString() ?? '';
        final targetId = payload['target_id']?.toString() ?? '';
        if (actorId.isNotEmpty && targetId.isNotEmpty && _hostEngine != null) {
          final res = _hostEngine!.submitNightAction(actorId, targetId);
          // 单播私密反馈给行动者（不泄露真实身份与成败细节）
          _transport?.sendToPeer(
            actorId,
            GameMessage.chat(
              senderId: 'SYSTEM',
              text: res.feedback,
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
          if (res.success) {
            _broadcastSystemChat(res.message);
            if (_hostEngine!.phase == GamePhase.nightAction) {
              state = state.copyWith(hasNightActedThisRound: false);
              _driveBotNightActions();
            }
            _syncHostStateToAll(announcement: res.message);
          }
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
        final prevPhase = state.currentPhase;
        final prevRound = state.currentRound;

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

        // 同步自身状态
        final mySelf = updatedPlayers.firstWhere(
          (p) => p.id == state.selfPlayer.id,
          orElse: () => state.selfPlayer,
        );

        final phaseChanged = phase != prevPhase ||
            (phase == GamePhase.description && round != prevRound);
        final enteringNewGame = phase == GamePhase.description &&
            round == 1 &&
            prevPhase != GamePhase.description;
        final enteringRound2PlusDesc = phase == GamePhase.description &&
            round >= 2 &&
            (round > prevRound || prevPhase != GamePhase.description);
        final enteringPreparing =
            phase == GamePhase.preparing && prevPhase != GamePhase.preparing;
        final enteringSettlement =
            phase == GamePhase.settlement && prevPhase != GamePhase.settlement;

        final resetVote = (phase == GamePhase.voting && prevPhase != GamePhase.voting) ||
            enteringPreparing ||
            enteringNewGame;
        final resetNight =
            (phase == GamePhase.nightAction && prevPhase != GamePhase.nightAction) ||
                enteringPreparing ||
                enteringNewGame;

        var nextChat = state.chatMessages;
        if (enteringPreparing || enteringNewGame) {
          nextChat = _stripSpeechTags(nextChat);
        }

        int nextNoticeSeq = state.phaseNoticeSeq;
        String? nextNoticeTitle = state.phaseNoticeTitle;
        String? nextNoticeBody = state.phaseNoticeBody;
        if (phaseChanged &&
            phase != GamePhase.preparing &&
            phase != GamePhase.settlement) {
          nextNoticeSeq = state.phaseNoticeSeq + 1;
          nextNoticeTitle = payload['phase_notice_title']?.toString() ??
              _defaultPhaseNoticeTitle(phase, round);
          nextNoticeBody = payload['phase_notice_body']?.toString() ??
              _defaultPhaseNoticeBody(phase, round);
        }

        final nextExtraInfo = payload['phase_extra_info']?.toString() ??
            _defaultPhaseExtraInfo(phase, round);

        state = state.copyWith(
          currentPhase: phase,
          currentRound: round,
          phaseExtraInfo: nextExtraInfo,
          winner: winner,
          clearWinner: winner == null,
          players: updatedPlayers,
          selfPlayer: mySelf,
          settlementDetails: details,
          clearSettlement: details == null,
          clearIdentity: phase == GamePhase.preparing,
          playerMarks:
              (enteringSettlement || enteringPreparing || enteringNewGame)
                  ? const {}
                  : state.playerMarks,
          hasVotedThisRound: resetVote ? false : state.hasVotedThisRound,
          clearMyVotedTarget: resetVote,
          hasNightActedThisRound:
              resetNight ? false : state.hasNightActedThisRound,
          chatMessages: nextChat,
          phaseNoticeSeq: nextNoticeSeq,
          phaseNoticeTitle: nextNoticeTitle,
          phaseNoticeBody: nextNoticeBody,
        );

        if (enteringRound2PlusDesc) {
          _replayRound1Speeches();
        }
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

      state = state.copyWith(
        chatMessages: _stripSpeechTags(state.chatMessages),
        playerMarks: const {},
        hasVotedThisRound: false,
        clearMyVotedTarget: true,
        hasNightActedThisRound: false,
        clearSettlement: true,
        clearWinner: true,
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

      const startNotice = '游戏开始，第 1 轮描述开始，请存活玩家描述自己的词语。';
      _syncHostStateToAll(announcement: startNotice);
      _broadcastSystemChat(startNotice);
      _driveBotSpeeches();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// 房主：推进至下一阶段
  Future<void> advancePhase() async {
    if (!state.isHost || _hostEngine == null) return;

    final res = _hostEngine!.advancePhase();
    String latestAnnouncement = res.announcement;
    _broadcastSystemChat(res.announcement);

    if (res.phase == GamePhase.voting) {
      state = state.copyWith(
        hasVotedThisRound: false,
        clearMyVotedTarget: true,
      );
      final autoAdvanced = _driveBotVotes();
      if (autoAdvanced) return;
    } else if (res.phase == GamePhase.nightAction) {
      state = state.copyWith(hasNightActedThisRound: false);
      _driveBotNightActions();
    } else if (res.phase == GamePhase.blankGuess) {
      final botGuessMsg = _driveBotBlankGuess();
      if (botGuessMsg != null) {
        latestAnnouncement = botGuessMsg;
      }
      if (_hostEngine!.phase == GamePhase.nightAction) {
        state = state.copyWith(hasNightActedThisRound: false);
        _driveBotNightActions();
      }
    }

    _syncHostStateToAll(announcement: latestAnnouncement);

    if (_hostEngine!.phase == GamePhase.description &&
        _hostEngine!.round >= 2) {
      _replayRound1Speeches();
    }
  }

  /// 提交白天投票
  Future<void> submitVote(String targetId) async {
    if (!state.canVote) return;

    String targetName = targetId;
    for (final p in state.players) {
      if (p.id == targetId) {
        targetName = p.name;
        break;
      }
    }

    if (state.isHost && _hostEngine != null) {
      final res = _hostEngine!.submitVote(state.selfPlayer.id, targetId);
      if (res.success) {
        state = state.copyWith(
          hasVotedThisRound: true,
          myVotedTargetId: targetId,
        );
        _appendLocalChat(GameMessage.chat(
          senderId: 'SYSTEM',
          text: '你已投票给 $targetName',
          isSystem: true,
        ));
        if (res.allVoted) {
          await advancePhase();
        } else {
          _syncHostStateToAll();
        }
      } else {
        state = state.copyWith(errorMessage: res.message);
      }
    } else {
      state = state.copyWith(
        hasVotedThisRound: true,
        myVotedTargetId: targetId,
      );
      _appendLocalChat(GameMessage.chat(
        senderId: 'SYSTEM',
        text: '你已投票给 $targetName',
        isSystem: true,
      ));
      await _transport?.sendToHost(GameMessage.vote(
        voterId: state.selfPlayer.id,
        targetId: targetId,
      ));
    }
  }

  /// 提交夜间行动
  Future<void> submitNightAction(String targetId) async {
    if (!state.canNightAct) return;

    if (state.isHost && _hostEngine != null) {
      final res = _hostEngine!.submitNightAction(state.selfPlayer.id, targetId);
      if (res.success) {
        state = state.copyWith(hasNightActedThisRound: true);
        _appendLocalChat(GameMessage.chat(
          senderId: 'SYSTEM',
          text: res.feedback,
          isSystem: true,
        ));
      } else {
        state = state.copyWith(errorMessage: res.feedback);
      }
    } else {
      state = state.copyWith(hasNightActedThisRound: true);
      await _transport?.sendToHost(GameMessage.night(
        actorId: state.selfPlayer.id,
        targetId: targetId,
      ));
    }
  }

  /// 提交白板双词猜词
  Future<void> submitBlankGuess(String wordA, String wordB) async {
    if (!state.canBlankGuess) return;

    if (state.isHost && _hostEngine != null) {
      final res = _hostEngine!.submitBlankGuess(
        playerId: state.selfPlayer.id,
        guessA: wordA,
        guessB: wordB,
      );
      if (res.success) {
        _broadcastSystemChat(res.message);
        if (_hostEngine!.phase == GamePhase.nightAction) {
          state = state.copyWith(hasNightActedThisRound: false);
          _driveBotNightActions();
        }
        _syncHostStateToAll(announcement: res.message);
      }
    } else {
      await _transport?.sendToHost(GameMessage.blankGuess(
        playerId: state.selfPlayer.id,
        wordA: wordA,
        wordB: wordB,
      ));
    }
  }

  /// 房主：添加机器人（最多至 12 人）
  void addMockBots(int count) {
    if (!state.isHost || _hostEngine == null) return;
    if (_hostEngine!.phase != GamePhase.preparing) return;

    final currentTotal = _hostEngine!.players.length;
    final availableSlots = 12 - currentTotal;
    final addCount = min(count, availableSlots);
    if (addCount <= 0) return;

    final existingIds = _hostEngine!.players.keys.toList();
    final existingNames =
        _hostEngine!.players.values.map((p) => p.name).toList();
    final newBots = MockBots.generateBots(
      addCount,
      excludeIds: existingIds,
      excludeNames: existingNames,
    );
    for (final b in newBots) {
      _hostEngine!.addPlayer(b);
    }

    _syncHostStateToAll();
    _broadcastSystemChat('已添加 ${newBots.length} 名机器人。');
  }

  /// 房主：将房间人数用机器人补至指定总数（4~12 人）
  void fillBotsToCount(int targetTotal) {
    if (!state.isHost || _hostEngine == null) return;
    if (_hostEngine!.phase != GamePhase.preparing) return;

    final clamped = targetTotal.clamp(4, 12);
    final needed = clamped - _hostEngine!.players.length;
    if (needed > 0) {
      addMockBots(needed);
    }
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
    _broadcastSystemChat('已移除全部机器人。');
  }

  /// 房主：重置游戏至准备状态
  void resetGame() {
    if (!state.isHost || _hostEngine == null) return;

    _hostEngine!.reset();
    state = state.copyWith(
      chatMessages: _stripSpeechTags(state.chatMessages),
      clearIdentity: true,
      clearSettlement: true,
      clearWinner: true,
      playerMarks: const {},
      hasVotedThisRound: false,
      clearMyVotedTarget: true,
      hasNightActedThisRound: false,
    );
    _syncHostStateToAll();
    _broadcastSystemChat('房主已重置对局，回到准备阶段。');
  }

  /// 发送聊天消息
  Future<void> sendChatMessage(String text) async {
    if (!state.canSendChat) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final isRound1Speech =
        state.currentPhase == GamePhase.description && state.currentRound == 1;

    final msg = GameMessage(
      type: GameMessageType.chat,
      payload: {
        'sender_id': state.selfPlayer.id,
        'text': trimmed,
        'is_system': false,
        if (isRound1Speech) 'is_speech': true,
        if (isRound1Speech) 'speech_round': 1,
      },
    );

    if (state.isHost) {
      _broadcastMessage(msg);
      _appendLocalChat(msg);
    } else {
      await _transport?.sendToHost(msg);
    }
  }

  /// 标记某玩家推理身份（仅本地可见）
  void markPlayer(String playerId, String roleMark) {
    final updated = Map<String, String>.from(state.playerMarks);
    if (roleMark.isEmpty) {
      updated.remove(playerId);
    } else {
      updated[playerId] = roleMark;
    }
    state = state.copyWith(playerMarks: updated);
  }

  /// 开启局域网房间扫描
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

  /// 停止局域网房间扫描
  void stopLanDiscovery() {
    _lanDiscoverySub?.cancel();
    _lanDiscoverySub = null;
    _lanDiscovery?.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
  }

  // --- 机器人自动行为调度器 ---

  bool _driveBotVotes() {
    if (_hostEngine == null) return false;
    final botVotes = MockBots.simulateBotVotes(_hostEngine!);
    for (final entry in botVotes.entries) {
      _hostEngine!.submitVote(entry.key, entry.value);
    }
    final aliveCount =
        _hostEngine!.players.values.where((p) => p.isAlive).length;
    if (aliveCount > 0 && _hostEngine!.votes.length >= aliveCount) {
      advancePhase();
      return true;
    }
    return false;
  }

  void _driveBotNightActions() {
    if (_hostEngine == null) return;
    final botActions = MockBots.simulateBotNightActions(_hostEngine!);
    for (final entry in botActions.entries) {
      _hostEngine!.submitNightAction(entry.key, entry.value);
    }
  }

  String? _driveBotBlankGuess() {
    if (_hostEngine == null) return null;
    final eliminatedId = _hostEngine!.lastEliminatedPlayerId;
    if (eliminatedId != null) {
      final p = _hostEngine!.players[eliminatedId];
      if (p != null && p.isBot && p.role == GameRoles.blank) {
        final guess = MockBots.simulateBotBlankGuess(_hostEngine!, eliminatedId);
        if (guess != null) {
          final res = _hostEngine!.submitBlankGuess(
            playerId: eliminatedId,
            guessA: guess['word_a'] ?? '',
            guessB: guess['word_b'] ?? '',
          );
          _broadcastSystemChat(res.message);
          return res.message;
        }
      }
    }
    return null;
  }

  void _driveBotSpeeches() {
    if (_hostEngine == null) return;
    if (_hostEngine!.phase != GamePhase.description ||
        _hostEngine!.round != 1) {
      return;
    }
    final aliveBots =
        _hostEngine!.players.values.where((p) => p.isAlive && p.isBot).toList();
    for (final bot in aliveBots) {
      final speech = MockBots.generateBotSpeech(bot, _hostEngine!.theme);
      final chat = GameMessage(
        type: GameMessageType.chat,
        payload: {
          'sender_id': bot.id,
          'text': speech,
          'is_system': false,
          'is_speech': true,
          'speech_round': 1,
        },
      );
      _broadcastMessage(chat);
      _appendLocalChat(chat);
    }
  }

  // --- 辅助方法 ---

  void _syncHostStateToAll({String? announcement}) {
    if (_hostEngine == null) return;

    final prevPhase = state.currentPhase;
    final prevRound = state.currentRound;
    final phase = _hostEngine!.phase;
    final round = _hostEngine!.round;
    final list = _hostEngine!.players.values.toList();
    final mySelf = _hostEngine!.players[state.selfPlayer.id] ?? state.selfPlayer;

    final phaseChanged = phase != prevPhase ||
        (phase == GamePhase.description && round != prevRound);

    final noticeTitle = _defaultPhaseNoticeTitle(phase, round);
    final noticeBody =
        announcement ?? _defaultPhaseNoticeBody(phase, round);
    final extraInfo = _defaultPhaseExtraInfo(phase, round);

    // 对外广播脱敏快照，保护词汇与未公开身份
    final snapshot = _hostEngine!.toSnapshotMap(maskSecrets: true);
    snapshot['phase_extra_info'] = extraInfo;
    if (phaseChanged &&
        phase != GamePhase.preparing &&
        phase != GamePhase.settlement) {
      snapshot['phase_notice_title'] = noticeTitle;
      snapshot['phase_notice_body'] = noticeBody;
    }

    final syncMsg = GameMessage.syncState(snapshot);
    _broadcastMessage(syncMsg);

    int nextNoticeSeq = state.phaseNoticeSeq;
    String? nextNoticeTitle = state.phaseNoticeTitle;
    String? nextNoticeBody = state.phaseNoticeBody;
    if (phaseChanged &&
        phase != GamePhase.preparing &&
        phase != GamePhase.settlement) {
      nextNoticeSeq = state.phaseNoticeSeq + 1;
      nextNoticeTitle = noticeTitle;
      nextNoticeBody = noticeBody;
    }

    final enteringSettlement =
        phase == GamePhase.settlement && prevPhase != GamePhase.settlement;

    state = state.copyWith(
      currentPhase: phase,
      currentRound: round,
      phaseExtraInfo: extraInfo,
      winner: _hostEngine!.winner,
      clearWinner: _hostEngine!.winner == null,
      settlementDetails: _hostEngine!.settlementDetails,
      clearSettlement: _hostEngine!.settlementDetails == null,
      clearIdentity: phase == GamePhase.preparing,
      players: list,
      selfPlayer: mySelf,
      playerMarks: enteringSettlement ? const {} : state.playerMarks,
      phaseNoticeSeq: nextNoticeSeq,
      phaseNoticeTitle: nextNoticeTitle,
      phaseNoticeBody: nextNoticeBody,
    );
  }

  void _syncHostStateToPeer(String peerId) {
    if (_hostEngine == null) return;
    final snapshot =
        _hostEngine!.toSnapshotMap(maskSecrets: true, forPlayerId: peerId);
    snapshot['phase_extra_info'] =
        _defaultPhaseExtraInfo(_hostEngine!.phase, _hostEngine!.round);
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
    final updated = List<GameMessage>.from(state.chatMessages);
    final isSystem = msg.payload['is_system'] == true;

    if (!isSystem &&
        state.currentPhase == GamePhase.description &&
        state.currentRound == 1) {
      final senderId = msg.payload['sender_id']?.toString() ?? '';
      final normalizedMsg = GameMessage(
        type: GameMessageType.chat,
        timestamp: msg.timestamp,
        payload: {
          ...msg.payload,
          'is_speech': true,
          'speech_round': 1,
        },
      );

      final existingIdx = updated.indexWhere((m) {
        final p = m.payload;
        return p['is_system'] != true &&
            p['sender_id']?.toString() == senderId &&
            p['is_speech'] == true &&
            (p['speech_round'] as num?)?.toInt() == 1;
      });

      if (existingIdx != -1) {
        updated[existingIdx] = normalizedMsg;
      } else {
        updated.add(normalizedMsg);
      }
    } else {
      updated.add(msg);
    }

    if (updated.length > 200) {
      updated.removeRange(0, updated.length - 200);
    }
    state = state.copyWith(chatMessages: updated);
  }

  void _replayRound1Speeches() {
    bool isRound1Speech(GameMessage m) {
      final p = m.payload;
      return p['is_system'] != true &&
          p['is_speech'] == true &&
          (p['speech_round'] as num?)?.toInt() == 1;
    }

    final speeches = state.chatMessages.where(isRound1Speech).toList();
    if (speeches.isEmpty) return;

    final reordered =
        state.chatMessages.where((m) => !isRound1Speech(m)).toList()
          ..addAll(speeches);

    if (reordered.length > 200) {
      reordered.removeRange(0, reordered.length - 200);
    }
    state = state.copyWith(chatMessages: reordered);
  }

  List<GameMessage> _stripSpeechTags(List<GameMessage> messages) {
    return messages.map((m) {
      if (m.payload['is_speech'] == true) {
        final nextPayload = Map<String, dynamic>.from(m.payload)
          ..['is_speech'] = false;
        return GameMessage(
          type: m.type,
          timestamp: m.timestamp,
          payload: nextPayload,
        );
      }
      return m;
    }).toList();
  }

  String _defaultPhaseNoticeTitle(GamePhase phase, int round) {
    switch (phase) {
      case GamePhase.preparing:
        return '准备中';
      case GamePhase.description:
        return '第 $round 轮 · 描述';
      case GamePhase.voting:
        return '第 $round 轮 · 投票';
      case GamePhase.nightAction:
        return '夜晚阶段';
      case GamePhase.blankGuess:
        return '白板猜词';
      case GamePhase.settlement:
        return '对局结算';
    }
  }

  String _defaultPhaseNoticeBody(GamePhase phase, int round) {
    switch (phase) {
      case GamePhase.preparing:
        return '等待房主开始游戏';
      case GamePhase.description:
        return round == 1
            ? '游戏开始，请存活玩家在首轮描述自己的词语。'
            : '天亮了，已回放第 1 轮发言供参考。';
      case GamePhase.voting:
        return '请存活玩家进行匿名投票。';
      case GamePhase.nightAction:
        return '进入夜晚阶段，请卧底选择目标。';
      case GamePhase.blankGuess:
        return '白板被投出，正在进行双词猜词。';
      case GamePhase.settlement:
        return '对局已结束。';
    }
  }

  String _defaultPhaseExtraInfo(GamePhase phase, int round) {
    switch (phase) {
      case GamePhase.preparing:
        return '等待玩家加入';
      case GamePhase.description:
        return round == 1 ? '首轮描述' : '第 $round 轮 · 回顾线索';
      case GamePhase.voting:
        return '第 $round 轮 · 匿名投票';
      case GamePhase.nightAction:
        return '夜晚阶段';
      case GamePhase.blankGuess:
        return '白板猜词';
      case GamePhase.settlement:
        return '对局结束';
    }
  }

  @override
  void dispose() {
    leaveRoom();
    super.dispose();
  }
}
