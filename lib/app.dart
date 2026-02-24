import 'package:book_app_themed/pages/auth_gate_page.dart';
import 'package:book_app_themed/pages/first_run_intro_page.dart';
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
          key: ValueKey<String>(
            'session:${controller.authSessionType.storageValue}|onboarding:${controller.hasSeenOnboarding}',
          ),
          debugShowCheckedModeBanner: false,
          title: 'BlackPirateX Book tracker',
          theme: controller.themeData,
          home: controller.shouldShowAuthGate
              ? AuthGatePage(controller: controller)
              : controller.shouldShowOnboarding
              ? FirstRunIntroPage(controller: controller)
              : HomePage(controller: controller),
        );
      },
    );
  }
}
