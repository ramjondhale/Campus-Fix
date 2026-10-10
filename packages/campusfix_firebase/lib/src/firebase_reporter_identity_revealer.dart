import 'package:campusfix_core/campusfix_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'campus_fix_firebase.dart';
import 'firestore_codec.dart';

/// [ReporterIdentityRevealer] over Firestore (plan seam S-5, section 6.4,
/// decision D4 = required reason).
///
/// One [reveal] is **one Firestore transaction**: read
/// `complaints/{id}/private/identity`, write one `auditLog/{entryId}` entry,
/// commit. The identity leaves this class only when that commit succeeded, so
/// the reveal is **fail-closed**: if the audit write is rejected (rules, network)
/// the transaction aborts and the caller gets the error, not the identity.
///
/// Audit entry (the shape `firestore.rules` `auditLog` accepts):
///
/// ```text
/// { type: 'identityReveal', actorUid, actorRole, complaintId,
///   reason, at: <server timestamp>, requestId }
/// ```
///
/// It carries **no reporter identity** (only the complaint id, the admin's uid
/// and the reason).
///
/// MVP trade-off (rules delta (a) and (d)): `private/identity` is admin-readable
/// and `auditLog` admin-writable, so a hand-made admin request could read an
/// identity without writing the audit entry, and could write or forge entries.
/// Prod closes both by moving the reveal behind a server endpoint.
class FirebaseReporterIdentityRevealer implements ReporterIdentityRevealer {
  FirebaseReporterIdentityRevealer(
    CampusFixFirebase fb, {
    required AuthRepository viewer,
  }) : _fs = fb.firestore,
       _viewer = viewer;

  final FirebaseFirestore _fs;
  final AuthRepository _viewer;

  /// Reveals the reporter of [complaintId] and records why ([reason], required).
  ///
  /// Throws an [ArgumentError] for a blank or over-long [reason] (nothing is
  /// read or written), a [StateError] when nobody is signed in as an admin or
  /// the complaint has no stored identity (nothing is audited), and lets a
  /// `FirebaseException` propagate (permission denied, offline; no identity is
  /// returned).
  @override
  Future<ReporterIdentity> reveal(String complaintId, {String? reason}) async {
    final String why = (reason ?? '').trim();
    if (why.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'A reason is required to reveal a reporter identity.',
      );
    }
    if (why.length > kRevealReasonMaxLength) {
      throw ArgumentError.value(
        why.length,
        'reason',
        'The reason is too long ($kRevealReasonMaxLength characters at most).',
      );
    }
    final AppUser? actor = _viewer.currentUser;
    if (actor == null || !actor.role.canSeeReporterIdentity) {
      throw StateError('Only an admin can reveal a reporter identity.');
    }
    if (complaintId.isEmpty || complaintId.contains('/')) {
      throw ArgumentError.value(complaintId, 'complaintId', 'Not a complaint id.');
    }

    final DocumentReference<Map<String, dynamic>> identityRef = _fs
        .collection('complaints')
        .doc(complaintId)
        .collection('private')
        .doc('identity');
    final DocumentReference<Map<String, dynamic>> auditRef = _fs
        .collection('auditLog')
        .doc();

    return _fs.runTransaction<ReporterIdentity>((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(
        identityRef,
      );
      if (!snap.exists) {
        throw StateError('No reporter identity is stored for this complaint.');
      }
      final ReporterIdentity identity = ReporterIdentity.fromJson(
        documentToJson(snap.data()),
      );
      tx.set(auditRef, <String, Object?>{
        'type': 'identityReveal',
        'actorUid': actor.id,
        'actorRole': actor.role.name,
        'complaintId': complaintId,
        'reason': why,
        'at': FieldValue.serverTimestamp(),
        'requestId': auditRef.id,
      });
      return identity;
    });
  }
}
