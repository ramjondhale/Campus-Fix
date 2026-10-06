import 'dart:async';

import 'package:meta/meta.dart';

import '../enums/attachment_kind.dart';
import '../enums/complaint_status.dart';
import '../enums/department.dart';
import '../enums/people_affected.dart';
import '../enums/priority.dart';
import '../enums/problem_category.dart';
import '../enums/severity.dart';
import '../enums/user_role.dart';
import '../logic/assignment_router.dart';
import '../logic/priority_engine.dart';
import '../logic/status_machine.dart';
import '../mock/id_generator.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';
import '../models/attachment.dart';
import '../models/complaint.dart';
import '../models/reporter_identity.dart';
import '../models/status_event.dart';
import '../repositories/complaint_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/user_repository.dart';
import 'notification_service.dart';

/// Outcome of a [ComplaintService] action.
///
/// Either [ok] - [complaint] is the stored result and [events] /
/// [notifications] are what the action appended / emitted - or blocked:
/// [blockers] says why, and **nothing** was changed or emitted. Validation
/// failures never throw.
@immutable
class ComplaintActionResult {
  const ComplaintActionResult._({
    this.complaint,
    this.blockers = const [],
    this.events = const [],
    this.notifications = const [],
  });

  /// A successful action.
  factory ComplaintActionResult.success({
    required Complaint complaint,
    List<StatusEvent> events = const [],
    List<AppNotification> notifications = const [],
  }) => ComplaintActionResult._(
    complaint: complaint,
    events: List.unmodifiable(events),
    notifications: List.unmodifiable(notifications),
  );

  /// A rejected action.
  factory ComplaintActionResult.blocked(List<TransitionBlocker> blockers) =>
      ComplaintActionResult._(blockers: List.unmodifiable(blockers));

  /// The stored complaint after the action; `null` when blocked.
  final Complaint? complaint;

  /// Why the action was rejected; empty on success.
  final List<TransitionBlocker> blockers;

  /// The `StatusEvent`s the action appended (two for Review & Route that
  /// auto-routes, one for a plain transition, none for non-event edits).
  final List<StatusEvent> events;

  /// The notifications the action stored.
  final List<AppNotification> notifications;

  /// Whether the action was applied.
  bool get ok => complaint != null;

  /// The blocker codes, in order (e.g. `['P1', 'P8']`).
  List<String> get codes => [for (final b in blockers) b.code];

  /// The user-facing blocker messages, in order.
  List<String> get messages => [for (final b in blockers) b.message];

  /// Concise and PII-free.
  @override
  String toString() => ok
      ? 'ComplaintActionResult(ok, events: ${events.length}, '
            'notifications: ${notifications.length})'
      : 'ComplaintActionResult(blocked: $codes)';
}

/// The atomic **L3 executor** of the status machine (status-machine-spec §1)
/// and the entry point for creating complaints.
///
/// For every action it re-reads the stored complaint, validates
/// (`StatusMachine.validateTransition` plus the service-level checks below),
/// applies the side effects, appends the `StatusEvent`, recomputes or freezes
/// the priority, persists once and finally emits the notifications. It never
/// throws on a validation failure - see [ComplaintActionResult].
///
/// Service-level rules on top of the pure state machine:
/// * `Assignment.isManual`, `assignedBy` and `assignedAt` are **derived**
///   (`isManualAssignment`, the actor, the event time) - whatever the caller
///   put in the request is overwritten.
/// * Only an `admin` may supply a `priorityOverride` (on any transition) or
///   a `safetyFlag` (at review), and only an admin may name a specific
///   `assigneeId` (codes `PO` / `SF` / `P5`); other roles are rejected, not
///   silently ignored.
/// * An `assigneeId` must name an existing `maintenance` user of the
///   assignment's department (the directory half of P4, code `P4`).
/// * A `closed` complaint is immutable (INV-4) and `priority` is frozen from
///   `resolved` on (INV-5), unfrozen by the T7 reject.
/// * Composites (Review & Route) plan every step before persisting
///   anything, so a failing later step leaves the complaint unchanged.
/// * Actions on one complaint are serialised, so a double tap or two
///   concurrent admins hit the stale check (P8) instead of racing.
///
/// `updatedAt` follows the timeline (TL-4): only actions that append an event
/// move it; changes that append none (`setPriorityOverride`, `setSafetyFlag`,
/// aging) leave it alone.
class ComplaintService {
  /// Creates the service. [clock] is used when an action is not given an
  /// explicit `now`.
  ComplaintService({
    required ComplaintRepository complaints,
    required NotificationRepository notifications,
    required UserRepository users,
    required ComplaintIdGenerator ids,
    NotificationService? notificationService,
    DateTime Function() clock = DateTime.now,
  }) : _complaints = complaints,
       _users = users,
       _ids = ids,
       _clock = clock,
       _notifier =
           notificationService ??
           NotificationService(notifications: notifications, users: users);

