// The A-04 controller: what the complaint detail may know, per role, and how it
// acts (screens-spec A-04, privacy-spec PV-4 / PV-5 / LK-8).
//
// **This directory is the one place the admin console touches a raw
// `Complaint`, the complaint repository, an `AdminComplaintView` or an
// `actorId` / `assigneeId`.** Core's PR-T14 guard allow-lists exactly
// `lib/features/complaint_detail/` for those and the single file
// `identity_panel.dart` for `ReporterIdentity` / `.reporter`; the admin guard
// (`test/architecture_guard_test.dart`) mirrors that. Nothing else in `lib/`
// may import this layer's raw types.
//
// **Role split.**
//
// * **Admin** -> the stored complaint is read from the repository and run
//   through `toAdminView` (null for any other role). The screen gets a
//   [ComplaintDetail] whose [AdminDetail] carries the admin view (priority
//   inputs, full assignment, actor-bearing timeline) and the staff directory
//   needed to turn an `assigneeId` / `actorId` into a name. The reporter's
//   identity rides inside the admin view and is only ever rendered by
//   `identity_panel.dart`, behind an explicit reveal.
// * **Verifier** -> `complaintViewProvider` (a `PublicComplaintView`), never
//   `toAdminView`: a [ComplaintDetail] with no [AdminDetail] at all, so there
//   is no identity, assignee, actor or priority input in memory to leak.
//
// **Actions.** [manageActionsFor] decides which manage actions a role is
// offered (from the status machine's L1 matrix plus the action's own role),
// and which of them are disabled with the unmet precondition; [DetailActionNotifier]
// runs them through `ComplaintService` as the signed-in user and hands the UI
// a PII-free [DetailActionResult] (success, or why not). The stored
// `Complaint` the service returns is dropped here.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
// The barrel hides the raw complaint repository on purpose; this directory is
// one of the two places allowed to read it.
import '../../providers/repositories.dart' show complaintRepositoryProvider;

// ---------------------------------------------------------------------------
// The view the screen consumes
// ---------------------------------------------------------------------------

/// A member of staff as an admin sees one: the name and ID that an `actorId`,
/// `assigneeId` or `assignedBy` resolves to (screens-spec A-04, SC-OI-4).
@immutable
class StaffRef {
  const StaffRef({
    required this.id,
    required this.name,
    required this.idNumber,
    required this.role,
    this.department,
  });

  /// Resolves a directory user.
  factory StaffRef.of(AppUser user) => StaffRef(
    id: user.id,
    name: user.displayName,
    idNumber: user.idNumber,
    role: user.role,
    department: user.department,
  );

  /// The user id (the value of an `assigneeId`).
  final String id;
  final String name;

  /// The staff ID number (e.g. `MNT-ELE-01`).
  final String idNumber;
  final UserRole role;
  final Department? department;

  /// "Name · ID", as shown beside an actor or an assignee.
  String get line => '$name · $idNumber';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffRef &&
          other.id == id &&
          other.name == name &&
          other.idNumber == idNumber &&
          other.role == role &&
          other.department == department;

  @override
  int get hashCode => Object.hash(id, name, idNumber, role, department);
}

/// The admin-only half of a [ComplaintDetail]: the full admin view and the
/// staff the ids on it resolve to.
@immutable
class AdminDetail {
  const AdminDetail({
    required this.view,
    this.staff = const <String, StaffRef>{},
  });

  /// The admin view (priority inputs, full assignment, actor-bearing
  /// timeline, reporter identity).
  final AdminComplaintView view;

  /// The staff the ids on [view] resolve to, by user id. Only
  /// admin / verifier / maintenance users: a reporter never appears here, so
  /// no reporter name can reach the timeline before the reveal.
  final Map<String, StaffRef> staff;

  /// The staff member [id] resolves to, or `null` when unknown.
  StaffRef? staffById(String? id) => id == null ? null : staff[id];
}

/// One complaint as the signed-in console user may see it.
///
/// [complaint] is the public data both roles share. [admin] is `null` for a
/// verifier: the type itself says whether identity, assignee, actor and
/// priority-input data exist for this viewer.
@immutable
class ComplaintDetail {
  /// The limited form: public data only (verifier).
  const ComplaintDetail.limited(this.complaint) : admin = null;

  /// The full form (admin).
  const ComplaintDetail.full({
    required this.complaint,
    required AdminDetail this.admin,
  });

  /// The public projection (no actor, assignee or reporter data).
  final PublicComplaintView complaint;

  /// The admin-only data; `null` for a verifier.
  final AdminDetail? admin;

  String get id => complaint.id;
  ComplaintStatus get status => complaint.status;

