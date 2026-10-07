// The Assignment panel of A-04 (screens-spec A-04, "Assignment panel").
//
// * **Both roles:** the department label.
// * **Admin only:** the assignee resolved to staff name / ID, who assigned it
//   and when, and the Auto / Manual chip. A verifier's panel has none of it
//   (AC-52): it is built from the public view, which carries no assignee.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import 'complaint_detail_controller.dart';
import 'detail_widgets.dart';

class AssignmentPanel extends StatelessWidget {
  const AssignmentPanel({super.key, required this.detail});

  final ComplaintDetail detail;

  @override
  Widget build(BuildContext context) {
    final Department? department = detail.complaint.assignedDepartment;
    final AdminDetail? admin = detail.admin;
    final Assignment? assignment = admin?.view.assignment;

    return DetailSection(
      title: 'Assignment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DetailFact(
            label: 'Department',
            value: department?.label ?? 'Not assigned yet',
          ),
          if (admin != null && assignment != null) ...<Widget>[
            DetailFact(
              label: 'Assignee',
              value:
                  admin.staffById(assignment.assigneeId)?.line ??
                  (assignment.assigneeId ?? 'Any member of the department'),
            ),
            DetailFact(
              label: 'Assigned by',
              value:
                  admin.staffById(assignment.assignedBy)?.line ??
                  assignment.assignedBy,
            ),
            DetailFact(
              label: 'Assigned at',
              value: formatAbsoluteTime(assignment.assignedAt),
            ),
            DetailFact(
              label: 'Routing',
              child: Align(
                alignment: Alignment.centerLeft,
                child: DetailLabelChip(
                  label: assignment.isManual ? 'Manual' : 'Auto',
                  icon: assignment.isManual
                      ? Icons.edit_outlined
                      : Icons.alt_route,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
