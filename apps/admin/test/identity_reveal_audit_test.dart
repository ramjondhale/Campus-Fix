import 'package:campusfix_admin/providers/providers.dart';
import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/detail_helpers.dart';

/// A revealer that records what it was asked and returns a recognisable
/// identity (so the tests can tell "what the revealer returned" from the
/// identity the admin view already holds).
class _FakeRevealer implements ReporterIdentityRevealer {
  _FakeRevealer({this.fail = false});

  /// Makes [reveal] fail, like a rejected audit write.
  final bool fail;

  final List<({String id, String? reason})> calls =
      <({String id, String? reason})>[];

  static const ReporterIdentity audited = ReporterIdentity(
    userId: 'u-audited',
    fullName: 'Audited Person',
    idNumber: 'AUD-001',
    email: 'audited.person@campus.test',
    phone: '+91 90000 00000',
  );

  @override
  Future<ReporterIdentity> reveal(String complaintId, {String? reason}) async {
    calls.add((id: complaintId, reason: reason));
    if (fail) throw StateError('audit write failed');
    return audited;
  }
}

/// The audited reveal of A-04 (plan seam S-5, decision D4 = required reason).
/// The offline reveal (no revealer) is covered by `complaint_detail_test.dart`.
void main() {
  List<Override> wiredTo(_FakeRevealer revealer) => <Override>[
    reporterIdentityRevealerProvider.overrideWithValue(revealer),
  ];

  group('audited identity reveal (a revealer is wired)', () {
    testWidgets('asks for a reason first, passes it on, and shows what the '
        'revealer returned; Hide drops it', (tester) async {
      final _FakeRevealer revealer = _FakeRevealer();
      await openDetail(
        tester,
        UserRole.admin,
        kResolvedIt,
        overrides: wiredTo(revealer),
      );

      await tapVisible(tester, buttonIn('Reveal reporter identity'));
      expect(find.byType(AppDialog), findsOneWidget);
      expect(revealer.calls, isEmpty, reason: 'nothing is fetched yet');
      expect(isEnabled(tester, dialogButton('Reveal identity')), isFalse);

      await tester.enterText(dialogFields.last, '   ');
      await tester.pump();
      expect(
        isEnabled(tester, dialogButton('Reveal identity')),
        isFalse,
        reason: 'a blank reason is no reason',
      );

      await tester.enterText(dialogFields.last, '  Need to contact the reporter ');
      await tester.pump();
      expect(isEnabled(tester, dialogButton('Reveal identity')), isTrue);
      await tapVisible(tester, dialogButton('Reveal identity'));

      expect(revealer.calls, hasLength(1));
      expect(revealer.calls.single.id, kResolvedIt);
      expect(revealer.calls.single.reason, 'Need to contact the reporter');

      final String text = detailText(tester);
      for (final String s in <String>[
        _FakeRevealer.audited.fullName,
        _FakeRevealer.audited.idNumber,
        _FakeRevealer.audited.email,
        _FakeRevealer.audited.phone!,
      ]) {
        expect(text, contains(s));
      }
      // The identity the admin view holds is never what the panel shows.
      expect(
        leaksIn(text, reporterSentinels(seed(kResolvedIt))),
        isEmpty,
        reason: 'the panel shows only what the audited revealer returned',
      );

      await tapVisible(tester, buttonIn('Hide'));
      expect(detailText(tester), isNot(contains('Audited Person')));
      expect(buttonIn('Reveal reporter identity'), findsOneWidget);
    });

    testWidgets('Cancel fetches nothing and keeps the panel collapsed', (
      tester,
    ) async {
      final _FakeRevealer revealer = _FakeRevealer();
      await openDetail(
        tester,
        UserRole.admin,
        kResolvedIt,
        overrides: wiredTo(revealer),
      );

      await tapVisible(tester, buttonIn('Reveal reporter identity'));
      await tapVisible(tester, dialogButton('Cancel'));

      expect(find.byType(AppDialog), findsNothing);
      expect(revealer.calls, isEmpty);
      expect(buttonIn('Reveal reporter identity'), findsOneWidget);
    });

    testWidgets('a failed audit shows nothing, says so, and can be retried', (
      tester,
    ) async {
      final _FakeRevealer revealer = _FakeRevealer(fail: true);
      await openDetail(
        tester,
        UserRole.admin,
        kResolvedIt,
        overrides: wiredTo(revealer),
      );

      await tapVisible(tester, buttonIn('Reveal reporter identity'));
      await tester.enterText(dialogFields.last, 'Safety follow-up');
      await tester.pump();
      await tapVisible(tester, dialogButton('Reveal identity'));

      expect(revealer.calls, hasLength(1));
      expect(find.text("Couldn't reveal the reporter"), findsOneWidget);
      final String text = detailText(tester);
      expect(text, isNot(contains('Audited Person')));
      expect(leaksIn(text, reporterSentinels(seed(kResolvedIt))), isEmpty);
      expect(isEnabled(tester, buttonIn('Reveal reporter identity')), isTrue);
    });
  });
}
