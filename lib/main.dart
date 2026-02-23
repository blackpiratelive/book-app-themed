import 'package:book_app_themed/app.dart';
import 'package:book_app_themed/services/app_storage_service.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(storage: AppStorageService());
  await controller.initialize();

runApp(BookTrackerApp(controller: controller));
}
