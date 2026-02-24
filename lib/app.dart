import 'package:book_app_themed/pages/auth_gate_page.dart';
import 'package:book_app_themed/pages/first_run_intro_page.dart';
import 'package:book_app_themed/pages/home_page.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:flutter/cupertino.dart';

class BookTrackerApp extends StatefulWidget {
  const BookTrackerApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<BookTrackerApp> createState() => _BookTrackerAppState();
}

class _BookTrackerAppState extends State<BookTrackerApp>
    with WidgetsBindingObserver {
  Brightness _platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next == _platformBrightness) return;
    setState(() => _platformBrightness = next);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return CupertinoApp(
          key: ValueKey<String>(
            'session:${widget.controller.authSessionType.storageValue}|onboarding:${widget.controller.hasSeenOnboarding}|theme:${widget.controller.themeMode.storageValue}|pb:${_platformBrightness.name}',
          ),
          debugShowCheckedModeBanner: false,
          title: 'BlackPirateX Book tracker',
          theme: widget.controller.themeDataFor(_platformBrightness),
          home: widget.controller.shouldShowOnboarding
              ? FirstRunIntroPage(controller: widget.controller)
              : widget.controller.shouldShowAuthGate
              ? AuthGatePage(controller: widget.controller)
              : HomePage(controller: widget.controller),
        );
      },
    );
  }
}
