import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../widgets/avatar_widget.dart';

class PlayerRosterSheet extends StatelessWidget {
  final List<Player> players;
  final String selfPlayerId;
  final Map<String, String> playerMarks;
  final void Function(Player player) onTapPlayer;

  const PlayerRosterSheet({
    super.key,
    required this.players,
    required this.selfPlayerId,
    required this.playerMarks,
    required this.onTapPlayer,
  });

  (String, Color) _markMeta(String mark, bool isDark) {
    switch (mark) {
      case GameRoles.good:
        return ('好人', isDark ? Colors.blue.shade300 : Colors.blue.shade700);
      case GameRoles.spy:
        return ('卧底', isDark ? Colors.red.shade300 : Colors.red.shade700);
      case GameRoles.angel:
        return ('天使', isDark ? Colors.amber.shade300 : Colors.amber.shade700);
      case GameRoles.blank:
        return ('白板', isDark ? Colors.purple.shade300 : Colors.purple.shade700);
      default:
        return (
          GameRoles.getRoleLabel(mark),
          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '玩家 (${players.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: players.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isSelf = player.id == selfPlayerId;
                  final mark = playerMarks[player.id];
                  final markMeta = (mark != null && mark.isNotEmpty)
                      ? _markMeta(mark, isDark)
                      : null;

                  return InkWell(
                    onTap: isSelf ? null : () => onTapPlayer(player),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Opacity(
                            opacity: player.isAlive ? 1.0 : 0.45,
                            child: AvatarWidget(
                              avatar: player.avatar,
                              size: 38,
                              showBorder: isSelf,
                              borderColor: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    player.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelf
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      decoration: player.isAlive
                                          ? null
                                          : TextDecoration.lineThrough,
                                      color: player.isAlive
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (isSelf) ...[
                                  const SizedBox(width: 6),
                                  _PillTag(
                                    text: '我',
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                                if (player.isBot) ...[
                                  const SizedBox(width: 6),
                                  _PillTag(
                                    text: 'AI',
                                    color: isDark
                                        ? Colors.blueGrey.shade200
                                        : Colors.blueGrey.shade700,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (markMeta != null) ...[
                            const SizedBox(width: 6),
                            _PillTag(
                              text: markMeta.$1,
                              color: markMeta.$2,
                            ),
                          ],
                          if (!player.isAlive) ...[
                            const SizedBox(width: 6),
                            _PillTag(
                              text: 'OUT',
                              color: isDark
                                  ? Colors.red.shade300
                                  : Colors.red.shade700,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  final String text;
  final Color color;

  const _PillTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
