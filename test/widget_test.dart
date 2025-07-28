// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:llm_voice_assistant/main.dart';

void main() {
  testWidgets('Voice Assistant App smoke test', (WidgetTester tester) async {
    // Build our app with providers and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => VoiceAssistantProvider()),
          ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
          ChangeNotifierProvider(create: (_) => ServerProvider()),
        ],
        child: const VoiceAssistantApp(),
      ),
    );

    // Verify that our app starts with the main screen
    expect(find.text('📱 LLM 음성 비서 프로토타입'), findsOneWidget);
    
    // Verify that the main content is present
    expect(find.byType(MainContent), findsOneWidget);
  });
}
