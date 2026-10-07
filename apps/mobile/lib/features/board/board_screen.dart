import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../complaint_details/complaint_details_view.dart';

import '../report/report_problem_fab.dart';
import '../shared/coming_soon_screen.dart';

/// Stub for M-11 Campus Problem Board (built in S4.4). A bottom-nav tab.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(
    title: 'Campus Board',
    icon: Icons.view_kanban_outlined,
    showBack: false,
    floatingActionButton: ReportProblemFab(),
  );
}

/// M-11b Board Item Detail: one board complaint limited to the board's
/// public field set, with no tracking history. [complaintId] comes from the
/// route (`/board/:id`).
class BoardItemDetailScreen extends ConsumerWidget {
  const BoardItemDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ComplaintDetailsPage(
      title: 'Board item',
      value: ref.watch(complaintViewProvider(complaintId)),
      mode: ComplaintDetailsMode.board,
      onRetry: () => refreshComplaints(ref),
    );
  }
}
