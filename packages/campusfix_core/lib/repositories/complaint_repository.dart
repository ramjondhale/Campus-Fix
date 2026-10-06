import '../models/complaint.dart';

/// Access to stored complaints. The prototype binds an in-memory mock; Phase 2
/// swaps in a Firestore implementation with no UI change.
///
/// Implementations return the full [Complaint] (including reporter PII); the
/// UI must project it through the privacy views before display.
abstract class ComplaintRepository {
  /// All complaints.
  Future<List<Complaint>> all();

  /// The complaint with [id], or `null` if none exists.
  Future<Complaint?> byId(String id);

  /// Persists a new complaint from [draft] (assigning its Complaint ID) and
  /// returns the stored complaint.
  Future<Complaint> submit(Complaint draft);

  /// Persists changes to an existing complaint and returns the stored result.
  Future<Complaint> update(Complaint c);

  /// Emits the full list of complaints now and again whenever it changes.
  Stream<List<Complaint>> watchAll();
}
