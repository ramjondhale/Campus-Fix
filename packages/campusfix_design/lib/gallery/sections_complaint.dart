import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../theme/tokens/spacing_tokens.dart';
import '../widgets/before_after.dart';
import '../widgets/complaint_card.dart';
import '../widgets/complaint_photo.dart';
import '../widgets/complaint_table.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';
import '../widgets/photo_uploader.dart';
import 'gallery_fixtures.dart';
import 'gallery_parts.dart';

/// 8.10: ComplaintCard in every variant and state.
class ComplaintCardSection extends StatefulWidget {
  /// Creates the section.
  const ComplaintCardSection({super.key});

  @override
  State<ComplaintCardSection> createState() => _ComplaintCardSectionState();
}

class _ComplaintCardSectionState extends State<ComplaintCardSection> {
  bool _selected = true;

  @override
  Widget build(BuildContext context) {
    final DateTime now = GalleryFixtures.now;
    return GallerySection(
      id: '8.10',
      title: 'ComplaintCard',
      description:
          'Built from a PublicComplaintView only: there is no parameter for '
          'a reporter, assignee, actor or "mine" marker. Hover, press and '
          'tab to see the states.',
      children: <Widget>[
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'board: CF-2026-00042, Electrical, Critical, In Progress',
              width: GalleryPhone.width,
              child: ComplaintCard(
                complaint: GalleryFixtures.electricalCritical,
                variant: ComplaintCardVariant.board,
                now: now,
                onTap: () {},
              ),
            ),
            GalleryLabel(
              'mine ("Updated 3 h ago" style)',
              width: GalleryPhone.width,
              child: ComplaintCard(
                complaint: GalleryFixtures.plumbingHigh,
                variant: ComplaintCardVariant.mine,
                now: now,
                onTap: () {},
              ),
            ),
            GalleryLabel(
              'work ("Waiting 5 h")',
              width: GalleryPhone.width,
              child: ComplaintCard(
                complaint: GalleryFixtures.electricalCritical,
                variant: ComplaintCardVariant.work,
                now: now,
                onTap: () {},
              ),
            ),
            GalleryLabel(
              'verify (Before and After, "Resolved 3 h ago")',
              width: GalleryPhone.width,
              child: ComplaintCard(
                complaint: GalleryFixtures.itResolved,
                variant: ComplaintCardVariant.verify,
                now: now,
                onTap: () {},
              ),
            ),
            GalleryLabel(
              'selected (tap to toggle)',
              width: GalleryPhone.width,
              child: ComplaintCard(
                complaint: GalleryFixtures.cleanlinessMedium,
                variant: ComplaintCardVariant.board,
                selected: _selected,
                now: now,
                onTap: () => setState(() => _selected = !_selected),
              ),
            ),
            GalleryLabel(
              'static (no onTap)',
              width: GalleryPhone.width,
              child: ComplaintCard(
                complaint: GalleryFixtures.furnitureClosed,
                variant: ComplaintCardVariant.board,
                now: now,
              ),
            ),
            GalleryLabel(
              'board, critical safety, Reviewed',
              width: GalleryPhone.width,
              child: ComplaintCard(
                complaint: GalleryFixtures.safetyCritical,
                now: now,
                onTap: () {},
              ),
            ),
            GalleryLabel(
              'skeleton: board, mine, verify, row',
              width: GalleryPhone.width,
              child: const Column(
                children: <Widget>[
                  ComplaintCardSkeleton(),
                  SizedBox(height: AppSpace.s3),
                  ComplaintCardSkeleton(variant: ComplaintCardVariant.mine),
                  SizedBox(height: AppSpace.s3),
                  ComplaintCardSkeleton(variant: ComplaintCardVariant.verify),
                  SizedBox(height: AppSpace.s3),
                  ComplaintCardSkeleton(variant: ComplaintCardVariant.row),
                ],
              ),
            ),
          ],
        ),
        GalleryLabel(
          'row (admin lists, A-02)',
          child: GalleryPanel(
            padding: false,
            child: Column(
              children: <Widget>[
                for (final PublicComplaintView c
                    in GalleryFixtures.complaints.take(5))
                  ComplaintCard(
                    complaint: c,
                    variant: ComplaintCardVariant.row,
                    now: now,
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 8.11: the admin complaint table.
class ComplaintTableSection extends StatefulWidget {
  /// Creates the section.
  const ComplaintTableSection({super.key});

  @override
  State<ComplaintTableSection> createState() => _ComplaintTableSectionState();
}

class _ComplaintTableSectionState extends State<ComplaintTableSection> {
  ComplaintTableColumn _sort = ComplaintTableColumn.priority;
  bool _ascending = true;
  String? _selectedId = 'CF-2026-00019';
  int _rows = 25;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final List<PublicComplaintView> sorted = <PublicComplaintView>[
      ...GalleryFixtures.complaints,
    ];
    int compare(PublicComplaintView a, PublicComplaintView b) =>
        switch (_sort) {
          ComplaintTableColumn.id => a.id.compareTo(b.id),
          ComplaintTableColumn.category => a.category.label.compareTo(
            b.category.label,
          ),
          ComplaintTableColumn.location => a.building.compareTo(b.building),
          ComplaintTableColumn.priority => a.effectivePriority.rank.compareTo(
            b.effectivePriority.rank,
          ),
          ComplaintTableColumn.status => a.status.order.compareTo(
            b.status.order,
          ),
          ComplaintTableColumn.department =>
            (a.assignedDepartment?.label ?? '~').compareTo(
              b.assignedDepartment?.label ?? '~',
            ),
          ComplaintTableColumn.waiting => a.createdAt.compareTo(b.createdAt),
          ComplaintTableColumn.updated => a.updatedAt.compareTo(b.updatedAt),
        };
    sorted.sort((PublicComplaintView a, PublicComplaintView b) {
      final int c = compare(a, b);
      return _ascending ? c : -c;
    });
    return GallerySection(
      id: '8.11',
      title: 'ComplaintTable',
      description:
          'Public fields only. There is no reporter column and no '
          'reporter-based search, sort or filter. Click a header to sort and '
          'a row to select it.',
      children: <Widget>[
        ComplaintTable(
          complaints: sorted,
          now: GalleryFixtures.now,
          sortColumn: _sort,
          sortAscending: _ascending,
          selectedId: _selectedId,
          page: _page,
          rowsPerPage: _rows,
          totalCount: 128,
          onSort: (ComplaintTableColumn c) => setState(() {
            if (c == _sort) {
              _ascending = !_ascending;
            } else {
              _sort = c;
              _ascending = true;
            }
          }),
          onRowTap: (PublicComplaintView c) =>
              setState(() => _selectedId = c.id),
          onPageChanged: (int p) => setState(() => _page = p),
          onRowsPerPageChanged: (int r) => setState(() {
            _rows = r;
            _page = 0;
          }),
        ),
        const SizedBox(height: 24),
        const GalleryLabel(
          'Loading (skeleton rows)',
          child: ComplaintTable(
            complaints: <PublicComplaintView>[],
            loading: true,
          ),
        ),
        const SizedBox(height: 24),
        GalleryLabel(
          'Empty (EmptyState, left aligned)',
          child: ComplaintTable(
            complaints: const <PublicComplaintView>[],
            onClearFilters: () {},
          ),
        ),
      ],
    );
  }
}

/// 8.12 and 8.13: photos, the uploader and the before / after comparator.
class PhotosSection extends StatefulWidget {
  /// Creates the section.
  const PhotosSection({super.key});

  @override
  State<PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends State<PhotosSection> {
  late List<PhotoUploadItem> _items = _seed(3);
  String? _selectedId;

  List<PhotoUploadItem> _seed(int n) => <PhotoUploadItem>[
    for (int i = 0; i < n; i++)
      PhotoUploadItem(
        attachment: Attachment(
          id: 'demo-$i',
          kind: AttachmentKind.beforePhoto,
          ref: 'assets/seed/electrical_0${i + 1}_before.jpg',
          createdAt: GalleryFixtures.now,
        ),
        status: i == 1
            ? PhotoUploadStatus.uploading
            : (i == 2 ? PhotoUploadStatus.failed : PhotoUploadStatus.ready),
        progress: 0.6,
        caption: i == 0 ? 'Flickering light' : null,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final PublicComplaintView c = GalleryFixtures.itResolved;
    final PublicComplaintView old = GalleryFixtures.plumbingHigh;
    return GallerySection(
      id: '8.12-8.13',
      title: 'PhotoThumbnail, PhotoUploader, BeforeAfter',
      description:
          'No image files ship: every photo is a drawn placeholder tinted by '
          'category, with a Before / After label from Attachment.kind and a '
          'pattern derived from the attachment ref.',
      children: <Widget>[
        GalleryLabel(
          'PhotoThumbnail sizes 56, 72, 80, 100 and 4:3 (Before and After)',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: <Widget>[
              for (final PhotoThumbnailSize size
                  in PhotoThumbnailSize.values.where(
                    (PhotoThumbnailSize s) => s.edge != null,
                  ))
                PhotoThumbnail(
                  category: c.category,
                  attachment: c.beforePhotos.first,
                  size: size,
                ),
              PhotoThumbnail(
                category: c.category,
                attachment: c.afterPhotos.first,
                size: PhotoThumbnailSize.s100,
              ),
              SizedBox(
                width: 160,
                child: PhotoThumbnail(
                  category: old.category,
                  attachment: old.beforePhotos.first,
                  size: PhotoThumbnailSize.ratio43,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GalleryLabel(
          'ComplaintPhoto placeholders: one per category',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ProblemCategory category in ProblemCategory.values)
                PhotoThumbnail(
                  category: category,
                  attachment: Attachment(
                    id: 'g-${category.name}',
                    kind: AttachmentKind.beforePhoto,
                    ref: 'assets/seed/${category.name}_01_before.jpg',
                    createdAt: GalleryFixtures.now,
                  ),
                  size: PhotoThumbnailSize.s80,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'PhotoUploader: ready, uploading, failed (tap a tile for its '
              'caption)',
              width: GalleryPhone.width,
              child: PhotoUploader(
                items: _items,
                category: ProblemCategory.electrical,
                selectedId: _selectedId,
                onAdd: () => setState(() {
                  _items = <PhotoUploadItem>[
                    ..._items,
                    PhotoUploadItem(
                      attachment: Attachment(
                        id: 'demo-${_items.length}-${DateTime.now().microsecond}',
                        kind: AttachmentKind.beforePhoto,
                        ref: 'assets/seed/electrical_new_${_items.length}.jpg',
                        createdAt: GalleryFixtures.now,
                      ),
                    ),
                  ];
                }),
                onRemove: (PhotoUploadItem item) => setState(
                  () => _items = <PhotoUploadItem>[
                    for (final PhotoUploadItem i in _items)
                      if (i != item) i,
                  ],
                ),
                onRetry: (PhotoUploadItem item) => setState(
                  () => _items = <PhotoUploadItem>[
                    for (final PhotoUploadItem i in _items)
                      if (i == item)
                        PhotoUploadItem(
                          attachment: i.attachment,
                          caption: i.caption,
                        )
                      else
                        i,
                  ],
                ),
                onSelect: (PhotoUploadItem item) =>
                    setState(() => _selectedId = item.attachment.id),
                onCaptionChanged: (String id, String caption) {},
              ),
            ),
            GalleryLabel(
              'PhotoUploader: empty',
              width: GalleryPhone.width,
              child: PhotoUploader(
                items: const <PhotoUploadItem>[],
                category: ProblemCategory.plumbing,
                onAdd: () {},
              ),
            ),
            GalleryLabel(
              'PhotoUploader: maximum reached',
              width: GalleryPhone.width,
              child: PhotoUploader(
                items: <PhotoUploadItem>[
                  for (int i = 0; i < 5; i++)
                    PhotoUploadItem(
                      attachment: Attachment(
                        id: 'max-$i',
                        kind: AttachmentKind.afterPhoto,
                        ref: 'assets/seed/it_0${i + 1}_after.jpg',
                        createdAt: GalleryFixtures.now,
                      ),
                    ),
                ],
                category: ProblemCategory.it,
                onAdd: null,
                onRemove: (PhotoUploadItem _) {},
              ),
            ),
          ],
        ),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'BeforeAfter slider (drag, or focus and use arrow keys; '
              'two After photos)',
              width: 440,
              child: BeforeAfter(
                category: c.category,
                before: c.beforePhotos.first,
                after: c.afterPhotos,
              ),
            ),
            GalleryLabel(
              'BeforeAfter split (no-drag alternative)',
              width: 440,
              child: BeforeAfter(
                category: c.category,
                before: c.beforePhotos.first,
                after: c.afterPhotos,
                variant: BeforeAfterVariant.split,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 8.15: MetricCard and the bar rows of the dashboard charts.
class MetricsSection extends StatelessWidget {
  /// Creates the section.
  const MetricsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      id: '8.15',
      title: 'MetricCard',
      description:
          'Auto-fit grid, min 190, gap 12. Clickable cards open the '
          'complaint list with a preset filter.',
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final int columns = (c.maxWidth / (190 + 12)).floor().clamp(1, 4);
            final double width = (c.maxWidth - 12 * (columns - 1)) / columns;
            Widget cell(Widget child) =>
                SizedBox(width: width.floorToDouble(), child: child);
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                cell(
                  MetricCard(
                    label: 'Total',
                    value: '128',
                    definition: 'All complaints',
                    onTap: () {},
                  ),
                ),
                cell(
                  MetricCard(
                    label: 'Pending',
                    value: '23',
                    definition: 'Reported or reviewed',
                    onTap: () {},
                  ),
                ),
                cell(
                  MetricCard(
                    label: 'Critical / High',
                    value: '9',
                    definition: 'Unresolved',
                    attention: true,
                    onTap: () {},
                  ),
                ),
                cell(
                  const MetricCard(
                    label: 'In progress',
                    value: '31',
                    definition: 'Being worked on',
                  ),
                ),
                cell(
                  const MetricCard(label: 'Loading', value: '', loading: true),
                ),
                cell(
                  MetricCard(
                    label: 'Awaiting verification',
                    value: '',
                    hasError: true,
                    onRetry: () {},
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        GalleryLabel(
          'Chart rows: status, priority and category use their own sets',
          width: 520,
          child: Builder(
            builder: (BuildContext context) => GalleryPanel(
              child: Column(
                children: <Widget>[
                  MetricBarRow.status(
                    context: context,
                    status: ComplaintStatus.reported,
                    value: 12,
                    maxValue: 40,
                  ),
                  MetricBarRow.status(
                    context: context,
                    status: ComplaintStatus.inProgress,
                    value: 31,
                    maxValue: 40,
                  ),
                  MetricBarRow.status(
                    context: context,
                    status: ComplaintStatus.closed,
                    value: 40,
                    maxValue: 40,
                  ),
                  const SizedBox(height: 12),
                  MetricBarRow.priority(
                    context: context,
                    priority: Priority.critical,
                    value: 3,
                    maxValue: 20,
                  ),
                  MetricBarRow.priority(
                    context: context,
                    priority: Priority.low,
                    value: 18,
                    maxValue: 20,
                  ),
                  const SizedBox(height: 12),
                  MetricBarRow.category(
                    context: context,
                    category: ProblemCategory.electrical,
                    value: 22,
                    maxValue: 30,
                  ),
                  MetricBarRow.category(
                    context: context,
                    category: ProblemCategory.it,
                    value: 9,
                    maxValue: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GalleryLabel(
          'EmptyState variants',
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: <Widget>[
              _EmptyDemo(
                child: EmptyState.nothing(
                  actionLabel: 'Report a problem',
                  onAction: () {},
                ),
              ),
              _EmptyDemo(child: EmptyState.filtered(onAction: () {})),
              _EmptyDemo(child: EmptyState.error(onAction: () {})),
              _EmptyDemo(child: EmptyState.notFound(onAction: () {})),
              _EmptyDemo(child: EmptyState.forbidden(onAction: () {})),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyDemo extends StatelessWidget {
  const _EmptyDemo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 360, child: GalleryPanel(padding: false, child: child));
}
