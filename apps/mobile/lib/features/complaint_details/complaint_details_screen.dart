import 'package:flutter/material.dart';

import '../shared/coming_soon_screen.dart';

/// Stub for M-10 Complaint Details (own), built in S4.3. [complaintId] comes
/// from the route (`/complaints/:id`); routes carry only the ID (LK-5).
class ComplaintDetailsScreen extends StatelessWidget {
  const ComplaintDetailsScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Complaint details',
    icon: Icons.assignment_outlined,
  );
}
