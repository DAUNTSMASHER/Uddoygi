import 'package:flutter_test/flutter_test.dart';
import 'package:uddoygi/main.dart';
import 'package:uddoygi/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('App shows login screen', (WidgetTester tester) async {
    // Build our app and wait for all animations and frames to settle.
    await tester.pumpWidget(const UddyogiApp());
    await tester.pumpAndSettle();

    // Verify that the LoginScreen widget is present.
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
