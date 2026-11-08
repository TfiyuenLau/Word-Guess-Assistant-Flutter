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

    test('默认主题应为暗夜特工 (night)', () {
      final notifier = ThemeNotifier();
      expect(notifier.state, equals(AppThemeType.night));
    });

    test('切换全部 6 款主题并验证 ThemeData 正常生成', () async {
      final notifier = ThemeNotifier();

      for (final opt in kThemeOptions) {
        await notifier.setTheme(opt.type);
        expect(notifier.state, equals(opt.type));

        final themeData = notifier.getThemeData(opt.type);
        expect(themeData.useMaterial3, isTrue);
        expect(themeData.brightness, equals(opt.isDark ? Brightness.dark : Brightness.light));
      }
    });

    test('主题设置持久化至 SharedPreferences 校验', () async {
      final notifier = ThemeNotifier();
      await notifier.setTheme(AppThemeType.cyberpunk);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wga_app_theme'), equals('cyberpunk'));
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