  /// Whether this is the full (admin) form.
  bool get isAdmin => admin != null;

  /// `closed` is read-only (INV-4): no manage action at all.
  bool get isReadOnly => complaint.status.isTerminal;
}

// ---------------------------------------------------------------------------
// Providers: the role split
// ---------------------------------------------------------------------------

/// The admin form of complaint [id]: the stored complaint through
/// `toAdminView`, live via the repository's change stream. `null` once loaded
/// when no such complaint exists. Stays loading for a viewer who is not an
/// admin (the router and the role guard already keep them out; this keeps the
/// data out too).
final _adminDetailProvider = StreamProvider.autoDispose
    .family<ComplaintDetail?, String>((ref, id) async* {
      final AppUser? actor = ref.watch(sessionProvider);
      if (actor == null || !actor.role.canSeeReporterIdentity) return;
      final ComplaintRepository repo = ref.watch(complaintRepositoryProvider);

      // Staff only: a reporter user never enters the directory, so a reporter
      // actor on the timeline stays a bare role until the reveal.
      final Map<String, StaffRef> staff = <String, StaffRef>{
        for (final AppUser u in await ref.watch(userRepositoryProvider).all())
          if (u.role != UserRole.reporter) u.id: StaffRef.of(u),
      };

      ComplaintDetail? build(Iterable<Complaint> all) {
        for (final Complaint c in all) {
          if (c.id != id) continue;
          final AdminComplaintView? view = toAdminView(c, actor);
          if (view == null) return null;
          return ComplaintDetail.full(
            complaint: toPublicView(c),
            admin: AdminDetail(view: view, staff: staff),
          );
        }
        return null;
      }

      yield build(await repo.all());
      await for (final List<Complaint> all in repo.watchAll()) {
        yield build(all);
      }
    });

/// Complaint [id] as the signed-in admin or verifier may see it: the admin
/// form for an admin, the public-view form for a verifier. `null` once loaded
/// means "no such complaint" (E-404, screens-spec G-6); the route carries only
/// the ID (privacy LK-5).
final complaintDetailProvider = Provider.autoDispose
    .family<AsyncValue<ComplaintDetail?>, String>((ref, id) {
      final AppUser? user = ref.watch(sessionProvider);
      if (user == null || !mayUseConsole(user.role)) {
        return const AsyncLoading<ComplaintDetail?>();
      }
      if (user.role.canSeeReporterIdentity) {
        return ref.watch(_adminDetailProvider(id));
      }
      return ref
          .watch(complaintViewProvider(id))
          .whenData(
            (PublicComplaintView? v) =>
                v == null ? null : ComplaintDetail.limited(v),
          );
    });

/// Re-reads complaint [id] (Retry / Refresh) and completes when it settles.
Future<void> refreshComplaintDetail(WidgetRef ref, String id) async {
  ref.invalidate(_adminDetailProvider(id));
  await refreshComplaints(ref);
}

/// The maintenance staff of [department] an admin may name as assignee.
final assignableStaffProvider = FutureProvider.autoDispose
    .family<List<StaffRef>, Department>((ref, department) async {
      final List<AppUser> users = await ref
          .watch(userRepositoryProvider)
          .maintenanceByDepartment(department);
      return <StaffRef>[for (final AppUser u in users) StaffRef.of(u)];
    });

// ---------------------------------------------------------------------------
// Which manage actions are offered
// ---------------------------------------------------------------------------

/// A manage action of A-04 (screens-spec A-04, the Manage-actions table).
enum ManageAction {
  /// T1 (+ T2): `reported -> reviewed`, auto-routed to a department when the
  /// category has one. A and V.
  reviewAndRoute('Review & Route'),

  /// T2 for a `reviewed`, unrouted complaint. A only.
  assign('Assign'),

  /// Reassign while `assigned` / `inProgress`; the reason is required. A only.
  reassign('Reassign'),

  /// T3 on behalf of maintenance. A only.
  startWork('Start work on behalf'),

  /// T4 on behalf of maintenance: after-photos and a resolution note. A only.
  resolve('Resolve on behalf'),

  /// T5. A and V.
  verify('Verify'),

  /// T7: back to maintenance; the reason is required. A and V.
  reject('Reject — needs rework'),

  /// T6. **A only** (the verifier never closes).
  close('Close'),

  /// Set or clear the priority override (not a status change). A only.
  setPriorityOverride('Set priority override'),

  /// Toggle the safety flag (not a status change). A only.
  toggleSafetyFlag('Safety flag');

  const ManageAction(this.label);

  /// The button label.
  final String label;

