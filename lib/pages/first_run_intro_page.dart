import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/widgets/brand_app_icon.dart';
import 'package:flutter/cupertino.dart';

class FirstRunIntroPage extends StatefulWidget {
  const FirstRunIntroPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<FirstRunIntroPage> createState() => _FirstRunIntroPageState();
}

class _FirstRunIntroPageState extends State<FirstRunIntroPage> {
  late final PageController _pageController;
  int _pageIndex = 0;
  bool _isCompleting = false;

  static final List<_IntroStep> _steps = <_IntroStep>[
    _IntroStep(
      title: 'Welcome to your shelf',
      subtitle:
          'Track what you are reading, what you finished, and what is waiting in your Reading List.',
      icon: CupertinoIcons.book_fill,
      accentColor: CupertinoColors.activeBlue,
      bullets: <String>[
        'Home shows the current shelf and book count.',
        'Use the bottom bar to switch between Reading, Read, and Reading List.',
        'The red button in the header opens the Abandoned shelf.',
      ],
    ),
    _IntroStep(
      title: 'Add books fast',
      subtitle:
          'Use the big + button to add manually or search your backend library API.',
      icon: CupertinoIcons.add_circled_solid,
      accentColor: CupertinoColors.activeGreen,
      bullets: <String>[
        'Choose Search Library (API) to pull a book into Reading List.',
        'Choose Add Manually to enter title, author, cover, notes, dates, and rating.',
        'New books are saved locally right away.',
      ],
    ),
    _IntroStep(
      title: 'Track progress and highlights',
      subtitle:
          'Open any book card to update progress, edit details, save notes, and manage highlights.',
      icon: CupertinoIcons.sparkles,
      accentColor: CupertinoColors.systemOrange,
      bullets: <String>[
        'Book details shows status, progress, and quick actions.',
        'Highlights can be copied and saved for later.',
        'Use Edit in the top bar to update metadata or reading dates.',
      ],
    ),
    _IntroStep(
      title: 'Sync, stats, and settings',
      subtitle:
          'Pull down on Home to refresh from backend, then use Stats and Settings to manage the app.',
      icon: CupertinoIcons.chart_bar_alt_fill,
      accentColor: CupertinoColors.systemPink,
      bullets: <String>[
        'Pull to refresh checks for backend changes.',
        'Stats in the bottom bar uses your local cache for reading summaries.',
        'Settings lets you configure backend URL/password and dark mode.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _pageIndex == _steps.length - 1;

  Future<void> _goNext() async {
    if (_isLastPage) {
      await _finish();
      return;
    }
    await _pageController.animateToPage(
      _pageIndex + 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await widget.controller.markOnboardingSeen();
    if (mounted) {
      setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              CupertinoColors.systemBackground.resolveFrom(context),
              bg,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: <Widget>[
                    const BrandAppIcon(size: 34, borderRadius: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'BlackPirateX Book tracker',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: label,
                            ),
                          ),
                          Text(
                            'Quick intro',
                            style: TextStyle(fontSize: 12, color: secondary),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minSize: 0,
                      onPressed: _isCompleting ? null : _finish,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (value) => setState(() => _pageIndex = value),
                  itemBuilder: (context, index) => _IntroStepView(
                    step: _steps[index],
                    index: index,
                    total: _steps.length,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(
                        _steps.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == _pageIndex ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == _pageIndex
                                ? CupertinoTheme.of(context).primaryColor
                                : CupertinoColors.tertiaryLabel.resolveFrom(
                                    context,
                                  ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        if (_pageIndex > 0)
                          Expanded(
                            child: CupertinoButton(
                              onPressed: _isCompleting
                                  ? null
                                  : () => _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    ),
                              child: const Text('Back'),
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: CupertinoButton.filled(
                            onPressed: _isCompleting ? null : _goNext,
                            child: _isCompleting
                                ? const CupertinoActivityIndicator()
                                : Text(_isLastPage ? 'Get Started' : 'Next'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroStep {
  const _IntroStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bullets,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> bullets;
}

class _IntroStepView extends StatelessWidget {
  const _IntroStepView({
    required this.step,
    required this.index,
    required this.total,
  });

  final _IntroStep step;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(step.accentColor, context);
    final cardColor = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        accent.withValues(alpha: 0.22),
                        accent.withValues(alpha: 0.08),
                      ],
                    ),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Icon(step.icon, color: accent, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Step ${index + 1} of $total',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 28,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            color: label,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.subtitle,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.28,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      children: step.bullets
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      CupertinoIcons.checkmark_seal_fill,
                                      size: 18,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.28,
                                        color: label,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _IntroMockPreview(accent: accent, index: index),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IntroMockPreview extends StatelessWidget {
  const _IntroMockPreview({required this.accent, required this.index});

  final Color accent;
  final int index;

  @override
  Widget build(BuildContext context) {
    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final tertiary = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final previewTitles = <String>[
      'Reading shelf + quick filters',
      'Manual / API add flow',
      'Details page + highlights',
      'Refresh + stats + settings',
    ];

    final previewLines = <List<String>>[
      <String>['Reading', 'Read', 'Reading List', 'Abandoned'],
      <String>['Search Library (API)', 'Add Manually', 'Saved locally'],
      <String>['Progress', 'Notes', 'Highlights', 'Edit'],
      <String>['Pull to refresh', 'Stats', 'Dark mode', 'Backend'],
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  CupertinoIcons.rectangle_grid_2x2_fill,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(
                  previewTitles[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: previewLines[index]
                  .map(
                    (line) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: tertiary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
