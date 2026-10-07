// The confirm dialogs of the A-04 manage actions (screens-spec A-04: "each asks
// for confirmation and a note where required").
//
// One dialog, [ManageActionDialog], covers every action; what it asks for
// depends on the action:
//
// | action                  | inputs                                          |
// |-------------------------|-------------------------------------------------|
// | Review & Route          | A: department (pre-set to the category's route), optional staff, optional note. V: confirm only |
// | Assign                  | department (required), optional staff, optional note |
// | Reassign                | department (required), optional staff, **reason required** |
// | Start / Resolve on behalf | optional note / after-photos (1-5) + resolution note (required) |
// | Verify / Close          | optional note                                   |
// | Reject                  | **reason required**                             |
// | Priority override       | a priority, or "No override"; shows the result  |
// | Safety flag             | confirm                                         |
//
// The confirm button stays disabled until the required input is there. When
// the rules say no (core rules P1-P9, RA2, SF ...) the dialog stays open and
// lists the messages inline; a stale complaint (P8) says so and offers a
// refresh; a failed write keeps the input and the same button retries. While
// an action is in flight every control waits, so nothing is sent twice.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'complaint_detail_controller.dart';

/// The limit of every note (core rule P9).
const int kDetailNoteMax = StatusMachine.maxNoteLength;

/// The most after-repair photos a resolve takes (screens-spec M-15).
const int kDetailMaxAfterPhotos = 5;

/// The most characters of a photo caption.
const int kDetailCaptionMax = 80;

/// What the toast says once [action] was applied.
String manageSuccessText(ManageAction action) => switch (action) {
  ManageAction.reviewAndRoute => 'Complaint reviewed',
  ManageAction.assign => 'Complaint assigned',
  ManageAction.reassign => 'Complaint reassigned',
  ManageAction.startWork => 'Work started',
  ManageAction.resolve => 'Marked as resolved',
  ManageAction.verify => 'Repair verified',
  ManageAction.reject => 'Sent back for rework',
  ManageAction.close => 'Complaint closed',
  ManageAction.setPriorityOverride => 'Priority updated',
  ManageAction.toggleSafetyFlag => 'Safety flag updated',
};

/// Opens the dialog of [action] for [detail]; resolves to `true` once the
/// action was applied, otherwise `false` / `null`.
Future<bool?> showManageActionDialog(
  BuildContext context, {
  required ManageAction action,
  required ComplaintDetail detail,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: AppMotion.moderate,
            reverseDuration: AppMotion.base,
            curve: AppMotion.enter,
            reverseCurve: AppMotion.exit,
          ),
    builder: (BuildContext dialogContext) =>
        ManageActionDialog(action: action, detail: detail),
  );
}

/// The dialog of one manage action (see the library comment).
class ManageActionDialog extends ConsumerStatefulWidget {
  const ManageActionDialog({
    super.key,
    required this.action,
    required this.detail,
  });

  final ManageAction action;
  final ComplaintDetail detail;

  @override
  ConsumerState<ManageActionDialog> createState() => _ManageActionDialogState();
}

class _ManageActionDialogState extends ConsumerState<ManageActionDialog> {
  final TextEditingController _note = TextEditingController();
  final TextEditingController _resolution = TextEditingController();
  final List<Attachment> _photos = <Attachment>[];
  Department? _department;
  String? _assigneeId;
  Priority? _override;
  int _photoSeq = 0;

  /// Why the last submit did not go through (blocked / stale / failed).
  DetailActionResult? _result;

  ManageAction get _action => widget.action;
  ComplaintDetail get _detail => widget.detail;
  PublicComplaintView get _c => _detail.complaint;
  AdminComplaintView? get _admin => _detail.admin?.view;

