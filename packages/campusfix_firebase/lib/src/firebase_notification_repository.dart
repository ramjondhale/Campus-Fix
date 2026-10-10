import 'package:campusfix_core/campusfix_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'campus_fix_firebase.dart';
import 'firestore_codec.dart';

/// [NotificationRepository] over Firestore `notifications/{id}` (in-app feed
/// only; no FCM in the MVP).
///
/// Security rules (firestore.rules): a recipient reads **only their own**
/// notifications (every query must filter `recipientId == uid`) and may flip
/// only the `read` field; any authenticated client may create a notification
/// (MVP: the writing client fans out; prod: the server does).
///
/// The document keeps its own `id` field (`ntf-<eventId>-<recipientId>`, a
/// deterministic id so retries are idempotent) and stores `createdAt` as a
/// Firestore `Timestamp`. The `(recipientId, createdAt desc)` composite index
/// in `firestore.indexes.json` serves [byRecipient] / [watchByRecipient].
///
/// This class is the storage half only. Who a notification is addressed to is
/// resolved by `FirebaseNotificationService` (chunk C4), which also owns the
/// idempotency policy for [add].
class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository(CampusFixFirebase fb)
    : _col = fb.firestore.collection('notifications');

  final CollectionReference<Map<String, dynamic>> _col;

  /// Firestore allows 500 operations per batch; stay well below.
  static const int _batchLimit = 400;

  /// Newest first; ties broken by id, descending (same as the mock).
  static int _newestFirst(AppNotification a, AppNotification b) {
    final int byTime = b.createdAt.compareTo(a.createdAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  }

  AppNotification _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppNotification.fromJson(documentToJson(doc.data(), id: doc.id));

  List<AppNotification> _sorted(QuerySnapshot<Map<String, dynamic>> snap) =>
      <AppNotification>[for (final doc in snap.docs) _fromDoc(doc)]
        ..sort(_newestFirst);

  Query<Map<String, dynamic>> _forRecipient(String recipientId) => _col
      .where('recipientId', isEqualTo: recipientId)
      .orderBy('createdAt', descending: true);

  /// Not available on the client: the rules only let a user read their own
  /// notifications, so "every notification for every recipient" cannot be
  /// served. Use [byRecipient] with the signed-in user's id.
  @override
  Future<List<AppNotification>> all() => Future<List<AppNotification>>.error(
    UnsupportedError(
      'FirebaseNotificationRepository.all: rules only allow reading your own '
      'notifications; use byRecipient(uid).',
    ),
  );

  @override
  Future<List<AppNotification>> byRecipient(String recipientId) async =>
      _sorted(await _forRecipient(recipientId).get());

  /// Stores [notification] (MVP client-side fan-out).
  ///
  /// A blind `set`: the writer is usually not the recipient and so cannot read
  /// the document first. Unlike the mock this does not throw a [StateError] for
  /// an existing id: re-writing it is denied by the rules (the recipient may
  /// only change `read`), which surfaces as a `permission-denied`
  /// `FirebaseException`.
  ///
  /// Duplicate policy (C4): `FirebaseNotificationService.deliver` catches that
  /// `permission-denied` and treats it as an idempotent re-delivery; this method
  /// itself stays a plain `set` and rethrows.
  @override
  Future<AppNotification> add(AppNotification notification) async {
    await _col
        .doc(notification.id)
        .set(jsonToFirestore(notification.toJson())! as Map<String, Object?>);
    return notification;
  }

  @override
  Future<AppNotification?> markRead(String id) async {
    final DocumentReference<Map<String, dynamic>> ref = _col.doc(id);
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    if (!snap.exists) return null;
    final AppNotification current = _fromDoc(snap);
    if (current.read) return current; // idempotent
    await ref.update(<String, Object?>{'read': true});
    return current.copyWith(read: true);
  }

  @override
  Future<void> markAllRead(String recipientId) async {
    final QuerySnapshot<Map<String, dynamic>> unread = await _col
        .where('recipientId', isEqualTo: recipientId)
        .where('read', isEqualTo: false)
        .get();
    for (int i = 0; i < unread.docs.length; i += _batchLimit) {
      final WriteBatch batch = _col.firestore.batch();
      final int end = i + _batchLimit < unread.docs.length
          ? i + _batchLimit
          : unread.docs.length;
      for (final doc in unread.docs.sublist(i, end)) {
        batch.update(doc.reference, <String, Object?>{'read': true});
      }
      await batch.commit();
    }
  }

  @override
  Stream<List<AppNotification>> watchByRecipient(String recipientId) =>
      _forRecipient(recipientId).snapshots().map(_sorted);
}
