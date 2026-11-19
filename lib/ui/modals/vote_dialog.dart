import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../widgets/avatar_widget.dart';

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
          Icon(
            Icons.how_to_vote_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('投票'),
          const Spacer(),
          Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            message: '匿名投票，提交后不可更改',
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: candidates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final player = candidates[index];
              final isSelf = player.id == widget.selfId;
              final isSelected = _selectedTargetId == player.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTargetId = player.id;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      AvatarWidget(avatar: player.avatar, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isSelf)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '我',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
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
          child: const Text('确认'),
        ),
      ],
    );
  }
}
