import 'package:flutter/material.dart';

class BlankGuessDialog extends StatefulWidget {
  final String? hint;
  final void Function(String wordA, String wordB) onGuess;

  const BlankGuessDialog({
    super.key,
    this.hint,
    required this.onGuess,
  });

  @override
  State<BlankGuessDialog> createState() => _BlankGuessDialogState();
}

class _BlankGuessDialogState extends State<BlankGuessDialog> {
  final _wordAController = TextEditingController();
  final _wordBController = TextEditingController();

  @override
  void dispose() {
    _wordAController.dispose();
    _wordBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bolt, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          const Text('白板终局双词逆袭'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '特权逆袭：若能同时准确猜出【好人词】与【卧底词】（顺序不限），暗号白板立即绝杀逆袭独赢！',
                style: TextStyle(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.hint != null && widget.hint!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '您持有的方向提示：${widget.hint}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _wordAController,
              decoration: const InputDecoration(
                labelText: '推测词语一 (好人词或卧底词)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.help_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wordBController,
              decoration: const InputDecoration(
                labelText: '推测词语二 (卧底词或好人词)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.help_outline),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onGuess('', '');
          },
          child: const Text('放弃猜词 (确认出局)'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.tertiary,
            foregroundColor: theme.colorScheme.onTertiary,
          ),
          onPressed: () {
            final w1 = _wordAController.text.trim();
            final w2 = _wordBController.text.trim();
            if (w1.isEmpty || w2.isEmpty) return;
            Navigator.of(context).pop();
            widget.onGuess(w1, w2);
          },
          child: const Text('发起终局绝杀'),
        ),
      ],
    );
  }
}
