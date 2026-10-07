import 'package:flutter/material.dart';

import '../shared/coming_soon_page.dart';

/// A-04 Complaint Detail / Manage ([complaintId] comes from the route and is
/// the only thing the URL carries, privacy LK-5). Placeholder: S5.4 replaces
/// the body with the detail view, the manage actions and, for admins only, the
/// reporter-identity reveal panel (`identity_panel.dart` in this directory is
/// the one path the core privacy guard allows to touch the reporter).
class ComplaintDetailScreen extends StatelessWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'Complaint details',
      icon: Icons.assignment_outlined,
    );
  }
}
