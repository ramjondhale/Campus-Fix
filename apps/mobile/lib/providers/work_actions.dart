// The maintenance write controller (screens-spec M-14 Start work, M-15 Mark
// resolved).
//
// It sits in the provider layer on purpose: it reads the raw complaint from the
// repository and hands it to `ComplaintService` (the L3 executor), which is
// exactly what a widget must never do (data-model §3.5). What it returns to
// the UI is a PII-free `WorkActionResult` (success, or why it did not happen);
// the stored `Complaint` the service hands back is dropped here. The actor is
// the signed-in user. Nothing in this file touches a reporter's identity: the
// start-work (T3) and resolve (T4) transitions do not need it.
//
// After a successful action the repository's change stream updates the public
// providers (`complaintViewProvider`, `workQueueProvider`), so the screens
// refresh themselves.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories.dart';
import 'services.dart';
import 'session.dart';

/// The two write actions of a maintenance worker.
enum WorkActionKind {
  /// T3: `assigned -> inProgress` (claims the job).
  startWork,

  /// T4: `inProgress -> resolved` (repair proof).
  resolve,
}

/// How a work action ended, as far as the UI is concerned.
enum WorkActionOutcome {
  /// The transition was applied.
  success,

  /// The rules said no (P1/P2/P6/P7/P8 ...): [WorkActionResult.messages] says
  /// why. Nothing was changed.
  blocked,

  /// The write itself failed (outage, unexpected error). Nothing was lost on
  /// the user's side: the screen keeps its input and offers Retry.
  failed,
}

/// What the UI may know about a finished action: the outcome and the
/// user-facing messages. No complaint, no identity.
@immutable
class WorkActionResult {
  const WorkActionResult._(this.outcome, this.messages);

  const WorkActionResult.success()
    : this._(WorkActionOutcome.success, const <String>[]);

  WorkActionResult.blocked(List<String> messages)
    : this._(WorkActionOutcome.blocked, List<String>.unmodifiable(messages));

  WorkActionResult.failed(String message)
    : this._(WorkActionOutcome.failed, <String>[message]);

  /// How the action ended.
  final WorkActionOutcome outcome;

  /// The user-facing text: why a [WorkActionOutcome.blocked] action did not
  /// happen (the rule messages, e.g. "Already claimed by a colleague.") or a
  /// friendly sentence for a [WorkActionOutcome.failed] one; empty on success.
  final List<String> messages;

  bool get ok => outcome == WorkActionOutcome.success;
}

/// Progress of the action in flight, or the last failure.
enum WorkActionStatus { idle, running, failed }

/// The controller's state. [complaintId] and [kind] say which action the
/// [status] belongs to, so a screen only reacts to its own complaint.
@immutable
class WorkActionState {
  const WorkActionState({
    this.status = WorkActionStatus.idle,
    this.complaintId,
    this.kind,
    this.blocked = false,
    this.messages = const <String>[],
  });

  final WorkActionStatus status;
  final String? complaintId;
  final WorkActionKind? kind;

  /// Whether a [WorkActionStatus.failed] state is a rule block (true) or a
  /// failed write (false).
  final bool blocked;

  /// The user-facing text of a failure: the rule messages when [blocked], a
  /// friendly sentence otherwise.
  final List<String> messages;

  /// Whether any action is in flight (a second tap is ignored).
  bool get busy => status == WorkActionStatus.running;

  bool _is(String id, WorkActionKind k, WorkActionStatus s) =>
      status == s && complaintId == id && kind == k;

  /// Whether [kind] on [id] is in flight.
  bool runningFor(String id, WorkActionKind kind) =>
      _is(id, kind, WorkActionStatus.running);

  /// Whether the last [kind] on [id] failed (blocked or errored).
  bool failedFor(String id, WorkActionKind kind) =>
      _is(id, kind, WorkActionStatus.failed);
}

/// Runs Start work (T3) and Mark resolved (T4) as the signed-in maintenance
/// worker.
class WorkActionNotifier extends Notifier<WorkActionState> {
  @override
  WorkActionState build() => const WorkActionState();

