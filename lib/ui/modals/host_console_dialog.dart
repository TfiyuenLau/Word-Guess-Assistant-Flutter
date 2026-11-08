import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../../models/word_bank.dart';

class HostConsoleDialog extends StatefulWidget {
  final int playerCount;
  final GamePhase currentPhase;
  final void Function(String theme, String similarity) onStartGame;
  final VoidCallback onAdvancePhase;
  final VoidCallback onResetGame;
  final ValueChanged<int> onAddBots;
  final VoidCallback onClearBots;

  const HostConsoleDialog({
    super.key,
    required this.playerCount,
    required this.currentPhase,
    required this.onStartGame,
    required this.onAdvancePhase,
    required this.onResetGame,
    required this.onAddBots,
    required this.onClearBots,
  });

  @override
  State<HostConsoleDialog> createState() => _HostConsoleDialogState();
}

class _HostConsoleDialogState extends State<HostConsoleDialog> {
  String _selectedTheme = '全部主题';
  String _selectedSimilarity = '极为接近';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPreparing = widget.currentPhase == GamePhase.preparing;
    final canStart = isPreparing && widget.playerCount >= 4 && widget.playerCount <= 12;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('房主指挥控制台'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('当前房间特工数：'),
                  Chip(
                    label: Text(
                      '${widget.playerCount} / 12 人',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.playerCount >= 4 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isPreparing) ...[
              Text(
                '词库出题参数配置',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedTheme,
                decoration: const InputDecoration(
                  labelText: '主题类别',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: WordBank.categories.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTheme = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedSimilarity,
                decoration: const InputDecoration(
                  labelText: '词义相似度',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: WordBank.similarities.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSimilarity = val);
                },
              ),
              const SizedBox(height: 16),
              Text(
                '特工局虚拟特工（Mock Bot）',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.playerCount < 12
                          ? () => widget.onAddBots(3)
                          : null,
                      icon: const Icon(Icons.smart_toy, size: 18),
                      label: const Text('填充 3 名机器人'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: '清空全部机器人',
                    onPressed: widget.onClearBots,
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: canStart
                    ? () {
                        Navigator.of(context).pop();
                        widget.onStartGame(_selectedTheme, _selectedSimilarity);
                      }
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  widget.playerCount < 4
                      ? '人数不足（至少 4 人）'
                      : widget.playerCount > 12
                          ? '人数超限（至多 12 人）'
                          : '启动博弈与角色发词',
                ),
              ),
            ] else ...[
              Text(
                '博弈正在进行中：${widget.currentPhase.label}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAdvancePhase();
                },
                icon: const Icon(Icons.skip_next),
                label: const Text('推进至下一阶段 (NEXT)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onResetGame();
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('重置房间并重开'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
