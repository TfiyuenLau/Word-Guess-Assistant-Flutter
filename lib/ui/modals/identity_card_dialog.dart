import 'package:flutter/material.dart';
import '../../models/game_models.dart';

class IdentityCardDialog extends StatefulWidget {
  final IdentityAssignment? identity;

  const IdentityCardDialog({super.key, required this.identity});

  @override
  State<IdentityCardDialog> createState() => _IdentityCardDialogState();
}

class _IdentityCardDialogState extends State<IdentityCardDialog> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final idn = widget.identity;
    final theme = Theme.of(context);

    if (idn == null) {
      return AlertDialog(
        title: const Text('身份未分配'),
        content: const Text('当前对局尚未启动，请等待房主开局发词。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      );
    }

    final isAngel = idn.role == GameRoles.angel;
    final isBlank = idn.role == GameRoles.blank;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  '特工机密身份档案',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '对外显示身份',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    avatar: Icon(
                      isAngel
                          ? Icons.auto_awesome
                          : isBlank
                              ? Icons.visibility_off
                              : Icons.lock,
                      size: 18,
                    ),
                    label: Text(
                      GameRoles.getRoleLabel(idn.role),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '绝密词语与线索',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isRevealed = !_isRevealed;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _isRevealed
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isRevealed
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          width: _isRevealed ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (!_isRevealed) ...[
                            Icon(
                              Icons.touch_app,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '点击防偷窥刮开查验',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '请确保四周无其他特工偷窥',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ] else ...[
                            Text(
                              idn.word.isEmpty ? '【无词】' : idn.word,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (idn.hint.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '方向提示: ${idn.hint}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onTertiaryContainer,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isRevealed = false;
                                });
                              },
                              icon: const Icon(Icons.visibility_off, size: 16),
                              label: const Text('隐藏底牌'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('已知悉，返回博弈'),
            ),
          ],
        ),
      ),
    );
  }
}
