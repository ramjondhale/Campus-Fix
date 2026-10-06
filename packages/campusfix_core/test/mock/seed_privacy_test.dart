// PR-T9 (privacy-spec §8.2): sweep the REAL seed for identity leaks.
//
// For every seed complaint, the public view must contain none of its own
// reporter's strings nor any other seeded reporter's - nor any seeded staff
// member's (P2). The same fragments are run against every seed notification
// (the LK-1 / PR-T15 channel). Reuses the scanner helpers of privacy_test.dart.
import 'dart:convert';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../logic/privacy_test.dart'
    show expectNoPii, leaksIn, sentinelFragments;

final SeedData seed = SeedData.build();

/// Name parts short enough to occur inside ordinary words are not scanned on
/// their own (the full name, ID, e-mail and phone always are).
const int _minTokenLength = 4;

List<String> fragmentsOfReporter(ReporterIdentity r) => [
  r.userId,
  r.fullName,
  r.idNumber,
  r.email,
  ?r.phone,
  ...r.fullName.split(' ').where((t) => t.length >= _minTokenLength),
];

List<String> fragmentsOfUser(AppUser u) => [
  u.id,
  u.displayName,
  u.idNumber,
  u.email,
  ...u.displayName.split(' ').where((t) => t.length >= _minTokenLength),
];

/// Every identity string in the seed: all reporters (with phones, from the
/// complaints that carry them), all staff, and the privacy-spec sentinels.
final List<String> allFragments = [
  for (final c in seed.complaints) ...fragmentsOfReporter(c.reporter),
  for (final u in seed.users) ...fragmentsOfUser(u),
  ...sentinelFragments,
];

