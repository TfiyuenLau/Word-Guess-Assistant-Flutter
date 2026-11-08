import 'package:flutter/material.dart';

class RuleDialog extends StatelessWidget {
  const RuleDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.menu_book, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('特工猜词规则密匙'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RuleSection(
              title: '一、身份矩阵（4~12 人动态配比）',
              content:
                  '• 潜伏卧底 (1~4名)：持有卧底词（显示为盲盒特工），黑夜具备刺杀权力。\n'
                  '• 平民好人 (1~6名)：持有好人词（显示为盲盒特工），需辨识队友驱逐卧底。\n'
                  '• 双面天使 (固定1名)：同时感知好词与坏词（顺序随机），不可暴露自身，暗中引导好人。\n'
                  '• 暗号白板 (固定1名)：完全无词，仅获知词义模糊提示，靠语言伪装求生。',
            ),
            const SizedBox(height: 12),
            _RuleSection(
              title: '二、白天秘密公投',
              content:
                  '所有存活特工秘密匿名投票，集齐票数后自动揭晓。单一最高票者公投出局；若出现平票或弃票，本轮无人出局直接入夜。',
            ),
            const SizedBox(height: 12),
            _RuleSection(
              title: '三、白板终局逆袭（专属特权）',
              content:
                  '若暗号白板在白天被公投淘汰，将直接触发特别阶段！只要白板能同时准确猜出【好人词】与【卧底词】（顺序不限），暗号白板直接绝杀逆袭独赢！',
            ),
            const SizedBox(height: 12),
            _RuleSection(
              title: '四、黑夜暗杀与误动自爆',
              content:
                  '夜幕降临，卧底可秘密刺杀一名特工；非卧底（好人、天使或白板）夜间盲动刺杀，将反噬误触机关当场殉职！天亮统一客观播报伤亡，不泄露死因。',
            ),
            const SizedBox(height: 12),
            _RuleSection(
              title: '五、胜负判定法则',
              content:
                  '1. 卧底胜利：存活卧底数 ≥ 好人存活数，或存活人数 ≤ 2 人且卧底在场。\n'
                  '2. 好人胜利：卧底全灭，且暗号白板已被驱逐。\n'
                  '3. 白板胜利：在专属逆袭阶段同时猜对双方词汇。',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('已熟记军规'),
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
            height: 1.4,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