  /// Whether this action changes the status (the Manage bar); the other two
  /// edit the priority (the Priority panel).
  bool get changesStatus => switch (this) {
    setPriorityOverride || toggleSafetyFlag => false,
    _ => true,
  };

  /// Whether the action asks for a confirm dialog that could destroy work
  /// (shown in the destructive style).
  bool get isDestructive => this == reject;
}

/// The roles that may take [action] (everything else is admin only).
bool mayTakeAction(ManageAction action, UserRole role) => switch (action) {
  ManageAction.reviewAndRoute ||
  ManageAction.verify ||
  ManageAction.reject => role == UserRole.admin || role == UserRole.verifier,
  _ => role == UserRole.admin,
};

/// An action on offer, enabled or disabled with the reason.
@immutable
class ManageActionOption {
  const ManageActionOption(this.action, {this.disabledReason, String? label})
    : _label = label;

  final ManageAction action;
  final String? _label;

  /// The button label: the action's own, unless the state calls for a more
  /// specific one ("Remove safety flag").
  String get label => _label ?? action.label;

  /// Why the action cannot be taken right now (the unmet precondition, in the
  /// words of the core rule); `null` when it can.
  final String? disabledReason;

  bool get enabled => disabledReason == null;
}

/// The reason a repair cannot be verified, in the words of core rules P1/P2,
/// or `null` when the evidence (an after-repair photo and a resolution note)
/// is there. Corrupt data only: a resolve always carries both.
String? verifyBlockedReason(PublicComplaintView c) {
  final List<String> problems = <String>[
    if (c.afterPhotos.isEmpty) 'Add at least one after-repair photo.',
    if ((c.resolutionNote ?? '').trim().isEmpty) 'Add a resolution note.',
  ];
  return problems.isEmpty ? null : problems.join(' ');
}

/// The manage actions [role] is offered for [c], in the order of the flow
/// (screens-spec A-04, AC-53).
///
/// An action is **shown** only when the status machine's L1 matrix lets
/// [role] take that edge (`StatusMachine.nextStatuses`) and the action's own
/// role allows it (Close, Assign, Reassign, Start, Resolve and the priority
/// edits are admin only even where the machine also lists the verifier). An
/// action whose precondition is already known to fail is **disabled** with
/// the core rule's reason. A `closed` complaint is read-only: nothing at all.
///
/// Preconditions that depend on what the user types (a reject reason, an
/// assignment's department, a resolution note) are checked by the dialog and
/// by the service when it is submitted.
List<ManageActionOption> manageActionsFor(
  PublicComplaintView c,
  UserRole role,
) {
  if (!mayUseConsole(role) || c.status.isTerminal) {
    return const <ManageActionOption>[];
  }
  final List<ComplaintStatus> next = StatusMachine.nextStatuses(c.status, role);
  bool offered(ManageAction a, ComplaintStatus to) =>
      mayTakeAction(a, role) && next.contains(to);
  final ComplaintStatus s = c.status;

  return <ManageActionOption>[
    if (s == ComplaintStatus.reported &&
        offered(ManageAction.reviewAndRoute, ComplaintStatus.reviewed))
      const ManageActionOption(ManageAction.reviewAndRoute),
    if (s == ComplaintStatus.reviewed &&
        offered(ManageAction.assign, ComplaintStatus.assigned))
      const ManageActionOption(ManageAction.assign),
    if (s == ComplaintStatus.assigned &&
        offered(ManageAction.startWork, ComplaintStatus.inProgress))
      const ManageActionOption(ManageAction.startWork),
    if (mayTakeAction(ManageAction.reassign, role) &&
        (s == ComplaintStatus.assigned || s == ComplaintStatus.inProgress))
      const ManageActionOption(ManageAction.reassign),
    if (s == ComplaintStatus.inProgress &&
        offered(ManageAction.resolve, ComplaintStatus.resolved))
      const ManageActionOption(ManageAction.resolve),
    if (s == ComplaintStatus.resolved &&
        offered(ManageAction.verify, ComplaintStatus.verified))
      ManageActionOption(
        ManageAction.verify,
        disabledReason: verifyBlockedReason(c),
      ),
    if (s == ComplaintStatus.resolved &&
        offered(ManageAction.reject, ComplaintStatus.inProgress))
      const ManageActionOption(ManageAction.reject),
    if (s == ComplaintStatus.verified &&
        offered(ManageAction.close, ComplaintStatus.closed))
      const ManageActionOption(ManageAction.close),
  ];
}