void main() {
  group('PR-T9 seed sweep', () {
    test('the seed has >= 24 complaints from distinct reporters', () {
      expect(seed.complaints.length, greaterThanOrEqualTo(24));
      expect(
        seed.complaints.map((c) => c.reporter.userId).toSet().length,
        greaterThanOrEqualTo(8),
      );
    });

    test('the fragment set is meaningful (anti-vacuity)', () {
      expect(allFragments.toSet().length, greaterThan(100));
      for (final c in seed.complaints) {
        final own = fragmentsOfReporter(c.reporter);
        expect(own.length, greaterThanOrEqualTo(6), reason: c.id);
        expect(own, everyElement(isNotEmpty));
      }
    });

    test(
      'no public view leaks its own reporter, another reporter or staff',
      () {
        for (final c in seed.complaints) {
          final view = toPublicView(c);
          // Scans object fields, toJson (deep + encoded) and toString.
          expectNoPii(view, fragments: allFragments);
          // Spec form of PR-T1 with this complaint's own strings, explicitly.
          final text = jsonEncode(view.toJson()).toLowerCase();
          for (final f in fragmentsOfReporter(c.reporter)) {
            expect(
              text.contains(f.toLowerCase()),
              isFalse,
              reason: '${c.id} leaks "$f"',
            );
          }
        }
      },
    );

    test(
      'free text channels are clean: title, description, notes, captions, refs',
      () {
        for (final c in seed.complaints) {
          final text = [
            c.title,
            c.description,
            c.resolutionNote,
            for (final e in c.timeline) e.note,
            for (final a in [...c.beforePhotos, ...c.afterPhotos]) ...[
              a.caption,
              a.ref,
            ],
          ].whereType<String>().join('\n');
          expect(leaksIn(text, allFragments), isEmpty, reason: c.id);
        }
      },
    );

    test('toPublicViews of the whole seed is clean in one pass', () {
      final json = jsonEncode([
        for (final v in toPublicViews(seed.complaints)) v.toJson(),
      ]);
      expect(leaksIn(json, allFragments), isEmpty);
    });

    test('no seed notification leaks identity (LK-1 / PR-T15)', () {
      expect(seed.notifications, isNotEmpty);
      for (final n in seed.notifications) {
        final text = '${n.title}\n${n.body}';
        expect(leaksIn(text, allFragments), isEmpty, reason: n.id);
      }
    });

    test('notification text uses only labels, locations and public notes', () {
      // Every notification body is built from the complaint ID plus public
      // data; strip those and nothing user-specific remains to leak.
      final byId = {for (final c in seed.complaints) c.id: c};
      for (final n in seed.notifications) {
        final c = byId[n.complaintId]!;
        final publicText = [
          c.id,
          c.category.label,
          c.building,
          c.room,
          for (final d in Department.values) d.label,
          for (final e in c.timeline) e.note,
        ].whereType<String>().join(' ');
        // Words of the body that are not in the template vocabulary must come
        // from public complaint data.
        final words = RegExp(
          r"[A-Za-z][A-Za-z\-']+",
        ).allMatches(n.body).map((m) => m.group(0)!);
        const vocabulary = {
          'Complaint',
          'submitted',
          'has',
          'been',
          'reviewed',
          'assigned',
          'to',
          'New',
          'work',
          'Work',
          'started',
          'on',
          'Repair',
          'completed',
          'awaiting',
          'verification',
          'is',
          'ready',
          'verify',
          'repair',
          'verified',
          'closed',
          'Rework',
          'needed',
          'needs',
          'more',
          'resumed',
          'reassigned',
          'removed',
          'from',
          'your',
          'queue',
          'Floor',
          'Ground',
          'floor',
          'CF',
        };
        for (final w in words) {
          if (vocabulary.contains(w)) continue;
          expect(
            publicText.toLowerCase(),
            contains(w.toLowerCase()),
            reason: '${n.id}: unexplained word "$w" in "${n.body}"',
          );
        }
      }
    });

    test('positive control: pasted PII is detected by the sweep', () {
      final c = seed.complaints.firstWhere((c) => c.reporter.phone != null);
      final r = c.reporter;
      for (final leaky in [
        c.copyWith(description: 'Reported by ${r.fullName}'),
        c.copyWith(description: 'call ${r.phone}'),
        c.copyWith(title: r.email.toUpperCase()),
        c.copyWith(resolutionNote: 'ask ${r.idNumber}'),
        c.copyWith(
          timeline: [
            ...c.timeline,
            c.timeline.last.copyWith(id: 'x', note: 'by ${r.userId}'),
          ],
        ),
        c.copyWith(
          beforePhotos: [
            c.beforePhotos.first.copyWith(
              ref: 'assets/${r.fullName.split(' ').first}.jpg',
            ),
          ],
        ),
      ]) {
        final json = jsonEncode(toPublicView(leaky).toJson());
        expect(
          leaksIn(json, allFragments),
          isNotEmpty,
          reason: 'the sweep must catch leaks',
        );
      }
      // ... and a staff name pasted into a note.
      final staff = seed.usersWithRole(UserRole.maintenance).first;
      final leakyNote = c.copyWith(
        resolutionNote: 'Done by ${staff.displayName}',
      );
      expect(
        leaksIn(jsonEncode(toPublicView(leakyNote).toJson()), allFragments),
        isNotEmpty,
      );
    });

    test(
      'positive control: the admin view does carry each reporter (scanner can see PII)',
      () {
        final admin = seed.usersWithRole(UserRole.admin).single;
        for (final c in seed.complaints) {
          final adminJson = jsonEncode(toAdminView(c, admin)!.toJson());
          for (final f in [
            c.reporter.fullName,
            c.reporter.email,
            c.reporter.userId,
          ]) {
            expect(leaksIn(adminJson, [f]), [f], reason: '${c.id}: $f');
          }
        }
      },
    );

    test('non-admin viewers get no admin view of any seed complaint', () {
      for (final u in seed.users.where((u) => u.role != UserRole.admin)) {
        for (final c in seed.complaints) {
          expect(toAdminView(c, u), isNull, reason: '${u.role.name} ${c.id}');
        }
      }
    });

    test(
      'seeded reporters are fictional: reserved .test domain, no real-looking numbers',
      () {
        for (final c in seed.complaints) {
          expect(c.reporter.email, endsWith('@campus.test'));
          final phone = c.reporter.phone;
          if (phone != null) {
            expect(phone, matches(RegExp(r'^\+91 90000 \d{5}$')));
          }
        }
      },
    );
  });
}
