// Privacy projection tests - privacy-spec §8 (PR-T1 ... PR-T16).
import 'dart:convert';
import 'dart:io';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart' as fx;

// ---------------------------------------------------------------------------
// Sentinel PII (privacy-spec §8.1). Unique strings that cannot collide with
// ordinary words, so a hit in a public projection is always a real leak.
// ---------------------------------------------------------------------------
const piiName = 'Zelda Quillfeather';
const piiId = 'STU-2026-31337';
const piiEmail = 'zelda.quillfeather@college.test';
const piiPhone = '+91 98765 43210';
const piiUid = 'u-9f3a-sentinel';
const staffId = 'staff-electrician-sentinel';
const staffName = 'Rohan Staffsentinel';
const adminActorId = 'admin-actor-sentinel';

/// Fragments scanned for (matched case-insensitively).
const sentinelFragments = <String>[
  piiName,
  piiId,
  piiEmail,
  piiPhone,
  piiUid,
  staffId,
  staffName,
  adminActorId,
  'Zelda',
  'Quillfeather',
  '31337',
  '98765',
  'u-9f3a',
  'staff-electrician-sentinel',
  'Staffsentinel',
  'admin-actor-sentinel',
];

const sentinelReporter = ReporterIdentity(
  userId: piiUid,
  fullName: piiName,
  idNumber: piiId,
  email: piiEmail,
  phone: piiPhone,
);

final t0 = fx.t0;

AppUser userWithRole(UserRole role, {String? id}) => AppUser(
  id: id ?? 'viewer-${role.name}',
  idNumber: 'VIEW-${role.name}',
  displayName: 'Viewer ${role.label}',
  role: role,
  email: 'viewer.${role.name}@college.test',
  department: role == UserRole.maintenance ? Department.electrician : null,
);

/// Staff user that appears in the fixture (its displayName is a sentinel).
const staffUser = AppUser(
  id: staffId,
  idNumber: 'STAFF-007',
  displayName: staffName,
  role: UserRole.maintenance,
  email: 'rohan.staffsentinel@college.test',
  department: Department.electrician,
);

StatusEvent timelineEvent(
  String id,
  ComplaintStatus status, {
  required String actorId,
  required UserRole role,
  String? note,
}) => StatusEvent(
  id: id,
  status: status,
  actorId: actorId,
  actorRole: role,
  note: note,
  at: t0.add(Duration(hours: status.order)),
);

/// A fully-populated complaint whose creation event is attributed to the
/// reporter's userId and whose later events are attributed to staff.
Complaint buildFixtureComplaint({
  ProblemCategory category = ProblemCategory.electrical,
  ComplaintStatus status = ComplaintStatus.resolved,
  Priority? priorityOverride = Priority.critical,
  bool withAssignment = true,
  bool withAfterPhotos = true,
  ReporterIdentity reporter = sentinelReporter,
  String id = 'CF-2026-00042',
  String description = 'Socket near the whiteboard sparks when used',
  String? note = 'Confirmed hazard',
}) {
  final events = <StatusEvent>[
    timelineEvent(
      'e1',
      ComplaintStatus.reported,
      actorId: reporter.userId,
      role: UserRole.reporter,
    ),
    for (final s in ComplaintStatus.values.where(
      (s) => s.order > 0 && s.order <= status.order,
    ))
      timelineEvent(
        'e${s.order + 1}',
        s,
        actorId: s == ComplaintStatus.verified || s == ComplaintStatus.closed
            ? adminActorId
            : staffId,
        role: switch (s) {
          ComplaintStatus.reviewed => UserRole.admin,
          ComplaintStatus.assigned => UserRole.admin,
          ComplaintStatus.inProgress => UserRole.maintenance,
          ComplaintStatus.resolved => UserRole.maintenance,
          ComplaintStatus.verified => UserRole.verifier,
          _ => UserRole.admin,
        },
        note: s == ComplaintStatus.reviewed ? note : null,
      ),
  ];
  return Complaint(
    id: id,
    category: category,
    title: 'Sparking socket',
    description: description,
    building: 'Science Block',
    floor: '1',
    room: 'Lab 3',
    reporter: reporter,
    beforePhotos: [fx.before('b1'), fx.before('b2')],
    afterPhotos: withAfterPhotos ? [fx.after('a1')] : const [],
    priority: Priority.high,
    priorityOverride: priorityOverride,
    status: status,
    assignment: withAssignment
        ? Assignment(
            department: Department.electrician,
            assigneeId: staffId,
            assignedBy: staffId,
            assignedAt: t0.add(const Duration(hours: 2)),
            isManual: true,
          )
        : null,
    timeline: events,
    resolutionNote: status.order >= ComplaintStatus.resolved.order
        ? 'Socket replaced and tested'
        : null,
    safetyFlag: true,
    severity: Severity.severe,
    peopleAffected: PeopleAffected.many,
    createdAt: t0,
    updatedAt: t0.add(const Duration(days: 2)),
  );
}

// ---------------------------------------------------------------------------
// Scanning helpers
// ---------------------------------------------------------------------------

