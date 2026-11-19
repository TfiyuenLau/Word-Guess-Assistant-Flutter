import 'dart:math';
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
  final ValueChanged<int>? onFillBotsTo;

  const HostConsoleDialog({
    super.key,
    required this.playerCount,
    required this.currentPhase,
    required this.onStartGame,
    required this.onAdvancePhase,
    required this.onResetGame,
    required this.onAddBots,
    required this.onClearBots,
    this.onFillBotsTo,
  });

  @override
  State<HostConsoleDialog> createState() => _HostConsoleDialogState();
}

class _HostConsoleDialogState extends State<HostConsoleDialog> {
  String _selectedTheme = '全部主题';
  String _selectedSimilarity = '极为接近';
  late int _displayCount;

  @override
  void initState() {
    super.initState();
    _displayCount = widget.playerCount;
  }

  @override
  void didUpdateWidget(covariant HostConsoleDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerCount != widget.playerCount) {
      _displayCount = widget.playerCount;
    }
  }

  void _addBots(int count) {
    widget.onAddBots(count);
    setState(() {
      _displayCount = min(12, _displayCount + count);
    });
  }

  void _fillToEight() {
    if (widget.onFillBotsTo != null) {
      widget.onFillBotsTo!(8);
    } else {
      final needed = 8 - _displayCount;
      if (needed > 0) {
        widget.onAddBots(needed);
      }
    }
    setState(() {
      _displayCount = max(_displayCount, 8);
    });
  }

  void _clearBots() {
    widget.onClearBots();
    setState(() {
      _displayCount = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPreparing = widget.currentPhase == GamePhase.preparing;
    final canStart = isPreparing && _displayCount >= 4 && _displayCount <= 12;
    final countColor = _displayCount >= 4
        ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
        : (isDark ? Colors.orange.shade300 : Colors.orange.shade700);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('房主控制'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: countColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$_displayCount / 12',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: countColor,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPreparing) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedTheme,
                decoration: const InputDecoration(
                  labelText: '主题',
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
                  labelText: '相似度',
                  isDense: true,
                ),
                items: WordBank.similarities.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSimilarity = val);
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: _displayCount < 12 ? () => _addBots(1) : null,
                      child: const Text('+1'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: _displayCount < 12 ? () => _addBots(3) : null,
                      child: const Text('+3'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: _displayCount < 8 ? _fillToEight : null,
                      child: const Text('补至8人'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    tooltip: '清空机器人',
                    onPressed: _clearBots,
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: canStart
                    ? () {
                        Navigator.of(context).pop();
                        widget.onStartGame(
                          _selectedTheme,
                          _selectedSimilarity,
                        );
                      }
                    : null,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text(
                  _displayCount < 4
                      ? '至少需要 4 人'
                      : _displayCount > 12
                          ? '人数上限 12 人'
                          : '开始游戏',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.currentPhase.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAdvancePhase();
                },
                icon: const Icon(Icons.skip_next, size: 20),
                label: const Text('下一阶段'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onResetGame();
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('重新开始'),
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
