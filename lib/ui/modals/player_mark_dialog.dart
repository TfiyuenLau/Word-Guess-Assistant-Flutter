import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../widgets/avatar_widget.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    final marks = [
      (
        role: GameRoles.good,
        label: '好人',
        icon: Icons.shield_outlined,
        color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
      ),
      (
        role: GameRoles.spy,
        label: '卧底',
        icon: Icons.visibility_off_outlined,
        color: isDark ? Colors.red.shade300 : Colors.red.shade700,
      ),
      (
        role: GameRoles.angel,
        label: '天使',
        icon: Icons.auto_awesome_outlined,
        color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
      ),
      (
        role: GameRoles.blank,
        label: '白板',
        icon: Icons.help_outline,
        color: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
      ),
    ];

    Widget buildTile(({String role, String label, IconData icon, Color color}) m) {
      final isSelected = currentMark == m.role;
      return Expanded(
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            onMarkSelected(m.role);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? m.color.withValues(alpha: 0.18)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? m.color
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(m.icon, size: 18, color: m.color),
                const SizedBox(width: 6),
                Text(
                  m.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? m.color : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          AvatarWidget(avatar: player.avatar, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            message: '仅本地可见',
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              buildTile(marks[0]),
              const SizedBox(width: 10),
              buildTile(marks[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              buildTile(marks[2]),
              const SizedBox(width: 10),
              buildTile(marks[3]),
            ],
          ),
          if (currentMark != null && currentMark!.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onMarkSelected('');
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('清除标记'),
            ),
          ],
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
