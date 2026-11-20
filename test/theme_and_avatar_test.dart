import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_guess_assistant_flutter/controllers/theme_controller.dart';
import 'package:word_guess_assistant_flutter/ui/widgets/avatar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController & ThemeOptions Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('默认主题应为浅色 (light) 且 kThemeOptions 首位为浅色', () {
      final notifier = ThemeNotifier();
      expect(notifier.state, equals(AppThemeType.light));
      expect(kThemeOptions.length, equals(5));
      expect(kThemeOptions.first.type, equals(AppThemeType.light));
      expect(kThemeOptions.first.label, equals('浅色'));
      expect(kThemeOptions.first.isDark, isFalse);

      final lightTheme = notifier.getThemeData(AppThemeType.light);
      expect(lightTheme.brightness, equals(Brightness.light));
      expect(lightTheme.scaffoldBackgroundColor, equals(const Color(0xFFF8FAFC)));
      expect(lightTheme.appBarTheme.backgroundColor, equals(Colors.white));
    });

    test('切换全部可选主题及兼容主题并验证 ThemeData 正常生成', () async {
      final notifier = ThemeNotifier();

      for (final opt in kThemeOptions) {
        await notifier.setTheme(opt.type);
        expect(notifier.state, equals(opt.type));

        final themeData = notifier.getThemeData(opt.type);
        expect(themeData.useMaterial3, isTrue);
        expect(
          themeData.brightness,
          equals(opt.isDark ? Brightness.dark : Brightness.light),
        );
      }

      // 兼容旧版 crimson 主题不崩溃
      final crimsonTheme = notifier.getThemeData(AppThemeType.crimson);
      expect(crimsonTheme.brightness, equals(Brightness.dark));
    });

    test('主题设置持久化及未知值回退浅色校验', () async {
      final notifier = ThemeNotifier();
      await notifier.setTheme(AppThemeType.cyberpunk);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wga_app_theme'), equals('cyberpunk'));

      // 模拟无效持久化值回退到 light
      SharedPreferences.setMockInitialValues({'wga_app_theme': 'unknown_legacy'});
      final fallbackNotifier = ThemeNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(fallbackNotifier.state, equals(AppThemeType.light));
    });
  });

  group('Avatar System & SVG Normalization Tests', () {
    test('内置 15 个精品 SVG 头像完整性验证', () {
      expect(kBuiltinAvatars.length, equals(15));

      final characters = kBuiltinAvatars.where((a) => a.category == '特工角色');
      final animals = kBuiltinAvatars.where((a) => a.category == '萌系动物');
      final cyber = kBuiltinAvatars.where((a) => a.category == '赛博朋克');

      expect(characters.length, equals(5));
      expect(animals.length, equals(5));
      expect(cyber.length, equals(5));
    });

    test('normalizeAvatarPath 兼容旧版及各种路径输入', () {
      expect(
        normalizeAvatarPath('/avatar/characters/detective.svg'),
        equals('assets/avatars/characters/detective.svg'),
      );
      expect(
        normalizeAvatarPath('avatar/cyber/agent.svg'),
        equals('assets/avatars/cyber/agent.svg'),
      );
      expect(
        normalizeAvatarPath('animals/cat.svg'),
        equals('assets/avatars/animals/cat.svg'),
      );
      expect(
        normalizeAvatarPath(''),
        equals('assets/avatars/characters/detective.svg'),
      );
    });
  });
}
