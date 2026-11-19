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
          Icon(Icons.bolt, size: 20, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          const Text('白板猜词'),
          const Spacer(),
          Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            message: '同时猜中两个词即获胜，不限顺序',
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.hint != null && widget.hint!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer
                      .withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '提示：${widget.hint}',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _wordAController,
              decoration: const InputDecoration(
                labelText: '词一',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wordBController,
              decoration: const InputDecoration(
                labelText: '词二',
                isDense: true,
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
          child: const Text('放弃'),
        ),
        FilledButton(
          onPressed: () {
            final w1 = _wordAController.text.trim();
            final w2 = _wordBController.text.trim();
            if (w1.isEmpty || w2.isEmpty) return;
            Navigator.of(context).pop();
            widget.onGuess(w1, w2);
          },
          child: const Text('提交'),
        ),
      ],
    );
  }
}
