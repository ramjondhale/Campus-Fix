import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The audited reporter-identity reveal of A-04 (plan seam S-5, privacy-spec
/// PV-4 / LK-8, decision D4 = required reason).
///
/// `null` in the offline prototype (the mock entrypoint): its admin detail
/// already holds the identity in memory and there is no audit store, so the
/// identity panel reveals it directly, as it always did. The Firebase entrypoint
/// overrides it (`firebase_overrides.dart`) with an implementation that writes
/// the audit entry (with the reason) before it returns the identity; the panel
/// then asks for a non-blank reason first.
///
/// Typed on the revealer interface only, so the exact admin allow-list (the
/// reporter type appears only in `identity_panel.dart`) still holds.
final reporterIdentityRevealerProvider = Provider<ReporterIdentityRevealer?>(
  (ref) => null,
);
