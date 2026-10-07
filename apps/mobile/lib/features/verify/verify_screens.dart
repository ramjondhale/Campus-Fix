/// The verifier's flow (screens-spec M-16, M-17): the verification queue and
/// the verify / reject detail. The router imports the two screens from here.
///
/// The verifier verifies (T5) or sends the job back (T7); closing a verified
/// complaint (T6) is an admin-only action on the web console.
library;

export 'verification_queue_screen.dart' show VerificationQueueScreen;
export 'verify_detail_screen.dart' show VerifyCloseScreen;
