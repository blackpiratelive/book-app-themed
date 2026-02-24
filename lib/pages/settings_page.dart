import 'dart:async';

import 'package:book_app_themed/services/local_backup_service.dart';
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
  static const String _defaultApiUrl = AppController.defaultBackendApiUrl;
  static const String _appVersionLabel = '0.1.5+6';

  late final TextEditingController _apiController;
  late String _password;
  String? _localStatusMessage;
  bool _isBackupBusy = false;
  bool _showAdvancedBackend = false;
  int _versionTapCount = 0;

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
    final isAccountMode = widget.controller.usesAccountBackend;
    final next = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: Text(
                isAccountMode ? 'Firebase ID Token' : 'Backend Password',
              ),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CupertinoTextField(
                  controller: controller,
                  obscureText: !isAccountMode,
                  autocorrect: false,
                  enableSuggestions: false,
                  placeholder: widget.controller.backendCredentialPlaceholder,
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
          ? '${widget.controller.backendCredentialLabel} cleared.'
          : '${widget.controller.backendCredentialLabel} saved locally.';
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
            widget.controller.lastBackendStatusMessage ??
            'Connection test failed.';
      });
    }
  }

  Future<void> _forceReload() async {
    await _persistBackendConfig();
    if (!mounted) return;

    if (widget.controller.hasLocalBookChanges) {
      final confirmed =
          await showCupertinoDialog<bool>(
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
            widget.controller.lastBackendStatusMessage ??
            'Backend refresh failed.';
      });
    }
  }

  Future<void> _logout() async {
    final confirmed =
        await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Log out?'),
            content: const Text('This signs you out on this device.'),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.controller.logout();
  }

  void _onVersionTap() {
    setState(() {
      _versionTapCount += 1;
      if (_versionTapCount >= 3) {
        _showAdvancedBackend = !_showAdvancedBackend;
        _versionTapCount = 0;
        _localStatusMessage = _showAdvancedBackend
            ? 'Advanced backend settings revealed.'
            : 'Advanced backend settings hidden.';
      }
    });
  }

  Future<void> _exportLocalBackup() async {
    if (_isBackupBusy) return;
    setState(() {
      _isBackupBusy = true;
      _localStatusMessage = 'Preparing local backup export...';
    });
    try {
      final path = await widget.controller.exportLocalBackup();
      if (!mounted) return;
      setState(() => _localStatusMessage = 'Exported local backup to: $path');
    } on LocalBackupException catch (e) {
      if (!mounted) return;
      setState(() => _localStatusMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _localStatusMessage = 'Local backup export failed.');
    } finally {
      if (mounted) {
        setState(() => _isBackupBusy = false);
      }
    }
  }

  Future<void> _importLocalBackup() async {
    if (_isBackupBusy) return;
    final confirmed =
        await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Import local backup?'),
            content: const Text(
              'This replaces current local books, settings, guest/account session UI state, and backend config on this device.',
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Import'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() {
      _isBackupBusy = true;
      _localStatusMessage = 'Importing local backup...';
    });
    try {
      await widget.controller.importLocalBackup();
      if (!mounted) return;
      _apiController.text = widget.controller.backendApiUrl.isEmpty
          ? _defaultApiUrl
          : widget.controller.backendApiUrl;
      _password = widget.controller.backendPassword;
      setState(
        () => _localStatusMessage = 'Local backup imported successfully.',
      );
    } on LocalBackupException catch (e) {
      if (!mounted) return;
      setState(() => _localStatusMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _localStatusMessage = 'Local backup import failed.');
    } finally {
      if (mounted) {
        setState(() => _isBackupBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.isBackendBusy;
        final isAccountMode = widget.controller.usesAccountBackend;
        final effectiveApiUrl = widget.controller.effectiveBackendApiUrl;
        if (_apiController.text != effectiveApiUrl) {
          _apiController.value = _apiController.value.copyWith(
            text: effectiveApiUrl,
            selection: TextSelection.collapsed(offset: effectiveApiUrl.length),
            composing: TextRange.empty,
          );
        }
        final backendStatus =
            _localStatusMessage ?? widget.controller.lastBackendStatusMessage;
        final syncLabel = _formatSyncLabel(
          widget.controller.lastBackendSyncAtIso,
        );

        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                SectionCard(
                  title: 'Account',
                  child: _AccountSummaryCard(
                    controller: widget.controller,
                    onLogout: widget.controller.isLoggedIn ? _logout : null,
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Local Data (Guest Mode)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Guest mode is local mode. Export/import saves books, preferences, session UI state, backend settings, and local cover image files.',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              color: CupertinoColors.activeBlue,
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _isBackupBusy
                                  ? null
                                  : _exportLocalBackup,
                              child: _isBackupBusy
                                  ? const CupertinoActivityIndicator(
                                      color: CupertinoColors.white,
                                    )
                                  : const Text(
                                      'Export Backup',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              color: CupertinoColors.tertiarySystemFill
                                  .resolveFrom(context),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _isBackupBusy
                                  ? null
                                  : _importLocalBackup,
                              child: Text(
                                'Import Backup',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: CupertinoColors.label.resolveFrom(
                                    context,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Appearance',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: CupertinoColors.tertiarySystemFill
                                  .resolveFrom(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              CupertinoIcons.moon_stars_fill,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Theme',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.label.resolveFrom(
                                      context,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Auto follows your device. You can also force Light or Dark.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CupertinoSlidingSegmentedControl<AppThemeMode>(
                        groupValue: widget.controller.themeMode,
                        children: const <AppThemeMode, Widget>{
                          AppThemeMode.system: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text('Auto'),
                          ),
                          AppThemeMode.light: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text('Light'),
                          ),
                          AppThemeMode.dark: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text('Dark'),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value == null) return;
                          widget.controller.setThemeMode(value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'About',
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _onVersionTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemFill.resolveFrom(
                          context,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            CupertinoIcons.info_circle_fill,
                            size: 18,
                            color: CupertinoColors.activeBlue.resolveFrom(
                              context,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Version',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _appVersionLabel,
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showAdvancedBackend) ...<Widget>[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Backend',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isAccountMode
                              ? 'Account Backend API (Fixed)'
                              : 'Backend API',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        CupertinoTextField(
                          controller: _apiController,
                          readOnly: isAccountMode,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          placeholder: effectiveApiUrl,
                          onEditingComplete: () {
                            FocusScope.of(context).unfocus();
                            unawaited(_persistBackendConfig());
                          },
                          onSubmitted: (_) =>
                              unawaited(_persistBackendConfig()),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground.resolveFrom(
                              context,
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: CupertinoColors.tertiarySystemFill
                                  .resolveFrom(context),
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
                                  widget.controller.backendCredentialLabel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.label.resolveFrom(
                                      context,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _password.trim().isEmpty
                                      ? 'Not set'
                                      : 'Saved',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  CupertinoIcons.chevron_forward,
                                  size: 16,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isAccountMode)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Logged-in mode uses the new API at ${AppController.accountBackendApiUrl}. Paste a Firebase ID token to authenticate backend sync. Legacy notes.blackpiratex.com is only used in guest mode.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                color: CupertinoColors.activeBlue,
                                borderRadius: BorderRadius.circular(12),
                                onPressed: busy ? null : _testConnection,
                                child: busy
                                    ? const CupertinoActivityIndicator()
                                    : const Text(
                                        'Test Connection',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: CupertinoColors.white,
                                        ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                color: CupertinoColors.tertiarySystemFill
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(12),
                                onPressed: busy ? null : _forceReload,
                                child: Text(
                                  'Force Reload From API',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: CupertinoColors.label.resolveFrom(
                                      context,
                                    ),
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
                          value: widget.controller.hasLocalBookChanges
                              ? 'Yes (auto refresh paused)'
                              : 'No',
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6.resolveFrom(
                                context,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              backendStatus,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.label.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({required this.controller, required this.onLogout});

  final AppController controller;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final isLoggedIn = controller.isLoggedIn;
    final isGuest = controller.isGuestSession;
    final name = controller.authDisplayName.isEmpty
        ? (isGuest ? 'Guest' : 'Reader')
        : controller.authDisplayName;
    final email = controller.authEmail.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLoggedIn
                      ? CupertinoColors.activeBlue.withValues(alpha: 0.14)
                      : CupertinoColors.systemGrey.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isGuest
                      ? CupertinoIcons.person
                      : CupertinoIcons.person_crop_circle_fill,
                  color: isLoggedIn
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: label,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.authStatusLabel,
                      style: TextStyle(fontSize: 13, color: secondary),
                    ),
                  ],
                ),
              ),
              if (isLoggedIn)
                _VerificationBadge(verified: controller.authEmailVerified),
            ],
          ),
          if (email.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(CupertinoIcons.mail_solid, size: 16, color: secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: TextStyle(fontSize: 14, color: label),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onLogout != null) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: CupertinoColors.systemRed.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
                onPressed: () => onLogout!(),
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified
        ? CupertinoColors.activeGreen
        : CupertinoColors.systemOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            verified
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.exclamationmark_circle_fill,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            verified ? 'Verified' : 'Unverified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
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