  final ComplaintRepository _complaints;
  final UserRepository _users;
  final ComplaintIdGenerator _ids;
  final DateTime Function() _clock;
  final NotificationService _notifier;

  /// Tail of the pending-action chain per complaint id (see [_serialized]).
  final Map<String, Future<void>> _tails = {};

  // -------------------------------------------------------------------------
  // Creation
  // -------------------------------------------------------------------------

  /// Files a new complaint: generates its `CF-YYYY-NNNNN` id, computes the
  /// priority (waiting time zero), stores it as `reported` with the TL-1
  /// timeline event and emits the submission notifications (owner and
  /// admins).
  ///
  /// `category == safety` forces `safetyFlag`. Throws an [ArgumentError] for
  /// a blank description / building / floor / room or a `beforePhotos` entry
  /// that is not `AttachmentKind.beforePhoto`.
  Future<Complaint> submit({
    required ReporterIdentity reporter,
    required ProblemCategory category,
    String? title,
    required String description,
    required String building,
    required String floor,
    required String room,
    List<Attachment> beforePhotos = const [],
    required Severity severity,
    required PeopleAffected peopleAffected,
    bool safetyFlag = false,
    DateTime? now,
  }) async {
    final at = now ?? _clock();
    final text = {
      'description': description,
      'building': building,
      'floor': floor,
      'room': room,
    };
    for (final entry in text.entries) {
      if (entry.value.trim().isEmpty) {
        throw ArgumentError.value(entry.value, entry.key, 'must not be blank');
      }
    }
    for (final photo in beforePhotos) {
      if (photo.kind != AttachmentKind.beforePhoto) {
        throw ArgumentError.value(
          photo.kind,
          'beforePhotos',
          'every photo must be a beforePhoto',
        );
      }
    }

    final flagged = safetyFlag || category == ProblemCategory.safety;
    final id = _ids.next(at);
    final draft = Complaint(
      id: id,
      category: category,
      title: _clean(title),
      description: description.trim(),
      building: building.trim(),
      floor: floor.trim(),
      room: room.trim(),
      reporter: reporter,
      beforePhotos: beforePhotos,
      priority: computePriority(
        PriorityInputs(
          category: category,
          safetyFlag: flagged,
          severity: severity,
          peopleAffected: peopleAffected,
        ),
      ),
      status: ComplaintStatus.reported,
      timeline: [
        StatusEvent(
          id: _eventId(id, 1),
          status: ComplaintStatus.reported,
          actorId: reporter.userId,
          actorRole: UserRole.reporter,
          at: at,
        ),
      ],
      safetyFlag: flagged,
      severity: severity,
      peopleAffected: peopleAffected,
      createdAt: at,
      updatedAt: at,
    );

    final notifications = await _notifier.buildFor(
      null,
      draft,
      draft.timeline.first,
    );
    final saved = await _complaints.submit(draft);
    await _notifier.deliver(notifications);
    return saved;
  }

  // -------------------------------------------------------------------------
  // The executor
  // -------------------------------------------------------------------------

