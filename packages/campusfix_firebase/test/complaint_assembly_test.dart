// Pure unit tests (NO Firebase, NO emulator: run with `flutter test` in this
// package) for the read path's two pure seams:
//
//   * `assembleComplaint` - the per-viewer assembly of plan section 5.3 (seam
//     S-4), including the plan's R2 mitigation: "tests assert no real identity
//     or staff id ever appears for non-admin viewers".
//   * `firestore_codec` - the Timestamp <-> ISO-8601 conversion, and that its
//     date-key set still equals the seed script's `DATE_KEYS`.
//
// The input is the real in-repo seed, split into the stored documents exactly
// as `packages/campusfix_core/tool/export_seed.dart` + `backend/seed/seed.mjs`
// store them (public doc + `version` + `claimed`, `private/admin`), then run
// through the codec both ways like a Firestore round trip.
//
// What these tests do NOT cover (they need the emulator; see the C2 report):
// the Firestore queries / listeners of `FirebaseComplaintRepository` and the
// rules.
import 'dart:convert';
import 'dart:io';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_firebase/campusfix_firebase.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

/// Keys of `private/admin` (mirrors `_adminKeys` in core's
/// `tool/export_seed.dart`).
const List<String> _adminKeys = <String>[
  'priority',
  'priorityOverride',
  'severity',
  'peopleAffected',
  'assignment',
  'timeline',
];

/// What a non-admin `reporter` placeholder looks like when not owned.
const ReporterIdentity _placeholder = ReporterIdentity(
  userId: '',
  fullName: '',
  idNumber: '',
  email: '',
);

/// The two documents one complaint is stored as, read back through the codec.
class _Stored {
  const _Stored(this.publicDoc, this.adminDoc);

  final Map<String, Object?> publicDoc;
  final Map<String, Object?> adminDoc;
}

_Stored _store(Complaint c, AppUser admin) {
  final Map<String, Object?> full = toAdminView(c, admin)!.toJson();
  final Map<String, Object?> publicJson = <String, Object?>{
    ...toPublicView(c).toJson(),
    'version': 1,
    'claimed': c.assignment?.assigneeId != null,
  };
  final Map<String, Object?> adminJson = <String, Object?>{
    for (final String k in _adminKeys) k: full[k],
  };
  // ISO strings -> Timestamps (what seed.mjs writes) -> ISO strings again (what
  // the repository's documentToJson reads).
  return _Stored(
    documentToJson(
      jsonToFirestore(publicJson) as Map<String, dynamic>,
      id: c.id,
    ),
    documentToJson(jsonToFirestore(adminJson) as Map<String, dynamic>),
  );
}

/// Every identity string of the seed (reporters incl. phones, staff, name
/// tokens of 4+ characters), the same set core's PR-T9 sweep uses.
List<String> _identityFragments(SeedData seed) => <String>[
  for (final Complaint c in seed.complaints) ...<String>[
    c.reporter.userId,
    c.reporter.fullName,
    c.reporter.idNumber,
    c.reporter.email,
    if (c.reporter.phone != null) c.reporter.phone!,
    ...c.reporter.fullName.split(' ').where((String t) => t.length >= 4),
  ],
  for (final AppUser u in seed.users) ...<String>[
    u.id,
    u.displayName,
    u.idNumber,
    u.email,
    ...u.displayName.split(' ').where((String t) => t.length >= 4),
  ],
];

