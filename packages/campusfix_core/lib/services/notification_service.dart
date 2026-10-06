import 'package:meta/meta.dart';

import '../enums/complaint_status.dart';
import '../enums/department.dart';
import '../enums/notification_type.dart';
import '../enums/user_role.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/complaint.dart';
import '../models/status_event.dart';
import '../repositories/notification_repository.dart';
import '../repositories/user_repository.dart';

/// The complaint events that notify people (status-machine-spec §5.1, R11).
enum NotificationTrigger {
  /// Creation of a complaint (not a transition).
  submitted,

  /// T1 `reported -> reviewed`.
  reviewed,

  /// T2 `reviewed -> assigned` (including the auto-route of Review & Route).
  assigned,

  /// T3 `assigned -> inProgress`.
  started,

  /// T4 `inProgress -> resolved`.
  resolved,

  /// T5 `resolved -> verified`.
  verified,

  /// T6 `verified -> closed`.
  closed,

  /// T7 `resolved -> inProgress` (verification failed, rework needed).
  rejected,

  /// T8 `inProgress -> assigned`, or the annotation event of a reassignment
  /// while already `assigned`.
  reassigned,
}

/// Who a templated message is for (status-machine-spec §5.1).
enum NotificationAudience {
  /// The complaint's reporter.
  owner,

  /// `maintenance` staff of a department.
  department,

  /// Every `verifier` and `admin` user.
  verifiers,

  /// Every `admin` user.
  admins,
}

/// One templated message for an audience, before recipients are resolved.
@immutable
class NotificationDraft {
  const NotificationDraft({
    required this.audience,
    required this.type,
    required this.title,
    required this.body,
    this.department,
  });

  final NotificationAudience audience;

  /// The department whose staff receive it; set iff [audience] is
  /// [NotificationAudience.department].
  final Department? department;
  final NotificationType type;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationDraft &&
          other.audience == audience &&
          other.department == department &&
          other.type == type &&
          other.title == title &&
          other.body == body;

  @override
  int get hashCode => Object.hash(audience, department, type, title, body);

  @override
  String toString() =>
      'NotificationDraft(${audience.name}, ${type.name}, $title)';
}

/// The canonical, PII-free notification templates (status-machine-spec §5.1,
/// privacy-spec LK-1).
///
/// Message text is built only from the complaint ID, category / department /
/// priority labels, the location and - for rework - the rejection note. It
/// never contains a reporter's or a staff member's name, ID, e-mail or phone:
/// no template reads `Complaint.reporter` and none is given a user.
///
/// Pure: no I/O, no clock.
abstract final class NotificationTemplates {
  /// The trigger for a complaint moving from [from] to [to], or `null` when
  /// that pair is not a notifying event. [from] is `null` for creation.
  ///
  /// `assigned -> assigned` is the annotation event of a reassignment
  /// (status-machine-spec §5), and `inProgress -> assigned` the T8 pull-back;
  /// both are [NotificationTrigger.reassigned].
  static NotificationTrigger? triggerFor(
    ComplaintStatus? from,
    ComplaintStatus to,
  ) {
    if (from == null) {
      return to == ComplaintStatus.reported
          ? NotificationTrigger.submitted
          : null;
    }
    return switch ((from, to)) {
      (ComplaintStatus.reported, ComplaintStatus.reviewed) =>
        NotificationTrigger.reviewed,
      (ComplaintStatus.reviewed, ComplaintStatus.assigned) =>
        NotificationTrigger.assigned,
      (ComplaintStatus.assigned, ComplaintStatus.inProgress) =>
        NotificationTrigger.started,
      (ComplaintStatus.inProgress, ComplaintStatus.resolved) =>
        NotificationTrigger.resolved,
      (ComplaintStatus.resolved, ComplaintStatus.verified) =>
        NotificationTrigger.verified,
      (ComplaintStatus.verified, ComplaintStatus.closed) =>
        NotificationTrigger.closed,
      (ComplaintStatus.resolved, ComplaintStatus.inProgress) =>
        NotificationTrigger.rejected,
      (ComplaintStatus.inProgress, ComplaintStatus.assigned) ||
      (
        ComplaintStatus.assigned,
        ComplaintStatus.assigned,
      ) => NotificationTrigger.reassigned,
      _ => null,
    };
  }

