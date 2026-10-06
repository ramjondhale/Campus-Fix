import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Smoke test that the barrel exports the full S2.1 public surface.
void main() {
  test('barrel exports enums, models, id generator and repositories', () {
    // Enums
    expect(<Object>[
      ProblemCategory.values,
      Priority.values,
      ComplaintStatus.values,
      UserRole.values,
      Department.values,
      Severity.values,
      PeopleAffected.values,
      AttachmentKind.values,
    ], everyElement(isNotEmpty));

    // Models
    expect(minimalComplaint(), isA<Complaint>());
    expect(reporter, isA<ReporterIdentity>());
    expect(before('b'), isA<Attachment>());
    expect(event('e', ComplaintStatus.reported), isA<StatusEvent>());

    // Id generator
    expect(ComplaintIdGenerator().next(DateTime(2026)), 'CF-2026-00001');
  });
}
