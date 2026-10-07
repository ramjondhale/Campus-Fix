// One job as the signed-in maintenance worker sees it (screens-spec M-14,
// M-15).
//
// Built from public views only: the complaint's `PublicComplaintView`, the
// worker's own `workQueueProvider` (which already resolved department and
// claim on the raw complaint, privacy-spec §5.3) and the status machine's L1
// matrix. The screens ask this provider what they may offer instead of
// re-deriving it.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'complaints.dart';
import 'session.dart';

/// A job of the worker's own department, with what the worker may do with it.
@immutable
class WorkJob {
  const WorkJob({
    required this.complaint,
    required this.mine,
    required this.rework,
    required this.reworkNote,
  });

  /// The job, as a public view.
  final PublicComplaintView complaint;

  /// Whether it is in the worker's own queue: unclaimed work waiting to start,
  /// or work the worker claimed.
  final bool mine;

  /// Whether a verifier sent it back (an `inProgress` job whose latest event
  /// was not the worker's own start).
  final bool rework;

  /// The verifier's rejection note when [rework] (public timeline text).
  final String? reworkNote;

  ComplaintStatus get status => complaint.status;

  List<ComplaintStatus> get _next =>
      StatusMachine.nextStatuses(status, UserRole.maintenance);

  /// "Start work" (T3) is offered: the job is `assigned`. A claim by a
  /// colleague still shows the P7 message when it is tried.
  bool get canStart => _next.contains(ComplaintStatus.inProgress);

  /// "Mark as resolved" (T4) is offered: the job is `inProgress` and claimed
  /// by the worker.
  bool get canResolve => _next.contains(ComplaintStatus.resolved) && mine;

  /// The job is being worked on by a colleague.
  bool get claimedByColleague =>
      _next.contains(ComplaintStatus.resolved) && !mine;
}

bool _isRework(PublicComplaintView c) {
  if (c.status != ComplaintStatus.inProgress || c.timeline.isEmpty) {
    return false;
  }
  final PublicStatusEvent last = c.timeline.last;
  return last.status == ComplaintStatus.inProgress &&
      last.actorRole != UserRole.maintenance;
}

/// The job [id] for the signed-in maintenance worker: `null` once loaded when
/// there is no such complaint or it belongs to another department (E-404:
/// never reveals whether it exists, screens-spec G-6).
final workJobProvider = Provider.family<AsyncValue<WorkJob?>, String>((
  ref,
  id,
) {
  final AppUser? user = ref.watch(sessionProvider);
  final AsyncValue<WorkQueue> queue = ref.watch(workQueueProvider);
  return ref.watch(complaintViewProvider(id)).whenData((
    PublicComplaintView? c,
  ) {
    if (c == null ||
        user == null ||
        user.role != UserRole.maintenance ||
        c.assignedDepartment == null ||
        c.assignedDepartment != user.department) {
      return null;
    }
    final WorkQueue q = queue.value ?? const WorkQueue();
    final bool mine = <PublicComplaintView>[
      ...q.toStart,
      ...q.inProgress,
      ...q.rework,
    ].any((PublicComplaintView v) => v.id == c.id);
    final bool rework = _isRework(c);
    return WorkJob(
      complaint: c,
      mine: mine,
      rework: rework,
      reworkNote: rework ? c.timeline.last.note : null,
    );
  });
});
