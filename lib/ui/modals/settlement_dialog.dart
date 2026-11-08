import 'package:flutter/material.dart';
import '../../models/game_models.dart';

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
    final winnerCamp = details.winnerCamp;

    Color bannerColor;
    String winnerTitle;
    IconData winnerIcon;

    switch (winnerCamp) {
      case GameRoles.good:
        bannerColor = Colors.blue;
        winnerTitle = '好人阵营 获胜！';
        winnerIcon = Icons.shield;
        break;
      case GameRoles.spy:
        bannerColor = Colors.red;
        winnerTitle = '潜伏卧底 获胜！';
        winnerIcon = Icons.visibility_off;
        break;
      case GameRoles.blank:
        bannerColor = Colors.purple;
        winnerTitle = '暗号白板 绝杀逆袭获胜！';
        winnerIcon = Icons.bolt;
        break;
      default:
        bannerColor = Colors.amber;
        winnerTitle = '对局结算结束';
        winnerIcon = Icons.emoji_events;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: bannerColor, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(winnerIcon, color: bannerColor, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    winnerTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: bannerColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _WordCard(
                        label: '好人平民词',
                        word: details.goodWord,
                        color: Colors.blue,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade400),
                      _WordCard(
                        label: '潜伏卧底词',
                        word: details.spyWord,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  if (details.hint.isNotEmpty) ...[
                    const Divider(height: 20),
                    Text(
                      '白板方向提示：${details.hint}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '特工真实身份与底牌揭晓',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: details.playerReveals.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final reveal = details.playerReveals[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: reveal.isAlive
                          ? theme.colorScheme.primaryContainer
                          : Colors.grey.shade400,
                      child: Text(
                        reveal.name.isNotEmpty ? reveal.name[0] : '?',
                        style: TextStyle(
                          color: reveal.isAlive
                              ? theme.colorScheme.onPrimaryContainer
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          reveal.name,
                          style: TextStyle(
                            decoration: reveal.isAlive ? null : TextDecoration.lineThrough,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoleChip(role: reveal.role),
                      ],
                    ),
                    subtitle: Text(
                      '词语：${reveal.word.isNotEmpty ? reveal.word : '无词'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Chip(
                      label: Text(
                        reveal.isAlive ? '存活' : '出局',
                        style: TextStyle(
                          fontSize: 11,
                          color: reveal.isAlive ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                      backgroundColor: reveal.isAlive
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      padding: EdgeInsets.zero,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss();
              },
              child: const Text('查看完毕'),
            ),
          ],
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
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          word,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
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
    Color bg;
    Color fg;
    String label = GameRoles.getRoleLabel(role);

    switch (role) {
      case GameRoles.good:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case GameRoles.spy:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case GameRoles.angel:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case GameRoles.blank:
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}
