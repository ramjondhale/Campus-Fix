import '../models/reporter_identity.dart';

/// Longest reveal reason (after trimming) an implementation accepts, in
/// characters. Same limit as every other free-text note (core rule P9).
const int kRevealReasonMaxLength = 500;

/// The one door through which an admin obtains a reporter's identity
/// (phase-2-firebase-plan seam S-5, privacy-spec PV-4 / PV-5 / LK-8, decision
/// D4).
///
/// A complaint read through `ComplaintRepository` never carries the real
/// reporter identity in a Phase 2 backend (the repository assembles a redacted
/// placeholder, plan section 5.3). The identity is released **only** by this
/// interface, which is also where the audit entry is written, so that "who
/// looked at whose identity, and why" cannot be bypassed by reading the
/// complaint.
///
/// Implementations must:
///
/// * release the identity to an `admin` only (anything else throws);
/// * require a non-blank [reveal] `reason` (D4: required reason);
/// * be **fail-closed**: if the audit entry cannot be written, the identity is
///   not returned;
/// * write exactly one audit entry per call (one per reveal, not per page
///   view), containing no reporter identity itself.
///
/// The offline prototype binds no revealer: its admin detail already holds the
/// identity in memory and has no audit store (the admin app's
/// `reporterIdentityRevealerProvider` is `null` there).
abstract interface class ReporterIdentityRevealer {
  /// The identity of the reporter of complaint [complaintId], after recording
  /// the audit entry with [reason] (required, non-blank, at most
  /// [kRevealReasonMaxLength] characters after trimming).
  ///
  /// Throws an [ArgumentError] for a blank or over-long [reason], a
  /// [StateError] when the complaint has no stored identity or the caller may
  /// not reveal it, and lets backend failures propagate unchanged.
  Future<ReporterIdentity> reveal(String complaintId, {String? reason});
}
