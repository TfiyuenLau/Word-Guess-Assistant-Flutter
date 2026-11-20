import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// 词库生成来源模式
enum WordSourceMode { localJson, aigc }

/// 预设双词题库条目
class PresetWordPair {
  final String wordA;
  final String wordB;
  final String hint;
  final String similarity; // "极为接近" 或 "较为接近"
  final String category;

  const PresetWordPair({
    required this.wordA,
    required this.wordB,
    required this.hint,
    required this.similarity,
    required this.category,
  });

  factory PresetWordPair.fromJson(Map<String, dynamic> json) {
    return PresetWordPair(
      wordA: (json['wordA'] ?? '').toString().trim(),
      wordB: (json['wordB'] ?? '').toString().trim(),
      hint: (json['hint'] ?? '').toString().trim(),
      similarity: (json['similarity'] ?? '极为接近').toString().trim(),
      category: (json['category'] ?? '默认').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'wordA': wordA,
        'wordB': wordB,
        'hint': hint,
        'similarity': similarity,
        'category': category,
      };
}

/// 本地 JSON 词库管理器（无 dart:io 依赖，全平台及 Web 兼容）
class WordBank {
  static const String assetPath = 'assets/word_bank.json';
  static const String randomCategory = '随机';
  static const String randomSimilarity = '随机';

  static List<PresetWordPair> _loadedPairs = const [];

  static bool get isLoaded => _loadedPairs.isNotEmpty;

  static List<PresetWordPair> get entries => List.unmodifiable(_loadedPairs);

  /// 从资源包异步加载 JSON 词库
  static Future<void> load({
    AssetBundle? bundle,
    bool forceReload = false,
  }) async {
    if (isLoaded && !forceReload) return;
    final targetBundle = bundle ?? rootBundle;
    final jsonStr = await targetBundle.loadString(assetPath);
    loadFromJsonString(jsonStr);
  }

  /// 从 JSON 字符串解析并刷新内存词库缓存
  static void loadFromJsonString(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('词库 JSON 根节点必须是对象');
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw const FormatException('词库 JSON 缺少 entries 列表');
    }

    final parsed = <PresetWordPair>[];
    for (final item in rawEntries) {
      if (item is Map<String, dynamic>) {
        final pair = PresetWordPair.fromJson(item);
        if (pair.wordA.isNotEmpty &&
            pair.wordB.isNotEmpty &&
            pair.wordA != pair.wordB) {
          parsed.add(pair);
        }
      } else if (item is Map) {
        final pair = PresetWordPair.fromJson(Map<String, dynamic>.from(item));
        if (pair.wordA.isNotEmpty &&
            pair.wordB.isNotEmpty &&
            pair.wordA != pair.wordB) {
          parsed.add(pair);
        }
      }
    }

    if (parsed.isEmpty) {
      throw const FormatException('词库有效词条为空');
    }

    _loadedPairs = List.unmodifiable(parsed);
  }

  /// 动态提取主题列表：['随机', ...JSON 中的唯一分类（按出现顺序）]
  static List<String> get categories {
    final seen = <String>{};
    final result = <String>[randomCategory];
    for (final pair in _loadedPairs) {
      if (pair.category.isNotEmpty && seen.add(pair.category)) {
        result.add(pair.category);
      }
    }
    return result;
  }

  static List<String> get similarities => const [
        randomSimilarity,
        '极为接近',
        '较为接近',
      ];

  /// 根据主题和相似度智能抽取词组
  static PresetWordPair generateWords({String? theme, String? similarity}) {
    if (_loadedPairs.isEmpty) {
      throw StateError('本地词库尚未加载');
    }

    final random = Random();
    final trimmedTheme = theme?.trim() ?? '';
    final trimmedSim = similarity?.trim() ?? '';

    final isWildcardTheme = trimmedTheme.isEmpty ||
        trimmedTheme == randomCategory ||
        trimmedTheme == '全部主题';
    final isWildcardSim =
        trimmedSim.isEmpty || trimmedSim == randomSimilarity;

    // 1. 尝试匹配主题 + 相似度
    var candidates = _loadedPairs.where((p) {
      final simMatch = isWildcardSim || p.similarity == trimmedSim;
      final themeMatch = isWildcardTheme ||
          p.category == trimmedTheme ||
          p.category.contains(trimmedTheme) ||
          p.hint.contains(trimmedTheme);
      return simMatch && themeMatch;
    }).toList();

    if (candidates.isNotEmpty) {
      return candidates[random.nextInt(candidates.length)];
    }

    // 2. 退化匹配相似度
    if (!isWildcardSim) {
      candidates =
          _loadedPairs.where((p) => p.similarity == trimmedSim).toList();
      if (candidates.isNotEmpty) {
        return candidates[random.nextInt(candidates.length)];
      }
    }

    // 3. 退化匹配主题
    if (!isWildcardTheme) {
      candidates = _loadedPairs
          .where((p) =>
              p.category == trimmedTheme ||
              p.category.contains(trimmedTheme) ||
              p.hint.contains(trimmedTheme))
          .toList();
      if (candidates.isNotEmpty) {
        return candidates[random.nextInt(candidates.length)];
      }
    }

    // 4. 兜底全局随机
    return _loadedPairs[random.nextInt(_loadedPairs.length)];
  }
}
