import 'package:flutter/material.dart';

import '../shared/coming_soon_page.dart';

/// A-02 Admin Dashboard (admins and verifiers). Placeholder: S5.2 replaces the
/// body with the metric cards, charts and lists, built on
/// `allComplaintsProvider` (public views only).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'The dashboard',
      icon: Icons.space_dashboard_outlined,
    );
  }
}
