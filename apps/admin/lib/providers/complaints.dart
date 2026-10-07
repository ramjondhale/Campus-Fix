// The privacy boundary of the admin console (data-model-spec section 3.5,
// privacy-spec section 5.1).
//
// `ComplaintRepository` returns raw `Complaint`s that carry reporter PII and
// assignee ids. The dashboard (A-02) and the complaint list (A-03) consume
// aggregates and `PublicComplaintView`s only, so the raw stream stays private
// to this file and every public provider below returns public views. Widgets
// and routes import this library for views; a raw `Complaint` or
// `ReporterIdentity` cannot reach a widget.
//
// Identity is revealed only on the admin-only A-04 panel (S5.4), which gets its
// own, separately allow-listed path; nothing here builds an admin view.

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

/// Re-reads the complaints (Retry) and completes when the new value, or an
/// error, has arrived. Errors surface through the providers' `AsyncValue`s,
/// not through this future.
Future<void> refreshComplaints(WidgetRef ref) async {
  ref.invalidate(_rawComplaintsProvider);
  try {
    await ref.read(_rawComplaintsProvider.future);
  } catch (_) {
    // Shown by the screens as an error state with Retry.
  }
}

/// Every complaint in the system as public views, live via the repository's
/// change stream, in repository order. This is the one feed the dashboard
/// aggregates (S5.2) and the list's filtering and sorting (S5.3) build on.
///
/// Empty unless the signed-in user may use the console (admin or verifier):
/// the route guard already keeps other roles out, this keeps the data out too.
final allComplaintsProvider = Provider<AsyncValue<List<PublicComplaintView>>>((
  ref,
) {
  final user = ref.watch(sessionProvider);
  return ref.watch(_rawComplaintsProvider).whenData((all) {
    if (user == null || !mayUseConsole(user.role)) return const [];
    return toPublicViews(all);
  });
});

/// One complaint by its ID, as a public view; `null` once loaded when no such
/// complaint exists (E-404, screens-spec G-6). The route carries only the ID
/// (privacy LK-5), so this is the screen's whole lookup.
final complaintViewProvider =
    Provider.family<AsyncValue<PublicComplaintView?>, String>(
      (ref, id) => ref.watch(allComplaintsProvider).whenData((all) {
        for (final c in all) {
          if (c.id == id) return c;
        }
        return null;
      }),
    );
