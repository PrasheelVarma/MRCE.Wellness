import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wellness/screens/home_screen.dart';
import 'package:wellness/services/quote_service.dart';

// ---------------------------------------------------------------------------
// Fake QuoteService — no Supabase needed
// ---------------------------------------------------------------------------

class _FakeQuoteService extends QuoteService {
  final Map<String, dynamic>? returnValue;
  _FakeQuoteService(this.returnValue);

  @override
  Future<Map<String, dynamic>?> getTodayQuote() async => returnValue;
}

// Helper: wrap HomeScreen in a minimal MaterialApp
Widget _buildApp(QuoteService service) {
  return MaterialApp(home: HomeScreen(quoteService: service));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('shows a loading indicator while fetching', (tester) async {
    final service = _FakeQuoteService(null);

    await tester.pumpWidget(_buildApp(service));
    // First frame — async call hasn't settled yet
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows quote card when data loads successfully', (tester) async {
    final service = _FakeQuoteService({
      'quote_text': 'Test quote',
      'author': 'Test Author',
      'meaning': 'Test meaning',
      'task_of_the_day': 'Test task',
    });

    await tester.pumpWidget(_buildApp(service));
    await tester.pumpAndSettle();

    expect(find.text('Test quote'), findsOneWidget);
    expect(find.text('— Test Author'), findsOneWidget);
    expect(find.text('Test meaning'), findsOneWidget);
    expect(find.text('Test task'), findsOneWidget);
  });

  testWidgets('shows error view with retry button when service returns null',
      (tester) async {
    final service = _FakeQuoteService(null);

    await tester.pumpWidget(_buildApp(service));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load today's quote."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry button reloads content successfully', (tester) async {
    int callCount = 0;
    final Map<String, dynamic> quoteData = {
      'quote_text': 'After retry',
      'author': 'Retry Author',
      'meaning': null,
      'task_of_the_day': null,
    };

    // First call fails, second succeeds
    final service = _CallCountService(
      onCall: () => callCount++ == 0 ? null : quoteData,
    );

    await tester.pumpWidget(_buildApp(service));
    await tester.pumpAndSettle();

    // Should show error
    expect(find.text('Retry'), findsOneWidget);

    // Tap retry
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('After retry'), findsOneWidget);
  });
}

class _CallCountService extends QuoteService {
  final Map<String, dynamic>? Function() onCall;
  _CallCountService({required this.onCall});

  @override
  Future<Map<String, dynamic>?> getTodayQuote() async => onCall();
}
