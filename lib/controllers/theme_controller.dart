import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType {
  night, // 暗夜特工 (默认)
  cyberpunk, // 赛博霓虹
  ocean, // 深海潜行
  forest, // 森林隐蔽
  crimson, // 赤红警报
  light, // 极简明亮
}

class AppThemeOption {
  final AppThemeType type;
  final String label;
  final String subtitle;
  final Color primaryColor;
  final Color backgroundColor;
  final bool isDark;

  const AppThemeOption({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.primaryColor,
    required this.backgroundColor,
    this.isDark = true,
  });
}

const List<AppThemeOption> kThemeOptions = [
  AppThemeOption(
    type: AppThemeType.night,
    label: '暗夜特工',
    subtitle: '深邃夜蓝，经典潜行沉浸体验',
    primaryColor: Color(0xFF38BDF8),
    backgroundColor: Color(0xFF0F172A),
    isDark: true,
  ),
  AppThemeOption(
    type: AppThemeType.cyberpunk,
    label: '赛博霓虹',
    subtitle: '高对比度霓虹紫金，黑客科技感',
    primaryColor: Color(0xFF00F0FF),
    backgroundColor: Color(0xFF130924),
    isDark: true,
  ),
  AppThemeOption(
    type: AppThemeType.ocean,
    label: '深海潜行',
    subtitle: '深洋蔚蓝，冷静克制与信息穿透',
    primaryColor: Color(0xFF00D2FF),
    backgroundColor: Color(0xFF07192F),
    isDark: true,
  ),
  AppThemeOption(
    type: AppThemeType.forest,
    label: '森林隐蔽',
    subtitle: '战术墨绿，隐秘丛林作战风格',
    primaryColor: Color(0xFF10B981),
    backgroundColor: Color(0xFF061A14),
    isDark: true,
  ),
  AppThemeOption(
    type: AppThemeType.crimson,
    label: '赤红警报',
    subtitle: '警戒深红，紧张刺激博弈心跳',
    primaryColor: Color(0xFFEF4444),
    backgroundColor: Color(0xFF180A0A),
    isDark: true,
  ),
  AppThemeOption(
    type: AppThemeType.light,
    label: '极简浅色',
    subtitle: '清爽白净，明亮日光阅读模式',
    primaryColor: Color(0xFF2563EB),
    backgroundColor: Color(0xFFF8FAFC),
    isDark: false,
  ),
];

class ThemeNotifier extends StateNotifier<AppThemeType> {
  static const _prefKey = 'wga_app_theme';

  ThemeNotifier() : super(AppThemeType.night) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final found = AppThemeType.values.firstWhere(
        (t) => t.name == saved,
        orElse: () => AppThemeType.night,
      );
      state = found;
    }
  }

  Future<void> setTheme(AppThemeType themeType) async {
    state = themeType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, themeType.name);
  }

  ThemeData getThemeData(AppThemeType type) {
    final opt = kThemeOptions.firstWhere((o) => o.type == type);

    if (!opt.isDark) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: opt.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: opt.primaryColor,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: opt.backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: opt.primaryColor,
        brightness: Brightness.dark,
        surface: Color.alphaBlend(
          opt.primaryColor.withValues(alpha: 0.05),
          opt.backgroundColor,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: opt.backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Color.alphaBlend(
          opt.primaryColor.withValues(alpha: 0.08),
          const Color(0xFF1E293B),
        ),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: opt.primaryColor.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeType>((ref) {
  return ThemeNotifier();
});
