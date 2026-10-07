import 'package:flutter/material.dart';

import '../shared/coming_soon_screen.dart';

/// Stub for M-09 My Complaints / Status (built in S4.3). A bottom-nav tab.
class MyComplaintsScreen extends StatelessWidget {
  const MyComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'My Complaints',
    icon: Icons.list_alt_outlined,
    showBack: false,
  );
}
