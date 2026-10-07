import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../../shell/admin_page.dart';
import 'assignment_panel.dart';
import 'complaint_detail_controller.dart';
import 'detail_header.dart';
import 'detail_timeline.dart';
import 'detail_widgets.dart';
import 'identity_panel.dart';
import 'manage_bar.dart';
import 'manage_dialogs.dart';
import 'priority_panel.dart';

/// A-04 Complaint Detail / Manage: review one complaint and act on it
/// (screens-spec A-04). [complaintId] comes from the route and is the only
/// thing the URL carries (privacy LK-5): no filter, no identity, no title.
///
/// The screen is **role-split by construction** (`complaintDetailProvider`):
///
/// * **Admin** gets the full view: the Priority panel (computed priority,
///   override and the inputs behind it), the Assignment panel with the
///   assignee's name and ID, the timeline with actor names, the reveal-gated
///   reporter-identity panel and every manage action.
/// * **Verifier** gets the public view only: the department label, the public
///   timeline (role, time, note), and Review & Route, Verify and Reject. No
///   identity panel, no assignee or actor names, no priority inputs and no
///   Close.
///
/// A `closed` complaint is read-only. States: loading skeleton, error with
/// Retry, E-404 for an unknown ID, and "This complaint changed; refresh" when
/// an action finds the complaint changed under it.
class ComplaintDetailScreen extends ConsumerWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ComplaintDetail?> detail = ref.watch(
      complaintDetailProvider(complaintId),
    );
    return AdminPage(
      child: detail.when(
        loading: () => const DetailSkeleton(),
        error: (Object _, StackTrace _) => EmptyState.error(
          title: "Couldn't load this complaint",
          alignment: CrossAxisAlignment.start,
          onAction: () => refreshComplaintDetail(ref, complaintId),
        ),
        data: (ComplaintDetail? d) => d == null
            ? EmptyState.notFound(
                alignment: CrossAxisAlignment.start,
                onAction: () => context.go(AppRoutes.dashboard),
              )
            : _DetailBody(detail: d),
      ),
    );
  }
}

/// The loaded screen for one [ComplaintDetail].
class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final ComplaintDetail detail;

  /// Back to the list the user came from, filters and page intact: the list
  /// opens a complaint on top of itself, so popping returns to it; a direct
  /// link has nothing to pop and goes to the plain list.
  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.complaints);
    }
  }

  Future<void> _act(BuildContext context, ManageAction action) async {
    final bool? done = await showManageActionDialog(
      context,
      action: action,
      detail: detail,
    );
    if (done == true && context.mounted) {
      AppToast.show(
        context,
        manageSuccessText(action),
        kind: AppToastKind.success,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    final DateTime now = ref.watch(dashboardClockProvider)();
    final DetailActionState action = ref.watch(detailActionProvider(detail.id));
    final PublicComplaintView c = detail.complaint;
    final AdminDetail? admin = detail.admin;

    final Widget manage = ManageBar(
      detail: detail,
      options: manageActionsFor(c, user.role),
      state: action,
      onAction: (ManageAction a) => _act(context, a),
    );

    final List<Widget> main = <Widget>[
      DetailSection(
        title: 'Description',
        child: Text(
          c.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      DetailPhotos(complaint: c),
      if (c.resolutionNote != null)
        DetailSection(
          title: 'Resolution note',
          child: Text(
            c.resolutionNote!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      DetailTimelinePanel(detail: detail, now: now),
    ];
    final List<Widget> side = <Widget>[
      if (admin != null)
        PriorityPanel(
          view: admin.view,
          now: now,
          options: priorityActionsFor(
            c,
            user.role,
            hasOverride: admin.view.priorityOverride != null,
          ),
          state: action,
          onAction: (ManageAction a) => _act(context, a),
        ),
      AssignmentPanel(detail: detail),
      // The identity panel exists for an admin only; it starts collapsed and
      // is keyed by complaint so a different complaint starts collapsed too.
      if (admin != null)
        IdentityPanel(key: ValueKey<String>(c.id), view: admin.view),
    ];

    final bool wide =
        AppWindowClass.fromWidth(MediaQuery.sizeOf(context).width) ==
        AppWindowClass.expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Back to complaints',
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.sm,
            leadingIcon: Icons.arrow_back,
            onPressed: () => _back(context),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        DetailHeader(
          complaint: c,
          now: now,
          overridden: admin?.view.priorityOverride != null,
        ),
        const SizedBox(height: AppSpace.s5),
        manage,
        const SizedBox(height: AppSpace.s5),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 5, child: _stack(main)),
              const SizedBox(width: AppSpace.s6),
              Expanded(flex: 3, child: _stack(side)),
            ],
          )
        else
          _stack(<Widget>[...side, ...main]),
      ],
    );
  }

  /// [children] one under the other with the card gap between them.
  Widget _stack(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int i = 0; i < children.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: AppSpace.s4),
        children[i],
      ],
    ],
  );
}
