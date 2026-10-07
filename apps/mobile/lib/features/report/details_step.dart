import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'report_flow.dart';

/// A one-line plain-language hint for each [Severity] (screens-spec M-06).
String severityHint(Severity severity) => switch (severity) {
  Severity.minor => 'A nuisance; things still work',
  Severity.moderate => 'Gets in the way of normal use',
  Severity.severe => 'Blocks use, or could get worse quickly',
};

/// M-06 Report: Description & Impact (step 4 of 5). The description plus the
/// three inputs of the priority engine: severity, people affected and the
/// safety flag.
class DetailsStep extends ConsumerStatefulWidget {
  const DetailsStep({super.key, this.edit = false});

  final bool edit;

  @override
  ConsumerState<DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<DetailsStep> {
  late final TextEditingController _description;
  final FocusNode _focus = FocusNode();
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(
      text: ref.read(reportDraftProvider).description,
    );
    // Inline validation on blur (screens-spec G-7).
    _focus.addListener(() {
      if (!_focus.hasFocus) setState(() => _touched = true);
    });
  }

  @override
  void dispose() {
    _description.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ReportDraft draft = ref.watch(reportDraftProvider);
    final ReportDraftNotifier notifier = ref.read(reportDraftProvider.notifier);
    final ThemeData theme = Theme.of(context);

    final String? descriptionError = _touched && !draft.descriptionValid
        ? 'Describe the problem in at least '
              '${ReportLimits.descriptionMin} characters'
        : null;

    return ReportStepScaffold(
      step: 4,
      stepLabel: 'Details',
      edit: widget.edit,
      primaryLabel: widget.edit ? 'Done' : 'Next',
      onPrimary: draft.descriptionValid
          ? () => continueFrom(
              context,
              edit: widget.edit,
              next: AppRoutes.reportReview,
            )
          : null,
      children: <Widget>[
        const StepHeading(
          title: 'Tell us more',
          subtitle: 'This helps us set the right priority.',
        ),
        AppTextField.multiline(
          label: 'Description',
          required: true,
          hintText: 'What is wrong, and what does it affect?',
          helperText:
              "Don't include names or contact details. "
              'Complaints are visible on the campus board.',
          controller: _description,
          focusNode: _focus,
          maxLength: ReportLimits.descriptionMax,
          errorText: descriptionError,
          onChanged: notifier.setDescription,
        ),
        const SizedBox(height: AppSpace.s6),
        _GroupLabel('How severe is it?'),
        for (final Severity s in Severity.values) ...<Widget>[
          SelectTile(
            title: s.label,
            hint: severityHint(s),
            selected: draft.severity == s,
            onTap: () => notifier.setSeverity(s),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
        const SizedBox(height: AppSpace.s4),
        _GroupLabel('How many people does it affect?'),
        for (final PeopleAffected p in PeopleAffected.values) ...<Widget>[
          SelectTile(
            title: peopleAffectedChoice(p),
            selected: draft.peopleAffected == p,
            onTap: () => notifier.setPeopleAffected(p),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
        const SizedBox(height: AppSpace.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'This is a safety hazard',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    draft.safetyLocked
                        ? 'Always on for the Safety category. '
                              'Marked urgent: minimum priority High.'
                        : draft.safetyFlag
                        ? 'Marked urgent: minimum priority High.'
                        : 'Turn on if someone could get hurt.',
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            AppSwitch(
              value: draft.safetyFlag,
              semanticLabel: 'This is a safety hazard',
              onChanged: draft.safetyLocked ? null : notifier.setSafetyFlag,
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s2),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