  /// The messages for [trigger], computed from [c] **after** the event.
  ///
  /// * [previousDepartment] - the department the complaint left (T8 /
  ///   reassignment); its staff are told the complaint left their queue.
  /// * [note] - the event note; the rejection reason for
  ///   [NotificationTrigger.rejected].
  ///
  /// A department message is dropped when the complaint has no department to
  /// address. Order matters: when one person falls in several audiences they
  /// receive only the first message (see `NotificationService`).
  static List<NotificationDraft> plan(
    NotificationTrigger trigger,
    Complaint c, {
    Department? previousDepartment,
    String? note,
  }) {
    final id = c.id;
    final dept = c.assignment?.department;

    NotificationDraft owner(NotificationType type, String title, String body) =>
        NotificationDraft(
          audience: NotificationAudience.owner,
          type: type,
          title: title,
          body: body,
        );

    NotificationDraft staff(
      Department department,
      NotificationType type,
      String title,
      String body,
    ) => NotificationDraft(
      audience: NotificationAudience.department,
      department: department,
      type: type,
      title: title,
      body: body,
    );

    NotificationDraft newWork(Department department) => staff(
      department,
      NotificationType.assignment,
      'New work assigned',
      'New work: $id — ${c.category.label}, ${_where(c)}.',
    );

    switch (trigger) {
      case NotificationTrigger.submitted:
        return [
          owner(
            NotificationType.submission,
            'Complaint submitted',
            'Complaint $id submitted.',
          ),
          NotificationDraft(
            audience: NotificationAudience.admins,
            type: NotificationType.submission,
            title: 'New complaint',
            body:
                'New ${c.effectivePriority.label} complaint $id — '
                '${c.category.label}, ${c.building}.',
          ),
        ];
      case NotificationTrigger.reviewed:
        return [
          owner(
            NotificationType.statusChange,
            'Complaint reviewed',
            '$id has been reviewed.',
          ),
        ];
      case NotificationTrigger.assigned:
        return [
          if (dept != null)
            owner(
              NotificationType.assignment,
              'Complaint assigned',
              '$id assigned to ${dept.label}.',
            ),
          if (dept != null) newWork(dept),
        ];
      case NotificationTrigger.started:
        return [
          owner(
            NotificationType.statusChange,
            'Work started',
            'Work has started on $id.',
          ),
        ];
      case NotificationTrigger.resolved:
        return [
          owner(
            NotificationType.completion,
            'Repair completed',
            'Repair completed on $id; awaiting verification.',
          ),
          NotificationDraft(
            audience: NotificationAudience.verifiers,
            type: NotificationType.completion,
            title: 'Ready to verify',
            body: '$id is ready to verify.',
          ),
        ];
      case NotificationTrigger.verified:
        return [
          owner(
            NotificationType.statusChange,
            'Repair verified',
            '$id repair verified.',
          ),
          if (dept != null)
            staff(
              dept,
              NotificationType.statusChange,
              'Repair verified',
              '$id repair verified.',
            ),
        ];
      case NotificationTrigger.closed:
        return [
          owner(NotificationType.closure, 'Complaint closed', '$id is closed.'),
        ];
      case NotificationTrigger.rejected:
        final reason = note == null || note.trim().isEmpty
            ? null
            : _sentence(note);
        return [
          if (dept != null)
            staff(
              dept,
              NotificationType.statusChange,
              'Rework needed',
              reason == null
                  ? 'Rework needed on $id.'
                  : 'Rework needed on $id: $reason',
            ),
          owner(
            NotificationType.statusChange,
            'Work resumed',
            '$id needs more work; work resumed.',
          ),
        ];
      case NotificationTrigger.reassigned:
        return [
          if (dept != null)
            owner(
              NotificationType.assignment,
              'Complaint reassigned',
              '$id reassigned to ${dept.label}.',
            ),
          if (previousDepartment != null && previousDepartment != dept)
            staff(
              previousDepartment,
              NotificationType.statusChange,
              'Removed from your queue',
              '$id removed from your queue.',
            ),
          if (dept != null) newWork(dept),
        ];
    }
  }

  /// `"Block A, Floor 2, Lab 204"`: building, floor label and room.
  static String _where(Complaint c) =>
      '${c.building}, ${_floorLabel(c.floor)}, ${c.room}';

  /// `"Floor 2"` for numeric floors, `"Ground floor"` for ground, otherwise
  /// the floor name as is.
  static String _floorLabel(String floor) {
    if (int.tryParse(floor) != null) return 'Floor $floor';
    if (floor == 'Ground') return 'Ground floor';
    return floor;
  }

