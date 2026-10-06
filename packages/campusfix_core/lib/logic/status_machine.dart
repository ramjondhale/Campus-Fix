import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../enums/attachment_kind.dart';
import '../enums/complaint_status.dart';
import '../enums/priority.dart';
import '../enums/user_role.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';
import '../models/attachment.dart';
import '../models/complaint.dart';

/// One legal edge of the status machine (status-machine-spec §2, T1-T8) and
/// the roles allowed to take it (L1), plus the edge-specific preconditions
/// (L2) that apply to it. P8 (stale check) and P9 (note length) apply to every
/// edge and are not listed here.
enum _Edge {
  t1(ComplaintStatus.reported, ComplaintStatus.reviewed, {
    UserRole.verifier,
    UserRole.admin,
  }, {}),
  t2(
    ComplaintStatus.reviewed,
    ComplaintStatus.assigned,
    {UserRole.verifier, UserRole.admin},
    {_Pre.p4, _Pre.p5},
  ),
  t3(
    ComplaintStatus.assigned,
    ComplaintStatus.inProgress,
    {UserRole.maintenance, UserRole.admin},
    {_Pre.p6, _Pre.p7},
  ),
  t4(
    ComplaintStatus.inProgress,
    ComplaintStatus.resolved,
    {UserRole.maintenance, UserRole.admin},
    {_Pre.p1, _Pre.p2, _Pre.p6, _Pre.p7},
  ),
  t5(
    ComplaintStatus.resolved,
    ComplaintStatus.verified,
    {UserRole.verifier, UserRole.admin},
    {_Pre.p1, _Pre.p2},
  ),
  t6(ComplaintStatus.verified, ComplaintStatus.closed, {
    UserRole.verifier,
    UserRole.admin,
  }, {}),

  /// Reject / verification failed.
  t7(
    ComplaintStatus.resolved,
    ComplaintStatus.inProgress,
    {UserRole.verifier, UserRole.admin},
    {_Pre.p3},
  ),

  /// Pull-back / reassign (admin only).
  t8(
    ComplaintStatus.inProgress,
    ComplaintStatus.assigned,
    {UserRole.admin},
    {_Pre.p3, _Pre.p4, _Pre.p5},
  );

  const _Edge(this.from, this.to, this.roles, this.preconditions);

  final ComplaintStatus from;
  final ComplaintStatus to;
  final Set<UserRole> roles;
  final Set<_Pre> preconditions;

  /// The edge `from -> to`, or `null` when no role can take it.
  static _Edge? of(ComplaintStatus from, ComplaintStatus to) {
    for (final edge in values) {
      if (edge.from == from && edge.to == to) return edge;
    }
    return null;
  }
}

/// Edge-specific preconditions (status-machine-spec §4). P8 and P9 are
/// universal and handled separately.
enum _Pre { p1, p2, p3, p4, p5, p6, p7 }

/// Pure, static rules for the complaint status lifecycle (R9).
///
/// Two layers live here (status-machine-spec §1):
///
/// * **L1** - [canTransition] / [nextStatuses]: edge + role legality only. They
///   never look at a complaint, so preconditions cannot influence them.
/// * **L2** - [validateTransition]: preconditions P1-P9 over the actual
///   complaint, acting user and request payload. It calls [canTransition]
///   internally, performs no I/O and never throws.
///
/// The atomic *executor* (apply the transition, append the `StatusEvent`,
/// recompute/freeze priority, persist) is L3 and lives in `ComplaintService`
/// (chunk S2.7), not here.
abstract class StatusMachine {
  /// Maximum length (after trimming) of any note (P2, P3, P9).
  static const int maxNoteLength = 500;

  /// Whether a user with [role] may move a complaint from [from] to [to]
  /// (L1). `true` iff `(from, to)` is one of the eight edges T1-T8 and [role]
  /// is allowed on it. Self-transitions, skips, reopening and anything from
  /// `closed` are always `false`.
  static bool canTransition(
    ComplaintStatus from,
    ComplaintStatus to,
    UserRole role,
  ) => _Edge.of(from, to)?.roles.contains(role) ?? false;

