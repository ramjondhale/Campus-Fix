import 'package:flutter/material.dart';

import '../shared/coming_soon_screen.dart';

/// Stub for M-11 Campus Problem Board (built in S4.4). A bottom-nav tab.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Campus Board',
    icon: Icons.view_kanban_outlined,
    showBack: false,
  );
}

/// Stub for M-11b Board Item Detail (built in S4.4). [complaintId] comes from
/// the route (`/board/:id`).
class BoardItemDetailScreen extends StatelessWidget {
  const BoardItemDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Board item',
    icon: Icons.view_kanban_outlined,
  );
}