void main() {
  final SeedData seed = SeedData.build();
  final AppUser admin = seed.usersWithRole(UserRole.admin).first;
  final AppUser verifier = seed.usersWithRole(UserRole.verifier).first;
  final AppUser reporter = seed.userById(seed.complaints.first.reporter.userId)!;
  // A maintenance user who is the named assignee of at least one complaint.
  final AppUser maintenance = seed.userById(
    seed.complaints
        .firstWhere((Complaint c) => c.assignment?.assigneeId != null)
        .assignment!
        .assigneeId!,
  )!;
  final Map<String, _Stored> stored = <String, _Stored>{
    for (final Complaint c in seed.complaints) c.id: _store(c, admin),
  };

  group('firestore_codec', () {
    const String scriptPath = '../../backend/seed/seed.mjs';

    test(
      'kFirestoreDateKeys equals DATE_KEYS in backend/seed/seed.mjs',
      () {
        final String source = File(scriptPath).readAsStringSync();
        final RegExpMatch? match = RegExp(
          r'DATE_KEYS\s*=\s*new Set\(\[([^\]]*)\]\)',
        ).firstMatch(source);
        expect(match, isNotNull, reason: 'DATE_KEYS not found in seed.mjs');
        final Set<String> seedKeys = <String>{
          for (final RegExpMatch m in RegExp(
            r"'([^']+)'",
          ).allMatches(match!.group(1)!))
            m.group(1)!,
        };
        expect(kFirestoreDateKeys, seedKeys);
      },
      skip: File(scriptPath).existsSync()
          ? false
          : 'run from packages/campusfix_firebase (seed.mjs not found)',
    );

    test('dates under the date keys become Timestamps and come back as ISO', () {
      const String iso = '2026-09-06T09:00:00.000Z';
      final Map<String, Object?> original = <String, Object?>{
        'createdAt': iso,
        'note': iso, // not a date key: must stay a string
        'timeline': <Object?>[
          <String, Object?>{'at': iso, 'note': null},
        ],
      };
      final Map<String, Object?> written =
          jsonToFirestore(original) as Map<String, Object?>;
      expect(written['createdAt'], isA<Timestamp>());
      expect(written['note'], iso);
      expect(
        ((written['timeline']! as List<Object?>).single!
            as Map<String, Object?>)['at'],
        isA<Timestamp>(),
      );
      expect(firestoreToJson(written), original);
    });
  });

  group('assembleComplaint - admin (plan 5.3)', () {
    test('restores every admin-only field from private/admin', () {
      for (final Complaint c in seed.complaints) {
        final _Stored s = stored[c.id]!;
        final Complaint got = assembleComplaint(
          publicDoc: s.publicDoc,
          adminDoc: s.adminDoc,
          viewer: admin,
        );
        // Everything but the reporter identity, which only the audited reveal
        // may supply (a placeholder here).
        expect(got, c.copyWith(reporter: _placeholder), reason: c.id);
      }
    });

    test('falls back to placeholders when private/admin is missing', () {
      final Complaint c = seed.complaints.first;
      final Complaint got = assembleComplaint(
        publicDoc: stored[c.id]!.publicDoc,
        viewer: admin,
      );
      expect(toPublicView(got), toPublicView(c));
      expect(got.timeline.every((StatusEvent e) => e.actorId.isEmpty), isTrue);
    });
  });

  group('assembleComplaint - non-admin projections', () {
    final List<AppUser> nonAdmins = <AppUser>[reporter, verifier, maintenance];

    test('keep exactly the public projection and ignore a passed admin doc', () {
      for (final AppUser v in nonAdmins) {
        for (final Complaint c in seed.complaints) {
          final _Stored s = stored[c.id]!;
          final Complaint got = assembleComplaint(
            publicDoc: s.publicDoc,
            // Defense in depth: even if a caller hands an admin doc to a
            // non-admin assembly it must not be used.
            adminDoc: s.adminDoc,
            viewer: v,
          );
          final String why = '${v.id} / ${c.id}';
          expect(toPublicView(got), toPublicView(c), reason: why);
          expect(got.priorityOverride, isNull, reason: why);
          expect(got.priority, c.effectivePriority, reason: why);
          expect(
            got.timeline.every((StatusEvent e) => e.actorId.isEmpty),
            isTrue,
            reason: why,
          );
          expect(got.assignment?.assignedBy ?? '', isEmpty, reason: why);
          expect(got.reporter.fullName, isEmpty, reason: why);
          expect(got.reporter.idNumber, isEmpty, reason: why);
          expect(got.reporter.email, isEmpty, reason: why);
          expect(got.reporter.phone, isNull, reason: why);
        }
      }
    });

    test('carry no identity string and no foreign user id (plan R2)', () {
      final List<String> fragments = _identityFragments(seed);
      expect(fragments.toSet().length, greaterThan(100)); // anti-vacuity
      for (final AppUser v in nonAdmins) {
        for (final Complaint c in seed.complaints) {
          final Complaint got = assembleComplaint(
            publicDoc: stored[c.id]!.publicDoc,
            adminDoc: stored[c.id]!.adminDoc,
            viewer: v,
            ownedByViewer: c.reporter.userId == v.id,
            claimedByViewer: c.assignment?.assigneeId == v.id,
          );
          final String text = jsonEncode(got.toJson()).toLowerCase();
          for (final String f in fragments) {
            // The viewer's own uid legitimately appears (own complaint / own
            // claim); nothing else may. A staff ID number such as MNT-IT-01 is
            // a substring of its own uid (u-mnt-it-01), so skip fragments the
            // viewer's uid contains.
            if (v.id.toLowerCase().contains(f.toLowerCase())) continue;
            expect(
              text.contains(f.toLowerCase()),
              isFalse,
              reason: '${v.id} sees "$f" in ${c.id}',
            );
          }
        }
      }
    });

    test('reporter / verifier: userId only for an owned complaint, never an '
        'assignee', () {
      int owned = 0;
      int notOwned = 0;
      for (final AppUser v in <AppUser>[reporter, verifier]) {
        for (final Complaint c in seed.complaints) {
          final bool isOwned = c.reporter.userId == v.id;
          final Complaint got = assembleComplaint(
            publicDoc: stored[c.id]!.publicDoc,
            viewer: v,
            ownedByViewer: isOwned,
          );
          expect(got.reporter.userId, isOwned ? v.id : '', reason: c.id);
          expect(got.assignment?.assigneeId, isNull, reason: c.id);
          if (v == reporter) isOwned ? owned++ : notOwned++;
        }
      }
      expect(owned, greaterThan(0));
      expect(notOwned, greaterThan(0));
    });

    test('maintenance: own uid if claimed by me, opaque sentinel if claimed by '
        'a colleague, null if unclaimed', () {
      bool sawMine = false;
      bool sawColleague = false;
      bool sawUnclaimed = false;
      for (final Complaint c in seed.complaints) {
        final String? assignee = c.assignment?.assigneeId;
        final Complaint got = assembleComplaint(
          publicDoc: stored[c.id]!.publicDoc,
          viewer: maintenance,
          claimedByViewer: assignee == maintenance.id,
        );
        final String? seen = got.assignment?.assigneeId;
        if (c.assignment == null) {
          expect(got.assignment, isNull, reason: c.id);
        } else if (assignee == null) {
          expect(seen, isNull, reason: c.id);
          sawUnclaimed = true;
        } else if (assignee == maintenance.id) {
          expect(seen, maintenance.id, reason: c.id);
          sawMine = true;
        } else {
          expect(seen, kClaimedByColleagueId, reason: c.id);
          sawColleague = true;
        }
        // Same department as the public document, whoever claimed it.
        expect(
          got.assignment?.department,
          c.assignment?.department,
          reason: c.id,
        );
      }
      expect(<bool>[sawMine, sawColleague, sawUnclaimed], everyElement(isTrue));
    });
  });
}