  /// [text] with a closing full stop unless it already ends in `.`, `!` or
  /// `?`.
  static String _sentence(String text) {
    final t = text.trim();
    return RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.';
  }
}

/// Generates and serves in-app notifications (R11, status-machine-spec §5.1).
///
/// In-app only for the prototype (assumption A1); push / e-mail / SMS and an
/// admin notification feed are Phase 2. Message text comes from
/// [NotificationTemplates] and is PII-free.
///
/// Recipient sets (§5.1): **owner** = the reporter; **department** = the
/// `maintenance` users of a department; **verifiers** = every `verifier` and
/// `admin` user; **admins** = every `admin` user. One person receives at most
/// one notification per event: when they fall in several audiences the first
/// message of the template (owner first) wins.
class NotificationService {
  NotificationService({
    required NotificationRepository notifications,
    required UserRepository users,
  }) : _notifications = notifications,
       _users = users;

  final NotificationRepository _notifications;
  final UserRepository _users;

  /// The notifications that [event] (which moved the complaint from [before]
  /// to [after]) produces, **without storing them**. [before] is `null` for
  /// creation.
  ///
  /// Each id is `ntf-<event id>-<recipient id>` and `createdAt` is
  /// `event.at`, so building twice yields identical results. Returns an empty
  /// list when the status pair is not a notifying event.
  Future<List<AppNotification>> buildFor(
    Complaint? before,
    Complaint after,
    StatusEvent event,
  ) async {
    final trigger = NotificationTemplates.triggerFor(
      before?.status,
      event.status,
    );
    if (trigger == null) return const [];

    final drafts = NotificationTemplates.plan(
      trigger,
      after,
      previousDepartment: before?.assignment?.department,
      note: event.note,
    );

    final directory = await _users.all();
    final built = <AppNotification>[];
    final addressed = <String>{};
    for (final draft in drafts) {
      for (final recipientId in _recipients(draft, after, directory)) {
        if (!addressed.add(recipientId)) continue;
        built.add(
          AppNotification(
            id: 'ntf-${event.id}-$recipientId',
            recipientId: recipientId,
            complaintId: after.id,
            type: draft.type,
            title: draft.title,
            body: draft.body,
            createdAt: event.at,
          ),
        );
      }
    }
    return List.unmodifiable(built);
  }

  /// Stores [items] and returns them.
  Future<List<AppNotification>> deliver(Iterable<AppNotification> items) async {
    final stored = <AppNotification>[];
    for (final n in items) {
      stored.add(await _notifications.add(n));
    }
    return List.unmodifiable(stored);
  }

  /// [buildFor] then [deliver]: generates and stores the notifications of one
  /// event. [before] is `null` for creation.
  Future<List<AppNotification>> emitFor(
    Complaint? before,
    Complaint after,
    StatusEvent event,
  ) async => deliver(await buildFor(before, after, event));

  /// Notifications for the creation of [created] (owner and admins).
  Future<List<AppNotification>> emitSubmission(Complaint created) =>
      emitFor(null, created, created.timeline.first);

  /// Notifications addressed to [recipientId], newest first.
  Future<List<AppNotification>> byRecipient(String recipientId) =>
      _notifications.byRecipient(recipientId);

  /// Emits [recipientId]'s notifications now and whenever they change.
  Stream<List<AppNotification>> watchByRecipient(String recipientId) =>
      _notifications.watchByRecipient(recipientId);

  /// Number of unread notifications addressed to [recipientId].
  Future<int> unreadCount(String recipientId) async =>
      (await _notifications.byRecipient(
        recipientId,
      )).where((n) => !n.read).length;

  /// Marks one notification read; `null` when it does not exist.
  Future<AppNotification?> markRead(String id) => _notifications.markRead(id);

  /// Marks every notification of [recipientId] read.
  Future<void> markAllRead(String recipientId) =>
      _notifications.markAllRead(recipientId);

  List<String> _recipients(
    NotificationDraft draft,
    Complaint c,
    List<AppUser> directory,
  ) {
    return switch (draft.audience) {
      NotificationAudience.owner => [c.reporter.userId],
      NotificationAudience.department => [
        for (final u in directory)
          if (u.role == UserRole.maintenance &&
              u.department == draft.department)
            u.id,
      ],
      NotificationAudience.verifiers => [
        for (final u in directory)
          if (u.role == UserRole.verifier || u.role == UserRole.admin) u.id,
      ],
      NotificationAudience.admins => [
        for (final u in directory)
          if (u.role == UserRole.admin) u.id,
      ],
    };
  }
}
