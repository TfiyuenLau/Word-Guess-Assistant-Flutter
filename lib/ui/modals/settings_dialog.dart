import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/theme_controller.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late final TextEditingController _apiUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;

  bool _obscureApiKey = true;
  bool _hasEdited = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(settingsControllerProvider);
    _apiUrlController = TextEditingController(text: current.apiUrl);
    _apiKeyController = TextEditingController(text: current.apiKey);
    _modelController = TextEditingController(text: current.model);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _syncControllers(LlmSettings settings) {
    if (_apiUrlController.text != settings.apiUrl) {
      _apiUrlController.text = settings.apiUrl;
    }
    if (_apiKeyController.text != settings.apiKey) {
      _apiKeyController.text = settings.apiKey;
    }
    if (_modelController.text != settings.model) {
      _modelController.text = settings.model;
    }
  }

  Future<void> _restoreDefaults() async {
    await ref.read(settingsControllerProvider.notifier).resetDefaults();
    if (!mounted) return;
    setState(() {
      _hasEdited = false;
      _apiUrlController.text = LlmSettings.defaultApiUrl;
      _apiKeyController.text = LlmSettings.defaultApiKey;
      _modelController.text = LlmSettings.defaultModel;
    });
  }

  Future<void> _saveSettings() async {
    final rawUrl = _apiUrlController.text.trim();
    final rawKey = _apiKeyController.text.trim();
    final rawModel = _modelController.text.trim();

    await ref.read(settingsControllerProvider.notifier).updateSettings(
          apiUrl: rawUrl.isEmpty ? LlmSettings.defaultApiUrl : rawUrl,
          apiKey: rawKey,
          model: rawModel.isEmpty ? LlmSettings.defaultModel : rawModel,
        );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen<LlmSettings>(settingsControllerProvider, (_, next) {
      if (!_hasEdited) {
        _syncControllers(next);
      }
    });

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '设置',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '主题',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kThemeOptions.map((opt) {
                  final isSelected = opt.type == currentTheme;
                  return InkWell(
                    onTap: () {
                      ref
                          .read(themeControllerProvider.notifier)
                          .setTheme(opt.type);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primaryContainer
                                .withValues(alpha: isDark ? 0.35 : 0.7)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: isDark ? 0.4 : 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: opt.backgroundColor,
                              border: Border.all(
                                color: opt.primaryColor,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: opt.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.check,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Text(
                    'AIGC 接口',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message:
                        '兼容 OpenAI Chat Completions 工具调用接口，默认 ChatAnywhere',
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.info_outline,
                        size: 17,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiUrlController,
                keyboardType: TextInputType.url,
                onChanged: (_) => _hasEdited = true,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'https://api.chatanywhere.tech',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                onChanged: (_) => _hasEdited = true,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: _obscureApiKey ? '显示' : '隐藏',
                    icon: Icon(
                      _obscureApiKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                onChanged: (_) => _hasEdited = true,
                decoration: const InputDecoration(
                  labelText: '模型名称',
                  hintText: LlmSettings.defaultModel,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: _restoreDefaults,
                    child: const Text('恢复默认'),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(104, 46),
                    ),
                    onPressed: _saveSettings,
                    child: const Text(
                      '保存',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
