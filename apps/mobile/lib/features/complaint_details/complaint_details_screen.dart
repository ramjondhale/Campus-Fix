import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'complaint_details_view.dart';

/// M-10 Complaint Details (own): the full tracking page of one of the signed-in
/// reporter's complaints. [complaintId] comes from the route
/// (`/complaints/:id`); routes carry only the ID (LK-5).
///
/// The complaint is looked up among the reporter's own complaints
/// (`myComplaintsProvider`, public views). A complaint that exists but is not
/// theirs is forwarded to its Board Item Detail (M-11b); an unknown ID shows
/// E-404, which never says whether the ID exists.
class ComplaintDetailsScreen extends ConsumerWidget {
  const ComplaintDetailsScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PublicComplaintView?> own = ref
        .watch(myComplaintsProvider)
        .whenData((List<PublicComplaintView> mine) {
          for (final PublicComplaintView c in mine) {
            if (c.id == complaintId) return c;
          }
          return null;
        });
    final bool existsOnBoard =
        ref.watch(complaintViewProvider(complaintId)).value != null;

    return ComplaintDetailsPage(
      title: 'Complaint details',
      value: own,
      mode: ComplaintDetailsMode.owner,
      onRetry: () => refreshComplaints(ref),
      notFound: existsOnBoard
          ? _ForwardToBoardItem(complaintId: complaintId)
          : null,
    );
  }
}

/// Replaces the owner page by the board item of the same complaint (the
/// signed-in user is not its reporter).
class _ForwardToBoardItem extends StatefulWidget {
  const _ForwardToBoardItem({required this.complaintId});

  final String complaintId;

  @override
  State<_ForwardToBoardItem> createState() => _ForwardToBoardItemState();
}

class _ForwardToBoardItemState extends State<_ForwardToBoardItem> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pushReplacement(AppRoutes.boardItem(widget.complaintId));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