  /// Every status [role] may move a complaint to from [from] (L1), sorted
  /// ascending by [ComplaintStatus.order], without duplicates. Ignores L2, so
  /// a UI may still show the action disabled with the unmet-precondition
  /// reason.
  static List<ComplaintStatus> nextStatuses(
    ComplaintStatus from,
    UserRole role,
  ) =>
      ComplaintStatus.values
          .where((to) => canTransition(from, to, role))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  /// Checks a transition attempt of [c] to [to] by [actor] with payload [req]
  /// (L2, resolves SM-OI-1).
  ///
  /// Pure: reads only its arguments. Returns every unmet blocker rather than
  /// the first (never throws). A transition is acceptable only when
  /// [ValidationResult.ok]; that already includes the L1 check
  /// ([canTransition] on `c.status -> to` for `actor.role`), reported as the
  /// blocker code `L1`.
  ///
  /// Blocker codes are `L1` or `P1`-`P9` (status-machine-spec §4), emitted in
  /// that order. When L1 fails only the universal checks P8 and P9 are added,
  /// because the edge-specific preconditions are meaningless for an illegal
  /// edge.
  static ValidationResult validateTransition(
    Complaint c,
    ComplaintStatus to,
    AppUser actor,
    TransitionRequest req,
  ) {
    final blockers = <TransitionBlocker>[];
    final legal = canTransition(c.status, to, actor.role);
    final edge = legal ? _Edge.of(c.status, to) : null;

    if (edge == null) {
      blockers.add(
        const TransitionBlocker(
          code: 'L1',
          message: 'You cannot make this status change.',
        ),
      );
    } else {
      final pre = edge.preconditions;
      if (pre.contains(_Pre.p1)) _add(blockers, _p1(c, edge, req));
      if (pre.contains(_Pre.p2)) _add(blockers, _p2(c, edge, req));
      if (pre.contains(_Pre.p3)) _add(blockers, _p3(req));
      if (pre.contains(_Pre.p4)) _add(blockers, _p4(c, edge, actor, req));
      if (pre.contains(_Pre.p5)) _add(blockers, _p5(actor, req));
      if (pre.contains(_Pre.p6)) _add(blockers, _p6(c, actor));
      if (pre.contains(_Pre.p7)) _add(blockers, _p7(c, actor));
    }
    _add(blockers, _p8(c, req));
    _add(blockers, _p9(req));

    return ValidationResult(blockers: blockers);
  }

  static void _add(List<TransitionBlocker> into, TransitionBlocker? blocker) {
    if (blocker != null) into.add(blocker);
  }

  static bool _isBlank(String? s) => s == null || s.trim().isEmpty;

  static bool _tooLong(String s) => s.trim().length > maxNoteLength;

  /// Start of the current repair cycle: the `at` of the most recent T7
  /// (reject) event, else the complaint's creation time. A T7 event is a
  /// timeline entry entering `inProgress` straight after one entering
  /// `resolved`.
  static DateTime _cycleStart(Complaint c) {
    var start = c.createdAt;
    var sawReject = false;
    for (var i = 1; i < c.timeline.length; i++) {
      final prev = c.timeline[i - 1];
      final cur = c.timeline[i];
      if (prev.status == ComplaintStatus.resolved &&
          cur.status == ComplaintStatus.inProgress &&
          (!sawReject || cur.at.isAfter(start))) {
        start = cur.at;
        sawReject = true;
      }
    }
    return start;
  }