  /// Moves [c] to [to] as [actor] (L3 executor).
  ///
  /// [c] only identifies the complaint: the stored copy is re-read and is
  /// what gets validated, so [TransitionRequest.expectedFrom] is checked
  /// against the real status (P8).
  ///
  /// `to == reviewed` performs **Review & Route** (T1, then T2 when the
  /// category auto-routes - or when an admin names a department): all steps
  /// are validated before anything is stored. For T2 / T8 the request's
  /// `assignment` supplies the department and `assigneeId` only; the rest is
  /// derived. [safetyFlag] lets an admin toggle the flag at review (T1 only).
  ///
  /// Never throws on a validation failure: see [ComplaintActionResult].
  Future<ComplaintActionResult> apply(
    Complaint c,
    ComplaintStatus to,
    AppUser actor,
    TransitionRequest req, {
    DateTime? now,
    bool? safetyFlag,
  }) => _serialized(
    c.id,
    () => _apply(c.id, to, actor, req, now ?? _clock(), safetyFlag),
  );

  /// Review & Route (T1, then T2 when routable). An admin may choose
  /// [department] (and [assigneeId]), set [priorityOverride] and toggle
  /// [safetyFlag]; a verifier may only accept the auto-route.
  ///
  /// For `safety` / `other` complaints (no route) it stops at `reviewed`
  /// unless an admin names a [department].
  Future<ComplaintActionResult> reviewAndRoute(
    Complaint c,
    AppUser actor, {
    String? note,
    Department? department,
    String? assigneeId,
    Priority? priorityOverride,
    bool? safetyFlag,
    DateTime? now,
  }) {
    final chosen = department ?? routeToDepartment(c.category);
    final wantsAssignee = _clean(assigneeId) != null;
    if (chosen == null && wantsAssignee) {
      return Future.value(
        ComplaintActionResult.blocked(const [
          TransitionBlocker(code: 'P4', message: 'Choose a department.'),
        ]),
      );
    }
    final at = now ?? _clock();
    return apply(
      c,
      ComplaintStatus.reviewed,
      actor,
      TransitionRequest(
        expectedFrom: c.status,
        note: note,
        priorityOverride: priorityOverride,
        assignment: (department == null && !wantsAssignee)
            ? null
            : _assignmentFor(c, actor, at, chosen!, assigneeId),
      ),
      now: at,
      safetyFlag: safetyFlag,
    );
  }

  /// T2 for a `reviewed` complaint that was not auto-routed (`safety` /
  /// `other`): only an admin may assign a custom department (P5).
  Future<ComplaintActionResult> assign(
    Complaint c,
    AppUser actor, {
    required Department department,
    String? assigneeId,
    String? note,
    DateTime? now,
  }) {
    final at = now ?? _clock();
    return apply(
      c,
      ComplaintStatus.assigned,
      actor,
      TransitionRequest(
        expectedFrom: c.status,
        note: note,
        assignment: _assignmentFor(c, actor, at, department, assigneeId),
      ),
      now: at,
    );
  }

  /// T3: start (claim) the work.
  Future<ComplaintActionResult> startWork(
    Complaint c,
    AppUser actor, {
    String? note,
    DateTime? now,
  }) => apply(
    c,
    ComplaintStatus.inProgress,
    actor,
    TransitionRequest(expectedFrom: c.status, note: note),
    now: now,
  );

  /// T4: submit repair proof - [afterPhotos] (fresh `afterPhoto`s) and a
  /// [resolutionNote].
  Future<ComplaintActionResult> resolve(
    Complaint c,
    AppUser actor, {
    required String resolutionNote,
    required List<Attachment> afterPhotos,
    DateTime? now,
  }) => apply(
    c,
    ComplaintStatus.resolved,
    actor,
    TransitionRequest(
      expectedFrom: c.status,
      resolutionNote: resolutionNote,
      afterPhotos: afterPhotos,
    ),
    now: now,
  );

  /// T5: verify the repair. Does **not** close the complaint (the verifier
  /// verifies, the admin closes - see [close]).
  Future<ComplaintActionResult> verify(
    Complaint c,
    AppUser actor, {
    String? note,
    DateTime? now,
  }) => apply(
    c,
    ComplaintStatus.verified,
    actor,
    TransitionRequest(expectedFrom: c.status, note: note),
    now: now,
  );

