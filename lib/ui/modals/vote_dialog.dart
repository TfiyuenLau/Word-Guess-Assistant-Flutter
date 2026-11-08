import 'package:flutter/material.dart';
import '../../models/game_models.dart';

class VoteDialog extends StatefulWidget {
  final List<Player> alivePlayers;
  final String selfId;
  final ValueChanged<String> onVote;

  const VoteDialog({
    super.key,
    required this.alivePlayers,
    required this.selfId,
    required this.onVote,
  });

  @override
  State<VoteDialog> createState() => _VoteDialogState();
}

class _VoteDialogState extends State<VoteDialog> {
  String? _selectedTargetId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = widget.alivePlayers;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.how_to_vote, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('白天秘密公投表决'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请指认您怀疑的潜伏特工。表决将匿名记录，集齐存活票数后统一公布结果。提交后不可更改！',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final player = candidates[index];
                  final isSelf = player.id == widget.selfId;
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
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Text(
                            player.name.isNotEmpty ? player.name[0] : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            player.name + (isSelf ? ' (自己)' : '') + (player.isBot ? ' [机器人]' : ''),
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedTargetId == null
              ? null
              : () {
                  final target = _selectedTargetId!;
                  Navigator.of(context).pop();
                  widget.onVote(target);
                },
          child: const Text('确认投出'),
        ),
      ],
    );
  }
}