  /// P1 FRESH_EVIDENCE (T4, T5): at least one `afterPhoto` created after the
  /// current cycle started.
  ///
  /// T4 counts the photos the request is adding. T5 ("must still hold") looks
  /// only at the photos already persisted on the complaint, because T5 stores
  /// nothing from the request (INV-3 must hold for `verified`).
  static TransitionBlocker? _p1(
    Complaint c,
    _Edge edge,
    TransitionRequest req,
  ) {
    final cycleStart = _cycleStart(c);
    final photos = edge == _Edge.t4
        ? [...c.afterPhotos, ...req.afterPhotos]
        : c.afterPhotos;
    final fresh = photos.any(
      (Attachment p) =>
          p.kind == AttachmentKind.afterPhoto &&
          p.createdAt.isAfter(cycleStart),
    );
    return fresh
        ? null
        : const TransitionBlocker(
            code: 'P1',
            message: 'Add at least one after-repair photo.',
          );
  }

  /// P2 RESOLUTION_NOTE (T4, T5): a non-blank note of at most 500 chars.
  ///
  /// T4 uses the note in the request when one is supplied, else the existing
  /// one. T5 uses the existing (persisted) one only; see [_p1].
  static TransitionBlocker? _p2(
    Complaint c,
    _Edge edge,
    TransitionRequest req,
  ) {
    final note = edge == _Edge.t4
        ? (req.resolutionNote ?? c.resolutionNote)
        : c.resolutionNote;
    if (_isBlank(note)) {
      return const TransitionBlocker(
        code: 'P2',
        message: 'Add a resolution note.',
      );
    }
    if (_tooLong(note!)) {
      return const TransitionBlocker(
        code: 'P2',
        message: 'Resolution note too long (500 max).',
      );
    }
    return null;
  }

  /// P3 NOTE_REQUIRED (T7, T8): `req.note` is non-blank and <= 500 chars.
  static TransitionBlocker? _p3(TransitionRequest req) {
    final note = req.note;
    if (_isBlank(note)) {
      return const TransitionBlocker(code: 'P3', message: 'Add a reason.');
    }
    if (_tooLong(note!)) {
      return const TransitionBlocker(
        code: 'P3',
        message: 'Reason too long (500 max).',
      );
    }
    return null;
  }

  /// P4 ASSIGNMENT_VALID (T2, T8): structural checks only.
  ///
  /// Enforced here: an assignment is present (its `department` is always a
  /// valid enum value), `assignedBy == actor.id`, and for T8 the new
  /// assignment differs from the current one in `department` or `assigneeId`.
  static TransitionBlocker? _p4(
    Complaint c,
    _Edge edge,
    AppUser actor,
    TransitionRequest req,
  ) {
    final next = req.assignment;
    if (next == null) {
      return const TransitionBlocker(
        code: 'P4',
        message: 'Choose a department.',
      );
    }
    if (next.assignedBy != actor.id) {
      return const TransitionBlocker(
        code: 'P4',
        message: 'The assignment must be made by the acting user.',
      );
    }
    final current = c.assignment;
    if (edge == _Edge.t8 &&
        current != null &&
        next.department == current.department &&
        next.assigneeId == current.assigneeId) {
      return const TransitionBlocker(
        code: 'P4',
        message: 'Choose a different department or assignee.',
      );
    }
    // NOTE: P4 also requires that a non-null `assigneeId` is a real
    // `maintenance` user whose department equals `assignment.department`.
    // That needs a user directory, which this pure function does not have; it
    // is enforced by `ComplaintService` (S2.7) before it persists the
    // transition.
    return null;
  }

  /// P5 MANUAL_ADMIN_ONLY (T2, T8): a manual assignment needs an admin.
  /// Uses [Assignment.isManual] as given (derived upstream, MA-2).
  static TransitionBlocker? _p5(AppUser actor, TransitionRequest req) {
    final next = req.assignment;
    if (next != null && next.isManual && actor.role != UserRole.admin) {
      return const TransitionBlocker(
        code: 'P5',
        message: 'Only an admin can assign a custom department.',
      );
    }
    return null;
  }

  /// P6 DEPT_MATCH (T3, T4; maintenance actors only - admins are not
  /// department-bound): the actor's department is the assigned department.
  static TransitionBlocker? _p6(Complaint c, AppUser actor) {
    if (actor.role != UserRole.maintenance) return null;
    final dept = c.assignment?.department;
    if (dept == null || dept != actor.department) {
      return const TransitionBlocker(
        code: 'P6',
        message: 'This work belongs to another department.',
      );
    }
    return null;
  }

