import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../widgets/avatar_widget.dart';

class SettlementDialog extends StatelessWidget {
  final SettlementDetails details;
  final VoidCallback onDismiss;

  const SettlementDialog({
    super.key,
    required this.details,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final winnerCamp = details.winnerCamp;

    Color bannerColor;
    String winnerTitle;
    IconData winnerIcon;

    switch (winnerCamp) {
      case GameRoles.good:
        bannerColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
        winnerTitle = '好人获胜';
        winnerIcon = Icons.shield_outlined;
        break;
      case GameRoles.spy:
        bannerColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
        winnerTitle = '卧底获胜';
        winnerIcon = Icons.visibility_off_outlined;
        break;
      case GameRoles.blank:
        bannerColor = isDark ? Colors.purple.shade300 : Colors.purple.shade700;
        winnerTitle = '白板获胜';
        winnerIcon = Icons.bolt;
        break;
      default:
        bannerColor = isDark ? Colors.amber.shade300 : Colors.amber.shade700;
        winnerTitle = '对局结束';
        winnerIcon = Icons.emoji_events_outlined;
    }

    final goodColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    final spyColor = isDark ? Colors.red.shade300 : Colors.red.shade700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: bannerColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: bannerColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(winnerIcon, color: bannerColor, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      winnerTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: bannerColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _WordCard(
                            label: '好人词',
                            word: details.goodWord,
                            color: goodColor,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        Expanded(
                          child: _WordCard(
                            label: '卧底词',
                            word: details.spyWord,
                            color: spyColor,
                          ),
                        ),
                      ],
                    ),
                    if (details.hint.isNotEmpty) ...[
                      const Divider(height: 16),
                      Text(
                        '提示：${details.hint}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: details.playerReveals.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final reveal = details.playerReveals[index];
                    final statusColor = reveal.isAlive
                        ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                        : (isDark ? Colors.red.shade300 : Colors.red.shade700);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Opacity(
                            opacity: reveal.isAlive ? 1.0 : 0.45,
                            child: AvatarWidget(
                              avatar: reveal.avatar,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        reveal.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          decoration: reveal.isAlive
                                              ? null
                                              : TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _RoleChip(role: reveal.role),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  reveal.word.isNotEmpty ? reveal.word : '无词',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              reveal.isAlive ? '存活' : 'OUT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss();
                },
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final String label;
  final String word;
  final Color color;

  const _WordCard({
    required this.label,
    required this.word,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          word,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    String label;

    switch (role) {
      case GameRoles.good:
        color = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
        label = '好人';
        break;
      case GameRoles.spy:
        color = isDark ? Colors.red.shade300 : Colors.red.shade700;
        label = '卧底';
        break;
      case GameRoles.angel:
        color = isDark ? Colors.amber.shade300 : Colors.amber.shade700;
        label = '天使';
        break;
      case GameRoles.blank:
        color = isDark ? Colors.purple.shade300 : Colors.purple.shade700;
        label = '白板';
        break;
      default:
        color = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
        label = GameRoles.getRoleLabel(role);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
