/// App-wide Riverpod providers: repositories, services, the session and the
/// privacy-safe (public-view) data feeds that widgets consume.
///
/// `complaintRepositoryProvider` is deliberately **not** re-exported: it hands
/// out raw `Complaint`s (reporter PII), so only the files in this directory
/// may read it (see `complaints.dart`).
library;

export 'complaint_filter.dart';
export 'complaint_list.dart';
export 'complaint_query.dart';
export 'complaints.dart';
export 'dashboard.dart';
export 'identity_revealer.dart';
export 'repositories.dart' hide complaintRepositoryProvider;
export 'services.dart';
export 'session.dart';
