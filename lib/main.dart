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
      title: '猜词助手',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 500) {
              return Container(
                color: const Color(0xFF030712),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 430,
                      maxHeight: 900,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 28,
                          spreadRadius: 2,
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
