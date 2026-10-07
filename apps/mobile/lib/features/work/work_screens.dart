import 'package:flutter/material.dart';

import '../shared/coming_soon_screen.dart';

/// Stub for M-13 Assigned Work (maintenance; built in S4.5). Reached from Home
/// "Open my work"; the bottom-nav "Work" tab keeps its selection here.
class AssignedWorkScreen extends StatelessWidget {
  const AssignedWorkScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Assigned work',
    icon: Icons.build_outlined,
  );
}

/// Stub for M-14 Work Detail (`/work/:id`, S4.5).
class WorkDetailScreen extends StatelessWidget {
  const WorkDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context) =>
      const ComingSoonScreen(title: 'Work detail', icon: Icons.build_outlined);
}

/// Stub for M-15 After-Repair Upload (`/work/:id/resolve`, S4.5).
class AfterRepairScreen extends StatelessWidget {
  const AfterRepairScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'After-repair photos',
    icon: Icons.add_a_photo_outlined,
  );
}
