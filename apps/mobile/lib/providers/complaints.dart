// The privacy boundary of the mobile app (data-model-spec §3.5).
//
// `ComplaintRepository` returns raw `Complaint`s that carry reporter PII and
// assignee ids. Ownership and department/claim filtering must see those, so it
// runs HERE, and every public provider below returns `PublicComplaintView`s
// only. Widgets and routes import this library for views; the raw stream stays
// private to this file, so a raw `Complaint` or `ReporterIdentity` cannot reach
// a widget.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories.dart';
import 'session.dart';

/// Every complaint, raw. File-private on purpose (see the header comment).
/// The first value is read through `all()` so the simulated latency produces a
/// loading state; later values come from the repository's change stream.
final _rawComplaintsProvider = StreamProvider<List<Complaint>>((ref) async* {
  final repo = ref.watch(complaintRepositoryProvider);
  yield await repo.all();
  yield* repo.watchAll();
});

/// Re-reads the complaints (pull-to-refresh / Retry) and completes when the
/// new value, or an error, has arrived. Errors surface through the providers'
/// `AsyncValue`s, not through this future.
Future<void> refreshComplaints(WidgetRef ref) async {
  ref.invalidate(_rawComplaintsProvider);
  try {
    await ref.read(_rawComplaintsProvider.future);
  } catch (_) {
    // Shown by the screens as an error state with Retry.
  }
}

/// Most urgent first, then newest (`createdAt`) first.
int _byPriorityThenNewest(PublicComplaintView a, PublicComplaintView b) {
  final byWeight = b.effectivePriority.weight.compareTo(
    a.effectivePriority.weight,
  );
  return byWeight != 0 ? byWeight : b.createdAt.compareTo(a.createdAt);
}

/// Most urgent first, then the longest waiting (oldest `createdAt`) first.
int _byPriorityThenOldest(Complaint a, Complaint b) {
  final byWeight = b.effectivePriority.weight.compareTo(
    a.effectivePriority.weight,
  );
  return byWeight != 0 ? byWeight : a.createdAt.compareTo(b.createdAt);
}

/// When [c] entered `resolved` (latest such event), else its last update.
DateTime _resolvedAt(Complaint c) {
  for (final e in c.timeline.reversed) {
    if (e.status == ComplaintStatus.resolved) return e.at;
  }
  return c.updatedAt;
}

/// An `inProgress` complaint whose latest event is a reject (T7): the entry
/// into `inProgress` was made by a verifier/admin, not the maintenance
/// worker's own "start work" (T3).
bool _isRework(Complaint c) {
  if (c.status != ComplaintStatus.inProgress || c.timeline.isEmpty) {
    return false;
  }
  final last = c.timeline.last;
  return last.status == ComplaintStatus.inProgress &&
      last.actorRole != UserRole.maintenance;
}

/// The Campus Problem Board's source: every complaint in the system, as public
/// views, in repository order. Screens filter/sort it for their own needs.
final boardComplaintsProvider = Provider<AsyncValue<List<PublicComplaintView>>>(
  (ref) => ref.watch(_rawComplaintsProvider).whenData(toPublicViews),
);

/// One complaint by its ID, as a public view; `null` once loaded when no such
/// complaint exists. Used by the Board Item Detail (screens-spec M-11b). The
/// route carries only the ID (privacy LK-5), so this is the screen's whole
/// lookup.
final complaintViewProvider =
    Provider.family<AsyncValue<PublicComplaintView?>, String>(
      (ref, id) => ref.watch(boardComplaintsProvider).whenData((all) {
        for (final c in all) {
          if (c.id == id) return c;
        }
        return null;
      }),
    );