  /// T6: close a verified complaint (terminal; immutable afterwards, INV-4).
  Future<ComplaintActionResult> close(
    Complaint c,
    AppUser actor, {
    String? note,
    DateTime? now,
  }) => apply(
    c,
    ComplaintStatus.closed,
    actor,
    TransitionRequest(expectedFrom: c.status, note: note),
    now: now,
  );

  /// T7: reject the repair (`resolved -> inProgress`); the [note] is
  /// required. Unfreezes and recomputes the priority.
  Future<ComplaintActionResult> reject(
    Complaint c,
    AppUser actor, {
    required String note,
    DateTime? now,
  }) => apply(
    c,
    ComplaintStatus.inProgress,
    actor,
    TransitionRequest(expectedFrom: c.status, note: note),
    now: now,
  );

  /// Admin reassignment with a required [reason]: the T8 pull-back when
  /// `inProgress`, an annotation event when `assigned` (status-machine-spec
  /// §5); rejected in any other status (RA-2).
  Future<ComplaintActionResult> reassign(
    Complaint c,
    AppUser actor, {
    required Department department,
    String? assigneeId,
    required String reason,
    DateTime? now,
  }) {
    final at = now ?? _clock();
    return _serialized(c.id, () async {
      final cur = await _complaints.byId(c.id);
      if (cur == null) return _notFound();
      final req = TransitionRequest(
        expectedFrom: c.status,
        note: reason,
        assignment: _assignmentFor(cur, actor, at, department, assigneeId),
      );
      switch (cur.status) {
        case ComplaintStatus.inProgress:
          return _applyPlanned(
            await _planStep(cur, ComplaintStatus.assigned, actor, req, at),
          );
        case ComplaintStatus.assigned:
          return _applyPlanned(await _planAnnotation(cur, actor, req, at));
        case ComplaintStatus.closed:
          return ComplaintActionResult.blocked([_closedBlocker]);
        case ComplaintStatus.reported ||
            ComplaintStatus.reviewed ||
            ComplaintStatus.resolved ||
            ComplaintStatus.verified:
          return ComplaintActionResult.blocked(const [
            TransitionBlocker(
              code: 'RA2',
              message:
                  'Only assigned or in-progress work can be reassigned '
                  '(reject first if rework is needed).',
            ),
          ]);
      }
    });
  }

  // -------------------------------------------------------------------------
  // Admin edits that are not status transitions
  // -------------------------------------------------------------------------

  /// Sets (or, with `null`, clears) the admin priority override. Admin only
  /// (PC-1); a `closed` complaint is immutable. Appends no event, so
  /// `updatedAt` is unchanged.
  Future<ComplaintActionResult> setPriorityOverride(
    Complaint c,
    AppUser actor,
    Priority? override,
  ) => _serialized(c.id, () async {
    final cur = await _complaints.byId(c.id);
    if (cur == null) return _notFound();
    final blockers = [
      if (cur.status.isTerminal) _closedBlocker,
      if (actor.role != UserRole.admin) _overrideBlocker,
    ];
    if (blockers.isNotEmpty) return ComplaintActionResult.blocked(blockers);
    final next = override == null
        ? cur.copyWith(clearPriorityOverride: true)
        : cur.copyWith(priorityOverride: override);
    return ComplaintActionResult.success(
      complaint: await _complaints.update(next),
    );
  });