/// Fragments found in [text] (case-insensitive).
List<String> leaksIn(String text, [Iterable<String>? fragments]) {
  final haystack = text.toLowerCase();
  return [
    for (final f in fragments ?? sentinelFragments)
      if (haystack.contains(f.toLowerCase())) f,
  ];
}

/// Every key and every leaf value of a decoded-JSON-like structure, stringified.
Iterable<String> deepStrings(Object? node) sync* {
  if (node is Map) {
    for (final e in node.entries) {
      yield e.key.toString();
      yield* deepStrings(e.value);
    }
  } else if (node is Iterable) {
    for (final e in node) {
      yield* deepStrings(e);
    }
  } else {
    yield '$node';
  }
}

/// Deep-stringified text of the *object fields* of a [PublicComplaintView]
/// (independent of `toJson`, so a leak via a field not serialized is caught).
String publicViewFieldText(PublicComplaintView v) {
  String att(Attachment a) =>
      '${a.id}|${a.kind}|${a.ref}|${a.caption}|${a.createdAt}';
  String ev(PublicStatusEvent e) =>
      '${e.status}|${e.actorRole}|${e.note}|${e.at}';
  return [
    v.id,
    v.category,
    v.title,
    v.building,
    v.floor,
    v.room,
    v.description,
    ...v.beforePhotos.map(att),
    ...v.afterPhotos.map(att),
    v.effectivePriority,
    v.status,
    v.safetyFlag,
    v.assignedDepartment,
    v.resolutionNote,
    ...v.timeline.map(ev),
    v.createdAt,
    v.updatedAt,
  ].join('\n');
}

/// Asserts no sentinel appears in [v]'s fields, `toJson()` (deep-stringified
/// and JSON-encoded) or `toString()`.
void expectNoPii(PublicComplaintView v, {Iterable<String>? fragments}) {
  expect(
    leaksIn(publicViewFieldText(v), fragments),
    isEmpty,
    reason: 'object fields leak PII',
  );
  final json = v.toJson();
  expect(
    leaksIn(jsonEncode(json), fragments),
    isEmpty,
    reason: 'jsonEncode(toJson()) leaks PII',
  );
  expect(
    leaksIn(deepStrings(json).join('\n'), fragments),
    isEmpty,
    reason: 'deep-stringified toJson() leaks PII',
  );
  expect(leaksIn(v.toString(), fragments), isEmpty, reason: 'toString leaks');
}

const publicKeys = <String>{
  'id',
  'category',
  'title',
  'building',
  'floor',
  'room',
  'description',
  'beforePhotos',
  'afterPhotos',
  'effectivePriority',
  'status',
  'safetyFlag',
  'assignedDepartment',
  'resolutionNote',
  'timeline',
  'createdAt',
  'updatedAt',
};

