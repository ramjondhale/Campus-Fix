import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../report/report_problem_fab.dart';
import '../shared/complaint_search.dart';
import '../shared/list_states.dart';

/// The All / Active / Closed segments of My Complaints (screens-spec M-09).
enum MyComplaintsSegment {
  all('All'),

  /// Not `closed`.
  active('Active'),
  closed('Closed');

  const MyComplaintsSegment(this.label);

  final String label;

  bool includes(ComplaintStatus status) => switch (this) {
    MyComplaintsSegment.all => true,
    MyComplaintsSegment.active => status != ComplaintStatus.closed,
    MyComplaintsSegment.closed => status == ComplaintStatus.closed,
  };
}

/// [all] narrowed to [segment] and the free-text [query] (ID / description),
/// keeping the order given (the provider sorts by `updatedAt` descending).
List<PublicComplaintView> filterMyComplaints(
  List<PublicComplaintView> all, {
  required MyComplaintsSegment segment,
  required String query,
}) => <PublicComplaintView>[
  for (final PublicComplaintView c in all)
    if (segment.includes(c.status) && matchesComplaintQuery(c, query)) c,
];

/// M-09 My Complaints / Status: the signed-in reporter's own complaints with
/// live status, newest update first. A bottom-nav tab. Consumes
/// `myComplaintsProvider` (public views; ownership is resolved in the
/// provider layer) only.
class MyComplaintsScreen extends ConsumerStatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  ConsumerState<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends ConsumerState<MyComplaintsScreen> {
  final TextEditingController _search = TextEditingController();
  MyComplaintsSegment _segment = MyComplaintsSegment.all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    setState(() {
      _segment = MyComplaintsSegment.all;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PublicComplaintView>> mine = ref.watch(
      myComplaintsProvider,
    );
    // With nothing reported yet the empty state carries its own call to
    // action, so the floating button would only repeat it.
    final bool hasNone = mine.maybeWhen(
      data: (List<PublicComplaintView> l) => l.isEmpty,
      orElse: () => false,
    );

    return Scaffold(
      appBar: const AppTopBar.page(title: 'My Complaints'),
      floatingActionButton: hasNone ? null : const ReportProblemFab(),
      body: mine.when(
        loading: () => const ComplaintListSkeleton(
          variant: ComplaintCardVariant.mine,
          count: 3,
        ),
        error: (_, _) => RefreshFill(
          onRefresh: () => refreshComplaints(ref),
          child: EmptyState.error(
            title: "Couldn't load your complaints",
            onAction: () => refreshComplaints(ref),
          ),
        ),
        data: _buildData,
      ),
    );
  }

  Widget _buildData(List<PublicComplaintView> all) {
    if (all.isEmpty) {
      return RefreshFill(
        onRefresh: () => refreshComplaints(ref),
        child: EmptyState.nothing(
          actionLabel: 'Report a Problem',
          onAction: () => context.push(AppRoutes.reportCategory),
        ),
      );
    }
    final List<PublicComplaintView> shown = filterMyComplaints(
      all,
      segment: _segment,
      query: _query,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s2,
            AppSpace.s4,
            AppSpace.s2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppSegmented<MyComplaintsSegment>(
                semanticLabel: 'Show complaints',
                segments: <AppSegment<MyComplaintsSegment>>[
                  for (final MyComplaintsSegment s in MyComplaintsSegment.values)
                    AppSegment<MyComplaintsSegment>(value: s, label: s.label),
                ],
                selected: _segment,
                onChanged: (MyComplaintsSegment s) =>
                    setState(() => _segment = s),
              ),
              const SizedBox(height: AppSpace.s3),
              AppSearchField(
                controller: _search,
                hintText: 'Search by ID or description',
                onChanged: (String q) => setState(() => _query = q),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? RefreshFill(
                  onRefresh: () => refreshComplaints(ref),
                  child: EmptyState.filtered(onAction: _clear),
                )
              : RefreshIndicator(
                  onRefresh: () => refreshComplaints(ref),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s4,
                      AppSpace.s2,
                      AppSpace.s4,
                      // Clears the floating "Report a Problem" button.
                      96,
                    ),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpace.s3),
                    itemBuilder: (BuildContext context, int i) {
                      final PublicComplaintView c = shown[i];
                      return ComplaintCard(
                        complaint: c,
                        variant: ComplaintCardVariant.mine,
                        onTap: () => context.push(AppRoutes.complaint(c.id)),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
