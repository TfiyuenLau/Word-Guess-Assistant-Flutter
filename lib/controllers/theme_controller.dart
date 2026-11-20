import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType {
  light,
  night,
  cyberpunk,
  ocean,
  forest,
  crimson,
}

class AppThemeOption {
  final AppThemeType type;
  final String label;
  final Color primaryColor;
  final Color backgroundColor;
  final bool isDark;

  const AppThemeOption({
    required this.type,
    required this.label,
    required this.primaryColor,
    required this.backgroundColor,
    this.isDark = true,
  });
}

const List<AppThemeOption> kThemeOptions = [
  AppThemeOption(
    type: AppThemeType.light,
    label: '浅色',
    primaryColor: Color(0xFF2563EB),
    backgroundColor: Color(0xFFF8FAFC),
    isDark: false,
  ),
  AppThemeOption(
    type: AppThemeType.night,
    label: '暗夜',
    primaryColor: Color(0xFF38BDF8),
    backgroundColor: Color(0xFF0F172A),
    isDark: true,
  ),
  AppThemeOption(
    type: AppThemeType.cyberpunk,
    label: '赛博',
    primaryColor: Color(0xFF00F0FF),
    backgroundColor: Color(0xFF130924),
    isDark: true,
  ),
  AppThemeOption(
    type: AppThemeType.ocean,
    label: '深海',
    primaryColor: Color(0xFF0EA5E9),
    backgroundColor: Color(0xFF07192F),
    isDark: true,
  ),
  AppThemeOption(
    type: AppThemeType.forest,
    label: '森林',
    primaryColor: Color(0xFF10B981),
    backgroundColor: Color(0xFF061A14),
    isDark: true,
  ),
];

const AppThemeOption _crimsonFallback = AppThemeOption(
  type: AppThemeType.crimson,
  label: '赤红',
  primaryColor: Color(0xFFEF4444),
  backgroundColor: Color(0xFF180A0A),
  isDark: true,
);

class ThemeNotifier extends StateNotifier<AppThemeType> {
  static const _prefKey = 'wga_app_theme';

  ThemeNotifier() : super(AppThemeType.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final found = AppThemeType.values.firstWhere(
        (t) => t.name == saved,
        orElse: () => AppThemeType.light,
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
    final opt = type == AppThemeType.crimson
        ? _crimsonFallback
        : kThemeOptions.firstWhere(
            (o) => o.type == type,
            orElse: () => kThemeOptions.first,
          );

    if (!opt.isDark) {
      final baseScheme = ColorScheme.fromSeed(
        seedColor: opt.primaryColor,
        brightness: Brightness.light,
        surface: Colors.white,
      );
      final scheme = baseScheme.copyWith(
        primary: opt.primaryColor,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDBEAFE),
        onPrimaryContainer: const Color(0xFF1E3A8A),
        secondaryContainer: const Color(0xFFDBEAFE),
        onSecondaryContainer: const Color(0xFF1E40AF),
        surface: Colors.white,
        onSurface: const Color(0xFF0F172A),
        onSurfaceVariant: const Color(0xFF475569),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF8FAFC),
        surfaceContainer: const Color(0xFFF1F5F9),
        surfaceContainerHigh: const Color(0xFFE2E8F0),
        surfaceContainerHighest: const Color(0xFFE2E8F0),
        outline: const Color(0xFF94A3B8),
        outlineVariant: const Color(0xFFE2E8F0),
      );
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: opt.backgroundColor,
        dividerColor: const Color(0xFFE2E8F0),
        colorScheme: scheme,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
          shape: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          labelStyle: const TextStyle(color: Color(0xFF475569)),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: opt.primaryColor, width: 1.5),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFDBEAFE);
              }
              return Colors.white;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF1D4ED8);
              }
              return const Color(0xFF334155);
            }),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: opt.primaryColor,
          foregroundColor: Colors.white,
          elevation: 3,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF0F172A),
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    final surfaceColor = Color.alphaBlend(
      opt.primaryColor.withValues(alpha: 0.05),
      opt.backgroundColor,
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: opt.primaryColor,
      brightness: Brightness.dark,
      surface: surfaceColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: opt.backgroundColor,
      colorScheme: scheme,
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: opt.primaryColor.withValues(alpha: 0.18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeType>((ref) {
  return ThemeNotifier();
});
