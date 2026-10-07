import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';

/// Whether [c] matches the free-text [query] on public fields only (privacy
/// LK-2): the Complaint ID and the description, and the location line when
/// [includeLocation] is set. Case-insensitive; a blank query matches all.
bool matchesComplaintQuery(
  PublicComplaintView c,
  String query, {
  bool includeLocation = false,
}) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (c.id.toLowerCase().contains(q)) return true;
  if (c.description.toLowerCase().contains(q)) return true;
  return includeLocation &&
      ComplaintCard.locationOf(c).toLowerCase().contains(q);
}
