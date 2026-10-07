import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

/// Whether the "Demo accounts" quick-fill is shown (screens-spec G-11). On by
/// default for the prototype; Phase 2 builds drop it with
/// `--dart-define=SHOW_DEMO_ACCOUNTS=false`.
const bool kShowDemoAccounts = bool.fromEnvironment(
  'SHOW_DEMO_ACCOUNTS',
  defaultValue: true,
);

enum _Failure { invalidCredentials, unexpected }

/// M-01 Login: ID number + password against the mock auth repository, with a
/// "Demo accounts" quick-fill. On success the session changes and the router's
/// auth redirect leaves this screen; an admin account starts no session and
/// gets the web-console notice instead (AC-04).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _submitting = false;
  bool _adminNotice = false;
  _Failure? _failure;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  /// AC-01: Sign in stays disabled while either field is empty.
  bool get _canSubmit =>
      !_submitting && _id.text.trim().isNotEmpty && _password.text.isNotEmpty;

  void _edited(String _) => setState(() {
    _failure = null;
    _adminNotice = false;
  });

  void _quickFill(MockAccount account) {
    setState(() {
      _id.text = account.user.idNumber;
      _password.text = account.password;
      _failure = null;
      _adminNotice = false;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _failure = null;
      _adminNotice = false;
    });
    SignInOutcome? outcome;
    try {
      outcome = await ref
          .read(sessionProvider.notifier)
          .signIn(_id.text.trim(), _password.text);
    } catch (_) {
      outcome = null;
    }
    // A successful sign-in has already left this screen via the router.
    if (!mounted) return;
    setState(() {
      _submitting = false;
      switch (outcome) {
        case SignInOutcome.success:
          break;
        case SignInOutcome.invalidCredentials:
          _failure = _Failure.invalidCredentials;
          _password.clear(); // AC-02
        case SignInOutcome.adminUsesWeb:
          _adminNotice = true;
          _password.clear();
        case null:
          _failure = _Failure.unexpected; // keep the input, offer Retry
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<MockAccount> demoAccounts = kShowDemoAccounts
        ? ref.watch(seedDataProvider).demoAccounts
        : const <MockAccount>[];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.dialogMaxWidthMobile,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Brand(),
                  const SizedBox(height: AppSpace.s8),
                  AppTextField(
                    label: 'ID number',
                    required: true,
                    controller: _id,
                    enabled: !_submitting,
                    leadingIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    onChanged: _edited,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  AppTextField.password(
                    label: 'Password',
                    required: true,
                    controller: _password,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.done,
                    onChanged: _edited,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_failure != null || _adminNotice) ...<Widget>[
                    const SizedBox(height: AppSpace.s4),
                    _buildNotice(),
                  ],
                  const SizedBox(height: AppSpace.s6),
                  AppButton(
                    label: 'Sign in',
                    size: AppButtonSize.lg,
                    expand: true,
                    loading: _submitting,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  if (demoAccounts.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpace.s8),
                    Semantics(
                      header: true,
                      child: Text('Demo accounts', style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      'Prototype only. Tap one to fill the sign-in form.',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    for (final MockAccount account in demoAccounts) ...<Widget>[
                      AppButton(
                        key: ValueKey<String>('demo-${account.user.role.name}'),
                        label: account.user.role.label,
                        variant: AppButtonVariant.secondary,
                        leadingIcon: RolePill.iconFor(account.user.role),
                        expand: true,
                        onPressed: _submitting
                            ? null
                            : () => _quickFill(account),
                      ),
                      const SizedBox(height: AppSpace.s2),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotice() {
    if (_adminNotice) {
      return const InlineBanner(
        kind: FeedbackKind.info,
        title: 'Admins use the web console',
        message: 'Sign in to the admin console on the web instead.',
      );
    }
    return switch (_failure!) {
      _Failure.invalidCredentials => const InlineBanner(
        kind: FeedbackKind.error,
        message: 'ID or password is incorrect',
      ),
      _Failure.unexpected => InlineBanner(
        kind: FeedbackKind.error,
        message: "Couldn't sign you in. Please try again.",
        actionLabel: 'Retry',
        onAction: _submit,
      ),
    };
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: AppSpace.s12,
            height: AppSpace.s12,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: AppRadius.br5,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.build_outlined,
              size: 28,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        Semantics(
          header: true,
          child: Text('CampusFix', style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpace.s1),
        Text(
          'Sign in with your ID number',
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