  /// Admin toggle of the safety flag, allowed until the repair is completed
  /// (before `resolved`). Recomputes the priority immediately (priority-engine
  /// §6). A `safety`-category complaint stays flagged. Appends no event.
  Future<ComplaintActionResult> setSafetyFlag(
    Complaint c,
    AppUser actor,
    bool flag, {
    DateTime? now,
  }) {
    final at = now ?? _clock();
    return _serialized(c.id, () async {
      final cur = await _complaints.byId(c.id);
      if (cur == null) return _notFound();
      if (cur.status.isTerminal) {
        return ComplaintActionResult.blocked([_closedBlocker]);
      }
      if (actor.role != UserRole.admin) {
        return ComplaintActionResult.blocked(const [
          TransitionBlocker(
            code: 'SF',
            message: 'Only an admin can change the safety flag.',
          ),
        ]);
      }
      if (!_isUnresolved(cur.status)) {
        return ComplaintActionResult.blocked(const [
          TransitionBlocker(
            code: 'SF',
            message: 'The safety flag cannot change once the repair is done.',
          ),
        ]);
      }
      if (!flag && cur.category == ProblemCategory.safety) {
        return ComplaintActionResult.blocked(const [
          TransitionBlocker(
            code: 'SF',
            message: 'A Safety complaint is always flagged.',
          ),
        ]);
      }
      final flagged = cur.copyWith(safetyFlag: flag);
      return ComplaintActionResult.success(
        complaint: await _complaints.update(_recomputed(flagged, at)),
      );
    });
  }

  // -------------------------------------------------------------------------
  // Aging (priority-engine-spec §6)
  // -------------------------------------------------------------------------

  /// [c] with its priority recomputed for the waiting time as of [now] - the
  /// on-read aging rule. A no-op (returns [c]) once the complaint is
  /// `resolved` / `verified` / `closed`, because the priority is frozen. Pure:
  /// persists nothing and leaves `updatedAt` alone.
  Complaint refreshAging(Complaint c, DateTime now) =>
      _isUnresolved(c.status) ? _recomputed(c, now) : c;

  /// [refreshAging] on the stored copy of [c], persisted when the priority
  /// changed. Returns the stored complaint (or the refreshed [c] if it is
  /// not stored).
  Future<Complaint> refreshAndPersist(Complaint c, {DateTime? now}) {
    final at = now ?? _clock();
    return _serialized(c.id, () async {
      final cur = await _complaints.byId(c.id);
      if (cur == null) return refreshAging(c, at);
      final refreshed = refreshAging(cur, at);
      return refreshed == cur ? cur : _complaints.update(refreshed);
    });
  }

  // -------------------------------------------------------------------------
  // Internals: executing a plan
  // -------------------------------------------------------------------------

  Future<ComplaintActionResult> _apply(
    String id,
    ComplaintStatus to,
    AppUser actor,
    TransitionRequest req,
    DateTime now,
    bool? safetyFlag,
  ) async {
    final cur = await _complaints.byId(id);
    if (cur == null) return _notFound();
    final plan = to == ComplaintStatus.reviewed
        ? await _planReview(cur, actor, req, now, safetyFlag)
        : await _planStep(cur, to, actor, req, now, safetyFlag: safetyFlag);
    return _applyPlanned(plan);
  }

  /// Persists a successful [plan] once, then emits its notifications. A
  /// blocked plan stores and emits nothing.
  Future<ComplaintActionResult> _applyPlanned(_Plan plan) async {
    if (!plan.ok) return ComplaintActionResult.blocked(plan.blockers);

    final notifications = <AppNotification>[
      for (final step in plan.steps)
        ...await _notifier.buildFor(step.before, step.after, step.event),
    ];
    final saved = await _complaints.update(plan.steps.last.after);
    final delivered = await _notifier.deliver(notifications);
    return ComplaintActionResult.success(
      complaint: saved,
      events: [for (final step in plan.steps) step.event],
      notifications: delivered,
    );
  }

  // -------------------------------------------------------------------------
  // Internals: planning (validation + side effects, no I/O writes)
  // -------------------------------------------------------------------------

  /// Review & Route: T1 then (when routable or an admin names a department)
  /// T2, planned on the in-memory result of T1 so that a failing T2 blocks
  /// the whole composite.
  Future<_Plan> _planReview(
    Complaint cur,
    AppUser actor,
    TransitionRequest req,
    DateTime now,
    bool? safetyFlag,
  ) async {
    final first = await _planStep(
      cur,
      ComplaintStatus.reviewed,
      actor,
      req,
      now,
      safetyFlag: safetyFlag,
    );
    if (!first.ok) return first;

    final route = routeToDepartment(cur.category);
    final requested = req.assignment;
    final department = requested?.department ?? route;
    if (department == null) return first; // manual triage: wait in `reviewed`

    final second = await _planStep(
      first.steps.single.after,
      ComplaintStatus.assigned,
      actor,
      TransitionRequest(
        expectedFrom: ComplaintStatus.reviewed,
        assignment: Assignment(
          department: department,
          assigneeId: requested?.assigneeId,
          assignedBy: actor.id,
          assignedAt: now,
          isManual: isManualAssignment(cur.category, department),
        ),
      ),
      now,
    );
    if (!second.ok) return second;
    return _Plan.ok([...first.steps, ...second.steps]);
  }

