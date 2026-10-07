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

/// A-01 Admin Login: ID number + password against the mock auth repository,
/// with a "Demo accounts" quick-fill for the admin and verifier accounts.
///
/// On success the session changes and the router's auth redirect leaves this
/// screen: an admin or verifier lands on the requested route (deep link
/// preserved) or the dashboard; a reporter or maintenance account is sent to
/// E-403 with Sign out (AC-45).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _submitting = false;
  _Failure? _failure;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Sign in stays disabled while either field is empty (AC-01).
  bool get _canSubmit =>
      !_submitting && _id.text.trim().isNotEmpty && _password.text.isNotEmpty;

  void _edited(String _) => setState(() => _failure = null);

  void _quickFill(MockAccount account) {
    setState(() {
      _id.text = account.user.idNumber;
      _password.text = account.password;
      _failure = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    SignInOutcome? outcome;
    try {
      outcome = await ref
          .read(sessionProvider.notifier)
          .signIn(_id.text.trim(), _password.text);
    } catch (_) {
      outcome = null;
    }
    // A signed-in user (console role or not) has already left this screen via
    // the router.
    if (!mounted) return;
    setState(() {
      _submitting = false;
      switch (outcome) {
        case SignInOutcome.success || SignInOutcome.notAuthorized:
          break;
        case SignInOutcome.invalidCredentials:
          _failure = _Failure.invalidCredentials;
          _password.clear(); // AC-02
        case null:
          _failure = _Failure.unexpected; // keep the input, offer Retry
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CampusColors colors = context.campusColors;
    final List<MockAccount> demoAccounts = kShowDemoAccounts
        ? <MockAccount>[
            for (final MockAccount a
                in ref.watch(seedDataProvider).demoAccounts)
              if (mayUseConsole(a.user.role)) a,
          ]
        : const <MockAccount>[];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.dialogMaxWidthMobile,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: AppRadius.br5,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _Brand(),
                      const SizedBox(height: AppSpace.s8),
                      AppTextField(
                        label: 'ID number',
                        required: true,
                        dense: true,
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
                        dense: true,
                        controller: _password,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.done,
                        onChanged: _edited,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_failure != null) ...<Widget>[
                        const SizedBox(height: AppSpace.s4),
                        _buildNotice(),
                      ],
                      const SizedBox(height: AppSpace.s6),
                      AppButton(
                        label: 'Sign in',
                        expand: true,
                        loading: _submitting,
                        onPressed: _canSubmit ? _submit : null,
                      ),
                      if (demoAccounts.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpace.s8),
                        Semantics(
                          header: true,
                          child: Text(
                            'Demo accounts',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s1),
                        Text(
                          'Prototype only. Choose one to fill the sign-in form.',
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        for (final MockAccount account
                            in demoAccounts) ...<Widget>[
                          AppButton(
                            key: ValueKey<String>(
                              'demo-${account.user.role.name}',
                            ),
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
        ),
      ),
    );
  }

  Widget _buildNotice() {
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
              size: AppIconSize.s24,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        Semantics(
          header: true,
          child: Text('CampusFix Admin', style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpace.s1),
        Text(
          'Sign in to the admin console',
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