  /// P7 ASSIGNEE_MATCH (T3, T4; maintenance actors only): the work is
  /// unclaimed or already claimed by the actor.
  static TransitionBlocker? _p7(Complaint c, AppUser actor) {
    if (actor.role != UserRole.maintenance) return null;
    final assigneeId = c.assignment?.assigneeId;
    if (assigneeId != null && assigneeId != actor.id) {
      return const TransitionBlocker(
        code: 'P7',
        message: 'Already claimed by a colleague.',
      );
    }
    return null;
  }

  /// P8 STALE_CHECK (all): the caller saw the current status, and the
  /// complaint is not `closed` (terminal, INV-4).
  static TransitionBlocker? _p8(Complaint c, TransitionRequest req) {
    if (req.expectedFrom != c.status || c.status.isTerminal) {
      return const TransitionBlocker(
        code: 'P8',
        message: 'This complaint changed; refresh and retry.',
      );
    }
    return null;
  }

  /// P9 NOTE_LENGTH (all): every supplied note is <= 500 chars (trimmed).
  static TransitionBlocker? _p9(TransitionRequest req) {
    final note = req.note;
    final resolutionNote = req.resolutionNote;
    if ((note != null && _tooLong(note)) ||
        (resolutionNote != null && _tooLong(resolutionNote))) {
      return const TransitionBlocker(
        code: 'P9',
        message: 'Note too long (500 max).',
      );
    }
    return null;
  }
}

/// What a caller supplies for one transition attempt (data-model §5).
@immutable
class TransitionRequest {
  const TransitionRequest({
    required this.expectedFrom,
    this.note,
    this.resolutionNote,
    this.afterPhotos = const [],
    this.assignment,
    this.priorityOverride,
  });

  /// The status the caller believes the complaint is in (stale guard, P8).
  final ComplaintStatus expectedFrom;

  /// Reject / reassign reason, or an optional event note.
  final String? note;

  /// Resolution note (T4).
  final String? resolutionNote;

  /// After-repair photos being added (T4); each should be
  /// `AttachmentKind.afterPhoto`.
  final List<Attachment> afterPhotos;

  /// The assignment being written (T2/T8).
  final Assignment? assignment;

  /// Admin priority override set at review (T1). Not validated by P1-P9.
  final Priority? priorityOverride;
}

/// Outcome of [StatusMachine.validateTransition]: the unmet [blockers]; empty
/// means the transition may proceed.
@immutable
class ValidationResult {
  /// Creates a result. [blockers] is copied into an unmodifiable list; the
  /// default (no blockers) is a passing result.
  factory ValidationResult({
    List<TransitionBlocker> blockers = const <TransitionBlocker>[],
  }) => ValidationResult._(List<TransitionBlocker>.unmodifiable(blockers));

  const ValidationResult._(this.blockers);

  /// Why the transition is rejected; empty when it is allowed.
  final List<TransitionBlocker> blockers;

  /// True when there are no blockers.
  bool get ok => blockers.isEmpty;

  /// The blocker codes, in order (e.g. `['P1', 'P8']`).
  List<String> get codes => [for (final b in blockers) b.code];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationResult &&
          const ListEquality<TransitionBlocker>().equals(
            other.blockers,
            blockers,
          );

  @override
  int get hashCode => const ListEquality<TransitionBlocker>().hash(blockers);

  @override
  String toString() => 'ValidationResult(ok: $ok, codes: $codes)';
}

/// One unmet requirement of a transition.
@immutable
class TransitionBlocker {
  const TransitionBlocker({required this.code, required this.message});

  /// `L1` (edge/role not allowed) or a precondition id `P1`-`P9`.
  final String code;

  /// User-facing explanation (status-machine-spec §4).
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitionBlocker &&
          other.code == code &&
          other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'TransitionBlocker($code: $message)';
}
