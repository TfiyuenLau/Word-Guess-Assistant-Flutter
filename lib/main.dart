import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/theme_controller.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: WordGuessAssistantApp()));
}

class WordGuessAssistantApp extends ConsumerWidget {
  const WordGuessAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeControllerProvider);
    final themeData =
        ref.read(themeControllerProvider.notifier).getThemeData(themeType);

    return MaterialApp(
      title: '特工猜词助手',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      builder: (context, child) {
        // 移动端友好比例视口适配：在桌面与宽屏下保持标准智能手机视口比例（480px以内居中），移动设备全屏响应
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 560) {
              return Container(
                color: const Color(0xFF030712), // 极黑底衬，衬托手机窗体
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 440,
                      maxHeight: 900,
                    ),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 32,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
      home: const HomeScreen(),
    );
  }
}
