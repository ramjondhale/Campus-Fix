import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../shared/coming_soon_screen.dart' show popOrHome;
import '../shared/list_states.dart';

/// The three tabs of the work queue (screens-spec M-13).
enum WorkTab {
  /// `assigned` to the worker's department, not claimed by a colleague.
  toStart('To start'),

  /// Started by the worker.
  inProgress('In progress'),

  /// Sent back by a verifier.
  rework('Rework');

  const WorkTab(this.label);

  final String label;

  /// The jobs of this tab, in the order the provider gave them.
  List<PublicComplaintView> of(WorkQueue queue) => switch (this) {
    WorkTab.toStart => queue.toStart,
    WorkTab.inProgress => queue.inProgress,
    WorkTab.rework => queue.rework,
  };

  /// "To start (2)": the label with the tab's count (equal to the Home count,
  /// AC-34).
  String labelWithCount(WorkQueue queue) => '$label (${of(queue).length})';

  String get emptyTitle => switch (this) {
    WorkTab.toStart => 'Nothing to start',
    WorkTab.inProgress => 'Nothing in progress',
    WorkTab.rework => 'No rework needed',
  };

  String get emptyMessage => switch (this) {
    WorkTab.toStart => 'New jobs for your department will show up here.',
    WorkTab.inProgress => 'Jobs you start will show up here.',
    WorkTab.rework => 'Jobs a verifier sends back will show up here.',
  };
}

/// M-13 Assigned Work: the signed-in maintenance worker's queue, in three tabs
/// (To start, In progress, Rework). Reached from Home "Open my work"; the
/// bottom navigation keeps Home selected. Consumes `workQueueProvider` (public
/// views; the department and claim filtering runs in the provider layer, so a
/// plumber never sees electrical complaints, AC-33).
class AssignedWorkScreen extends ConsumerStatefulWidget {
  const AssignedWorkScreen({super.key});

  @override
  ConsumerState<AssignedWorkScreen> createState() => _AssignedWorkScreenState();
}

class _AssignedWorkScreenState extends ConsumerState<AssignedWorkScreen> {
  WorkTab _tab = WorkTab.toStart;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WorkQueue> queue = ref.watch(workQueueProvider);
    final String department =
        ref
            .watch(sessionProvider.select((AppUser? u) => u?.department))
            ?.label ??
        'your department';

    return Scaffold(
      appBar: AppTopBar.page(
        title: 'Assigned work',
        onBack: () => popOrHome(context),
      ),
      body: queue.when(
        loading: () =>
            const ComplaintListSkeleton(variant: ComplaintCardVariant.work),
        error: (_, _) => RefreshFill(
          onRefresh: () => refreshComplaints(ref),
          child: EmptyState.error(
            title: "Couldn't load your work",
            onAction: () => refreshComplaints(ref),
          ),
        ),
        data: (WorkQueue q) => _buildData(q, department),
      ),
    );
  }

  Widget _buildData(WorkQueue queue, String department) {
    final List<PublicComplaintView> shown = _tab.of(queue);
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
          child: AppSegmented<WorkTab>(
            semanticLabel: 'Show work',
            segments: <AppSegment<WorkTab>>[
              for (final WorkTab t in WorkTab.values)
                AppSegment<WorkTab>(value: t, label: t.labelWithCount(queue)),
            ],
            selected: _tab,
            onChanged: (WorkTab t) => setState(() => _tab = t),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? RefreshFill(
                  onRefresh: () => refreshComplaints(ref),
                  child: queue.isEmpty
                      ? EmptyState(
                          icon: Icons.task_alt,
                          title: 'No work assigned to $department',
                          message: 'New jobs will show up here.',
                        )
                      : EmptyState(
                          icon: Icons.task_alt,
                          title: _tab.emptyTitle,
                          message: _tab.emptyMessage,
                        ),
                )
              : RefreshIndicator(
                  onRefresh: () => refreshComplaints(ref),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s4,
                      AppSpace.s2,
                      AppSpace.s4,
                      AppSpace.s4,
                    ),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpace.s3),
                    itemBuilder: (BuildContext context, int i) {
                      final PublicComplaintView c = shown[i];
                      return ComplaintCard(
                        complaint: c,
                        variant: ComplaintCardVariant.work,
                        onTap: () => context.push(AppRoutes.workItem(c.id)),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
