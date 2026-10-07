import 'package:flutter/material.dart';

import '../shared/coming_soon_page.dart';

/// A-03 Complaint List + Filters (admins and verifiers). Placeholder: S5.3
/// replaces the body with the filterable, sortable table, built on
/// `allComplaintsProvider` (public views only, no reporter column).
class ComplaintListScreen extends StatelessWidget {
  const ComplaintListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'The complaint list',
      icon: Icons.list_alt_outlined,
    );
  }
}
