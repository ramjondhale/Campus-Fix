// The report-submit controller (screens-spec M-07, privacy-spec §5.1).
//
// This is the ONLY file in the app that may touch `ReporterIdentity`: it maps
// the signed-in `AppUser` to the reporter of the new complaint and hands it to
// `ComplaintService.submit`. The identity never leaves this file: what it
// returns to the UI is a PII-free `SubmittedReport` (Complaint ID + priority).
// The architecture guards allow-list exactly this path.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report_draft.dart';
import 'services.dart';
import 'session.dart';

/// What the UI may know about a filed complaint: its generated ID and the
/// priority the engine computed for it (screens-spec M-08). No identity.
@immutable
class SubmittedReport {
  const SubmittedReport({required this.complaintId, required this.priority});

  final String complaintId;
  final Priority priority;
}

/// Progress of a submit.
enum ReportSubmitStatus { idle, submitting, failed }

@immutable
class ReportSubmitState {
  const ReportSubmitState({
    this.status = ReportSubmitStatus.idle,
    this.last,
    this.error,
  });

  final ReportSubmitStatus status;

  /// The most recent successful submit (shown by Confirmation even when the
  /// re-fetch of the stored complaint fails).
  final SubmittedReport? last;

  /// A user-facing message when [status] is `failed`.
  final String? error;

  bool get submitting => status == ReportSubmitStatus.submitting;
}

/// Files the current [reportDraftProvider] as the signed-in reporter.
class ReportSubmitNotifier extends Notifier<ReportSubmitState> {
  @override
  ReportSubmitState build() => const ReportSubmitState();

  /// Submits the draft. Returns the filed report, or `null` when nothing was
  /// filed: already in flight (a second tap is ignored, AC-18), the draft is
  /// incomplete, nobody is signed in as a reporter, or the write failed (then
  /// [ReportSubmitState.error] says so and the draft is kept intact, G-4).
  /// On success the draft is cleared.
  Future<SubmittedReport?> submit() async {
    if (state.submitting) return null;
    final AppUser? user = ref.read(sessionProvider);
    final ReportDraft draft = ref.read(reportDraftProvider);
    final ProblemCategory? category = draft.category;
    final String? floor = draft.floor;
    if (user == null ||
        user.role != UserRole.reporter ||
        category == null ||
        floor == null ||
        !draft.isComplete) {
      state = ReportSubmitState(
        status: ReportSubmitStatus.failed,
        last: state.last,
        error: 'Your report is not complete. Check each step and try again.',
      );
      return null;
    }

    state = ReportSubmitState(
      status: ReportSubmitStatus.submitting,
      last: state.last,
    );
    try {
      // The one place the reporter's identity is built (privacy-spec §5.1).
      final ReporterIdentity reporter = ReporterIdentity(
        userId: user.id,
        fullName: user.displayName,
        idNumber: user.idNumber,
        email: user.email,
      );
      final saved = await ref
          .read(complaintServiceProvider)
          .submit(
            reporter: reporter,
            category: category,
            description: draft.trimmedDescription,
            building: draft.trimmedBuilding,
            floor: floor,
            room: draft.trimmedRoom,
            beforePhotos: draft.photos,
            severity: draft.severity,
            peopleAffected: draft.peopleAffected,
            safetyFlag: draft.safetyFlag || category == ProblemCategory.safety,
          );
      final SubmittedReport report = SubmittedReport(
        complaintId: saved.id,
        priority: saved.effectivePriority,
      );
      state = ReportSubmitState(last: report);
      ref.read(reportDraftProvider.notifier).reset();
      return report;
    } catch (_) {
      state = ReportSubmitState(
        status: ReportSubmitStatus.failed,
        last: state.last,
        error:
            "We couldn't submit your report. Check your connection and "
            'try again. Nothing you entered was lost.',
      );
      return null;
    }
  }

  /// Dismisses a failure banner.
  void clearError() {
    if (state.status == ReportSubmitStatus.failed) {
      state = ReportSubmitState(last: state.last);
    }
  }
}

/// The report-submit controller.
final reportSubmitProvider =
    NotifierProvider<ReportSubmitNotifier, ReportSubmitState>(
      ReportSubmitNotifier.new,
    );
