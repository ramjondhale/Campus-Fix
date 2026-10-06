import '../enums/complaint_status.dart';
import '../enums/department.dart';
import '../models/complaint.dart';

/// Access to stored complaints. The prototype binds an in-memory mock; Phase 2
/// swaps in a Firestore implementation with no UI change.
///
/// Implementations return the full [Complaint] (including reporter PII); the
/// UI must project it through the privacy views before display. The query
/// methods ([byReporter], [byDepartment], [byStatus]) exist so ownership and
/// department filtering can run inside the data layer, before projection
/// (privacy-spec §5.3).
abstract class ComplaintRepository {
  /// All complaints.
  Future<List<Complaint>> all();

  /// The complaint with [id], or `null` if none exists.
  Future<Complaint?> byId(String id);

  /// Complaints filed by the reporter whose `reporter.userId` is [userId].
  Future<List<Complaint>> byReporter(String userId);

  /// Complaints currently assigned to [department]
  /// (`assignment.department == department`). Unassigned complaints are never
  /// included.
  Future<List<Complaint>> byDepartment(Department department);

  /// Complaints whose current status is [status].
  Future<List<Complaint>> byStatus(ComplaintStatus status);

  /// Persists a new complaint exactly as prepared by the caller and returns
  /// it. The repository does **not** assign the Complaint ID or compute the
  /// priority - the caller (`ComplaintService`) has already done both.
  Future<Complaint> submit(Complaint draft);

  /// Persists changes to an existing complaint and returns the stored result.
  Future<Complaint> update(Complaint c);

  /// Emits the full list of complaints now and again whenever it changes.
  Stream<List<Complaint>> watchAll();
}
