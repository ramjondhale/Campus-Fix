import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../shared/coming_soon_screen.dart' show popOrHome;

/// How much of a complaint a details page may show.
enum ComplaintDetailsMode {
  /// M-10: the reporter's own complaint with its full tracking history:
  /// progress, resolution note, assigned department and the public timeline
  /// (role + time + note, never who).
  owner,

  /// M-11b: a board item, limited to the board's R6 field set (privacy-spec
  /// section 4): ID, category, location, description, priority, status,
  /// date/time and the photos. No tracking history.
  board,
}

/// A page showing one complaint (M-10 / M-11b) in every data state: loading
/// skeleton, error + Retry, not found (E-404) and the [ComplaintDetailsView].
///
/// [value] is the lookup result: `null` once loaded means "no such
/// complaint". [notFound] replaces the default E-404 (the owner page uses it
/// to forward a non-owner to the board item). [bodyBuilder] replaces the
/// default [ComplaintDetailsView] body (the maintenance Work Detail wraps it
/// with its actions).
class ComplaintDetailsPage extends StatelessWidget {
  const ComplaintDetailsPage({
    super.key,
    required this.title,
    required this.value,
    required this.mode,
    required this.onRetry,
    this.notFound,
    this.bodyBuilder,
  });

  final String title;
  final AsyncValue<PublicComplaintView?> value;
  final ComplaintDetailsMode mode;
  final VoidCallback onRetry;
  final Widget? notFound;
  final Widget Function(BuildContext context, PublicComplaintView complaint)?
  bodyBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar.page(title: title, onBack: () => popOrHome(context)),
      body: value.when(
        loading: () => const ComplaintDetailsSkeleton(),
        error: (_, _) => EmptyState.error(
          title: "Couldn't load this complaint",
          onAction: onRetry,
        ),
        data: (PublicComplaintView? c) {
          if (c == null) {
            return notFound ??
                EmptyState.notFound(onAction: () => context.go(AppRoutes.home));
          }
          return bodyBuilder?.call(context, c) ??
              ComplaintDetailsView(complaint: c, mode: mode);
        },
      ),
    );
  }
}

/// The loading placeholder of a details page.
class ComplaintDetailsSkeleton extends StatelessWidget {
  const ComplaintDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.s4),
        children: const <Widget>[
          SkeletonBlock.fraction(widthFactor: 0.5, height: 24),
          SizedBox(height: AppSpace.s3),
          SkeletonBlock.fraction(widthFactor: 0.8, height: 20),
          SizedBox(height: AppSpace.s5),
          SkeletonBlock(height: 72, radius: AppRadius.br4),
          SizedBox(height: AppSpace.s5),
          SkeletonBlock(height: 96, radius: AppRadius.br4),
          SizedBox(height: AppSpace.s5),
          SkeletonBlock(height: 160, radius: AppRadius.br4),
        ],
      ),
    );
  }
}

/// The body of M-10 / M-11b for one [PublicComplaintView]. It takes the
/// public view only: no reporter, assignee or actor identity exists on it.
class ComplaintDetailsView extends StatelessWidget {
  const ComplaintDetailsView({
    super.key,
    required this.complaint,
    this.mode = ComplaintDetailsMode.owner,
    this.now,
    this.leading = const <Widget>[],
    this.trailing = const <Widget>[],
  });

  final PublicComplaintView complaint;
  final ComplaintDetailsMode mode;

  /// Extra blocks right under the header (e.g. a rework notice), each spaced
  /// like a card.
  final List<Widget> leading;

  /// Extra blocks after the cards, before the dates (e.g. a note field).
  final List<Widget> trailing;

  /// Clock for relative times (tests).
  final DateTime? now;

  bool get _owner => mode == ComplaintDetailsMode.owner;