  /// T3: starts (claims) [complaintId], with an optional [note]. Returns the
  /// result, or `null` when another action is already in flight (a second tap
  /// is ignored, screens-spec G-3).
  Future<WorkActionResult?> startWork(String complaintId, {String? note}) {
    final String? clean = note?.trim();
    return _run(
      complaintId,
      WorkActionKind.startWork,
      (ComplaintService service, Complaint c, AppUser actor) =>
          service.startWork(
            c,
            actor,
            note: (clean == null || clean.isEmpty) ? null : clean,
          ),
    );
  }

  /// T4: submits the repair proof of [complaintId]: [afterPhotos] and the
  /// [resolutionNote]. Returns `null` when another action is in flight.
  Future<WorkActionResult?> resolve(
    String complaintId, {
    required String resolutionNote,
    required List<Attachment> afterPhotos,
  }) => _run(
    complaintId,
    WorkActionKind.resolve,
    (ComplaintService service, Complaint c, AppUser actor) => service.resolve(
      c,
      actor,
      resolutionNote: resolutionNote.trim(),
      afterPhotos: afterPhotos,
    ),
  );

  Future<WorkActionResult?> _run(
    String complaintId,
    WorkActionKind kind,
    Future<ComplaintActionResult> Function(
      ComplaintService service,
      Complaint complaint,
      AppUser actor,
    )
    act,
  ) async {
    if (state.busy) return null;
    final AppUser? actor = ref.read(sessionProvider);
    if (actor == null || actor.role != UserRole.maintenance) {
      return _fail(
        complaintId,
        kind,
        blocked: true,
        messages: const <String>['Only maintenance staff can do this.'],
      );
    }

    state = WorkActionState(
      status: WorkActionStatus.running,
      complaintId: complaintId,
      kind: kind,
    );
    try {
      final Complaint? complaint = await ref
          .read(complaintRepositoryProvider)
          .byId(complaintId);
      if (complaint == null) {
        return _fail(
          complaintId,
          kind,
          blocked: true,
          messages: const <String>["We couldn't find that complaint."],
        );
      }
      final ComplaintActionResult result = await act(
        ref.read(complaintServiceProvider),
        complaint,
        actor,
      );
      if (!result.ok) {
        return _fail(
          complaintId,
          kind,
          blocked: true,
          messages: result.messages,
        );
      }
      if (ref.mounted) state = const WorkActionState();
      return const WorkActionResult.success();
    } catch (_) {
      return _fail(
        complaintId,
        kind,
        blocked: false,
        messages: <String>[_failureText(kind)],
      );
    }
  }

  /// Records a failure and returns it as a result. Safe to call after the
  /// provider was disposed (the user left the screen while it was running).
  WorkActionResult _fail(
    String complaintId,
    WorkActionKind kind, {
    required bool blocked,
    required List<String> messages,
  }) {
    if (ref.mounted) {
      state = WorkActionState(
        status: WorkActionStatus.failed,
        complaintId: complaintId,
        kind: kind,
        blocked: blocked,
        messages: messages,
      );
    }
    return blocked
        ? WorkActionResult.blocked(messages)
        : WorkActionResult.failed(messages.first);
  }

  static String _failureText(WorkActionKind kind) => switch (kind) {
    WorkActionKind.startWork =>
      "We couldn't start the work. Check your connection and try again. "
          'Nothing you entered was lost.',
    WorkActionKind.resolve =>
      "We couldn't send your repair proof. Check your connection and try "
          'again. Your photos and note were kept.',
  };

  /// Dismisses a failure banner.
  void clearError() {
    if (state.status == WorkActionStatus.failed) {
      state = const WorkActionState();
    }
  }
}

/// The maintenance write controller. Auto-disposed so a failure banner never
/// outlives the screens that show it.
final workActionProvider =
    NotifierProvider.autoDispose<WorkActionNotifier, WorkActionState>(
      WorkActionNotifier.new,
    );
