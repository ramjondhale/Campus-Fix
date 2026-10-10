// Serializes the in-repo `SeedData` to JSON for the Firebase seed script
// (`backend/seed/seed.mjs`). Pure Dart: no Firebase, no network.
//
//   cd packages/campusfix_core
//   dart run tool/export_seed.dart > ../../backend/seed/seed.json
//
// Options:
//   --deterministic  build the seed at `seedReferenceTime` (2026-10-06 09:00 UTC)
//                    instead of "now" (omits `generatedAt` so output is stable)
//   --pretty         indent the JSON
//   --out <file>     write to <file> instead of stdout
//   -h, --help       this text
//
// Output shape (keep in sync with `validateSeed` in backend/seed/seed.mjs):
//
//   {
//     "schemaVersion": 1,
//     "generatedAt": "<ISO>",            // absent with --deterministic
//     "referenceNow": "<ISO>",           // the seed's reference time
//     "users":         [ AppUser.toJson() ],
//     "complaints":    [ { "id", "public", "admin", "identity" } ],
//     "notifications": [ AppNotification.toJson() ],
//     "lastSequenceByYear": { "2026": 29 }
//   }
//
// A complaint is exported already SPLIT the way Firestore stores it (plan
// section 5), reusing the privacy projections as the single choke point:
//   public   = toPublicView(c).toJson()            -> complaints/{id}
//   admin    = the AdminComplaintView keys the public view lacks, minus identity
//                                                  -> complaints/{id}/private/admin
//   identity = ReporterIdentity.toJson()           -> complaints/{id}/private/identity
// All dates are ISO-8601 strings (UTC); the seed script turns them into
// Firestore Timestamps.
import 'dart:convert';
import 'dart:io';

import 'package:campusfix_core/campusfix_core.dart';

/// Bumped when the output shape changes.
const int seedSchemaVersion = 1;

/// The 17 keys of `PublicComplaintView.toJson()` (privacy-spec PR-T2 allow-list).
/// Must equal `publicKeys()` in backend/firestore.rules minus `version` and
/// `claimed` (which the seed script adds).
const Set<String> _publicKeys = <String>{
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

/// The part of `AdminComplaintView.toJson()` that lives in `private/admin`:
/// priority inputs, the full assignment and the actor-bearing timeline.
/// (`reporter` goes to `private/identity`; every other key is in the public
/// document.)
const List<String> _adminKeys = <String>[
  'priority',
  'priorityOverride',
  'severity',
  'peopleAffected',
  'assignment',
  'timeline',
];

void main(List<String> args) {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/export_seed.dart '
      '[--deterministic] [--pretty] [--out <file>]',
    );
    return;
  }
  final bool deterministic = args.contains('--deterministic');
  final bool pretty = args.contains('--pretty');
  final String? out = _option(args, '--out');

  final SeedData seed = SeedData.build(
    now: deterministic ? seedReferenceTime : DateTime.now().toUtc(),
  );
  final Map<String, Object?> json = exportSeed(
    seed,
    generatedAt: deterministic ? null : DateTime.now().toUtc(),
  );

  final JsonEncoder encoder = pretty
      ? const JsonEncoder.withIndent('  ')
      : const JsonEncoder();
  final String text = encoder.convert(json);

  if (out == null) {
    stdout.writeln(text);
  } else {
    File(out).writeAsStringSync('$text\n');
  }
  stderr.writeln(
    'export_seed: ${seed.users.length} users, ${seed.complaints.length} '
    'complaints, ${seed.notifications.length} notifications'
    '${out == null ? '' : ' -> $out'}',
  );
}

/// The JSON-encodable export of [seed] (see the file header for the shape).
Map<String, Object?> exportSeed(SeedData seed, {DateTime? generatedAt}) {
  final AppUser admin = seed.usersWithRole(UserRole.admin).first;
  return <String, Object?>{
    'schemaVersion': seedSchemaVersion,
    if (generatedAt != null) 'generatedAt': generatedAt.toIso8601String(),
    'referenceNow': seed.now.toUtc().toIso8601String(),
    'users': <Object?>[for (final AppUser u in seed.users) u.toJson()],
    'complaints': <Object?>[
      for (final Complaint c in seed.complaints) _exportComplaint(c, admin),
    ],
    'notifications': <Object?>[
      for (final AppNotification n in seed.notifications) n.toJson(),
    ],
    // JSON object keys must be strings.
    'lastSequenceByYear': <String, Object?>{
      for (final MapEntry<int, int> e in seed.lastSequenceByYear.entries)
        '${e.key}': e.value,
    },
  };
}

Map<String, Object?> _exportComplaint(Complaint c, AppUser admin) {
  final Map<String, Object?> publicJson = toPublicView(c).toJson();
  final Set<String> keys = publicJson.keys.toSet();
  if (keys.length != _publicKeys.length || !keys.containsAll(_publicKeys)) {
    throw StateError(
      'PublicComplaintView.toJson() no longer matches the 17-key allow-list '
      '(update _publicKeys here AND publicKeys() in backend/firestore.rules): '
      '${keys.difference(_publicKeys)} / ${_publicKeys.difference(keys)}',
    );
  }

  // The admin view carries everything; split it into the stored documents.
  final Map<String, Object?> full = toAdminView(c, admin)!.toJson();
  return <String, Object?>{
    'id': c.id,
    'public': publicJson,
    'admin': <String, Object?>{for (final String k in _adminKeys) k: full[k]},
    'identity': full['reporter'],
  };
}

/// The value of `--name <value>` or `--name=<value>`, or null.
String? _option(List<String> args, String name) {
  for (int i = 0; i < args.length; i++) {
    final String a = args[i];
    if (a == name) return i + 1 < args.length ? args[i + 1] : null;
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}