  /// One status transition: validate (state machine + service rules), then
  /// apply its side effects to an in-memory copy.
  Future<_Plan> _planStep(
    Complaint cur,
    ComplaintStatus to,
    AppUser actor,
    TransitionRequest req,
    DateTime now, {
    bool? safetyFlag,
  }) async {
    final request = _normalised(cur, to, actor, req, now);
    final result = StatusMachine.validateTransition(cur, to, actor, request);
    final blockers = [...result.blockers];
    blockers.addAll(_roleBlockers(to, actor, request, safetyFlag));
    if (to == ComplaintStatus.assigned && !result.codes.contains('L1')) {
      final directory = await _directoryBlocker(request.assignment);
      if (directory != null) blockers.add(directory);
    }
    if (blockers.isNotEmpty) return _Plan.blocked(blockers);
    return _Plan.ok([_effects(cur, to, actor, request, now, safetyFlag)]);
  }

  /// The annotation event of a reassignment while already `assigned`
  /// (status-machine-spec §5): the status does not change, so it is not a
  /// transition and `canTransition` is bypassed. Only an admin; needs the
  /// reason (P3), a changed assignment (P4), P5, and the stale / closed check
  /// (P8).
  ///
  /// The preconditions are exactly those of T8, so they are checked by
  /// validating the equivalent T8 on a copy of the complaint that is
  /// `inProgress`.
  Future<_Plan> _planAnnotation(
    Complaint cur,
    AppUser actor,
    TransitionRequest req,
    DateTime now,
  ) async {
    final request = _normalised(cur, ComplaintStatus.assigned, actor, req, now);
    final shadow = StatusMachine.validateTransition(
      cur.copyWith(status: ComplaintStatus.inProgress),
      ComplaintStatus.assigned,
      actor,
      TransitionRequest(
        expectedFrom: ComplaintStatus.inProgress,
        note: request.note,
        assignment: request.assignment,
      ),
    );
    final blockers = [
      if (req.expectedFrom != cur.status || cur.status.isTerminal)
        _staleBlocker,
      ...shadow.blockers,
    ];
    blockers.addAll(
      _roleBlockers(ComplaintStatus.assigned, actor, request, null),
    );
    if (!shadow.codes.contains('L1')) {
      final directory = await _directoryBlocker(request.assignment);
      if (directory != null) blockers.add(directory);
    }
    if (blockers.isNotEmpty) return _Plan.blocked(blockers);

    final next = request.assignment!;
    final old = cur.assignment?.department.label ?? 'Unassigned';
    final at = _eventAt(cur, now);
    final event = StatusEvent(
      id: _eventId(cur.id, cur.timeline.length + 1),
      status: ComplaintStatus.assigned,
      actorId: actor.id,
      actorRole: actor.role,
      note:
          'Reassigned: $old -> ${next.department.label} — '
          '${request.note!.trim()}',
      at: at,
    );
    final after = _recomputed(
      cur.copyWith(
        assignment: next,
        updatedAt: at,
        timeline: [...cur.timeline, event],
      ),
      at,
    );
    return _Plan.ok([_Step(cur, after, event)]);
  }

  /// [req] with a derived assignment: `isManual`, `assignedBy` and
  /// `assignedAt` are never taken from the caller.
  TransitionRequest _normalised(
    Complaint cur,
    ComplaintStatus to,
    AppUser actor,
    TransitionRequest req,
    DateTime now,
  ) {
    final given = req.assignment;
    if (to != ComplaintStatus.assigned || given == null) return req;
    return TransitionRequest(
      expectedFrom: req.expectedFrom,
      note: req.note,
      resolutionNote: req.resolutionNote,
      afterPhotos: req.afterPhotos,
      priorityOverride: req.priorityOverride,
      assignment: _assignmentFor(
        cur,
        actor,
        _eventAt(cur, now),
        given.department,
        given.assigneeId,
      ),
    );
  }

