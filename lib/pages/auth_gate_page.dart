import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/widgets/brand_app_icon.dart';
import 'package:flutter/cupertino.dart';

enum _AuthFormMode { login, signup }

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  _AuthFormMode _mode = _AuthFormMode.signup;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isSignup => _mode == _AuthFormMode.signup;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isSignup && name.isEmpty) {
      setState(() => _errorText = 'Enter a name to create an account.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Enter a valid email address.');
      return;
    }
    if (password.trim().isEmpty) {
      setState(() => _errorText = 'Enter a password.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    await widget.controller.completeFrontendAuth(
      displayName: _isSignup ? name : _fallbackNameFromEmail(email),
      email: email,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    await widget.controller.continueAsGuest();
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final card = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    );
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final accent = CupertinoTheme.of(context).primaryColor;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const BrandAppIcon(size: 52, borderRadius: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: label,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up or log in to sync later. You can also continue as a guest.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: secondary),
                      ),
                      const SizedBox(height: 18),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: CupertinoColors.separator
                                .resolveFrom(context)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              CupertinoSlidingSegmentedControl<_AuthFormMode>(
                                groupValue: _mode,
                                children: const <_AuthFormMode, Widget>{
                                  _AuthFormMode.signup: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Sign Up'),
                                  ),
                                  _AuthFormMode.login: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Log In'),
                                  ),
                                },
                                onValueChanged: _submitting
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _mode = value;
                                          _errorText = null;
                                        });
                                      },
                              ),
                              const SizedBox(height: 14),
                              if (_isSignup) ...<Widget>[
                                _CupertinoFormField(
                                  controller: _nameController,
                                  placeholder: 'Name',
                                  icon: CupertinoIcons.person_fill,
                                  textInputAction: TextInputAction.next,
                                  enabled: !_submitting,
                                ),
                                const SizedBox(height: 10),
                              ],
                              _CupertinoFormField(
                                controller: _emailController,
                                placeholder: 'Email',
                                icon: CupertinoIcons.mail_solid,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                enabled: !_submitting,
                                autocorrect: false,
                              ),
                              const SizedBox(height: 10),
                              _CupertinoFormField(
                                controller: _passwordController,
                                placeholder: 'Password',
                                icon: CupertinoIcons.lock_fill,
                                obscureText: true,
                                enabled: !_submitting,
                                autocorrect: false,
                                onSubmitted: (_) => _submit(),
                              ),
                              if (_errorText != null) ...<Widget>[
                                const SizedBox(height: 10),
                                Text(
                                  _errorText!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.systemRed
                                        .resolveFrom(context),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              CupertinoButton.filled(
                                onPressed: _submitting ? null : _submit,
                                borderRadius: BorderRadius.circular(12),
                                child: _submitting
                                    ? const CupertinoActivityIndicator(
                                        color: CupertinoColors.white,
                                      )
                                    : Text(
                                        _isSignup ? 'Create Account' : 'Log In',
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Frontend UI only for now. Backend auth will be wired later.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      CupertinoButton(
                        onPressed: _submitting ? null : _continueAsGuest,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(14),
                        color: card,
                        child: Text(
                          'Continue as Guest',
                          style: TextStyle(
                            color: label,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CupertinoFormField extends StatelessWidget {
  const _CupertinoFormField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autocorrect = true,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autocorrect;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 10),
            child: Icon(
              icon,
              size: 17,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          Expanded(
            child: CupertinoTextField.borderless(
              controller: controller,
              enabled: enabled,
              placeholder: placeholder,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              obscureText: obscureText,
              autocorrect: autocorrect,
              enableSuggestions: !obscureText,
              onSubmitted: onSubmitted,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

String _fallbackNameFromEmail(String email) {
  final localPart = email.split('@').first.trim();
  if (localPart.isEmpty) return 'Reader';
  return localPart;
}
