import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/game_controller.dart';
import '../../models/game_models.dart';
import '../../models/protocol_messages.dart';
import '../modals/blank_guess_dialog.dart';
import '../modals/host_console_dialog.dart';
import '../modals/identity_card_dialog.dart';
import '../modals/night_action_dialog.dart';
import '../modals/phase_notice_dialog.dart';
import '../modals/player_mark_dialog.dart';
import '../modals/player_roster_sheet.dart';
import '../modals/settlement_dialog.dart';
import '../modals/vote_dialog.dart';
import '../widgets/avatar_widget.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _chatInputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _settlementShown = false;
  int _lastShownNoticeSeq = 0;

  @override
  void dispose() {
    _chatInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _chatInputController.text;
    if (text.trim().isEmpty) return;
    ref.read(gameControllerProvider.notifier).sendChatMessage(text);
    _chatInputController.clear();
  }

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('离开房间'),
        content: const Text('确定要退出当前房间吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(gameControllerProvider.notifier).leaveRoom();
              Navigator.of(context).pop();
            },
            child: const Text('离开'),
          ),
        ],
      ),
    );
  }

  void _openPlayerMarkDialog(Player player, String? currentMark) {
    showDialog(
      context: context,
      builder: (_) => PlayerMarkDialog(
        player: player,
        currentMark: currentMark,
        onMarkSelected: (roleMark) {
          ref.read(gameControllerProvider.notifier).markPlayer(player.id, roleMark);
        },
      ),
    );
  }

  void _openPlayerRoster(RoomState roomState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => PlayerRosterSheet(
        players: roomState.players,
        selfPlayerId: roomState.selfPlayer.id,
        playerMarks: roomState.playerMarks,
        onTapPlayer: (player) {
          if (player.id == roomState.selfPlayer.id) return;
          Navigator.of(sheetCtx).pop();
          _openPlayerMarkDialog(player, roomState.playerMarks[player.id]);
        },
      ),
    );
  }

  void _openHostConsole() {
    showDialog(
      context: context,
      builder: (_) => Consumer(
        builder: (ctx, dialogRef, _) {
          final liveState = dialogRef.watch(gameControllerProvider);
          return HostConsoleDialog(
            playerCount: liveState.players.length,
            currentPhase: liveState.currentPhase,
            onStartGame: (th, sim) {
              dialogRef
                  .read(gameControllerProvider.notifier)
                  .startGame(theme: th, similarity: sim);
            },
            onAdvancePhase: () {
              dialogRef.read(gameControllerProvider.notifier).advancePhase();
            },
            onResetGame: () {
              dialogRef.read(gameControllerProvider.notifier).resetGame();
            },
            onAddBots: (count) {
              dialogRef.read(gameControllerProvider.notifier).addMockBots(count);
            },
            onClearBots: () {
              dialogRef.read(gameControllerProvider.notifier).clearMockBots();
            },
            onFillBotsTo: (target) {
              dialogRef
                  .read(gameControllerProvider.notifier)
                  .fillBotsToCount(target);
            },
          );
        },
      ),
    );
  }

  void _copyRoomId(String roomId) {
    if (roomId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: roomId));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已复制房间号 $roomId'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _phasePillText(GamePhase phase, int round) {
    switch (phase) {
      case GamePhase.preparing:
        return '准备中';
      case GamePhase.description:
        return '描述 · R$round';
      case GamePhase.voting:
        return '投票 · R$round';
      case GamePhase.nightAction:
        return '夜晚 · R$round';
      case GamePhase.blankGuess:
        return '白板猜词';
      case GamePhase.settlement:
        return '结算';
    }
  }

  (Color, Color) _phasePillColors(ThemeData theme, GamePhase phase) {
    final isDark = theme.brightness == Brightness.dark;
    switch (phase) {
      case GamePhase.preparing:
        return (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        );
      case GamePhase.description:
        return (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        );
      case GamePhase.voting:
        return (
          Colors.orange.withValues(alpha: 0.18),
          isDark ? Colors.orange.shade300 : Colors.orange.shade800,
        );
      case GamePhase.nightAction:
        return (
          Colors.deepPurple.withValues(alpha: 0.22),
          isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
        );
      case GamePhase.blankGuess:
        return (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        );
      case GamePhase.settlement:
        return (
          Colors.green.withValues(alpha: 0.18),
          isDark ? Colors.green.shade300 : Colors.green.shade700,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);

    ref.listen<RoomState>(gameControllerProvider, (prev, next) {
      final prevNoticeSeq = prev?.phaseNoticeSeq ?? 0;
      if (next.phaseNoticeSeq > prevNoticeSeq &&
          next.phaseNoticeTitle != null &&
          next.currentPhase != GamePhase.settlement &&
          next.phaseNoticeSeq != _lastShownNoticeSeq) {
        _lastShownNoticeSeq = next.phaseNoticeSeq;
        showDialog(
          context: context,
          builder: (_) => PhaseNoticeDialog(
            title: next.phaseNoticeTitle!,
            message: next.phaseNoticeBody ?? '',
            phase: next.currentPhase,
          ),
        );
      }

      if (next.currentPhase == GamePhase.settlement &&
          next.settlementDetails != null &&
          !_settlementShown) {
        _settlementShown = true;
        showDialog(
          context: context,
          builder: (_) => SettlementDialog(
            details: next.settlementDetails!,
            onDismiss: () {},
          ),
        );
      } else if (next.currentPhase != GamePhase.settlement) {
        _settlementShown = false;
      }

      if (next.chatMessages.length != prev?.chatMessages.length ||
          next.currentPhase != prev?.currentPhase ||
          next.currentRound != prev?.currentRound) {
        _scrollToBottom();
      }
    });

    final (pillBg, pillFg) = _phasePillColors(theme, roomState.currentPhase);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 44,
        titleSpacing: 4,
        leading: IconButton(
          tooltip: '离开房间',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _confirmLeave(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _phasePillText(roomState.currentPhase, roomState.currentRound),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pillFg,
                ),
              ),
            ),
            if (roomState.roomId.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: InkWell(
                  onTap: () => _copyRoomId(roomState.roomId),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      '#${roomState.roomId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Tooltip(
            message: '玩家列表',
            child: InkWell(
              onTap: () => _openPlayerRoster(roomState),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 19,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${roomState.players.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 34),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => IdentityCardDialog(
                    identity: roomState.myIdentity,
                  ),
                );
              },
              icon: const Icon(Icons.badge_outlined, size: 16),
              label: const Text(
                '身份',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: roomState.isHost ? 84 : 12,
                  ),
                  itemCount: roomState.chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = roomState.chatMessages[index];
                    return _ChatMessageItem(
                      message: msg,
                      players: roomState.players,
                      selfPlayer: roomState.selfPlayer,
                      playerMarks: roomState.playerMarks,
                      onTapPlayerAvatar: (target) {
                        _openPlayerMarkDialog(
                          target,
                          roomState.playerMarks[target.id],
                        );
                      },
                    );
                  },
                ),
                if (roomState.isHost)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      heroTag: 'room_host_fab',
                      tooltip: '房主控制',
                      onPressed: _openHostConsole,
                      child: const Icon(Icons.tune),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: _BottomActionBar(
              roomState: roomState,
              chatInputController: _chatInputController,
              onSendChat: _sendMessage,
              onOpenVote: () {
                final alivePlayers =
                    roomState.players.where((p) => p.isAlive).toList();
                showDialog(
                  context: context,
                  builder: (_) => VoteDialog(
                    alivePlayers: alivePlayers,
                    selfId: roomState.selfPlayer.id,
                    onVote: (targetId) {
                      ref
                          .read(gameControllerProvider.notifier)
                          .submitVote(targetId);
                    },
                  ),
                );
              },
              onOpenNightAction: () {
                final alivePlayers =
                    roomState.players.where((p) => p.isAlive).toList();
                showDialog(
                  context: context,
                  builder: (_) => NightActionDialog(
                    alivePlayers: alivePlayers,
                    selfId: roomState.selfPlayer.id,
                    onAction: (targetId) {
                      ref
                          .read(gameControllerProvider.notifier)
                          .submitNightAction(targetId);
                    },
                  ),
                );
              },
              onOpenBlankGuess: () {
                showDialog(
                  context: context,
                  builder: (_) => BlankGuessDialog(
                    hint: roomState.myIdentity?.hint,
                    onGuess: (wA, wB) {
                      ref
                          .read(gameControllerProvider.notifier)
                          .submitBlankGuess(wA, wB);
                    },
                  ),
                );
              },
              onOpenSettlement: () {
                if (roomState.settlementDetails == null) return;
                showDialog(
                  context: context,
                  builder: (_) => SettlementDialog(
                    details: roomState.settlementDetails!,
                    onDismiss: () {},
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final RoomState roomState;
  final TextEditingController chatInputController;
  final VoidCallback onSendChat;
  final VoidCallback onOpenVote;
  final VoidCallback onOpenNightAction;
  final VoidCallback onOpenBlankGuess;
  final VoidCallback onOpenSettlement;

  const _BottomActionBar({
    required this.roomState,
    required this.chatInputController,
    required this.onSendChat,
    required this.onOpenVote,
    required this.onOpenNightAction,
    required this.onOpenBlankGuess,
    required this.onOpenSettlement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: _buildContent(context, theme),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    if (roomState.canSendChat) {
      final hint = roomState.currentPhase == GamePhase.description
          ? '描述你的词语...'
          : '输入发言...';
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: chatInputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSendChat(),
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '发送',
            onPressed: onSendChat,
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      );
    }

    switch (roomState.currentPhase) {
      case GamePhase.voting:
        if (roomState.canVote) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onOpenVote,
              icon: const Icon(Icons.how_to_vote_outlined),
              label: const Text('投票'),
            ),
          );
        }
        if (roomState.hasVotedThisRound) {
          return _MutedStatusPill(
            icon: Icons.check_circle_outline,
            label: '已投票',
          );
        }
        return _MutedStatusPill(
          icon: Icons.block,
          label: roomState.isSpectator ? '观战中' : '已出局',
        );

      case GamePhase.nightAction:
        if (roomState.canNightAct) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: onOpenNightAction,
              icon: const Icon(Icons.nights_stay_outlined),
              label: const Text('夜间行动'),
            ),
          );
        }
        if (roomState.hasNightActedThisRound) {
          return const _MutedStatusPill(
            icon: Icons.check_circle_outline,
            label: '已行动',
          );
        }
        return _MutedStatusPill(
          icon: Icons.block,
          label: roomState.isSpectator ? '观战中' : '已出局',
        );

      case GamePhase.blankGuess:
        if (roomState.canBlankGuess) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.tertiary,
                foregroundColor: theme.colorScheme.onTertiary,
              ),
              onPressed: onOpenBlankGuess,
              icon: const Icon(Icons.bolt_outlined),
              label: const Text('白板猜词'),
            ),
          );
        }
        return const _MutedStatusPill(
          icon: Icons.hourglass_empty,
          label: '等待白板猜词',
        );

      case GamePhase.settlement:
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: roomState.settlementDetails != null ? onOpenSettlement : null,
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('查看结算'),
          ),
        );

      case GamePhase.description:
        if (roomState.currentRound >= 2) {
          return _MutedStatusPill(
            icon: Icons.forum_outlined,
            label: '第 ${roomState.currentRound} 轮讨论中',
          );
        }
        return _MutedStatusPill(
          icon: Icons.block,
          label: roomState.isSpectator ? '观战中' : '已出局',
        );

      case GamePhase.preparing:
        return _MutedStatusPill(
          icon: Icons.visibility_outlined,
          label: roomState.isSpectator ? '观战中' : '等待开始',
        );
    }
  }
}