  Assignment _assignmentFor(
    Complaint c,
    AppUser actor,
    DateTime at,
    Department department,
    String? assigneeId,
  ) => Assignment(
    department: department,
    assigneeId: _clean(assigneeId),
    assignedBy: actor.id,
    assignedAt: at,
    isManual: isManualAssignment(c.category, department),
  );

  /// Admin-only inputs: `priorityOverride`, `safetyFlag` (only when
  /// reviewing) and picking a specific assignee (MA-3, MA-7).
  List<TransitionBlocker> _roleBlockers(
    ComplaintStatus to,
    AppUser actor,
    TransitionRequest req,
    bool? safetyFlag,
  ) {
    final isAdmin = actor.role == UserRole.admin;
    return [
      if (req.priorityOverride != null && !isAdmin) _overrideBlocker,
      if (to == ComplaintStatus.assigned &&
          req.assignment?.assigneeId != null &&
          !isAdmin)
        const TransitionBlocker(
          code: 'P5',
          message: 'Only an admin can assign a specific staff member.',
        ),
      if (safetyFlag != null && !isAdmin)
        const TransitionBlocker(
          code: 'SF',
          message: 'Only an admin can change the safety flag.',
        ),
      if (safetyFlag != null && isAdmin && to != ComplaintStatus.reviewed)
        const TransitionBlocker(
          code: 'SF',
          message: 'The safety flag can only be set when reviewing.',
        ),
    ];
  }

