import 'package:flutter/material.dart';
import '../../models/game_models.dart';

class PhaseNoticeDialog extends StatelessWidget {
  final String title;
  final String message;
  final GamePhase phase;

  const PhaseNoticeDialog({
    super.key,
    required this.title,
    required this.message,
    required this.phase,
  });

  IconData _phaseIcon() {
    switch (phase) {
      case GamePhase.preparing:
        return Icons.hourglass_empty;
      case GamePhase.description:
        return Icons.chat_bubble_outline;
      case GamePhase.voting:
        return Icons.how_to_vote_outlined;
      case GamePhase.nightAction:
        return Icons.nights_stay_outlined;
      case GamePhase.blankGuess:
        return Icons.bolt;
      case GamePhase.settlement:
        return Icons.emoji_events_outlined;
    }
  }

  Color _phaseColor(ThemeData theme) {
    switch (phase) {
      case GamePhase.voting:
        return Colors.orange.shade700;
      case GamePhase.nightAction:
        return theme.colorScheme.error;
      case GamePhase.blankGuess:
        return theme.colorScheme.tertiary;
      case GamePhase.settlement:
        return Colors.green.shade600;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _phaseColor(theme);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_phaseIcon(), size: 22, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
