import 'package:flutter/material.dart';

class RuleDialog extends StatelessWidget {
  const RuleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('规则'),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RuleSection(
              title: '角色与人数 (4~12人)',
              content:
                  '• 好人：持有好人词，需找出卧底并防止白板逃脱。\n'
                  '• 卧底：持有卧底词，夜间可出刀淘汰一名玩家。\n'
                  '• 天使：同时看到双词（顺序随机），暗中引导好人。\n'
                  '• 白板：无词，仅获方向提示，靠伪装发言存活。',
            ),
            SizedBox(height: 12),
            _RuleSection(
              title: '流程',
              content:
                  '首轮描述 → 白天投票（单人最高票出局，平票无人出局）→ 夜晚（卧底可出刀，非卧底行动会自爆；天亮统一播报结果）。第 2 轮起仅展示首轮线索并继续投票。',
            ),
            SizedBox(height: 12),
            _RuleSection(
              title: '白板逆袭',
              content: '白板在白天被投票出局时，可猜好人词与卧底词（不限顺序），同时猜中立即独赢。',
            ),
            SizedBox(height: 12),
            _RuleSection(
              title: '胜负条件',
              content:
                  '• 好人胜：所有卧底出局且白板已出局。\n'
                  '• 卧底胜：存活卧底数 ≥ 存活好人数，或存活 ≤ 2 人且仍有卧底。\n'
                  '• 白板胜：被投出时猜中双词，或存活到最后。',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}

class _RuleSection extends StatelessWidget {
  final String title;
  final String content;

  const _RuleSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.45,
            fontSize: 13,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