/// The signed-in reporter's own complaints (`reporter.userId` equals the
/// session user), `updatedAt` descending. Ownership is resolved on the raw
/// complaint here and only the public projection is returned (screens-spec
/// M-09). Empty for any other role or when signed out.
final myComplaintsProvider = Provider<AsyncValue<List<PublicComplaintView>>>((
  ref,
) {
  final user = ref.watch(sessionProvider);
  return ref.watch(_rawComplaintsProvider).whenData((all) {
    if (user == null || user.role != UserRole.reporter) return const [];
    final mine = [
      for (final c in all)
        if (c.reporter.userId == user.id) c,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return toPublicViews(mine);
  });
});

/// Home "My active complaints": at most three of the reporter's complaints
/// that are not `closed`, most recently updated first (screens-spec M-02).
final myActiveComplaintsProvider =
    Provider<AsyncValue<List<PublicComplaintView>>>(
      (ref) => ref
          .watch(myComplaintsProvider)
          .whenData(
            (mine) => [
              for (final c in mine)
                if (c.status != ComplaintStatus.closed) c,
            ].take(3).toList(growable: false),
          ),
    );

/// Home "Campus board highlights": at most three open (not `closed`)
/// complaints whose `effectivePriority` is critical or high, most urgent then
/// newest first (screens-spec M-02).
final boardHighlightsProvider = Provider<AsyncValue<List<PublicComplaintView>>>(
  (ref) => ref.watch(boardComplaintsProvider).whenData((all) {
    final urgent = [
      for (final c in all)
        if (c.status != ComplaintStatus.closed &&
            (c.effectivePriority == Priority.critical ||
                c.effectivePriority == Priority.high))
          c,
    ]..sort(_byPriorityThenNewest);
    return urgent.take(3).toList(growable: false);
  }),
);

/// A maintenance worker's queue (screens-spec M-13): three disjoint lists of
/// public views, scoped to the worker's department.
class WorkQueue {
  const WorkQueue({
    this.toStart = const [],
    this.inProgress = const [],
    this.rework = const [],
  });

  /// `assigned` to the worker's department and not claimed by a colleague.
  final List<PublicComplaintView> toStart;

  /// `inProgress`, claimed by the worker, not awaiting rework.
  final List<PublicComplaintView> inProgress;

  /// `inProgress`, claimed by the worker, whose latest event is a reject.
  final List<PublicComplaintView> rework;

  int get toStartCount => toStart.length;
  int get inProgressCount => inProgress.length;
  int get reworkCount => rework.length;

  /// Whether there is nothing to do at all.
  bool get isEmpty => toStart.isEmpty && inProgress.isEmpty && rework.isEmpty;
}

/// The signed-in maintenance worker's [WorkQueue]. Department and claim
/// filtering (privacy-spec §5.3) uses the raw `assignment` here; the lists
/// carry public views only. Empty for any other role.
final workQueueProvider = Provider<AsyncValue<WorkQueue>>((ref) {
  final user = ref.watch(sessionProvider);
  return ref.watch(_rawComplaintsProvider).whenData((all) {
    final department = user?.department;
    if (user == null ||
        user.role != UserRole.maintenance ||
        department == null) {
      return const WorkQueue();
    }
    final toStart = <Complaint>[];
    final inProgress = <Complaint>[];
    final rework = <Complaint>[];
    for (final c in all) {
      final assignment = c.assignment;
      if (assignment == null || assignment.department != department) continue;
      final claimedBy = assignment.assigneeId;
      if (c.status == ComplaintStatus.assigned) {
        // P7: work a colleague already claimed is not "to start" for me.
        if (claimedBy == null || claimedBy == user.id) toStart.add(c);
      } else if (c.status == ComplaintStatus.inProgress &&
          claimedBy == user.id) {
        (_isRework(c) ? rework : inProgress).add(c);
      }
    }
    List<PublicComplaintView> view(List<Complaint> l) =>
        toPublicViews(l..sort(_byPriorityThenOldest));
    return WorkQueue(
      toStart: view(toStart),
      inProgress: view(inProgress),
      rework: view(rework),
    );
  });
});

/// The verifier's queue (screens-spec M-16): `resolved` complaints, most
/// urgent first, then the longest waiting since being resolved.
final verificationQueueProvider =
    Provider<AsyncValue<List<PublicComplaintView>>>((ref) {
      final user = ref.watch(sessionProvider);
      return ref.watch(_rawComplaintsProvider).whenData((all) {
        if (user == null || user.role != UserRole.verifier) return const [];
        final waiting = [
          for (final c in all)
            if (c.status == ComplaintStatus.resolved) c,
        ];
        waiting.sort((a, b) {
          final byWeight = b.effectivePriority.weight.compareTo(
            a.effectivePriority.weight,
          );
          return byWeight != 0
              ? byWeight
              : _resolvedAt(a).compareTo(_resolvedAt(b));
        });
        return toPublicViews(waiting);
      });
    });
