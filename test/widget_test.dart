import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_guess_assistant_flutter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test - HomeScreen loads successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: WordGuessAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('特工猜词助手'), findsOneWidget);
    expect(find.text('特工代号与机密形象'), findsOneWidget);
    expect(find.text('WebRTC P2P (外网快速联机)'), findsOneWidget);
  });
}
