import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/game_controller.dart';
import '../../models/game_models.dart';
import '../../models/protocol_messages.dart';
import '../modals/blank_guess_dialog.dart';
import '../modals/host_console_dialog.dart';
import '../modals/identity_card_dialog.dart';
import '../modals/night_action_dialog.dart';
import '../modals/player_mark_dialog.dart';
import '../modals/settlement_dialog.dart';
import '../modals/theme_picker_dialog.dart';
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);

    // 监听结算弹窗自动弹出
    ref.listen(gameControllerProvider, (prev, next) {
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
      _scrollToBottom();
    });

    final isAlive = roomState.selfPlayer.isAlive;
    final isVoting = roomState.currentPhase == GamePhase.voting;
    final isNight = roomState.currentPhase == GamePhase.nightAction;
    final isBlankGuess = roomState.currentPhase == GamePhase.blankGuess;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('房间 ${roomState.roomId}'),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                roomState.networkMode.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              padding: EdgeInsets.zero,
            ),
            if (roomState.isHost) ...[
              const SizedBox(width: 6),
              const Chip(
                avatar: Icon(Icons.star, size: 14, color: Colors.amber),
                label: Text('房主', style: TextStyle(fontSize: 10)),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: '终端主题风格',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ThemePickerDialog(),
              );
            },
          ),
          IconButton(
            tooltip: '撤出房间',
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认撤出？'),
                  content: const Text('离开后将断开与房间各特工的加密连接。'),
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
                      child: const Text('确认离开'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 阶段状态横幅
          _PhaseBanner(
            phase: roomState.currentPhase,
            round: roomState.currentRound,
            info: roomState.phaseExtraInfo,
          ),

          // 核心对局区域：特工网格 + 聊天公屏
          Expanded(
            child: Column(
              children: [
                // 特工阵列（可滚动横向或网格）
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: roomState.players.length,
                    itemBuilder: (context, index) {
                      final p = roomState.players[index];
                      final mark = roomState.playerMarks[p.id];
                      final isMe = p.id == roomState.selfPlayer.id;

                      return _PlayerCard(
                        player: p,
                        isMe: isMe,
                        mark: mark,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => PlayerMarkDialog(
                              player: p,
                              currentMark: mark,
                              onMarkSelected: (roleMark) {
                                ref
                                    .read(gameControllerProvider.notifier)
                                    .markPlayer(p.id, roleMark);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                // 消息公屏
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: roomState.chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = roomState.chatMessages[index];
                      return _ChatMessageItem(
                        message: msg,
                        players: roomState.players,
                        selfPlayerId: roomState.selfPlayer.id,
                      );
                    },
                  ),
                ),

                // 底部输入框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatInputController,
                          decoration: const InputDecoration(
                            hintText: '发送特工发言或线索...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              ref
                                  .read(gameControllerProvider.notifier)
                                  .sendChatMessage(val);
                              _chatInputController.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          final text = _chatInputController.text;
                          if (text.trim().isNotEmpty) {
                            ref
                                .read(gameControllerProvider.notifier)
                                .sendChatMessage(text);
                            _chatInputController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 底部行动动作栏
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => IdentityCardDialog(
                            identity: roomState.myIdentity,
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock_person),
                      label: const Text('我的身份'),
                    ),
                    const SizedBox(width: 8),

                    if (isVoting) ...[
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                        ),
                        onPressed: isAlive
                            ? () {
                                final alivePlayers = roomState.players
                                    .where((p) => p.isAlive)
                                    .toList();
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
                              }
                            : null,
                        icon: const Icon(Icons.how_to_vote),
                        label: const Text('公投表决'),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (isNight) ...[
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.onErrorContainer,
                        ),
                        onPressed: isAlive
                            ? () {
                                final alivePlayers = roomState.players
                                    .where((p) => p.isAlive)
                                    .toList();
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
                              }
                            : null,
                        icon: const Icon(Icons.nights_stay),
                        label: const Text('黑夜行动'),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (isBlankGuess) ...[
                      if (roomState.myIdentity?.role == GameRoles.blank)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.tertiaryContainer,
                            foregroundColor: theme.colorScheme.onTertiaryContainer,
                          ),
                          onPressed: () {
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
                          icon: const Icon(Icons.bolt),
                          label: const Text('白板逆袭'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.hourglass_top),
                          label: const Text('等待白板逆袭猜词...'),
                        ),
                      const SizedBox(width: 8),
                    ],

                    if (roomState.settlementDetails != null) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => SettlementDialog(
                              details: roomState.settlementDetails!,
                              onDismiss: () {},
                            ),
                          );
                        },
                        icon: const Icon(Icons.emoji_events),
                        label: const Text('查看战报'),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (roomState.isHost) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => HostConsoleDialog(
                              playerCount: roomState.players.length,
                              currentPhase: roomState.currentPhase,
                              onStartGame: (th, sim) {
                                ref
                                    .read(gameControllerProvider.notifier)
                                    .startGame(theme: th, similarity: sim);
                              },
                              onAdvancePhase: () {
                                ref
                                    .read(gameControllerProvider.notifier)
                                    .advancePhase();
                              },
                              onResetGame: () {
                                ref
                                    .read(gameControllerProvider.notifier)
                                    .resetGame();
                              },
                              onAddBots: (count) {
                                ref
                                    .read(gameControllerProvider.notifier)
                                    .addMockBots(count);
                              },
                              onClearBots: () {
                                ref
                                    .read(gameControllerProvider.notifier)
                                    .clearMockBots();
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('房主控制台'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  final GamePhase phase;
  final int round;
  final String info;

  const _PhaseBanner({
    required this.phase,
    required this.round,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bg;
    Color fg;

    switch (phase) {
      case GamePhase.description:
        bg = theme.colorScheme.primaryContainer;
        fg = theme.colorScheme.onPrimaryContainer;
        break;
      case GamePhase.voting:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case GamePhase.nightAction:
        bg = Colors.deepPurple.shade900;
        fg = Colors.white;
        break;
      case GamePhase.blankGuess:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case GamePhase.settlement:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      default:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bg,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${phase.label} · 第 $round 轮',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Player player;
  final bool isMe;
  final String? mark;
  final VoidCallback onTap;

  const _PlayerCard({
    required this.player,
    required this.isMe,
    this.mark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlive = player.isAlive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isMe
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe
                ? theme.colorScheme.primary
                : isAlive
                    ? theme.colorScheme.outlineVariant
                    : Colors.red.shade400,
            width: isMe ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: isAlive ? 1.0 : 0.4,
                  child: AvatarWidget(
                    avatar: player.avatar,
                    size: 34,
                    showBorder: isMe,
                    borderColor: theme.colorScheme.primary,
                  ),
                ),
                if (!isAlive)
                  const Positioned(
                    bottom: -2,
                    right: -2,
                    child: Icon(Icons.cancel, color: Colors.red, size: 14),
                  ),
                if (player.isBot)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smart_toy, color: Colors.white, size: 9),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              player.name + (isMe ? ' (我)' : ''),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                color: isAlive ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                decoration: isAlive ? null : TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (mark != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  GameRoles.getRoleLabel(mark),
                  style: TextStyle(fontSize: 8, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageItem extends StatelessWidget {
  final GameMessage message;
  final List<Player> players;
  final String selfPlayerId;

  const _ChatMessageItem({
    required this.message,
    required this.players,
    required this.selfPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = message.payload;
    final isSystem = payload['is_system'] == true;
    final senderId = payload['sender_id']?.toString() ?? '';
    final text = payload['text']?.toString() ?? '';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.campaign,
              color: theme.colorScheme.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isMe = senderId == selfPlayerId;
    Player? sender;
    for (final p in players) {
      if (p.id == senderId) {
        sender = p;
        break;
      }
    }
    final senderName = sender?.name ?? senderId;
    final senderAvatar = sender?.avatar ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            AvatarWidget(avatar: senderAvatar, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isMe ? 12 : 2),
                      bottomRight: Radius.circular(isMe ? 2 : 12),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            AvatarWidget(avatar: senderAvatar, size: 28),
          ],
        ],
      ),
    );
  }
}
