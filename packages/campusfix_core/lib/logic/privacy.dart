// Privacy projections - the single choke point where a raw `Complaint`
// (which carries reporter PII) becomes a view (privacy-spec PV-3).
// All functions are pure: no logging, no caching, no mutation.

import '../models/app_user.dart';
import '../models/complaint.dart';
import '../models/complaint_views.dart';
import '../models/status_event.dart';

/// Projects [c] to the PII-free [PublicComplaintView].
///
/// Total, pure and role-independent: the output is the same for every
/// caller. Drops the reporter, the assignee / assigner, every timeline
/// `actorId` and `id`, and the raw `priority` / `priorityOverride` (only the
/// effective priority is exposed). The department label is derived from
/// `c.assignment?.department`.
PublicComplaintView toPublicView(Complaint c) {
  return PublicComplaintView(
    id: c.id,
    category: c.category,
    title: c.title,
    building: c.building,
    floor: c.floor,
    room: c.room,
    description: c.description,
    beforePhotos: c.beforePhotos,
    afterPhotos: c.afterPhotos,
    effectivePriority: c.effectivePriority,
    status: c.status,
    safetyFlag: c.safetyFlag,
    assignedDepartment: c.assignment?.department,
    resolutionNote: c.resolutionNote,
    timeline: [for (final e in c.timeline) _toPublicEvent(e)],
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
  );
}

/// Projects every complaint in [cs] with [toPublicView], preserving order.
List<PublicComplaintView> toPublicViews(Iterable<Complaint> cs) => [
  for (final c in cs) toPublicView(c),
];

/// Projects [c] to the admin-only [AdminComplaintView], or returns `null`
/// unless [requester] may see reporter identity
/// (`UserRole.canSeeReporterIdentity`, i.e. `role == admin`).
///
/// A reporter requesting their **own** complaint also gets `null` (they use
/// the public view; privacy-spec PV-6).
AdminComplaintView? toAdminView(Complaint c, AppUser requester) {
  if (!requester.role.canSeeReporterIdentity) return null;
  return AdminComplaintView(
    id: c.id,
    category: c.category,
    title: c.title,
    building: c.building,
    floor: c.floor,
    room: c.room,
    description: c.description,
    beforePhotos: c.beforePhotos,
    afterPhotos: c.afterPhotos,
    priority: c.priority,
    priorityOverride: c.priorityOverride,
    status: c.status,
    safetyFlag: c.safetyFlag,
    assignment: c.assignment,
    resolutionNote: c.resolutionNote,
    timeline: c.timeline,
    reporter: c.reporter,
    severity: c.severity,
    peopleAffected: c.peopleAffected,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
  );
}

PublicStatusEvent _toPublicEvent(StatusEvent e) => PublicStatusEvent(
  status: e.status,
  actorRole: e.actorRole,
  note: e.note,
  at: e.at,
);