/// The two priority edits an admin is offered for [c] (not status changes):
/// the override is open until the complaint closes; the safety flag changes
/// only while the repair is unresolved and never on a Safety-category
/// complaint, which is always flagged (core rule SF).
List<ManageActionOption> priorityActionsFor(
  PublicComplaintView c,
  UserRole role, {
  bool hasOverride = false,
}) {
  if (role != UserRole.admin || c.status.isTerminal) {
    return const <ManageActionOption>[];
  }
  final bool unresolved = c.status.order < ComplaintStatus.resolved.order;
  final String? flagBlocked = !unresolved
      ? 'The safety flag cannot change once the repair is done.'
      : (c.safetyFlag && c.category == ProblemCategory.safety)
      ? 'A Safety complaint is always flagged.'
      : null;
  return <ManageActionOption>[
    ManageActionOption(
      ManageAction.setPriorityOverride,
      label: hasOverride ? 'Change priority override' : null,
    ),
    ManageActionOption(
      ManageAction.toggleSafetyFlag,
      disabledReason: flagBlocked,
      label: c.safetyFlag ? 'Remove safety flag' : 'Flag as safety issue',
    ),
  ];
}

// ---------------------------------------------------------------------------
// Running an action
// ---------------------------------------------------------------------------

/// What an action asks of the service. Plain values only (no identity): the
/// fields an action does not use stay at their defaults.
@immutable
class ManageInput {
  const ManageInput({
    this.note,
    this.resolutionNote,
    this.department,
    this.assigneeId,
    this.afterPhotos = const <Attachment>[],
    this.priorityOverride,
    this.safetyFlag,
  });

  /// The optional note, or the reason of a reject / reassign.
  final String? note;

  /// The resolution note of a resolve.
  final String? resolutionNote;

  /// The department to route or assign to.
  final Department? department;

  /// The staff member to name (an opaque user id), or `null` for none.
  final String? assigneeId;

  /// The after-repair photos of a resolve.
  final List<Attachment> afterPhotos;

  /// The override to set; `null` clears it ([ManageAction.setPriorityOverride]).
  final Priority? priorityOverride;

  /// The new safety flag ([ManageAction.toggleSafetyFlag]).
  final bool? safetyFlag;
}

/// How an action ended, as far as the UI is concerned.
enum DetailActionOutcome {
  /// The change was applied.
  success,

  /// The rules said no (P1..P9, RA2, SF ...): [DetailActionResult.messages]
  /// says why. Nothing was changed.
  blocked,

  /// Somebody changed the complaint since the screen drew it (P8). Nothing
  /// was changed; refresh and try again.
  stale,

  /// The write itself failed (outage, unexpected error). The dialog keeps its
  /// input and offers Retry.
  failed,
}

/// What the UI may know about a finished action: the outcome and the
/// user-facing messages. No complaint, no identity.
@immutable
class DetailActionResult {
  const DetailActionResult._(this.outcome, this.messages);

  const DetailActionResult.success()
    : this._(DetailActionOutcome.success, const <String>[]);

  DetailActionResult.blocked(List<String> messages)
    : this._(DetailActionOutcome.blocked, List<String>.unmodifiable(messages));

  DetailActionResult.stale(List<String> messages)
    : this._(DetailActionOutcome.stale, List<String>.unmodifiable(messages));

  DetailActionResult.failed(String message)
    : this._(DetailActionOutcome.failed, <String>[message]);

  final DetailActionOutcome outcome;

  /// Why a blocked / stale action did not happen (the rule messages) or a
  /// friendly sentence for a failed one; empty on success.
  final List<String> messages;

  bool get ok => outcome == DetailActionOutcome.success;
}

/// The action in flight, if any.
@immutable
class DetailActionState {
  const DetailActionState({this.running});

  /// The action being sent right now; `null` when idle.
  final ManageAction? running;

  /// Whether any action is in flight (a second tap is ignored, G-3).
  bool get busy => running != null;

  /// Whether [action] is the one in flight.
  bool isRunning(ManageAction action) => running == action;
}

/// Runs the manage actions of one complaint as the signed-in console user.
///
/// It sits beside the raw repository on purpose: it reads the stored complaint
/// and hands it to `ComplaintService` (the L3 executor), which a widget must
/// never do. The complaint it gives the service carries the status the screen
/// was showing, so a change made in between is rejected as stale (rule P8)
/// instead of silently applied. Only [mayTakeAction] roles get through: a
/// verifier cannot assign, close or touch the priority even by calling this
/// directly.
class DetailActionNotifier extends Notifier<DetailActionState> {
  DetailActionNotifier(this.complaintId);

  /// The complaint these actions are for.
  final String complaintId;

  @override
  DetailActionState build() => const DetailActionState();

