import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/theme_controller.dart';
import 'models/word_bank.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WordBank.load();
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
      home: const HomeScreen(),
    );
  }
}
