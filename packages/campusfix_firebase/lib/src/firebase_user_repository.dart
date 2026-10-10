import 'package:campusfix_core/campusfix_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'campus_fix_firebase.dart';
import 'firestore_codec.dart';

/// [UserRepository] over Firestore `users/{uid}` (plan sections 5 and 6.2).
///
/// **Staff only.** Security rules let an admin read *staff* profiles
/// (maintenance, verifier, admin) and every user read only their own profile,
/// so this directory never holds a reporter for an admin. That matches the
/// prototype (`_adminDetails` filters reporters out) and keeps a reporter's name
/// from surfacing before the audited identity reveal. [all] and
/// [maintenanceByDepartment] therefore constrain `role` in every query, as the
/// list rule requires.
///
/// The document has no `id` field (the document id is the uid, which equals
/// `AppUser.id`); [documentToJson] adds it for `AppUser.fromJson`.
///
/// TODO(C1): verify against the emulator once the seed has written `users/*`.
/// TODO(C4): non-admin clients cannot list users under these rules, but core's
/// client-side `NotificationService.buildFor` calls [all] to resolve recipients.
/// Decide how recipients are resolved (see the chunk report) before C3/C4.
class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository(CampusFixFirebase fb)
    : _users = fb.firestore.collection('users');

  final CollectionReference<Map<String, dynamic>> _users;

  /// Roles whose profiles an admin may list (plan section 6.2).
  static final List<String> _staffRoles = <String>[
    UserRole.maintenance.name,
    UserRole.verifier.name,
    UserRole.admin.name,
  ];

  AppUser _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromJson(documentToJson(doc.data(), id: doc.id));

  /// Every staff profile (admin-only under the rules; see the class doc).
  @override
  Future<List<AppUser>> all() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _users
        .where('role', whereIn: _staffRoles)
        .get();
    return <AppUser>[for (final doc in snap.docs) _fromDoc(doc)];
  }

  /// The user with [id], or `null` when there is no such profile **or the
  /// caller may not read it** (a reporter's profile is not readable by an
  /// admin): an unresolvable actor id degrades to "unknown user" instead of
  /// failing the screen.
  @override
  Future<AppUser?> byId(String id) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _users
          .doc(id)
          .get();
      return doc.exists ? _fromDoc(doc) : null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// The `maintenance` users of [department] (admin assignee picker).
  @override
  Future<List<AppUser>> maintenanceByDepartment(Department department) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _users
        .where('role', isEqualTo: UserRole.maintenance.name)
        .where('department', isEqualTo: department.name)
        .get();
    return <AppUser>[for (final doc in snap.docs) _fromDoc(doc)];
  }
}
