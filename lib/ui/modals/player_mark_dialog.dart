import 'package:flutter/material.dart';
import '../../models/game_models.dart';

class PlayerMarkDialog extends StatelessWidget {
  final Player player;
  final String? currentMark;
  final ValueChanged<String> onMarkSelected;

  const PlayerMarkDialog({
    super.key,
    required this.player,
    this.currentMark,
    required this.onMarkSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final marks = [
      {'role': GameRoles.good, 'label': '好人特工', 'icon': Icons.shield, 'color': Colors.blue},
      {'role': GameRoles.spy, 'label': '潜伏卧底', 'icon': Icons.visibility_off, 'color': Colors.red},
      {'role': GameRoles.angel, 'label': '双面天使', 'icon': Icons.auto_awesome, 'color': Colors.amber},
      {'role': GameRoles.blank, 'label': '暗号白板', 'icon': Icons.help_outline, 'color': Colors.purple},
    ];

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text(player.name.isNotEmpty ? player.name[0] : '?'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '推测标记：${player.name}',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '仅您自己可见，用于记录盘道推导逻辑：',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...marks.map((m) {
            final role = m['role'] as String;
            final isCurrent = currentMark == role;

            return ListTile(
              leading: Icon(m['icon'] as IconData, color: m['color'] as Color),
              title: Text(m['label'] as String),
              trailing: isCurrent ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () {
                Navigator.of(context).pop();
                onMarkSelected(role);
              },
            );
          }),
          if (currentMark != null)
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.grey),
              title: const Text('清除推测标记'),
              onTap: () {
                Navigator.of(context).pop();
                onMarkSelected('');
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
