import 'package:flutter/material.dart';

import '../shared/coming_soon_screen.dart';

/// Stub for M-12 Notifications (built in S4.4). A bottom-nav tab.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Notifications',
    icon: Icons.notifications_none,
    showBack: false,
  );
}
