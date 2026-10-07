import 'package:flutter/material.dart';

import '../shared/coming_soon_screen.dart';

/// Stub for M-16 Verification Queue (verifier; built in S4.6). Reached from
/// Home "Open verification queue"; the bottom-nav "Verify" tab keeps its
/// selection here.
class VerificationQueueScreen extends StatelessWidget {
  const VerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Verification queue',
    icon: Icons.fact_check_outlined,
  );
}

/// Stub for M-17 Verify & Close (`/verify/:id`, S4.6).
class VerifyCloseScreen extends StatelessWidget {
  const VerifyCloseScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Verify & close',
    icon: Icons.fact_check_outlined,
  );
}
