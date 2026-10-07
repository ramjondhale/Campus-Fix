import 'package:flutter/material.dart';

import '../shared/coming_soon_screen.dart';

export 'verification_queue_screen.dart' show VerificationQueueScreen;

/// Stub for M-17 Verify & Close (`/verify/:id`, built in the next commit).
class VerifyCloseScreen extends StatelessWidget {
  const VerifyCloseScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Verify repair',
    icon: Icons.fact_check_outlined,
  );
}
