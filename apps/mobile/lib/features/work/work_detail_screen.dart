import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../complaint_details/complaint_details_view.dart';
import 'work_widgets.dart';

/// M-14 Work Detail (start / progress): the read-only summary of a job of the
/// worker's department, with its actions. [complaintId] comes from the route
/// (`/work/:id`); routes carry only the ID (LK-5).
///
/// * `assigned`: **Start work** (optional note up to 500) claims the job (T3);
///   the screen then updates in place (status In Progress, a timeline entry).
/// * `inProgress`, claimed by the worker: **Mark as resolved** opens the
///   After-Repair Upload (M-15).
/// * A rule that blocks an action (P6, P7, P8 ...) shows its message here.
///
/// The lookup is `workJobProvider` (public views only); a job that does not
/// exist or belongs to another department shows E-404.
class WorkDetailScreen extends ConsumerWidget {
  const WorkDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkJob?> job = ref.watch(workJobProvider(complaintId));
    return ComplaintDetailsPage(
      title: 'Work detail',
      value: job.whenData((WorkJob? j) => j?.complaint),
      mode: ComplaintDetailsMode.owner,
      onRetry: () => refreshComplaints(ref),
      bodyBuilder: (BuildContext context, PublicComplaintView c) =>
          _WorkDetailBody(complaintId: complaintId),
    );
  }
}

class _WorkDetailBody extends ConsumerStatefulWidget {
  const _WorkDetailBody({required this.complaintId});

  final String complaintId;

  @override
  ConsumerState<_WorkDetailBody> createState() => _WorkDetailBodyState();
}

class _WorkDetailBodyState extends ConsumerState<_WorkDetailBody> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final WorkActionResult? result = await ref
        .read(workActionProvider.notifier)
        .startWork(widget.complaintId, note: _note.text);
    if (result == null || !mounted || !result.ok) return;
    AppToast.show(context, 'Work started', kind: AppToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final WorkJob? job = ref.watch(workJobProvider(widget.complaintId)).value;
    if (job == null) return const SizedBox.shrink();
    final WorkActionState action = ref.watch(workActionProvider);
    final bool starting = action.runningFor(
      widget.complaintId,
      WorkActionKind.startWork,
    );
    final bool busy = action.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ComplaintDetailsView(
            complaint: job.complaint,
            leading: <Widget>[
              if (job.rework)
                InlineBanner(
                  kind: FeedbackKind.warning,
                  title: 'Rework needed',
                  message:
                      job.reworkNote ??
                      'A verifier sent this job back for more work.',
                ),
            ],
            trailing: <Widget>[
              if (job.canStart)
                AppTextField.multiline(
                  label: 'Note (optional)',
                  helperText: kNoteVisibilityHelper,
                  controller: _note,
                  maxLength: StartWorkLimits.noteMax,
                  enabled: !starting,
                ),
            ],
          ),
        ),
        WorkActionBar(
          children: <Widget>[
            if (action.failedFor(widget.complaintId, WorkActionKind.startWork))
              WorkFailureBanner(
                state: action,
                title: "Couldn't start the work",
                onRetry: job.canStart && !busy ? _start : null,
              ),
            if (job.canStart)
              AppButton(
                label: 'Start work',
                size: AppButtonSize.lg,
                expand: true,
                loading: starting,
                onPressed: busy ? null : _start,
              ),
            if (job.canResolve)
              AppButton(
                label: 'Mark as resolved',
                size: AppButtonSize.lg,
                expand: true,
                onPressed: () =>
                    context.push(AppRoutes.workResolve(widget.complaintId)),
              ),
            if (job.claimedByColleague)
              const InlineBanner(
                kind: FeedbackKind.info,
                message: 'Already claimed by a colleague.',
              ),
          ],
        ),
      ],
    );
  }
}
