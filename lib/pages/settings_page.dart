import 'dart:async';

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
  static const String _defaultApiUrl = 'https://notes.blackpiratex.com';

  late final TextEditingController _apiController;
  late String _password;
  String? _localStatusMessage;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(
      text: widget.controller.backendApiUrl.isEmpty
          ? _defaultApiUrl
          : widget.controller.backendApiUrl,
    );
    _password = widget.controller.backendPassword;
  }

  @override
  void dispose() {
    unawaited(_persistBackendConfig());
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _persistBackendConfig() {
    return widget.controller.saveBackendConfig(
      apiUrl: _apiController.text,
      password: _password,
    );
  }

  Future<void> _openPasswordDialog() async {
    final controller = TextEditingController(text: _password);
    var draft = _password;
    final next = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('Backend Password'),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CupertinoTextField(
                  controller: controller,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  placeholder: 'Enter admin password',
                  onChanged: (value) => setDialogState(() => draft = value),
                ),
              ),
              actions: <Widget>[
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(draft),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (next == null) return;
    setState(() => _password = next);
    await _persistBackendConfig();
    if (!mounted) return;
    setState(() {
      _localStatusMessage = next.trim().isEmpty
          ? 'Password cleared.'
          : 'Password saved locally.';
    });
  }

  Future<void> _testConnection() async {
    await _persistBackendConfig();
    setState(() => _localStatusMessage = 'Testing backend connection...');
    try {
      final result = await widget.controller.testBackendConnection(
        apiUrl: _apiController.text,
        password: _password,
      );
      if (!mounted) return;
      setState(() => _localStatusMessage = result.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localStatusMessage =
            widget.controller.lastBackendStatusMessage ?? 'Connection test failed.';
      });
    }
  }

  Future<void> _forceReload() async {
    await _persistBackendConfig();

    if (widget.controller.hasLocalBookChanges) {
      final confirmed = await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Force reload from backend?'),
              content: const Text(
                'This will replace your local cached books and discard local-only changes.',
              ),
              actions: <Widget>[
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Reload'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }

    setState(() => _localStatusMessage = 'Refreshing from backend...');
    try {
      final result = await widget.controller.forceReloadFromBackend();
      if (!mounted) return;
      setState(() => _localStatusMessage = result.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localStatusMessage =
            widget.controller.lastBackendStatusMessage ?? 'Backend refresh failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.isBackendBusy;
        final backendStatus = _localStatusMessage ?? widget.controller.lastBackendStatusMessage;
        final syncLabel = _formatSyncLabel(widget.controller.lastBackendSyncAtIso);

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
                  title: 'Backend',
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
                        onEditingComplete: () {
                          FocusScope.of(context).unfocus();
                          unawaited(_persistBackendConfig());
                        },
                        onSubmitted: (_) => unawaited(_persistBackendConfig()),
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
                        onPressed: busy ? null : _openPasswordDialog,
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
                              Text(
                                _password.trim().isEmpty ? 'Not set' : 'Saved',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                CupertinoIcons.chevron_forward,
                                size: 16,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              color: CupertinoColors.activeBlue,
                              borderRadius: BorderRadius.circular(12),
                              onPressed: busy ? null : _testConnection,
                              child: busy
                                  ? const CupertinoActivityIndicator()
                                  : const Text(
                                      'Test Connection',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: busy ? null : _forceReload,
                              child: Text(
                                'Force Reload From API',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: CupertinoColors.label.resolveFrom(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _BackendInfoRow(
                        label: 'Cache status',
                        value: widget.controller.backendCachePrimed
                            ? 'Cached locally'
                            : 'Not loaded from backend yet',
                      ),
                      _BackendInfoRow(
                        label: 'Local changes',
                        value: widget.controller.hasLocalBookChanges ? 'Yes (auto refresh paused)' : 'No',
                      ),
                      _BackendInfoRow(
                        label: 'Last backend sync',
                        value: syncLabel,
                        isLast: backendStatus == null,
                      ),
                      if (backendStatus != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6.resolveFrom(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            backendStatus,
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                      ],
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

class _BackendInfoRow extends StatelessWidget {
  const _BackendInfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSyncLabel(String? iso) {
  if (iso == null || iso.trim().isEmpty) return 'Never';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$mm-$dd $hh:$min';
}
