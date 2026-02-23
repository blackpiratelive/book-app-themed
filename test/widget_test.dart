import 'package:book_app_themed/app.dart';
import 'package:book_app_themed/services/app_storage_service.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders book tracker shell', (tester) async {
    final controller = AppController(storage: AppStorageService());

    await tester.pumpWidget(BookTrackerApp(controller: controller));
    await tester.pump();

    expect(find.text('My Books'), findsOneWidget);
  });
}
