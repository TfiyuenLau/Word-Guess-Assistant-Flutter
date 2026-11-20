import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AIGC 大模型接口配置模型
class LlmSettings {
  static const String defaultApiUrl =
      'https://api.chatanywhere.tech/v1/chat/completions';
  static const String defaultModel = 'deepseek-v4.1-flash-1017';
  static const String defaultApiKey = '';

  final String apiUrl;
  final String apiKey;
  final String model;

  const LlmSettings({
    this.apiUrl = defaultApiUrl,
    this.apiKey = defaultApiKey,
    this.model = defaultModel,
  });

  bool get isConfigured =>
      apiUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  /// 自动补全兼容 OpenAI Chat Completions 端点路径
  String get resolvedEndpoint {
    var trimmed = apiUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.isEmpty) return '';
    if (trimmed.endsWith('/chat/completions')) {
      return trimmed;
    }
    if (trimmed.endsWith('/v1')) {
      return '$trimmed/chat/completions';
    }
    return '$trimmed/v1/chat/completions';
  }

  LlmSettings copyWith({
    String? apiUrl,
    String? apiKey,
    String? model,
  }) {
    return LlmSettings(
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LlmSettings &&
        other.apiUrl == apiUrl &&
        other.apiKey == apiKey &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(apiUrl, apiKey, model);
}

/// 全局 AIGC 设置持久化控制器
class SettingsController extends StateNotifier<LlmSettings> {
  static const String prefKeyApiUrl = 'wga_llm_api_url';
  static const String prefKeyApiKey = 'wga_llm_api_key';
  static const String prefKeyModel = 'wga_llm_model';

  bool _dirty = false;

  SettingsController() : super(const LlmSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _dirty) return;

      final savedUrl = prefs.getString(prefKeyApiUrl);
      final savedKey = prefs.getString(prefKeyApiKey);
      final savedModel = prefs.getString(prefKeyModel);

      state = LlmSettings(
        apiUrl: (savedUrl != null && savedUrl.trim().isNotEmpty)
            ? savedUrl.trim()
            : LlmSettings.defaultApiUrl,
        apiKey: savedKey?.trim() ?? LlmSettings.defaultApiKey,
        model: (savedModel != null && savedModel.trim().isNotEmpty)
            ? savedModel.trim()
            : LlmSettings.defaultModel,
      );
    } catch (_) {}
  }

  Future<void> updateSettings({
    String? apiUrl,
    String? apiKey,
    String? model,
  }) async {
    _dirty = true;
    final next = state.copyWith(
      apiUrl: apiUrl?.trim(),
      apiKey: apiKey?.trim(),
      model: model?.trim(),
    );
    state = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyApiUrl, next.apiUrl);
      await prefs.setString(prefKeyApiKey, next.apiKey);
      await prefs.setString(prefKeyModel, next.model);
    } catch (_) {}
  }

  Future<void> resetDefaults() async {
    _dirty = true;
    const next = LlmSettings();
    state = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyApiUrl, next.apiUrl);
      await prefs.setString(prefKeyApiKey, next.apiKey);
      await prefs.setString(prefKeyModel, next.model);
    } catch (_) {}
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, LlmSettings>((ref) {
  return SettingsController();
});