void main() {
  group('PublicStatusEvent', () {
    final e = PublicStatusEvent(
      status: ComplaintStatus.assigned,
      actorRole: UserRole.admin,
      note: 'Auto-routed to Electrician',
      at: t0,
    );

    test('toJson has exactly {status, actorRole, note, at}', () {
      expect(e.toJson().keys.toSet(), {'status', 'actorRole', 'note', 'at'});
      expect(e.toJson()['status'], 'assigned');
      expect(e.toJson()['actorRole'], 'admin');
      expect(e.toJson()['at'], t0.toIso8601String());
    });

    test('equality, hashCode and round-trip', () {
      final same = PublicStatusEvent(
        status: ComplaintStatus.assigned,
        actorRole: UserRole.admin,
        note: 'Auto-routed to Electrician',
        at: t0,
      );
      expect(e, same);
      expect(e.hashCode, same.hashCode);
      expect(
        e,
        isNot(
          PublicStatusEvent(
            status: ComplaintStatus.assigned,
            actorRole: UserRole.verifier,
            note: e.note,
            at: t0,
          ),
        ),
      );
      expect(PublicStatusEvent.fromJson(e.toJson()), e);
    });

    test('null note is allowed and serialized as null', () {
      final n = PublicStatusEvent(
        status: ComplaintStatus.reported,
        actorRole: UserRole.reporter,
        at: t0,
      );
      expect(n.note, isNull);
      expect(n.toJson()['note'], isNull);
      expect(PublicStatusEvent.fromJson(n.toJson()), n);
    });
  });

  group('projection basics', () {
    test('toPublicView maps every public field', () {
      final c = buildFixtureComplaint();
      final v = toPublicView(c);
      expect(v.id, c.id);
      expect(v.category, c.category);
      expect(v.title, c.title);
      expect(v.building, c.building);
      expect(v.floor, c.floor);
      expect(v.room, c.room);
      expect(v.description, c.description);
      expect(v.beforePhotos, c.beforePhotos);
      expect(v.afterPhotos, c.afterPhotos);
      expect(v.effectivePriority, c.effectivePriority);
      expect(v.status, c.status);
      expect(v.safetyFlag, c.safetyFlag);
      expect(v.assignedDepartment, Department.electrician);
      expect(v.resolutionNote, c.resolutionNote);
      expect(v.createdAt, c.createdAt);
      expect(v.updatedAt, c.updatedAt);
      expect(v.timeline, hasLength(c.timeline.length));
    });

    test('assignedDepartment is null when the complaint is unassigned', () {
      final v = toPublicView(buildFixtureComplaint(withAssignment: false));
      expect(v.assignedDepartment, isNull);
    });

    test(
      'timeline projection preserves order, status, role, note and time',
      () {
        final c = buildFixtureComplaint();
        final v = toPublicView(c);
        for (var i = 0; i < c.timeline.length; i++) {
          expect(v.timeline[i].status, c.timeline[i].status);
          expect(v.timeline[i].actorRole, c.timeline[i].actorRole);
          expect(v.timeline[i].note, c.timeline[i].note);
          expect(v.timeline[i].at, c.timeline[i].at);
        }
      },
    );

    test('toPublicViews maps in order; empty input -> empty list', () {
      final a = buildFixtureComplaint(id: 'CF-2026-00001');
      final b = buildFixtureComplaint(id: 'CF-2026-00002');
      expect(toPublicViews([a, b]).map((v) => v.id), [a.id, b.id]);
      expect(toPublicViews(const <Complaint>[]), isEmpty);
      expect(toPublicViews({a}), [toPublicView(a)]);
    });

    test('view lists are unmodifiable', () {
      final v = toPublicView(buildFixtureComplaint());
      expect(() => v.timeline.clear(), throwsUnsupportedError);
      expect(() => v.beforePhotos.clear(), throwsUnsupportedError);
      expect(() => v.afterPhotos.clear(), throwsUnsupportedError);
    });

    test('equality and hashCode', () {
      final c = buildFixtureComplaint();
      final a = toPublicView(c);
      final b = toPublicView(c.copyWith());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(toPublicView(c.copyWith(status: ComplaintStatus.verified))),
      );
      expect(a, isNot(toPublicView(c.copyWith(description: 'different'))));
    });

    test('admin view equality and hashCode', () {
      final c = buildFixtureComplaint();
      final admin = userWithRole(UserRole.admin);
      final a = toAdminView(c, admin)!;
      final b = toAdminView(c.copyWith(), admin)!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(toAdminView(c.copyWith(severity: Severity.minor), admin)),
      );
    });
  });

  group('PR-T1 no-PII serialization', () {
    test('fixture public view carries no sentinel anywhere', () {
      final v = toPublicView(buildFixtureComplaint());
      expectNoPii(v);
      // Spec form of the assertion, verbatim.
      final s = jsonEncode(v.toJson()).toLowerCase();
      for (final f in sentinelFragments) {
        expect(s.contains(f.toLowerCase()), isFalse, reason: 'leaked "$f"');
      }
    });
  });

  group('PR-T2 key allow-list (default deny)', () {
    test('public JSON keys equal exactly the data-model §3.2 set', () {
      final keys = toPublicView(buildFixtureComplaint()).toJson().keys.toSet();
      // Adding a field to the view fails this test until a reviewer updates
      // [publicKeys] deliberately.
      expect(keys, publicKeys);
      expect(keys, hasLength(17));
    });

    test('no reporter / actor / assignee / raw-priority key is present', () {
      final keys = toPublicView(buildFixtureComplaint()).toJson().keys.toSet();
      for (final forbidden in [
        'reporter',
        'userId',
        'fullName',
        'idNumber',
        'email',
        'phone',
        'assignment',
        'assigneeId',
        'assignedBy',
        'priority',
        'priorityOverride',
        'severity',
        'peopleAffected',
      ]) {
        expect(keys, isNot(contains(forbidden)));
      }
    });
  });

  group('PR-T3 nested allow-lists', () {
    test('attachments carry exactly {id, kind, ref, caption, createdAt}', () {
      final json = toPublicView(buildFixtureComplaint()).toJson();
      final photos = [
        ...(json['beforePhotos'] as List),
        ...(json['afterPhotos'] as List),
      ];
      expect(photos, isNotEmpty);
      for (final p in photos) {
        expect((p as Map).keys.toSet(), {
          'id',
          'kind',
          'ref',
          'caption',
          'createdAt',
        });
      }
    });

    test('timeline entries carry exactly {status, actorRole, note, at}', () {
      final json = toPublicView(buildFixtureComplaint()).toJson();
      final timeline = json['timeline'] as List;
      expect(timeline, isNotEmpty);
      for (final e in timeline) {
        final m = e as Map;
        expect(m.keys.toSet(), {'status', 'actorRole', 'note', 'at'});
        expect(m.containsKey('id'), isFalse);
        expect(m.containsKey('actorId'), isFalse);
      }
    });

    test('timeline objects are PublicStatusEvent, never StatusEvent', () {
      final v = toPublicView(buildFixtureComplaint());
      for (final e in v.timeline) {
        expect(e, isA<PublicStatusEvent>());
        expect(e, isNot(isA<StatusEvent>()));
      }
    });
  });

  group('PR-T4 admin gating', () {
    final c = buildFixtureComplaint();

    for (final role in UserRole.values) {
      test('toAdminView for ${role.name} -> '
          '${role == UserRole.admin ? 'non-null' : 'null'}', () {
        final view = toAdminView(c, userWithRole(role));
        if (role == UserRole.admin) {
          expect(view, isNotNull);
        } else {
          expect(view, isNull);
        }
      });
    }

    test('a reporter requesting their OWN complaint gets null', () {
      final own = AppUser(
        id: c.reporter.userId,
        idNumber: c.reporter.idNumber,
        displayName: c.reporter.fullName,
        role: UserRole.reporter,
        email: c.reporter.email,
      );
      expect(own.id, c.reporter.userId);
      expect(toAdminView(c, own), isNull);
    });

    test('a maintenance user assigned to the complaint gets null', () {
      expect(toAdminView(c, staffUser), isNull);
    });

    test('canSeeReporterIdentity is true for admin only', () {
      for (final role in UserRole.values) {
        expect(
          role.canSeeReporterIdentity,
          role == UserRole.admin,
          reason: role.name,
        );
      }
    });
  });

  group('PR-T5 positive control (anti-vacuity)', () {
    final c = buildFixtureComplaint();
    final adminView = toAdminView(c, userWithRole(UserRole.admin))!;

    test('admin JSON DOES contain the sentinel PII and staff id', () {
      final s = jsonEncode(adminView.toJson());
      for (final needle in [piiName, piiEmail, piiUid, staffId]) {
        expect(s, contains(needle));
      }
      expect(leaksIn(s), isNotEmpty, reason: 'scanner must detect sentinels');
      expect(leaksIn(s), containsAll(['Zelda', 'u-9f3a', staffId]));
    });

    test('admin view reporter equals the complaint reporter', () {
      expect(adminView.reporter, c.reporter);
      expect(adminView.reporter.fullName, piiName);
      expect(adminView.reporter.idNumber, piiId);
      expect(adminView.reporter.email, piiEmail);
      expect(adminView.reporter.phone, piiPhone);
      expect(adminView.reporter.userId, piiUid);
    });

    test('admin view carries the DM-3 priority inputs and full assignment', () {
      expect(adminView.title, c.title);
      expect(adminView.priority, c.priority);
      expect(adminView.priorityOverride, c.priorityOverride);
      expect(adminView.effectivePriority, c.effectivePriority);
      expect(adminView.safetyFlag, c.safetyFlag);
      expect(adminView.severity, c.severity);
      expect(adminView.peopleAffected, c.peopleAffected);
      expect(adminView.assignment, c.assignment);
      expect(adminView.assignment!.assigneeId, staffId);
      expect(adminView.assignment!.assignedBy, staffId);
      expect(adminView.assignedDepartment, Department.electrician);
      expect(adminView.resolutionNote, c.resolutionNote);
    });

    test('the sentinel scan is not vacuous: a leaky view is caught', () {
      final leaky = toPublicView(
        buildFixtureComplaint(description: 'Reported by $piiName ($piiEmail)'),
      );
      expect(leaksIn(jsonEncode(leaky.toJson())), isNotEmpty);
      expect(leaksIn(publicViewFieldText(leaky)), isNotEmpty);
    });

    test('admin toString and list fields are redacted / unmodifiable', () {
      expect(leaksIn(adminView.toString()), isEmpty);
      expect(() => adminView.timeline.clear(), throwsUnsupportedError);
      expect(() => adminView.beforePhotos.clear(), throwsUnsupportedError);
      expect(() => adminView.afterPhotos.clear(), throwsUnsupportedError);
    });
  });

  group('PR-T6 public timeline has no actor identity', () {
    final c = buildFixtureComplaint(status: ComplaintStatus.closed);
    final publicView = toPublicView(c);
    final adminView = toAdminView(c, userWithRole(UserRole.admin))!;

    test('fixture timeline really contains reporter and staff actor ids', () {
      expect(c.timeline.first.actorId, piiUid);
      expect(c.timeline.first.actorRole, UserRole.reporter);
      expect(c.timeline.skip(1).map((e) => e.actorId), contains(staffId));
    });

    test('every public entry serializes without any actor id or name', () {
      final timeline = publicView.toJson()['timeline'] as List;
      expect(timeline, hasLength(c.timeline.length));
      for (final entry in timeline) {
        final text = jsonEncode(entry);
        expect(text, isNot(contains(piiUid)));
        expect(text, isNot(contains(staffId)));
        expect(text, isNot(contains(adminActorId)));
        expect(text, isNot(contains(staffUser.displayName)));
        expect((entry as Map)['actorRole'], isNotNull);
        expect(entry['status'], isNotNull);
        expect(entry['at'], isNotNull);
      }
    });

    test('public entries keep role + note + time', () {
      final reviewed = publicView.timeline.firstWhere(
        (e) => e.status == ComplaintStatus.reviewed,
      );
      expect(reviewed.note, 'Confirmed hazard');
      expect(reviewed.actorRole, UserRole.admin);
      expect(reviewed.at, isNotNull);
      expect(publicView.timeline.first.actorRole, UserRole.reporter);
    });

    test('admin timeline DOES carry actorId for every event', () {
      expect(adminView.timeline, hasLength(c.timeline.length));
      final json = adminView.toJson()['timeline'] as List;
      for (final e in json) {
        expect((e as Map)['actorId'], isA<String>());
        expect(e['actorId'], isNotEmpty);
        expect(e['id'], isNotNull);
      }
      expect(adminView.timeline.first.actorId, piiUid);
      expect(adminView.timeline.map((e) => e.actorId), contains(staffId));
    });
  });

  group('PR-T7 admin view is a superset of the public view', () {
    test('every public key appears in the admin JSON with an equal value', () {
      final c = buildFixtureComplaint();
      final pub = toPublicView(c).toJson();
      final adm = toAdminView(c, userWithRole(UserRole.admin))!.toJson();
      expect(adm.keys.toSet().containsAll(pub.keys), isTrue);
      for (final key in pub.keys.where((k) => k != 'timeline')) {
        expect(adm[key], pub[key], reason: key);
      }
      final pubTimeline = pub['timeline'] as List;
      final admTimeline = adm['timeline'] as List;
      expect(admTimeline, hasLength(pubTimeline.length));
      for (var i = 0; i < pubTimeline.length; i++) {
        final p = pubTimeline[i] as Map;
        final a = admTimeline[i] as Map;
        for (final k in p.keys) {
          expect(a[k], p[k], reason: 'timeline[$i].$k');
        }
        expect(a.containsKey('actorId'), isTrue);
      }
    });

    test('admin adds exactly the admin-only keys', () {
      final c = buildFixtureComplaint();
      final extra = toAdminView(
        c,
        userWithRole(UserRole.admin),
      )!.toJson().keys.toSet().difference(publicKeys);
      expect(extra, {
        'reporter',
        'severity',
        'peopleAffected',
        'priority',
        'priorityOverride',
        'assignment',
      });
    });
  });

  group('PR-T8 priority exposure', () {
    test('public effectivePriority is priorityOverride ?? priority', () {
      final withOverride = buildFixtureComplaint(
        priorityOverride: Priority.low,
      );
      expect(toPublicView(withOverride).effectivePriority, Priority.low);
      final without = buildFixtureComplaint(priorityOverride: null);
      expect(toPublicView(without).effectivePriority, without.priority);
      for (final c in [withOverride, without]) {
        expect(
          toPublicView(c).effectivePriority,
          c.priorityOverride ?? c.priority,
        );
      }
    });

    test('raw priority and priorityOverride are absent from public JSON', () {
      for (final o in [null, Priority.critical, Priority.low]) {
        final json = toPublicView(
          buildFixtureComplaint(priorityOverride: o),
        ).toJson();
        expect(json.containsKey('priority'), isFalse);
        expect(json.containsKey('priorityOverride'), isFalse);
        expect(json['effectivePriority'], (o ?? Priority.high).name);
      }
    });
  });

  group('PR-T9 seed-style sweep (>= 24 complaints, cross-reporter)', () {
    // S2.6 re-runs this sweep over the real seed data; here it is run over a
    // synthetic population with 24 distinct fictional reporters so the sweep
    // logic itself is covered and proven non-vacuous.
    const count = 24;

    ReporterIdentity reporterFor(int i) => ReporterIdentity(
      userId: 'u-seedsentinel-$i-x',
      fullName: 'Seedfirst$i Seedlast$i',
      idNumber: 'SEED-ID-$i-77',
      email: 'seedfirst$i.seedlast$i@college.test',
      phone: '+91 70000 ${10000 + i}',
    );

    List<String> fragmentsOf(ReporterIdentity r) => [
      r.userId,
      r.fullName,
      r.idNumber,
      r.email,
      r.phone!,
      ...r.fullName.split(' '),
    ];

    final complaints = [
      for (var i = 0; i < count; i++)
        buildFixtureComplaint(
          id: 'CF-2026-${(i + 1).toString().padLeft(5, '0')}',
          reporter: reporterFor(i),
          category: ProblemCategory.values[i % ProblemCategory.values.length],
          status: ComplaintStatus.values[i % ComplaintStatus.values.length],
        ),
    ];
    final allFragments = [
      for (var i = 0; i < count; i++) ...fragmentsOf(reporterFor(i)),
      ...sentinelFragments,
    ];

    test('population has >= 24 complaints with distinct reporters', () {
      expect(complaints.length, greaterThanOrEqualTo(24));
      expect(
        complaints.map((c) => c.reporter.userId).toSet(),
        hasLength(count),
      );
    });

    test("no complaint's public view leaks its own or any other reporter", () {
      for (final c in complaints) {
        final v = toPublicView(c);
        expectNoPii(v, fragments: allFragments);
        // Own reporter explicitly, via spec form.
        final s = jsonEncode(v.toJson()).toLowerCase();
        for (final f in fragmentsOf(c.reporter)) {
          expect(s.contains(f.toLowerCase()), isFalse, reason: '${c.id}: $f');
        }
      }
    });

    test('positive control: PII pasted into seed free text is detected', () {
      final r = reporterFor(3);
      for (final leak in [
        buildFixtureComplaint(reporter: r, description: 'From ${r.fullName}'),
        buildFixtureComplaint(reporter: r, note: 'Call ${r.phone}'),
        buildFixtureComplaint(
          reporter: r,
          description: 'mail ${r.email.toUpperCase()}',
        ),
      ]) {
        final s = jsonEncode(toPublicView(leak).toJson()).toLowerCase();
        expect(
          fragmentsOf(r).any((f) => s.contains(f.toLowerCase())),
          isTrue,
          reason: 'sweep must catch pasted PII',
        );
      }
    });
  });

  group('PR-T10 matrix sweep', () {
    // 8 categories x 7 statuses x {override} x {assignment} x {after photos}.
    test('the matrix spans 8 categories and 7 statuses', () {
      expect(ProblemCategory.values, hasLength(8));
      expect(ComplaintStatus.values, hasLength(7));
    });
    for (final category in ProblemCategory.values) {
      test('${category.name}: all 7 statuses x 8 option combinations', () {
        var combos = 0;
        for (final status in ComplaintStatus.values) {
          for (final override in [null, Priority.critical]) {
            for (final assigned in [false, true]) {
              for (final afterPhotos in [false, true]) {
                final c = buildFixtureComplaint(
                  category: category,
                  status: status,
                  priorityOverride: override,
                  withAssignment: assigned,
                  withAfterPhotos: afterPhotos,
                );
                final v = toPublicView(c);
                expectNoPii(v);
                expect(v.toJson().keys.toSet(), publicKeys);
                expect(v.effectivePriority, override ?? c.priority);
                expect(
                  v.assignedDepartment,
                  assigned ? Department.electrician : isNull,
                );
                combos++;
              }
            }
          }
        }
        expect(combos, 7 * 2 * 2 * 2);
      });
    }
  });

  group('PR-T11 redaction (LK-3)', () {
    final c = buildFixtureComplaint();

    test('ReporterIdentity.toString hides name, id number, email, phone', () {
      final s = sentinelReporter.toString();
      for (final f in [piiName, piiId, piiEmail, piiPhone, 'Zelda', '31337']) {
        expect(s.toLowerCase(), isNot(contains(f.toLowerCase())), reason: f);
      }
    });

    test('ReporterIdentity.toString hides the userId (P1)', () {
      expect(sentinelReporter.toString(), isNot(contains(piiUid)));
    });

    test('Complaint.toString contains no sentinel', () {
      expect(leaksIn(c.toString()), isEmpty);
    });

    test('toPublicView(c).toString contains no sentinel', () {
      expect(leaksIn(toPublicView(c).toString()), isEmpty);
    });

    test('public timeline events and view lists stringify PII-free', () {
      final v = toPublicView(c);
      expect(leaksIn(v.timeline.map((e) => e.toString()).join()), isEmpty);
      expect(leaksIn(v.timeline.toString()), isEmpty);
      expect(leaksIn(v.beforePhotos.toString()), isEmpty);
    });
  });

  group('PR-T12 purity and stability', () {
    test('two calls return equal values', () {
      final c = buildFixtureComplaint();
      expect(toPublicView(c), toPublicView(c));
      expect(toPublicView(c).hashCode, toPublicView(c).hashCode);
      expect(toPublicView(c).toJson(), toPublicView(c).toJson());
    });

    test('output is identical regardless of who is asking', () {
      // toPublicView takes no viewer: the same output serves every role.
      final c = buildFixtureComplaint();
      final forEachRole = [
        for (final _ in UserRole.values) jsonEncode(toPublicView(c).toJson()),
      ];
      expect(forEachRole.toSet(), hasLength(1));
    });

    test('does not mutate the complaint (deep-equal before/after)', () {
      final c = buildFixtureComplaint();
      final snapshot = Complaint.fromJson(
        jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>,
      );
      final jsonBefore = jsonEncode(c.toJson());
      toPublicView(c);
      toPublicViews([c, c]);
      toAdminView(c, userWithRole(UserRole.admin));
      toAdminView(c, userWithRole(UserRole.reporter));
      expect(jsonEncode(c.toJson()), jsonBefore);
      expect(c, snapshot);
    });

    test('mutating a view input list later cannot change an issued view', () {
      final photos = [fx.before('p1')];
      final timeline = <PublicStatusEvent>[
        PublicStatusEvent(
          status: ComplaintStatus.reported,
          actorRole: UserRole.reporter,
          at: t0,
        ),
      ];
      final v = PublicComplaintView(
        id: 'CF-2026-00009',
        category: ProblemCategory.plumbing,
        building: 'A',
        floor: '1',
        room: '1',
        description: 'd',
        beforePhotos: photos,
        effectivePriority: Priority.low,
        status: ComplaintStatus.reported,
        timeline: timeline,
        createdAt: t0,
        updatedAt: t0,
      );
      photos.clear();
      timeline.clear();
      expect(v.beforePhotos, hasLength(1));
      expect(v.timeline, hasLength(1));
    });
  });

  group('PR-T13 JSON round-trip', () {
    test('fromJson(toJson(v)) == v and still passes PR-T1', () {
      final v = toPublicView(buildFixtureComplaint());
      final round = PublicComplaintView.fromJson(
        jsonDecode(jsonEncode(v.toJson())) as Map<String, Object?>,
      );
      expect(round, v);
      expect(round.hashCode, v.hashCode);
      expectNoPii(round);
    });

    test('round-trips across the matrix incl. null optionals', () {
      for (final status in ComplaintStatus.values) {
        for (final assigned in [false, true]) {
          final v = toPublicView(
            buildFixtureComplaint(
              status: status,
              withAssignment: assigned,
              priorityOverride: null,
              withAfterPhotos: assigned,
            ),
          );
          expect(PublicComplaintView.fromJson(v.toJson()), v);
        }
      }
    });

    test('fromJson of a malformed map throws FormatException', () {
      expect(
        () => PublicComplaintView.fromJson(const {'id': 'x'}),
        throwsFormatException,
      );
    });
  });

  group('PR-T14 architecture guard (static)', () {
    final root = _findRepoRoot();

    // Explicit allow-list entries (repo-relative, forward slashes). The ONLY
    // permitted reference to the reporter in apps/mobile is the report-submit
    // controller that builds the draft Complaint from the signed-in user.
    // S4 adds its path here (and only here) when that file exists.
    const mobileReporterAllowList = <String>{};
    const adminIdentityPanel =
        'apps/admin/lib/features/complaint_detail/identity_panel.dart';
    const adminDetailDir = 'apps/admin/lib/features/complaint_detail/';

    test('repo root located', () {
      expect(root, isNotNull, reason: 'could not find the repo root');
    });

    test('scanner flags violations (positive controls)', () {
      List<String> scan(String path, String src) => scanForPrivacyViolations(
        path,
        src,
        mobileReporterAllowList: mobileReporterAllowList,
        adminIdentityPanel: adminIdentityPanel,
        adminDetailDir: adminDetailDir,
      );

      // (a) mobile / design
      expect(
        scan('apps/mobile/lib/a.dart', 'final r = ReporterIdentity(x);'),
        isNotEmpty,
      );
      expect(
        scan('apps/mobile/lib/a.dart', 'final n = complaint.reporter.name;'),
        isNotEmpty,
      );
      expect(
        scan('apps/mobile/lib/a.dart', 'void f(AdminComplaintView v) {}'),
        isNotEmpty,
      );
      expect(
        scan('packages/campusfix_design/lib/w.dart', 'ReporterIdentity? x;'),
        isNotEmpty,
      );
      expect(
        scanForPrivacyViolations(
          'apps/mobile/lib/features/report/submit.dart',
          'final r = ReporterIdentity(x); c.reporter;',
          mobileReporterAllowList: const {
            'apps/mobile/lib/features/report/submit.dart',
          },
          adminIdentityPanel: adminIdentityPanel,
          adminDetailDir: adminDetailDir,
        ),
        isEmpty,
        reason: 'allow-listed submit controller may build the reporter',
      );
      expect(
        scanForPrivacyViolations(
          'apps/mobile/lib/features/report/submit.dart',
          'void f(AdminComplaintView v) {}',
          mobileReporterAllowList: const {
            'apps/mobile/lib/features/report/submit.dart',
          },
          adminIdentityPanel: adminIdentityPanel,
          adminDetailDir: adminDetailDir,
        ),
        isNotEmpty,
        reason: 'the allow-list never covers AdminComplaintView',
      );

      // (b) admin
      expect(
        scan('apps/admin/lib/features/board/list.dart', 'c.reporter.email'),
        isNotEmpty,
      );
      expect(scan(adminIdentityPanel, 'c.reporter.email'), isEmpty);
      expect(
        scan(
          'apps/admin/lib/features/dashboard/d.dart',
          'AdminComplaintView v;',
        ),
        isNotEmpty,
      );
      expect(
        scan('${adminDetailDir}controller.dart', 'AdminComplaintView? v;'),
        isEmpty,
      );
      expect(
        scan('${adminDetailDir}controller.dart', 'ReporterIdentity r;'),
        isNotEmpty,
        reason: 'only the identity panel may touch the reporter',
      );

      // (c) logging
      expect(scan('apps/mobile/lib/a.dart', 'print(complaint);'), isNotEmpty);
      expect(
        scan('apps/admin/lib/a.dart', 'debugPrint("x \$complaint");'),
        isNotEmpty,
      );
      expect(
        scan('packages/campusfix_core/lib/a.dart', 'log(adminView.toJson());'),
        isNotEmpty,
      );
      expect(
        scan(
          'packages/campusfix_core/lib/a.dart',
          'print(\n  Complaint.fromJson(j),\n);',
        ),
        isNotEmpty,
        reason: 'multi-line calls are scanned',
      );
    });

    test('scanner ignores benign code and comments (negative controls)', () {
      List<String> scan(String path, String src) => scanForPrivacyViolations(
        path,
        src,
        mobileReporterAllowList: mobileReporterAllowList,
        adminIdentityPanel: adminIdentityPanel,
        adminDetailDir: adminDetailDir,
      );
      expect(
        scan(
          'apps/mobile/lib/a.dart',
          '// ReporterIdentity and .reporter are forbidden here\n'
              '/* AdminComplaintView */ final v = PublicComplaintView;',
        ),
        isEmpty,
      );
      expect(scan('apps/mobile/lib/a.dart', 'print(complaint.id);'), isEmpty);
      expect(scan('apps/mobile/lib/a.dart', 'print(view.status);'), isEmpty);
      expect(scan('apps/mobile/lib/a.dart', 'print("hello");'), isEmpty);
      expect(
        scan('apps/mobile/lib/a.dart', 'final reporterName = x;'),
        isEmpty,
      );
    });

    test('real source tree has no privacy-layering violations', () {
      if (root == null) fail('repo root not found');
      final zones = <String>[
        'apps/mobile/lib',
        'apps/admin/lib',
        'packages/campusfix_design/lib',
        'packages/campusfix_core/lib',
      ];
      var scanned = 0;
      final violations = <String>[];
      for (final zone in zones) {
        final dir = Directory('${root.path}/$zone');
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          final rel = f.path
              .substring(root.path.length + 1)
              .replaceAll(r'\', '/');
          scanned++;
          violations.addAll(
            scanForPrivacyViolations(
              rel,
              f.readAsStringSync(),
              mobileReporterAllowList: mobileReporterAllowList,
              adminIdentityPanel: adminIdentityPanel,
              adminDetailDir: adminDetailDir,
            ),
          );
        }
      }
      expect(scanned, greaterThan(0), reason: 'guard scanned no files');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('PR-T15 notification derivation (S4.4)', () {
    test(
      'every seed StatusEvent yields a PII-free templated message',
      () {},
      skip:
          'Deferred: NotificationService / seed data land in S2.6-S2.7/S4.4. '
          'Re-run PR-T9 fragments over the generated messages there.',
    );
  });

  group('PR-T16 screen-level (widget tests)', () {
    test(
      'board, My Complaints, maintenance, verifier, admin list render no PII',
      () {},
      skip:
          'Deferred: widget tests belong to the Flutter app chunks (S4/S5); '
          'screens must be constructed with PublicComplaintView only.',
    );
  });
}

// ---------------------------------------------------------------------------
// Static architecture scanner (PR-T14)
// ---------------------------------------------------------------------------

Directory? _findRepoRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/apps').existsSync() &&
        Directory('${dir.path}/packages').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

final _blockComment = RegExp(r'/\*[\s\S]*?\*/');
final _lineComment = RegExp(r'//[^\n]*');
final _reporterType = RegExp(r'\bReporterIdentity\b');
final _reporterAccess = RegExp(r'\.reporter\b');
final _adminViewType = RegExp(r'\bAdminComplaintView\b');
final _logCall = RegExp(r'(?<![\w.])(print|debugPrint|log)\s*\(');

/// Identifiers that, passed to a logging call, would log a complaint/PII.
/// `complaint.id`-style scalar accesses are allowed.
final _sensitiveArg = RegExp(
  r'\b(Complaint|AdminComplaintView|ReporterIdentity)\b'
  r'|\b(complaints?|adminView|adminComplaint|reporter)\b'
  r'(?!\s*\.\s*(id|length|isEmpty|isNotEmpty|status|category)\b)',
);

String _stripComments(String source) =>
    source.replaceAll(_blockComment, '').replaceAll(_lineComment, '');

/// Text inside the parentheses of the call whose `(` is at [openIndex].
String _callArguments(String text, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < text.length; i++) {
    final ch = text[i];
    if (ch == '(') depth++;
    if (ch == ')') {
      depth--;
      if (depth == 0) return text.substring(openIndex + 1, i);
    }
  }
  return text.substring(openIndex + 1);
}

/// Heuristic static check of one source file (privacy-spec PR-T14).
///
/// Returns human-readable violations (empty = clean). [path] is
/// repo-relative with forward slashes.
List<String> scanForPrivacyViolations(
  String path,
  String source, {
  required Set<String> mobileReporterAllowList,
  required String adminIdentityPanel,
  required String adminDetailDir,
}) {
  final text = _stripComments(source);
  final out = <String>[];

  final inMobile = path.startsWith('apps/mobile/lib/');
  final inDesign = path.startsWith('packages/campusfix_design/lib/');
  final inAdmin = path.startsWith('apps/admin/lib/');

  if (inMobile || inDesign) {
    final allowed = mobileReporterAllowList.contains(path);
    if (!allowed &&
        (_reporterType.hasMatch(text) || _reporterAccess.hasMatch(text))) {
      out.add('$path: references ReporterIdentity / .reporter (rule a)');
    }
    if (_adminViewType.hasMatch(text)) {
      out.add('$path: references AdminComplaintView (rule a)');
    }
  }

  if (inAdmin) {
    if (path != adminIdentityPanel &&
        (_reporterType.hasMatch(text) || _reporterAccess.hasMatch(text))) {
      out.add(
        '$path: references ReporterIdentity / .reporter outside the '
        'identity panel (rule b)',
      );
    }
    if (!path.startsWith(adminDetailDir) && _adminViewType.hasMatch(text)) {
      out.add('$path: references AdminComplaintView outside A-04 (rule b)');
    }
  }

  // (c) logging a Complaint / AdminComplaintView / reporter.
  for (final m in _logCall.allMatches(text)) {
    final args = _callArguments(text, m.end - 1);
    if (_sensitiveArg.hasMatch(args)) {
      out.add(
        '$path: ${m.group(1)}(...) is passed a complaint/PII '
        'expression (rule c)',
      );
    }
  }
  return out;
}