  /// The directory half of P4 (the skipped N15): a non-null `assigneeId` must
  /// be an existing `maintenance` user of the assignment's department.
  Future<TransitionBlocker?> _directoryBlocker(Assignment? assignment) async {
    final assigneeId = assignment?.assigneeId;
    if (assignment == null || assigneeId == null) return null;
    final user = await _users.byId(assigneeId);
    if (user == null ||
        user.role != UserRole.maintenance ||
        user.department != assignment.department) {
      return const TransitionBlocker(
        code: 'P4',
        message: 'Assignee not in that department.',
      );
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Internals: side effects of one validated transition
  // -------------------------------------------------------------------------

  _Step _effects(
    Complaint cur,
    ComplaintStatus to,
    AppUser actor,
    TransitionRequest req,
    DateTime now,
    bool? safetyFlag,
  ) {
    final at = _eventAt(cur, now);
    final isAdmin = actor.role == UserRole.admin;
    final from = cur.status;
    var next = cur;
    String? note = _clean(req.note);
    if (isAdmin && req.priorityOverride != null) {
      next = next.copyWith(priorityOverride: req.priorityOverride);
    }

    switch (to) {
      case ComplaintStatus.reviewed: // T1
        if (isAdmin && safetyFlag != null) {
          next = next.copyWith(
            safetyFlag: safetyFlag || cur.category == ProblemCategory.safety,
          );
        }
        next = _recomputed(next, at);
      case ComplaintStatus.assigned: // T2, T8
        final assignment = req.assignment!;
        next = _recomputed(next.copyWith(assignment: assignment), at);
        if (from == ComplaintStatus.reviewed) {
          note ??= assignment.isManual
              ? 'Assigned to ${assignment.department.label}'
              : 'Auto-routed to ${assignment.department.label}';
        }
      case ComplaintStatus.inProgress:
        if (from == ComplaintStatus.assigned) {
          next = _claimed(next, actor); // T3
        }
        // T3 recomputes; T7 (reject) unfreezes and recomputes (INV-5).
        next = _recomputed(next, at);
      case ComplaintStatus.resolved: // T4: freeze the priority
        final resolution = (req.resolutionNote ?? cur.resolutionNote)!.trim();
        final known = {for (final p in cur.afterPhotos) p.id};
        next = _claimed(next, actor).copyWith(
          resolutionNote: resolution,
          afterPhotos: [
            ...cur.afterPhotos,
            for (final p in req.afterPhotos)
              if (p.kind == AttachmentKind.afterPhoto && known.add(p.id)) p,
          ],
        );
        note = resolution;
      case ComplaintStatus.verified || ComplaintStatus.closed: // T5, T6
        break;
      case ComplaintStatus.reported:
        throw StateError('Nothing transitions into reported.');
    }

    final event = StatusEvent(
      id: _eventId(cur.id, cur.timeline.length + 1),
      status: to,
      actorId: actor.id,
      actorRole: actor.role,
      note: note,
      at: at,
    );
    next = next.copyWith(
      status: to,
      updatedAt: at,
      timeline: [...cur.timeline, event],
    );
    return _Step(cur, next, event);
  }

  /// CL-1 / CL-3: a maintenance actor claims unclaimed work.
  Complaint _claimed(Complaint c, AppUser actor) {
    final assignment = c.assignment;
    if (actor.role != UserRole.maintenance ||
        assignment == null ||
        assignment.assigneeId != null) {
      return c;
    }
    return c.copyWith(assignment: assignment.copyWith(assigneeId: actor.id));
  }

  // -------------------------------------------------------------------------
  // Internals: helpers
  // -------------------------------------------------------------------------

  static const TransitionBlocker _staleBlocker = TransitionBlocker(
    code: 'P8',
    message: 'This complaint changed; refresh and retry.',
  );

  static const TransitionBlocker _closedBlocker = TransitionBlocker(
    code: 'P8',
    message: 'This complaint is closed and cannot be changed.',
  );

  static const TransitionBlocker _overrideBlocker = TransitionBlocker(
    code: 'PO',
    message: 'Only an admin can override the priority.',
  );

  ComplaintActionResult _notFound() => ComplaintActionResult.blocked(const [
    TransitionBlocker(code: 'NF', message: 'Complaint not found.'),
  ]);

  /// Priority is recomputed only while unresolved (priority-engine-spec §6).
  static bool _isUnresolved(ComplaintStatus s) =>
      s.order < ComplaintStatus.resolved.order;

  /// [c] with `priority` recomputed for the waiting time as of [at]; the
  /// admin override is never touched (PC-2).
  Complaint _recomputed(Complaint c, DateTime at) {
    final priority = computePriority(
      PriorityInputs(
        category: c.category,
        safetyFlag: c.safetyFlag,
        severity: c.severity,
        peopleAffected: c.peopleAffected,
        waitingTime: c.waitingTime(at),
      ),
    );
    return priority == c.priority ? c : c.copyWith(priority: priority);
  }

  /// The event time: [now], but never before the last timeline entry (TL-2).
  DateTime _eventAt(Complaint c, DateTime now) {
    final last = c.timeline.isEmpty ? c.createdAt : c.timeline.last.at;
    return now.isBefore(last) ? last : now;
  }

  static String _eventId(String complaintId, int n) =>
      'ev-$complaintId-${n.toString().padLeft(2, '0')}';

  /// [s] trimmed, or `null` when blank.
  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Runs [action] after every earlier action on the same complaint [key]
  /// has finished.
  Future<T> _serialized<T>(String key, Future<T> Function() action) {
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _tails[key] = tail;
    tail.whenComplete(() {
      if (identical(_tails[key], tail)) _tails.remove(key);
    });
    return result;
  }
}

/// One planned change of a complaint: the state before and after, and the
/// event that produced it.
class _Step {
  const _Step(this.before, this.after, this.event);

  final Complaint before;
  final Complaint after;
  final StatusEvent event;
}

/// A validated sequence of steps (one, or two for Review & Route), or the
/// blockers that stop it. Nothing is stored until the plan is applied.
class _Plan {
  const _Plan.ok(this.steps) : blockers = const [];
  const _Plan.blocked(this.blockers) : steps = const [];

  final List<_Step> steps;
  final List<TransitionBlocker> blockers;

  bool get ok => blockers.isEmpty;
}