  /// Runs [action] on the complaint [seenStatus] says the screen was showing.
  /// Returns the result, or `null` when another action is already in flight
  /// (a second tap is ignored, screens-spec G-3).
  Future<DetailActionResult?> run(
    ManageAction action, {
    required ComplaintStatus seenStatus,
    ManageInput input = const ManageInput(),
  }) async {
    if (state.busy) return null;
    final AppUser? actor = ref.read(sessionProvider);
    if (actor == null || !mayTakeAction(action, actor.role)) {
      return DetailActionResult.blocked(const <String>[
        'You cannot take this action.',
      ]);
    }

    // The same words as core rule P4; the service takes a department as a
    // required value, so a missing one is stopped here.
    if ((action == ManageAction.assign || action == ManageAction.reassign) &&
        input.department == null) {
      return DetailActionResult.blocked(const <String>['Choose a department.']);
    }

    state = DetailActionState(running: action);
    try {
      final Complaint? stored = await ref
          .read(complaintRepositoryProvider)
          .byId(complaintId);
      if (stored == null) {
        return DetailActionResult.blocked(const <String>[
          "We couldn't find that complaint.",
        ]);
      }
      // The service validates against the stored copy and treats the status
      // of the one it is given as "what the caller saw" (P8).
      final Complaint seen = stored.copyWith(status: seenStatus);
      final ComplaintActionResult result = await _dispatch(
        ref.read(complaintServiceProvider),
        action,
        seen,
        actor,
        input,
      );
      if (result.ok) return const DetailActionResult.success();
      return result.codes.contains('P8')
          ? DetailActionResult.stale(result.messages)
          : DetailActionResult.blocked(result.messages);
    } catch (_) {
      return DetailActionResult.failed(_failureText(action));
    } finally {
      if (ref.mounted) state = const DetailActionState();
    }
  }

  Future<ComplaintActionResult> _dispatch(
    ComplaintService service,
    ManageAction action,
    Complaint c,
    AppUser actor,
    ManageInput input,
  ) {
    final bool admin = actor.role == UserRole.admin;
    final String? note = _clean(input.note);
    return switch (action) {
      // A may choose the department and staff member; a verifier can only
      // accept the auto-route (core rules P5 / MA-3).
      ManageAction.reviewAndRoute => service.reviewAndRoute(
        c,
        actor,
        note: note,
        department: admin ? input.department : null,
        assigneeId: admin ? input.assigneeId : null,
      ),
      ManageAction.assign => service.assign(
        c,
        actor,
        department: input.department!,
        assigneeId: input.assigneeId,
        note: note,
      ),
      ManageAction.reassign => service.reassign(
        c,
        actor,
        department: input.department!,
        assigneeId: input.assigneeId,
        reason: input.note?.trim() ?? '',
      ),
      ManageAction.startWork => service.startWork(c, actor, note: note),
      ManageAction.resolve => service.resolve(
        c,
        actor,
        resolutionNote: input.resolutionNote?.trim() ?? '',
        afterPhotos: input.afterPhotos,
      ),
      ManageAction.verify => service.verify(c, actor, note: note),
      ManageAction.reject => service.reject(
        c,
        actor,
        note: input.note?.trim() ?? '',
      ),
      ManageAction.close => service.close(c, actor, note: note),
      ManageAction.setPriorityOverride => service.setPriorityOverride(
        c,
        actor,
        input.priorityOverride,
      ),
      ManageAction.toggleSafetyFlag => service.setSafetyFlag(
        c,
        actor,
        input.safetyFlag ?? !c.safetyFlag,
      ),
    };
  }

  static String? _clean(String? s) {
    final String? t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _failureText(ManageAction action) =>
      "We couldn't ${_verb(action)}. Check your connection and try again. "
      'Nothing you entered was lost.';

  static String _verb(ManageAction action) => switch (action) {
    ManageAction.reviewAndRoute => 'review this complaint',
    ManageAction.assign => 'assign this complaint',
    ManageAction.reassign => 'reassign this complaint',
    ManageAction.startWork => 'start the work',
    ManageAction.resolve => 'resolve this complaint',
    ManageAction.verify => 'verify the repair',
    ManageAction.reject => 'send the job back',
    ManageAction.close => 'close this complaint',
    ManageAction.setPriorityOverride => 'change the priority',
    ManageAction.toggleSafetyFlag => 'change the safety flag',
  };
}

/// The manage-action runner of complaint [id]. Auto-disposed: it holds only
/// "what is in flight", which never outlives the screen.
final detailActionProvider = NotifierProvider.autoDispose
    .family<DetailActionNotifier, DetailActionState, String>(
      DetailActionNotifier.new,
    );
