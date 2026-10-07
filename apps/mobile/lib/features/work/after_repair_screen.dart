import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import '../complaint_details/complaint_details_view.dart'
    show ComplaintDetailsSkeleton, showComplaintPhotoViewer;
import '../shared/coming_soon_screen.dart' show popOrHome;
import '../shared/sample_photo_picker.dart';
import 'work_widgets.dart';

/// How far the photo tiles' progress bars show while the proof is being sent.
/// The prototype's mock write has no real upload, so this is a fixed mid-way
/// mark that only says "sending".
const double _kSendingProgress = 0.5;

/// M-15 After-Repair Upload (resolve): the repair proof of a job the worker
/// claimed: one to five after-repair photos (optional caption each) and a
/// required resolution note. [complaintId] comes from the route
/// (`/work/:id/resolve`).
///
/// **Mark resolved** is enabled only with at least one photo and a non-empty
/// note (AC-37). It asks for confirmation, then sends T4; on success the
/// worker goes back to the work list (the job has left the queue), on failure
/// the photos and note are kept and a Retry is offered (screens-spec G-4).
/// Consumes `workJobProvider` (public views) only; the form is
/// `afterRepairDraftProvider`.
class AfterRepairScreen extends ConsumerStatefulWidget {
  const AfterRepairScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  ConsumerState<AfterRepairScreen> createState() => _AfterRepairScreenState();
}

class _AfterRepairScreenState extends ConsumerState<AfterRepairScreen> {
  late final TextEditingController _note;
  final FocusNode _noteFocus = FocusNode();
  bool _noteTouched = false;
  String? _selectedId;

  /// The proof was accepted and the screen is on its way out: keep showing
  /// the form instead of flashing "not in progress" as the status changes.
  bool _sent = false;

