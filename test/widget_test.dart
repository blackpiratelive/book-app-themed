import 'package:book_app_themed/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders book tracker shell', (tester) async {
    await tester.pumpWidget(const BookTrackerApp());

    expect(find.text('My Books'), findsOneWidget);
  });
}
