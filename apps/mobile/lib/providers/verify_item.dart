// One resolved complaint as the signed-in verifier sees it (screens-spec
// M-17).
//
// Built from public views only: the complaint's `PublicComplaintView` and the
// status machine's L1 matrix. The screen asks this provider what it may offer
// instead of re-deriving it. The verifier verifies (T5) or rejects (T7); there
// is no close here: T6 is an admin-only action on the web console.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'complaints.dart';
import 'session.dart';

/// A complaint awaiting verification, with what the verifier may do with it.
@immutable
class VerifyJob {
  const VerifyJob({required this.complaint});

  /// The complaint, as a public view.
  final PublicComplaintView complaint;

  ComplaintStatus get status => complaint.status;

  List<ComplaintStatus> get _next =>
      StatusMachine.nextStatuses(status, UserRole.verifier);

  /// The repair evidence the verifier judges is there: at least one
  /// after-repair photo (P1) and a resolution note (P2).
  bool get hasAfterPhoto => complaint.afterPhotos.isNotEmpty;
  bool get hasResolutionNote =>
      (complaint.resolutionNote ?? '').trim().isNotEmpty;

  /// Why the repair cannot be verified, in the words of the core rules P1/P2;
  /// empty when the evidence is complete (corrupt data only: a resolve always
  /// carries both).
  List<String> get evidenceProblems => <String>[
    if (!hasAfterPhoto) 'Add at least one after-repair photo.',
    if (!hasResolutionNote) 'Add a resolution note.',
  ];

  /// "Verify" (T5) is offered and the evidence is complete.
  bool get canVerify =>
      _next.contains(ComplaintStatus.verified) && evidenceProblems.isEmpty;

  /// "Reject" (T7, send back for rework) is offered. It needs no evidence:
  /// missing evidence is itself a reason to send the job back.
  bool get canReject => _next.contains(ComplaintStatus.inProgress);
}

/// The job [id] for the signed-in verifier: `null` once loaded when there is
/// no such complaint or it is not awaiting verification (E-404: never
/// reveals more than the screen needs, screens-spec G-6).
final verifyJobProvider = Provider.family<AsyncValue<VerifyJob?>, String>((
  ref,
  id,
) {
  final AppUser? user = ref.watch(sessionProvider);
  return ref.watch(complaintViewProvider(id)).whenData((
    PublicComplaintView? c,
  ) {
    if (c == null ||
        user == null ||
        user.role != UserRole.verifier ||
        c.status != ComplaintStatus.resolved) {
      return null;
    }
    return VerifyJob(complaint: c);
  });
});
