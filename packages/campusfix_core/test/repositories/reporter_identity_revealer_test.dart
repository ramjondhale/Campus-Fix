import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// A minimal fake proving the audited-reveal seam (plan S-5) has the spec
/// signature and can be implemented from outside the package.
class _FakeRevealer implements ReporterIdentityRevealer {
  String? lastReason;

  @override
  Future<ReporterIdentity> reveal(String complaintId, {String? reason}) async {
    lastReason = reason;
    return reporter;
  }
}

void main() {
  test('the barrel exports the audited-reveal seam', () async {
    final _FakeRevealer fake = _FakeRevealer();
    final ReporterIdentityRevealer revealer = fake;

    expect(await revealer.reveal('CF-2026-00001', reason: 'follow-up'), reporter);
    expect(fake.lastReason, 'follow-up');
  });

  test('the reason limit is the note limit', () {
    expect(kRevealReasonMaxLength, StatusMachine.maxNoteLength);
  });
}
