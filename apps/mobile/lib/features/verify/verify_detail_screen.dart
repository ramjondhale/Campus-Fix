import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../complaint_details/complaint_details_view.dart';
import '../work/work_widgets.dart' show WorkActionBar, kNoteVisibilityHelper;
import 'verify_widgets.dart';

/// M-17 Verify (the repair a verifier judges): the evidence side by side
/// (before and after photos, the resolution note, the description, the
/// location, the priority and the public timeline) with two decisions.
/// [complaintId] comes from the route (`/verify/:id`); routes carry only the
/// ID (LK-5). The class keeps its M-17 route name; the screen verifies or
/// rejects and never closes: closing (T6) is an admin-only action on the web
/// console.
///
/// * **Verify** (T5, `resolved -> verified`): the note is optional; a confirm
///   dialog first.
/// * **Reject** (T7, `resolved -> inProgress`): sends the job back to
///   maintenance, which sees it under Rework. The note is the reason and is
///   required (AC-43): the button stays disabled until there is one. A confirm
///   dialog first.
///
/// One note field serves both decisions (up to 500, counter), like the one
/// comment box of a review. A rule that blocks an action shows its message
/// here, and a failed write keeps the note and offers Retry (screens-spec
/// G-4). On success the verifier goes back to the queue (the complaint has
/// left it).
///
/// Consumes `verifyJobProvider` (public views only): the verifier never sees
/// who reported the complaint. An unknown id, or one that is not awaiting
/// verification, shows E-404.
class VerifyCloseScreen extends ConsumerStatefulWidget {
  const VerifyCloseScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  ConsumerState<VerifyCloseScreen> createState() => _VerifyCloseScreenState();
}

class _VerifyCloseScreenState extends ConsumerState<VerifyCloseScreen> {
  final TextEditingController _note = TextEditingController();

  /// The last job seen, kept while the screen leaves: the moment an action
  /// lands the complaint is no longer `resolved`, and the page must not flash
  /// "not found" on its way back to the queue.
  VerifyJob? _held;

  /// An action was accepted and the screen is on its way out.
  bool _finishing = false;

  String get _id => widget.complaintId;

  bool get _noteFilled => _note.text.trim().isNotEmpty;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  VerifyActionNotifier get _actions => ref.read(verifyActionProvider.notifier);

  Future<void> _confirmVerify() async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: 'Mark $_id as verified?',
      message: 'This confirms the repair. An admin closes the complaint.',
      confirmLabel: 'Verify',
    );
    if (confirmed != true || !mounted) return;
    await _verify();
  }

  Future<void> _verify() async {
    final VerifyActionResult? result = await _actions.verify(
      _id,
      note: _note.text,
    );
    if (result == null || !mounted || !result.ok) return;
    _leave('Repair verified');
  }

  Future<void> _confirmReject() async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: 'Reject $_id?',
      message:
          'The job goes back to maintenance with your reason, and the '
          'department is notified.',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _reject();
  }

  Future<void> _reject() async {
    if (!_noteFilled) return;
    final VerifyActionResult? result = await _actions.reject(
      _id,
      note: _note.text,
    );
    if (result == null || !mounted || !result.ok) return;
    _leave('Sent back for rework');
  }

  /// The action was accepted: say so and go back to the queue.
  void _leave(String message) {
    setState(() => _finishing = true);
    AppToast.show(context, message, kind: AppToastKind.success);
    context.go(AppRoutes.verify);
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<VerifyJob?> job = ref.watch(verifyJobProvider(_id));
    final VerifyJob? current = job.value;
    if (current != null) {
      _held = current;
    } else if (_finishing && _held != null) {
      job = AsyncData<VerifyJob?>(_held);
    }
    final VerifyJob? shown = job.value;

    return ComplaintDetailsPage(
      title: 'Verify repair',
      value: job.whenData((VerifyJob? j) => j?.complaint),
      mode: ComplaintDetailsMode.owner,
      onRetry: () => refreshComplaints(ref),
      bodyBuilder: (BuildContext context, PublicComplaintView c) =>
          shown == null ? const SizedBox.shrink() : _buildBody(shown),
    );
  }

  Widget _buildBody(VerifyJob job) {
    final VerifyActionState action = ref.watch(verifyActionProvider);
    final bool verifying = action.runningFor(_id, VerifyActionKind.verify);
    final bool rejecting = action.runningFor(_id, VerifyActionKind.reject);
    final bool busy = action.busy || _finishing;
    final bool canVerify = job.canVerify && !busy;
    final bool canReject = job.canReject && _noteFilled && !busy;
    final VerifyActionKind? failed = action.anyFailedFor(_id)
        ? action.kind
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ComplaintDetailsView(
            complaint: job.complaint,
            leading: <Widget>[
              if (job.evidenceProblems.isNotEmpty)
                InlineBanner(
                  kind: FeedbackKind.warning,
                  title: "Can't verify this repair",
                  message:
                      '${job.evidenceProblems.join(' ')} '
                      'You can send it back for rework.',
                ),
            ],
            trailing: <Widget>[
              AppTextField.multiline(
                label: 'Note',
                helperText:
                    'Optional to verify, required to reject. '
                    '$kNoteVisibilityHelper',
                controller: _note,
                maxLength: VerifyLimits.noteMax,
                enabled: !busy,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        WorkActionBar(
          children: <Widget>[
            if (failed != null)
              VerifyFailureBanner(
                state: action,
                title: failed == VerifyActionKind.verify
                    ? "Couldn't verify the repair"
                    : "Couldn't send the job back",
                onRetry: failed == VerifyActionKind.verify
                    ? (canVerify ? _verify : null)
                    : (canReject ? _reject : null),
              ),
            AppButton(
              label: 'Verify',
              size: AppButtonSize.lg,
              expand: true,
              loading: verifying,
              onPressed: canVerify ? _confirmVerify : null,
            ),
            AppButton(
              label: 'Reject',
              variant: AppButtonVariant.destructiveOutlined,
              size: AppButtonSize.lg,
              expand: true,
              loading: rejecting,
              onPressed: canReject ? _confirmReject : null,
            ),
          ],
        ),
      ],
    );
  }
}