  @override
  Widget build(BuildContext context) {
    final PublicComplaintView c = complaint;
    final ThemeData theme = Theme.of(context);
    final bool resolvedOrLater =
        c.status.order >= ComplaintStatus.resolved.order;
    final String? resolutionNote = c.resolutionNote;
    final Department? department = c.assignedDepartment;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: <Widget>[
        _Header(complaint: c),
        for (final Widget w in leading) ...<Widget>[
          const SizedBox(height: AppSpace.s4),
          w,
        ],
        if (c.status == ComplaintStatus.closed) ...<Widget>[
          const SizedBox(height: AppSpace.s4),
          const InlineBanner(
            kind: FeedbackKind.info,
            message: 'This complaint is closed.',
          ),
        ],
        if (_owner) ...<Widget>[
          const SizedBox(height: AppSpace.s4),
          _Card(
            title: 'Progress',
            child: StatusStepper(
              status: c.status,
              hasRework: timelineHasRework(c.timeline),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s4),
        _Card(
          title: 'Location',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  ComplaintCard.locationOf(c),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        _Card(
          title: 'Description',
          child: Text(c.description, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(height: AppSpace.s4),
        _Photos(complaint: c, showComparison: _owner),
        if (_owner && resolvedOrLater && resolutionNote != null) ...<Widget>[
          const SizedBox(height: AppSpace.s4),
          _Card(
            title: 'Resolution note',
            child: Text(resolutionNote, style: theme.textTheme.bodyMedium),
          ),
        ],
        if (_owner && department != null) ...<Widget>[
          const SizedBox(height: AppSpace.s4),
          _Card(
            title: 'Assigned department',
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.groups_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpace.s2),
                Text(department.label, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
        if (_owner && c.timeline.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.s4),
          _Card(
            title: 'Timeline',
            child: ComplaintTimeline(events: c.timeline, now: now),
          ),
        ],
        for (final Widget w in trailing) ...<Widget>[
          const SizedBox(height: AppSpace.s4),
          w,
        ],
        const SizedBox(height: AppSpace.s4),
        _Dates(complaint: c),
        const SizedBox(height: AppSpace.s6),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.complaint});

  final PublicComplaintView complaint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ComplaintIdText(id: complaint.id, size: ComplaintIdSize.md),
        const SizedBox(height: AppSpace.s2),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            StatusBadge(status: complaint.status),
            PriorityTag(priority: complaint.effectivePriority),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        Row(
          children: <Widget>[
            CategoryChip(category: complaint.category),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  complaint.category.label,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A titled card section.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.campusColors.card,
        borderRadius: AppRadius.br5,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: AppSpace.s3),
            child,
          ],
        ),
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.complaint, required this.showComparison});

  final PublicComplaintView complaint;

  /// Whether the before/after comparator shows (owner page only).
  final bool showComparison;

  @override
  Widget build(BuildContext context) {
    final PublicComplaintView c = complaint;
    final bool hasAfter = c.afterPhotos.isNotEmpty;
    final bool compare =
        showComparison && hasAfter && c.beforePhotos.isNotEmpty;
    if (c.beforePhotos.isEmpty && !hasAfter) return const SizedBox.shrink();
    return _Card(
      title: 'Photos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (compare) ...<Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: BeforeAfter.maxWidth,
                ),
                child: BeforeAfter(
                  category: c.category,
                  before: c.beforePhotos.first,
                  after: c.afterPhotos,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s4),
          ],
          if (c.beforePhotos.isNotEmpty)
            _Gallery(
              label: 'Before',
              category: c.category,
              photos: c.beforePhotos,
            ),
          if (hasAfter) ...<Widget>[
            if (c.beforePhotos.isNotEmpty) const SizedBox(height: AppSpace.s4),
            _Gallery(
              label: 'After repair',
              category: c.category,
              photos: c.afterPhotos,
            ),
          ],
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.label,
    required this.category,
    required this.photos,
  });

  final String label;
  final ProblemCategory category;
  final List<Attachment> photos;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: <Widget>[
            for (int i = 0; i < photos.length; i++)
              PhotoThumbnail(
                category: category,
                attachment: photos[i],
                size: PhotoThumbnailSize.s100,
                semanticLabel:
                    '$label photo ${i + 1} of ${photos.length}. '
                    'Open full screen',
                onTap: () => showComplaintPhotoViewer(
                  context,
                  category: category,
                  attachment: photos[i],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Dates extends StatelessWidget {
  const _Dates({required this.complaint});

  final PublicComplaintView complaint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle style = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Created ${formatAbsoluteTime(complaint.createdAt)}',
          style: style,
        ),
        const SizedBox(height: AppSpace.s1),
        Text(
          'Last updated ${formatAbsoluteTime(complaint.updatedAt)}',
          style: style,
        ),
      ],
    );
  }
}

/// Opens [attachment] full screen with pinch-to-zoom.
Future<void> showComplaintPhotoViewer(
  BuildContext context, {
  required ProblemCategory category,
  required Attachment attachment,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => Dialog.fullscreen(
      backgroundColor: dialogContext.campusColors.photoOverlayBackground,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Semantics(
                    label: 'Photo of a ${category.label} problem',
                    child: ComplaintPhoto(
                      category: category,
                      attachment: attachment,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                color: dialogContext.campusColors.photoOverlayForeground,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