  @override
  void initState() {
    super.initState();
    if (_action == ManageAction.reviewAndRoute && _detail.isAdmin) {
      // Pre-set to the category's route; Safety and Other have none.
      _department = routeToDepartment(_c.category);
    }
    if (_action == ManageAction.setPriorityOverride) {
      _override = _admin?.priorityOverride;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _resolution.dispose();
    super.dispose();
  }

  bool get _noteFilled => _note.text.trim().isNotEmpty;

  /// Whether the required input of this action is there.
  bool get _canConfirm => switch (_action) {
    ManageAction.assign => _department != null,
    ManageAction.reassign => _department != null && _noteFilled,
    ManageAction.resolve =>
      _photos.isNotEmpty && _resolution.text.trim().isNotEmpty,
    ManageAction.reject => _noteFilled,
    ManageAction.setPriorityOverride => _override != _admin?.priorityOverride,
    _ => true,
  };

  ManageInput _input() => ManageInput(
    note: _note.text,
    resolutionNote: _resolution.text,
    department: _department,
    assigneeId: _assigneeId,
    afterPhotos: List<Attachment>.unmodifiable(_photos),
    priorityOverride: _override,
    safetyFlag: _action == ManageAction.toggleSafetyFlag
        ? !_c.safetyFlag
        : null,
  );

  Future<void> _submit() async {
    setState(() => _result = null);
    final DetailActionResult? result = await ref
        .read(detailActionProvider(_c.id).notifier)
        .run(_action, seenStatus: _c.status, input: _input());
    if (!mounted || result == null) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _result = result);
    }
  }

  Future<void> _addPhoto() async {
    final bool? picked = await AppBottomSheet.showOptions<bool>(
      context: context,
      title: 'Add a photo',
      options: const <AppSheetOption<bool>>[
        AppSheetOption<bool>(
          value: true,
          label: 'Take a photo (sample)',
          icon: Icons.photo_camera_outlined,
        ),
        AppSheetOption<bool>(
          value: true,
          label: 'Choose from gallery (sample)',
          icon: Icons.photo_library_outlined,
        ),
      ],
    );
    if (picked != true || !mounted) return;
    if (_photos.length >= kDetailMaxAfterPhotos) return;
    // Stamped with the current time, so it counts as fresh evidence (P1).
    final DateTime at = DateTime.now();
    final int n = ++_photoSeq;
    setState(() {
      _photos.add(
        Attachment(
          id: 'after-${at.microsecondsSinceEpoch}-$n',
          kind: AttachmentKind.afterPhoto,
          ref: 'assets/samples/after_sample_${(n - 1) % 6 + 1}.jpg',
          createdAt: at,
        ),
      );
    });
  }

  void _setCaption(String id, String caption) {
    final String text = caption.trim();
    final String clipped = text.length > kDetailCaptionMax
        ? text.substring(0, kDetailCaptionMax)
        : text;
    setState(() {
      for (int i = 0; i < _photos.length; i++) {
        if (_photos[i].id != id) continue;
        _photos[i] = clipped.isEmpty
            ? _photos[i].copyWith(clearCaption: true)
            : _photos[i].copyWith(caption: clipped);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = ref.watch(detailActionProvider(_c.id)).busy;
    final bool destructive = _action.isDestructive;
    final double maxBodyHeight = MediaQuery.sizeOf(context).height * 0.6;

    return AppDialog(
      title: _title(),
      message: _message(),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxBodyHeight),
        child: SingleChildScrollView(child: _body(busy)),
      ),
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.tertiary,
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: _confirmLabel(),
          variant: destructive
              ? AppButtonVariant.destructive
              : AppButtonVariant.primary,
          loading: busy,
          onPressed: _canConfirm && !busy ? _submit : null,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Wording
  // -------------------------------------------------------------------------

  String _title() => switch (_action) {
    ManageAction.reviewAndRoute => 'Review and route ${_c.id}?',
    ManageAction.assign => 'Assign ${_c.id}',
    ManageAction.reassign => 'Reassign ${_c.id}',
    ManageAction.startWork => 'Start work on ${_c.id}?',
    ManageAction.resolve => 'Resolve ${_c.id} on behalf of maintenance',
    ManageAction.verify => 'Verify the repair of ${_c.id}?',
    ManageAction.reject => 'Reject ${_c.id}?',
    ManageAction.close => 'Close ${_c.id}?',
    ManageAction.setPriorityOverride => 'Priority override for ${_c.id}',
    ManageAction.toggleSafetyFlag =>
      _c.safetyFlag
          ? 'Remove the safety flag from ${_c.id}?'
          : 'Flag ${_c.id} as a safety issue?',
  };

  String? _message() => switch (_action) {
    ManageAction.reviewAndRoute => _reviewMessage(),
    ManageAction.assign =>
      'This complaint has no department yet. Choose who takes it.',
    ManageAction.reassign =>
      'Choose the new department (and person), and say why.',
    ManageAction.startWork =>
      'Marks the work as started on behalf of the department.',
    ManageAction.resolve =>
      'Add the repair proof: one to $kDetailMaxAfterPhotos after-repair '
          'photos and a resolution note. A verifier reviews it next.',
    ManageAction.verify =>
      'This confirms the repair. The complaint can then be closed.',
    ManageAction.reject => 'The job goes back to maintenance with your reason.',
    ManageAction.close =>
      'A closed complaint is final: it cannot be changed afterwards.',
    ManageAction.setPriorityOverride =>
      'The override replaces the computed priority everywhere. The computed '
          'priority itself does not change.',
    ManageAction.toggleSafetyFlag =>
      'The priority is recomputed straight away. A safety flag raises it to '
          'at least High.',
  };

  String _reviewMessage() {
    final Department? route = routeToDepartment(_c.category);
    if (_detail.isAdmin) {
      return 'Reviews the complaint and routes it to a department.';
    }
    return route == null
        ? 'This category has no default department, so the review ends at '
              'Reviewed. An admin assigns it.'
        : 'Reviews the complaint. It is routed to ${route.label}.';
  }

  String _confirmLabel() => switch (_action) {
    ManageAction.reviewAndRoute => 'Review and route',
    ManageAction.assign => 'Assign',
    ManageAction.reassign => 'Reassign',
    ManageAction.startWork => 'Start work',
    ManageAction.resolve => 'Mark resolved',
    ManageAction.verify => 'Verify',
    ManageAction.reject => 'Reject',
    ManageAction.close => 'Close complaint',
    ManageAction.setPriorityOverride =>
      _override == null ? 'Clear override' : 'Set override',
    ManageAction.toggleSafetyFlag =>
      _c.safetyFlag ? 'Remove flag' : 'Flag as safety issue',
  };

  // -------------------------------------------------------------------------
  // Fields
  // -------------------------------------------------------------------------

  Widget _body(bool busy) {
    final List<Widget> fields = <Widget>[
      if (_result != null) ...<Widget>[
        _resultBanner(_result!),
        const SizedBox(height: AppSpace.s3),
      ],
      ..._actionFields(busy),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: fields,
    );
  }

  List<Widget> _actionFields(bool busy) => switch (_action) {
    ManageAction.reviewAndRoute =>
      _detail.isAdmin
          ? <Widget>[..._routeFields(busy), ..._noteFields(busy)]
          : const <Widget>[],
    ManageAction.assign => <Widget>[
      ..._routeFields(busy),
      ..._noteFields(busy),
    ],
    ManageAction.reassign => <Widget>[
      ..._routeFields(busy),
      ..._noteFields(busy, label: 'Reason', required: true),
    ],
    ManageAction.startWork ||
    ManageAction.verify ||
    ManageAction.close => _noteFields(busy),
    ManageAction.reject => _noteFields(busy, label: 'Reason', required: true),
    ManageAction.resolve => _resolveFields(busy),
    ManageAction.setPriorityOverride => _overrideFields(busy),
    ManageAction.toggleSafetyFlag => const <Widget>[],
  };

  List<Widget> _noteFields(
    bool busy, {
    String label = 'Note (optional)',
    bool required = false,
  }) => <Widget>[
    const SizedBox(height: AppSpace.s3),
    AppTextField.multiline(
      label: label,
      required: required,
      helperText: AppTextField.visibilityHelper,
      controller: _note,
      maxLength: kDetailNoteMax,
      enabled: !busy,
      onChanged: (_) => setState(() {}),
    ),
  ];

  List<Widget> _routeFields(bool busy) {
    final Department? route = routeToDepartment(_c.category);
    final String? departmentHelper = _action != ManageAction.reviewAndRoute
        ? null
        : route == null
        ? 'This category has no default department. Leave it empty to stop at '
              'Reviewed, or choose one to assign now.'
        : _department != null && _department != route
        ? 'A department other than ${route.label} makes this a manual '
              'assignment.'
        : null;
    return <Widget>[
      AppSelect<Department>(
        label: 'Department',
        required: _action != ManageAction.reviewAndRoute,
        hintText: _action == ManageAction.reviewAndRoute
            ? 'No department yet'
            : 'Choose a department',
        helperText: departmentHelper,
        value: _department,
        enabled: !busy,
        options: <AppSelectOption<Department>>[
          for (final Department d in Department.values)
            AppSelectOption<Department>(value: d, label: d.label),
        ],
        onChanged: (Department d) => setState(() {
          _department = d;
          _assigneeId = null;
        }),
      ),
      const SizedBox(height: AppSpace.s3),
      _StaffSelect(
        department: _department,
        value: _assigneeId,
        enabled: !busy,
        onChanged: (String? id) => setState(() => _assigneeId = id),
      ),
    ];
  }

  List<Widget> _resolveFields(bool busy) => <Widget>[
    const SizedBox(height: AppSpace.s3),
    PhotoUploader(
      category: _c.category,
      maxPhotos: kDetailMaxAfterPhotos,
      items: <PhotoUploadItem>[
        for (final Attachment a in _photos)
          PhotoUploadItem(attachment: a, caption: a.caption),
      ],
      onAdd: busy ? null : _addPhoto,
      onRemove: busy
          ? null
          : (PhotoUploadItem item) => setState(
              () => _photos.removeWhere(
                (Attachment a) => a.id == item.attachment.id,
              ),
            ),
      onCaptionChanged: busy ? null : _setCaption,
    ),
    if (_photos.isEmpty) ...<Widget>[
      const SizedBox(height: AppSpace.s2),
      Text(
        'Add after-repair photo: at least 1 is required.',
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    ],
    const SizedBox(height: AppSpace.s3),
    AppTextField.multiline(
      label: 'Resolution note',
      required: true,
      hintText: 'What was fixed, and how?',
      helperText: AppTextField.visibilityHelper,
      controller: _resolution,
      maxLength: kDetailNoteMax,
      enabled: !busy,
      onChanged: (_) => setState(() {}),
    ),
  ];

  List<Widget> _overrideFields(bool busy) {
    final Priority computed = _admin?.priority ?? _c.effectivePriority;
    return <Widget>[
      const SizedBox(height: AppSpace.s3),
      AppSegmented<Priority?>(
        semanticLabel: 'Priority override',
        dense: true,
        selected: _override,
        onChanged: busy ? null : (Priority? p) => setState(() => _override = p),
        segments: <AppSegment<Priority?>>[
          const AppSegment<Priority?>(value: null, label: 'No override'),
          for (final Priority p in Priority.values.reversed)
            AppSegment<Priority?>(value: p, label: p.label),
        ],
      ),
      const SizedBox(height: AppSpace.s4),
      Wrap(
        spacing: AppSpace.s3,
        runSpacing: AppSpace.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            'Resulting priority',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          PriorityTag(
            priority: _override ?? computed,
            overridden: _override != null,
          ),
        ],
      ),
    ];
  }

  Widget _resultBanner(DetailActionResult result) {
    return switch (result.outcome) {
      DetailActionOutcome.stale => InlineBanner(
        kind: FeedbackKind.warning,
        title: 'This complaint changed',
        message: 'Refresh to see the latest version, then try again.',
        actionLabel: 'Refresh',
        onAction: () async {
          Navigator.of(context).pop(false);
          await refreshComplaintDetail(ref, _c.id);
        },
      ),
      DetailActionOutcome.failed => InlineBanner(
        kind: FeedbackKind.error,
        title: "Couldn't complete this action",
        message: result.messages.join(' '),
      ),
      _ => InlineBanner(
        kind: FeedbackKind.error,
        title: "This can't be done yet",
        message: result.messages.join(' '),
      ),
    };
  }
}

/// The optional staff member of an assignment: the maintenance staff of
/// [department], or "anyone in the department".
class _StaffSelect extends ConsumerWidget {
  const _StaffSelect({
    required this.department,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Department? department;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  /// The value of the "no specific person" option.
  static const String _anyone = '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Department? d = department;
    final List<StaffRef> staff = d == null
        ? const <StaffRef>[]
        : ref.watch(assignableStaffProvider(d)).value ?? const <StaffRef>[];
    return AppSelect<String>(
      label: 'Staff member (optional)',
      hintText: d == null
          ? 'Choose a department first'
          : 'Anyone in the department',
      value: value ?? _anyone,
      enabled: enabled && d != null,
      options: <AppSelectOption<String>>[
        const AppSelectOption<String>(
          value: _anyone,
          label: 'Anyone in the department',
        ),
        for (final StaffRef s in staff)
          AppSelectOption<String>(value: s.id, label: s.line),
      ],
      onChanged: (String id) => onChanged(id == _anyone ? null : id),
    );
  }
}
