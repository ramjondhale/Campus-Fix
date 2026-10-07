// The verifier write controller (screens-spec M-17 Verify / Reject).
//
// Like the maintenance controller (`work_actions.dart`) it sits in the
// provider layer on purpose: it reads the raw complaint from the repository
// and hands it to `ComplaintService` (the L3 executor), which is exactly what
// a widget must never do (data-model §3.5). What it returns to the UI is a
// PII-free `VerifyActionResult` (success, or why it did not happen); the
// stored `Complaint` the service hands back is dropped here. The actor is the
// signed-in verifier. Nothing in this file touches a reporter's identity: the
// verify (T5) and reject (T7) transitions do not need it, and the verifier
// never sees it (privacy PV-4).
//
// The verifier VERIFIES (T5, `resolved -> verified`); closing (T6) is an
// admin-only action on the web console and has no mobile controller.
//
// After a successful action the repository's change stream updates the public
// providers (`complaintViewProvider`, `verificationQueueProvider`), so the
// screens refresh themselves.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories.dart';
import 'services.dart';
import 'session.dart';

/// Limit of the note of Verify (optional) and Reject (required) (screens-spec
/// M-17).
abstract final class VerifyLimits {
  static const int noteMax = 500;
}

/// The two write actions of a verifier.
enum VerifyActionKind {
  /// T5: `resolved -> verified` (the repair is good).
  verify,

  /// T7: `resolved -> inProgress` (the repair is inadequate; the job goes
  /// back to maintenance with the reason).
  reject,
}

/// How a verify action ended, as far as the UI is concerned.
enum VerifyActionOutcome {
  /// The transition was applied.
  success,

  /// The rules said no (P1/P3/P8 ...): [VerifyActionResult.messages] says why.
  /// Nothing was changed.
  blocked,

  /// The write itself failed (outage, unexpected error). Nothing was lost on
  /// the user's side: the screen keeps its input and offers Retry.
  failed,
}

/// What the UI may know about a finished action: the outcome and the
/// user-facing messages. No complaint, no identity.
@immutable
class VerifyActionResult {
  const VerifyActionResult._(this.outcome, this.messages);

  const VerifyActionResult.success()
    : this._(VerifyActionOutcome.success, const <String>[]);

  VerifyActionResult.blocked(List<String> messages)
    : this._(VerifyActionOutcome.blocked, List<String>.unmodifiable(messages));

  VerifyActionResult.failed(String message)
    : this._(VerifyActionOutcome.failed, <String>[message]);

  /// How the action ended.
  final VerifyActionOutcome outcome;

  /// The user-facing text: why a [VerifyActionOutcome.blocked] action did not
  /// happen (the rule messages, e.g. "Add a reason.") or a friendly sentence
  /// for a [VerifyActionOutcome.failed] one; empty on success.
  final List<String> messages;

  bool get ok => outcome == VerifyActionOutcome.success;
}

/// Progress of the action in flight, or the last failure.
enum VerifyActionStatus { idle, running, failed }

/// The controller's state. [complaintId] and [kind] say which action the
/// [status] belongs to, so a screen only reacts to its own complaint.
@immutable
class VerifyActionState {
  const VerifyActionState({
    this.status = VerifyActionStatus.idle,
    this.complaintId,
    this.kind,
    this.blocked = false,
    this.messages = const <String>[],
  });

  final VerifyActionStatus status;
  final String? complaintId;
  final VerifyActionKind? kind;

  /// Whether a [VerifyActionStatus.failed] state is a rule block (true) or a
  /// failed write (false).
  final bool blocked;

  /// The user-facing text of a failure: the rule messages when [blocked], a
  /// friendly sentence otherwise.
  final List<String> messages;

  /// Whether any action is in flight (a second tap is ignored).
  bool get busy => status == VerifyActionStatus.running;

  bool _is(String id, VerifyActionKind k, VerifyActionStatus s) =>
      status == s && complaintId == id && kind == k;

  /// Whether [kind] on [id] is in flight.
  bool runningFor(String id, VerifyActionKind kind) =>
      _is(id, kind, VerifyActionStatus.running);

  /// Whether the last [kind] on [id] failed (blocked or errored).
  bool failedFor(String id, VerifyActionKind kind) =>
      _is(id, kind, VerifyActionStatus.failed);

  /// Whether the last action on [id], of either kind, failed.
  bool anyFailedFor(String id) =>
      status == VerifyActionStatus.failed && complaintId == id;
}

/// Runs Verify (T5) and Reject (T7) as the signed-in verifier.
class VerifyActionNotifier extends Notifier<VerifyActionState> {
  @override
  VerifyActionState build() => const VerifyActionState();

  /// T5: verifies the repair of [complaintId], with an optional [note].
  /// Returns the result, or `null` when another action is already in flight
  /// (a second tap is ignored, screens-spec G-3).
  Future<VerifyActionResult?> verify(String complaintId, {String? note}) {
    final String? clean = note?.trim();
    return _run(
      complaintId,
      VerifyActionKind.verify,
      (ComplaintService service, Complaint c, AppUser actor) => service.verify(
        c,
        actor,
        note: (clean == null || clean.isEmpty) ? null : clean,
      ),
    );
  }

  /// T7: sends [complaintId] back to maintenance for rework. The [note] (the
  /// reason) is required: a blank one is blocked by the core rule P3 ("Add a
  /// reason."), and the screen keeps the button disabled until there is one.
  /// Returns `null` when another action is in flight.
  Future<VerifyActionResult?> reject(
    String complaintId, {
    required String note,
  }) => _run(
    complaintId,
    VerifyActionKind.reject,
    (ComplaintService service, Complaint c, AppUser actor) =>
        service.reject(c, actor, note: note.trim()),
  );

  Future<VerifyActionResult?> _run(
    String complaintId,
    VerifyActionKind kind,
    Future<ComplaintActionResult> Function(
      ComplaintService service,
      Complaint complaint,
      AppUser actor,
    )
    act,
  ) async {
    if (state.busy) return null;
    final AppUser? actor = ref.read(sessionProvider);
    if (actor == null || actor.role != UserRole.verifier) {
      return _fail(
        complaintId,
        kind,
        blocked: true,
        messages: const <String>['Only verifiers can do this.'],
      );
    }

    state = VerifyActionState(
      status: VerifyActionStatus.running,
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
      if (ref.mounted) state = const VerifyActionState();
      return const VerifyActionResult.success();
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
  VerifyActionResult _fail(
    String complaintId,
    VerifyActionKind kind, {
    required bool blocked,
    required List<String> messages,
  }) {
    if (ref.mounted) {
      state = VerifyActionState(
        status: VerifyActionStatus.failed,
        complaintId: complaintId,
        kind: kind,
        blocked: blocked,
        messages: messages,
      );
    }
    return blocked
        ? VerifyActionResult.blocked(messages)
        : VerifyActionResult.failed(messages.first);
  }

  static String _failureText(VerifyActionKind kind) => switch (kind) {
    VerifyActionKind.verify =>
      "We couldn't verify the repair. Check your connection and try again. "
          'Nothing you entered was lost.',
    VerifyActionKind.reject =>
      "We couldn't send the job back. Check your connection and try again. "
          'Your reason was kept.',
  };

  /// Dismisses a failure banner.
  void clearError() {
    if (state.status == VerifyActionStatus.failed) {
      state = const VerifyActionState();
    }
  }
}

/// The verifier write controller. Auto-disposed so a failure banner never
/// outlives the screens that show it.
final verifyActionProvider =
    NotifierProvider.autoDispose<VerifyActionNotifier, VerifyActionState>(
      VerifyActionNotifier.new,
    );
