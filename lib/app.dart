import 'package:book_app_themed/pages/home_page.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:flutter/cupertino.dart';

class BookTrackerApp extends StatelessWidget {
  const BookTrackerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CupertinoApp(
          debugShowCheckedModeBanner: false,
          title: 'BlackPirateX Book tracker',
          theme: controller.themeData,
          home: HomePage(controller: controller),
        );
      },
    );
  }
}
