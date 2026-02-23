import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiController;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(text: 'https://notes.blackpiratex.com');
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Settings'),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                SectionCard(
                  title: 'Appearance',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(CupertinoIcons.moon_fill, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Use a darker interface across the app.',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: widget.controller.isDarkMode,
                        onChanged: widget.controller.setDarkMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Backend (UI Only)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Backend API',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: _apiController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.separator
                                .resolveFrom(context)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        onPressed: () {},
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.separator
                                  .resolveFrom(context)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(CupertinoIcons.lock_fill, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label.resolveFrom(context),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                CupertinoIcons.chevron_forward,
                                size: 16,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
