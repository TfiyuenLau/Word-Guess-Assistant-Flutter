import 'package:flutter/material.dart';
import '../../models/game_models.dart';

class NightActionDialog extends StatefulWidget {
  final List<Player> alivePlayers;
  final String selfId;
  final ValueChanged<String> onAction;

  const NightActionDialog({
    super.key,
    required this.alivePlayers,
    required this.selfId,
    required this.onAction,
  });

  @override
  State<NightActionDialog> createState() => _NightActionDialogState();
}

class _NightActionDialogState extends State<NightActionDialog> {
  String? _selectedTargetId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 排除自己
    final candidates = widget.alivePlayers.where((p) => p.id != widget.selfId).toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.nights_stay, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          const Text('黑夜盲动暗杀'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: theme.colorScheme.onErrorContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '高危提示：唯有潜伏卧底可成功刺杀！非卧底身份（好人/天使/白板）盲动将触发自爆当场殉职！',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '请选择您要实施行动的特工目标：',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final player = candidates[index];
                  final isSelected = _selectedTargetId == player.id;

                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedTargetId = player.id;
                      });
                    },
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? theme.colorScheme.error : null,
                    ),
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.errorContainer,
                          child: Text(
                            player.name.isNotEmpty ? player.name[0] : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            player.name + (player.isBot ? ' [机器人]' : ''),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('放弃行动 (静默度过)'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: _selectedTargetId == null
              ? null
              : () {
                  final target = _selectedTargetId!;
                  Navigator.of(context).pop();
                  widget.onAction(target);
                },
          child: const Text('执行暗杀'),
        ),
      ],
    );
  }
}
