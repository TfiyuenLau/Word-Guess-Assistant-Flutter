import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../widgets/avatar_widget.dart';

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
    final candidates =
        widget.alivePlayers.where((p) => p.id != widget.selfId).toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.nights_stay_outlined,
            size: 20,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          const Text('夜晚行动'),
          const Spacer(),
          Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            message: '仅卧底可成功出刀，非卧底行动会自爆',
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
                        ? theme.colorScheme.errorContainer
                            .withValues(alpha: 0.4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.error
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
                            ? theme.colorScheme.error
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
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _selectedTargetId == null
              ? null
              : () {
                  final target = _selectedTargetId!;
                  Navigator.of(context).pop();
                  widget.onAction(target);
                },
          child: const Text('确认'),
        ),
      ],
    );
  }
}