  AfterRepairDraftNotifier get _draft =>
      ref.read(afterRepairDraftProvider(widget.complaintId).notifier);

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(
      text: ref.read(afterRepairDraftProvider(widget.complaintId)).note,
    );
    // Inline validation on blur (screens-spec G-7).
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) setState(() => _noteTouched = true);
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (!await pickSamplePhoto(context)) return;
    _draft.addPhoto();
  }

  /// Leaves the screen; with anything entered, asks "Discard?" first.
  Future<void> _leave() async {
    if (ref.read(workActionProvider).busy) return;
    final AfterRepairDraft draft = ref.read(
      afterRepairDraftProvider(widget.complaintId),
    );
    if (draft.hasInput) {
      final bool? discard = await AppDialog.confirm(
        context: context,
        title: 'Discard changes?',
        message: 'The photos and note you added will be lost.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (discard != true || !mounted) return;
      _draft.reset();
    }
    // The draft is empty now, so the back gesture is no longer intercepted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) popOrHome(context);
    });
  }

  Future<void> _confirmAndSend() async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: 'Mark ${widget.complaintId} as resolved?',
      message: 'A verifier will review.',
      confirmLabel: 'Mark resolved',
    );
    if (confirmed != true || !mounted) return;
    await _send();
  }

  Future<void> _send() async {
    final AfterRepairDraft draft = ref.read(
      afterRepairDraftProvider(widget.complaintId),
    );
    if (!draft.canSubmit) return;
    final WorkActionResult? result = await ref
        .read(workActionProvider.notifier)
        .resolve(
          widget.complaintId,
          resolutionNote: draft.trimmedNote,
          afterPhotos: draft.photos,
        );
    if (result == null || !mounted || !result.ok) return;
    setState(() => _sent = true);
    AppToast.show(context, 'Sent for verification', kind: AppToastKind.success);
    context.go(AppRoutes.work);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WorkJob?> job = ref.watch(
      workJobProvider(widget.complaintId),
    );
    final AfterRepairDraft draft = ref.watch(
      afterRepairDraftProvider(widget.complaintId),
    );
    final bool busy = ref.watch(workActionProvider).busy;

    return PopScope(
      canPop: !draft.hasInput && !busy,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppTopBar.page(
          title: 'After-repair photos',
          onBack: busy ? null : _leave,
        ),
        body: job.when(
          loading: () => const ComplaintDetailsSkeleton(),
          error: (_, _) => EmptyState.error(
            title: "Couldn't load this job",
            onAction: () => refreshComplaints(ref),
          ),
          data: (WorkJob? j) {
            if (j == null) {
              return EmptyState.notFound(
                onAction: () => context.go(AppRoutes.home),
              );
            }
            if (!j.canResolve && !_sent) return _NotResolvable(job: j);
            return _buildForm(j, draft);
          },
        ),
      ),
    );
  }

  Widget _buildForm(WorkJob job, AfterRepairDraft draft) {
    final PublicComplaintView c = job.complaint;
    final ThemeData theme = Theme.of(context);
    final WorkActionState action = ref.watch(workActionProvider);
    final bool sending = action.runningFor(
      widget.complaintId,
      WorkActionKind.resolve,
    );
    final bool busy = action.busy;
    final String? noteError = _noteTouched && !draft.noteValid
        ? 'Add a resolution note'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: <Widget>[
              ComplaintCard(complaint: c, variant: ComplaintCardVariant.work),
              if (job.rework) ...<Widget>[
                const SizedBox(height: AppSpace.s4),
                InlineBanner(
                  kind: FeedbackKind.warning,
                  title: 'Rework needed',
                  message:
                      job.reworkNote ??
                      'A verifier sent this job back for more work.',
                ),
              ],
              if (c.beforePhotos.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpace.s6),
                const WorkSectionTitle('Before repair'),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: <Widget>[
                    for (int i = 0; i < c.beforePhotos.length; i++)
                      PhotoThumbnail(
                        category: c.category,
                        attachment: c.beforePhotos[i],
                        size: PhotoThumbnailSize.s72,
                        semanticLabel:
                            'Before photo ${i + 1} of '
                            '${c.beforePhotos.length}. Open full screen',
                        onTap: () => showComplaintPhotoViewer(
                          context,
                          category: c.category,
                          attachment: c.beforePhotos[i],
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.s6),
              const WorkSectionTitle('After photos'),
              Text(
                'Show the finished repair. Add 1 to '
                '${ResolveLimits.maxPhotos} photos.',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              PhotoUploader(
                category: c.category,
                maxPhotos: ResolveLimits.maxPhotos,
                items: <PhotoUploadItem>[
                  for (final Attachment a in draft.photos)
                    PhotoUploadItem(
                      attachment: a,
                      caption: a.caption,
                      status: sending
                          ? PhotoUploadStatus.uploading
                          : PhotoUploadStatus.ready,
                      progress: _kSendingProgress,
                    ),
                ],
                onAdd: busy ? null : _addPhoto,
                onRemove: busy
                    ? null
                    : (PhotoUploadItem item) =>
                          _draft.removePhoto(item.attachment.id),
                onSelect: (PhotoUploadItem item) =>
                    setState(() => _selectedId = item.attachment.id),
                selectedId: draft.photos.any((a) => a.id == _selectedId)
                    ? _selectedId
                    : null,
                onCaptionChanged: busy ? null : _draft.setCaption,
              ),
              if (!draft.photosValid) ...<Widget>[
                const SizedBox(height: AppSpace.s3),
                Text(
                  'Add after-repair photo: at least '
                  '${ResolveLimits.minPhotos} is required.',
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s6),
              AppTextField.multiline(
                label: 'Resolution note',
                required: true,
                hintText: 'What was fixed, and how?',
                helperText: kNoteVisibilityHelper,
                controller: _note,
                focusNode: _noteFocus,
                maxLength: ResolveLimits.noteMax,
                enabled: !busy,
                errorText: noteError,
                onChanged: _draft.setNote,
              ),
            ],
          ),
        ),
        WorkActionBar(
          children: <Widget>[
            if (action.failedFor(widget.complaintId, WorkActionKind.resolve))
              WorkFailureBanner(
                state: action,
                title: "Couldn't mark as resolved",
                onRetry: draft.canSubmit && !busy ? _send : null,
              ),
            Row(
              children: <Widget>[
                AppButton(
                  label: 'Cancel',
                  size: AppButtonSize.lg,
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : _leave,
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: AppButton(
                    label: 'Mark resolved',
                    size: AppButtonSize.lg,
                    expand: true,
                    loading: sending,
                    onPressed: draft.canSubmit && !busy
                        ? _confirmAndSend
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The job cannot be resolved by this worker: it is not in progress, or a
/// colleague has it.
class _NotResolvable extends StatelessWidget {
  const _NotResolvable({required this.job});

  final WorkJob job;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.info_outline,
      title: job.claimedByColleague
          ? 'Already claimed by a colleague'
          : "This job isn't in progress",
      message: 'Only work you have started can be marked as resolved.',
      actionLabel: 'Back to my work',
      onAction: () => context.go(AppRoutes.work),
    );
  }
}