class _MutedStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MutedStatusPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageItem extends StatelessWidget {
  final GameMessage message;
  final List<Player> players;
  final Player selfPlayer;
  final Map<String, String> playerMarks;
  final ValueChanged<Player> onTapPlayerAvatar;

  const _ChatMessageItem({
    required this.message,
    required this.players,
    required this.selfPlayer,
    required this.playerMarks,
    required this.onTapPlayerAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = message.payload;
    final isSystem = payload['is_system'] == true;
    final senderId = payload['sender_id']?.toString() ?? '';
    final text = payload['text']?.toString() ?? '';

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    final isMe = senderId == selfPlayer.id;
    Player? sender;
    for (final p in players) {
      if (p.id == senderId) {
        sender = p;
        break;
      }
    }

    final senderName = sender?.name ?? payload['sender_name']?.toString() ?? senderId;
    final senderAvatar = sender?.avatar ?? (isMe ? selfPlayer.avatar : '');
    final isOut = sender != null ? !sender.isAlive : (isMe && !selfPlayer.isAlive);
    final mark = isMe ? null : playerMarks[senderId];

    if (isMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AvatarWidget(
              avatar: senderAvatar,
              size: 38,
              isOut: isOut,
            ),
          ],
        ),
      );
    }

    final targetPlayer = sender ??
        Player(
          id: senderId,
          name: senderName,
          avatar: senderAvatar,
          isAlive: !isOut,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => onTapPlayerAvatar(targetPlayer),
              borderRadius: BorderRadius.circular(20),
              child: AvatarWidget(
                avatar: senderAvatar,
                size: 38,
                isOut: isOut,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOut
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    if (mark != null && mark.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _GuessMarkChip(role: mark),
                    ],
                    if (isOut) ...[
                      const SizedBox(width: 6),
                      const _OutHeaderPill(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isOut
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuessMarkChip extends StatelessWidget {
  final String role;

  const _GuessMarkChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (role) {
      GameRoles.good => (
          Colors.blue.withValues(alpha: 0.16),
          isDark ? Colors.blue.shade300 : Colors.blue.shade700,
        ),
      GameRoles.spy => (
          Colors.red.withValues(alpha: 0.16),
          isDark ? Colors.red.shade300 : Colors.red.shade700,
        ),
      GameRoles.angel => (
          Colors.amber.withValues(alpha: 0.2),
          isDark ? Colors.amber.shade300 : Colors.amber.shade800,
        ),
      GameRoles.blank => (
          Colors.purple.withValues(alpha: 0.16),
          isDark ? Colors.purple.shade300 : Colors.purple.shade700,
        ),
      _ => (
          Colors.grey.withValues(alpha: 0.16),
          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        GameRoles.getRoleLabel(role),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.1,
        ),
      ),
    );
  }
}

class _OutHeaderPill extends StatelessWidget {
  const _OutHeaderPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'OUT',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.1,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
