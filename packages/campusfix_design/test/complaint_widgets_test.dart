import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_design/gallery/gallery_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// Strings that would identify a person. The fixtures contain none of them;
/// the cards and tables must not invent any either.
const List<String> _piiMarkers = <String>[
  'reporter',
  'Reporter',
  '@',
  'phone',
  'Phone',
  'email',
  'Email',
  'ID number',
];

void main() {
  final DateTime now = GalleryFixtures.now;
  final PublicComplaintView lead = GalleryFixtures.electricalCritical;

  for (final Brightness brightness in kBrightnesses) {
    group('ComplaintCard ($brightness)', () {
      testWidgets('CF-2026-00042 board card shows public fields only', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          SizedBox(
            width: 360,
            child: ComplaintCard(complaint: lead, now: now, onTap: () {}),
          ),
          brightness: brightness,
          size: const Size(420, 900),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('CF-2026-00042'), findsOneWidget);
        expect(find.text('Electrical'), findsOneWidget);
        expect(find.text('Critical'), findsOneWidget);
        expect(find.text('In Progress'), findsOneWidget);
        expect(
          find.text('Academic Block A · 2 · Electronics Lab 204'),
          findsOneWidget,
        );
        expect(find.byType(StatusBadge), findsOneWidget);
        expect(find.byType(PriorityTag), findsOneWidget);
        expect(find.byType(PhotoThumbnail), findsOneWidget);
        // No avatar and no identity marker anywhere on the card.
        expect(find.byType(UserAvatar), findsNothing);
        expect(find.byType(RolePill), findsNothing);
        final String allText = tester
            .widgetList<Text>(find.byType(Text))
            .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
            .join(' | ');
        for (final String marker in _piiMarkers) {
          expect(allText.contains(marker), isFalse, reason: marker);
        }
      });

      testWidgets('shows effectivePriority and the semantics label', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          SizedBox(
            width: 360,
            child: ComplaintCard(complaint: lead, now: now, onTap: () {}),
          ),
          brightness: brightness,
        );
        expect(
          find.bySemanticsLabel(
            'CF-2026-00042, Electrical, Critical priority, In Progress',
          ),
          findsOneWidget,
        );
        handle.dispose();
      });

      testWidgets('all variants render without overflow', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          SizedBox(
            width: 360,
            child: Column(
              children: <Widget>[
                for (final ComplaintCardVariant v
                    in ComplaintCardVariant.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ComplaintCard(
                      complaint: GalleryFixtures.itResolved,
                      variant: v,
                      now: now,
                      onTap: () {},
                    ),
                  ),
                for (final ComplaintCardVariant v
                    in ComplaintCardVariant.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ComplaintCardSkeleton(variant: v),
                  ),
              ],
            ),
          ),
          brightness: brightness,
          size: const Size(420, 4000),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(ComplaintCard), findsNWidgets(5));
        // Variant specifics.
        expect(find.textContaining('Resolved '), findsWidgets);
        expect(find.textContaining('Updated '), findsWidgets);
        expect(
          find.textContaining('Waiting'),
          findsNothing,
          reason: 'a resolved complaint is not waiting',
        );
        // The verify card shows Before and After labels.
        expect(find.text('BEFORE'), findsOneWidget);
        expect(find.text('AFTER'), findsOneWidget);
      });

      testWidgets('work variant shows the waiting time', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          SizedBox(
            width: 360,
            child: ComplaintCard(
              complaint: lead,
              variant: ComplaintCardVariant.work,
              now: now,
            ),
          ),
          brightness: brightness,
        );
        expect(find.text('Waiting 5 h'), findsOneWidget);
      });

      testWidgets('board shows relative time under 24 h, absolute after', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          SizedBox(
            width: 360,
            child: Column(
              children: <Widget>[
                ComplaintCard(complaint: lead, now: now),
                ComplaintCard(
                  complaint: GalleryFixtures.plumbingHigh,
                  now: now,
                ),
              ],
            ),
          ),
          brightness: brightness,
          size: const Size(420, 1200),
        );
        expect(find.text('5 h ago'), findsOneWidget);
        expect(find.text('4 Oct 2026, 11:30'), findsOneWidget);
      });

      testWidgets('tap, selected and static states', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await pumpApp(
          tester,
          SizedBox(
            width: 360,
            child: Column(
              children: <Widget>[
                ComplaintCard(
                  complaint: lead,
                  now: now,
                  selected: true,
                  onTap: () => taps++,
                ),
                ComplaintCard(
                  complaint: GalleryFixtures.safetyCritical,
                  now: now,
                ),
              ],
            ),
          ),
          brightness: brightness,
          size: const Size(420, 1200),
        );
        await tester.tap(find.text('CF-2026-00042'));
        await tester.tap(find.text('CF-2026-00040'));
        expect(taps, 1);
        final BuildContext context = tester.element(
          find.byType(ComplaintCard).first,
        );
        final Container selected = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(ComplaintCard).first,
                matching: find.byType(Container),
              )
              .first,
        );
        final BoxDecoration d = selected.decoration! as BoxDecoration;
        expect(
          (d.border! as Border).top.color,
          Theme.of(context).colorScheme.primary,
        );
        expect((d.border! as Border).top.width, 2);
      });
    });

    group('ComplaintTable ($brightness)', () {
      testWidgets('public columns only, no reporter column', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          ComplaintTable(
            complaints: GalleryFixtures.complaints,
            now: now,
            totalCount: 128,
          ),
          brightness: brightness,
          size: const Size(1300, 1000),
        );
        expect(tester.takeException(), isNull);
        for (final String header in <String>[
          'ID',
          'CATEGORY',
          'LOCATION',
          'PRIORITY',
          'STATUS',
          'DEPARTMENT',
          'WAITING',
          'UPDATED',
        ]) {
          expect(find.text(header), findsOneWidget, reason: header);
        }
        expect(find.textContaining('REPORTER'), findsNothing);
        expect(find.textContaining('Reporter'), findsNothing);
        expect(find.byType(ComplaintIdText), findsNWidgets(8));
        expect(find.text('Unassigned'), findsWidgets);
        expect(find.text('1-8 of 128'), findsOneWidget);
        // Waiting is unresolved only: resolved and closed show "-".
        expect(find.text('-'), findsWidgets);
      });

      testWidgets('sorting and row taps call back', (
        WidgetTester tester,
      ) async {
        ComplaintTableColumn? sorted;
        PublicComplaintView? tapped;
        await pumpApp(
          tester,
          ComplaintTable(
            complaints: GalleryFixtures.complaints,
            now: now,
            sortColumn: ComplaintTableColumn.priority,
            onSort: (ComplaintTableColumn c) => sorted = c,
            onRowTap: (PublicComplaintView c) => tapped = c,
          ),
          brightness: brightness,
          size: const Size(1300, 1000),
        );
        expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
        await tester.tap(find.text('STATUS'));
        expect(sorted, ComplaintTableColumn.status);
        await tester.tap(find.text('CF-2026-00019'));
        expect(tapped?.id, 'CF-2026-00019');
      });

      testWidgets('loading shows skeleton rows; empty shows EmptyState', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const ComplaintTable(
            complaints: <PublicComplaintView>[],
            loading: true,
          ),
          brightness: brightness,
          size: const Size(1300, 1000),
        );
        expect(find.byType(Skeleton), findsNWidgets(5));
        await pumpApp(
          tester,
          const ComplaintTable(complaints: <PublicComplaintView>[]),
          brightness: brightness,
          size: const Size(1300, 1000),
        );
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('No matching complaints'), findsOneWidget);
      });

      testWidgets(
        'narrow containers scroll horizontally instead of overflowing',
        (WidgetTester tester) async {
          await pumpApp(
            tester,
            SizedBox(
              width: 600,
              child: ComplaintTable(
                complaints: GalleryFixtures.complaints,
                now: now,
              ),
            ),
            brightness: brightness,
            size: const Size(700, 1000),
          );
          expect(tester.takeException(), isNull);
        },
      );
    });

    group('photos ($brightness)', () {
      testWidgets('placeholder is deterministic per attachment ref', (
        WidgetTester tester,
      ) async {
        expect(
          ComplaintPhoto.variantFor('assets/seed/electrical_01_before.jpg'),
          ComplaintPhoto.variantFor('assets/seed/electrical_01_before.jpg'),
        );
        final Set<int> variants = <int>{
          for (int i = 0; i < 40; i++) ComplaintPhoto.variantFor('ref-$i'),
        };
        expect(variants.length, greaterThan(1));
      });

      testWidgets('kind label comes from Attachment.kind', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Wrap(
            spacing: 8,
            children: <Widget>[
              PhotoThumbnail(
                category: ProblemCategory.it,
                attachment: GalleryFixtures.itResolved.beforePhotos.first,
                size: PhotoThumbnailSize.s100,
              ),
              PhotoThumbnail(
                category: ProblemCategory.it,
                attachment: GalleryFixtures.itResolved.afterPhotos.first,
                size: PhotoThumbnailSize.s100,
              ),
              PhotoThumbnail(
                category: ProblemCategory.it,
                attachment: Attachment(
                  id: 'o',
                  kind: AttachmentKind.other,
                  ref: 'assets/seed/other.jpg',
                  createdAt: now,
                ),
                size: PhotoThumbnailSize.s100,
              ),
            ],
          ),
          brightness: brightness,
        );
        expect(find.text('BEFORE'), findsOneWidget);
        expect(find.text('AFTER'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('PhotoUploader: counter, add tile, maximum', (
        WidgetTester tester,
      ) async {
        int adds = 0;
        List<PhotoUploadItem> items(int n) => <PhotoUploadItem>[
          for (int i = 0; i < n; i++)
            PhotoUploadItem(
              attachment: Attachment(
                id: 'a$i',
                kind: AttachmentKind.beforePhoto,
                ref: 'assets/seed/x$i.jpg',
                createdAt: now,
              ),
            ),
        ];
        await pumpApp(
          tester,
          SizedBox(
            width: 328,
            child: PhotoUploader(
              items: items(0),
              category: ProblemCategory.plumbing,
              onAdd: () => adds++,
            ),
          ),
          brightness: brightness,
          size: const Size(400, 900),
        );
        expect(find.text('0 of 5'), findsOneWidget);
        expect(find.text('Add a photo'), findsOneWidget);
        await tester.tap(find.text('Add a photo'));
        expect(adds, 1);

        await pumpApp(
          tester,
          SizedBox(
            width: 328,
            child: PhotoUploader(
              items: items(2),
              category: ProblemCategory.plumbing,
              onAdd: () => adds++,
              onRemove: (PhotoUploadItem _) {},
            ),
          ),
          brightness: brightness,
          size: const Size(400, 900),
        );
        expect(find.text('2 of 5'), findsOneWidget);
        expect(find.text('Add photo'), findsOneWidget);
        expect(find.text(PhotoUploader.defaultHelper), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNWidgets(2));

        await pumpApp(
          tester,
          SizedBox(
            width: 328,
            child: PhotoUploader(
              items: items(5),
              category: ProblemCategory.plumbing,
              onAdd: () => adds++,
            ),
          ),
          brightness: brightness,
          size: const Size(400, 900),
        );
        expect(find.text('5 of 5'), findsOneWidget);
        expect(find.text('Add photo'), findsNothing);
        expect(find.text('Maximum 5 photos'), findsOneWidget);
      });

      testWidgets('PhotoUploader: uploading and failed tile states', (
        WidgetTester tester,
      ) async {
        int retries = 0;
        PhotoUploadItem item(String id, PhotoUploadStatus status) =>
            PhotoUploadItem(
              attachment: Attachment(
                id: id,
                kind: AttachmentKind.beforePhoto,
                ref: 'assets/seed/$id.jpg',
                createdAt: now,
              ),
              status: status,
              progress: 0.5,
            );
        await pumpApp(
          tester,
          SizedBox(
            width: 328,
            child: PhotoUploader(
              items: <PhotoUploadItem>[
                item('up', PhotoUploadStatus.uploading),
                item('bad', PhotoUploadStatus.failed),
              ],
              category: ProblemCategory.it,
              onAdd: () {},
              onRetry: (PhotoUploadItem _) => retries++,
            ),
          ),
          brightness: brightness,
          size: const Size(400, 900),
        );
        expect(find.byIcon(Icons.upload_outlined), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('Upload failed'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        expect(retries, 1);
      });

      testWidgets('BeforeAfter slider moves with the keyboard', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final PublicComplaintView c = GalleryFixtures.itResolved;
        await pumpApp(
          tester,
          SizedBox(
            width: 400,
            child: BeforeAfter(
              category: c.category,
              before: c.beforePhotos.first,
              after: <Attachment>[c.afterPhotos.first],
            ),
          ),
          brightness: brightness,
        );
        // Corner tags: one Before, one After (a single After photo has no
        // thumbnail strip).
        expect(find.text('BEFORE'), findsOneWidget);
        expect(find.text('AFTER'), findsOneWidget);
        int value() => int.parse(
          tester
              .getSemantics(
                find.bySemanticsLabel('Before and after comparison'),
              )
              .value,
        );
        expect(value(), 50);
        await tester.tap(find.byType(BeforeAfter));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(value(), greaterThan(50));
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(value(), 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pump();
        expect(value(), 98);
        handle.dispose();
      });

      testWidgets('BeforeAfter: drag, after strip and split variant', (
        WidgetTester tester,
      ) async {
        final PublicComplaintView c = GalleryFixtures.itResolved;
        await pumpApp(
          tester,
          SizedBox(
            width: 400,
            child: BeforeAfter(
              category: c.category,
              before: c.beforePhotos.first,
              after: c.afterPhotos,
            ),
          ),
          brightness: brightness,
        );
        // Two after photos: a strip of two thumbnails appears.
        expect(find.byType(PhotoThumbnail), findsNWidgets(2));
        await tester.drag(find.byType(BeforeAfter), const Offset(120, 0));
        await tester.pump();
        expect(tester.takeException(), isNull);

        await pumpApp(
          tester,
          SizedBox(
            width: 400,
            child: BeforeAfter(
              category: c.category,
              before: c.beforePhotos.first,
              after: c.afterPhotos,
              variant: BeforeAfterVariant.split,
            ),
          ),
          brightness: brightness,
        );
        expect(find.text('Added with the report'), findsOneWidget);
        expect(find.text('Added when resolved'), findsOneWidget);
      });
    });

    group('timeline and stepper ($brightness)', () {
      testWidgets('timeline shows roles, notes and a rework marker', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          SizedBox(
            width: 420,
            child: ComplaintTimeline(
              events: GalleryFixtures.civilRework.timeline,
              now: now,
            ),
          ),
          brightness: brightness,
          size: const Size(500, 1200),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(TimelineItem), findsNWidgets(6));
        expect(find.byType(RolePill), findsNWidgets(6));
        expect(find.text('Rework'), findsOneWidget);
        expect(
          find.text(
            'The crack is still visible above the frame. Please seal it fully.',
          ),
          findsOneWidget,
        );
        expect(find.text('Verifier'), findsOneWidget);
        // The public form never shows the admin-only actor line or tag.
        expect(find.text('ADMIN ONLY'), findsNothing);
      });

      testWidgets('admin form adds the actor line and the Admin only tag', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          TimelineItem(
            status: ComplaintStatus.assigned,
            actorRole: UserRole.admin,
            at: now,
            adminActorLine: 'actor-001 · Sample Admin',
            isLast: true,
            now: now,
          ),
          brightness: brightness,
        );
        expect(find.text('actor-001 · Sample Admin'), findsOneWidget);
        expect(find.text('ADMIN ONLY'), findsOneWidget);
      });

      test('timelineHasRework detects a T7 reject only', () {
        expect(timelineHasRework(GalleryFixtures.civilRework.timeline), isTrue);
        expect(timelineHasRework(lead.timeline), isFalse);
        expect(timelineHasRework(const <PublicStatusEvent>[]), isFalse);
      });

      testWidgets('compact stepper shows step n of 7 for each status', (
        WidgetTester tester,
      ) async {
        for (final ComplaintStatus s in ComplaintStatus.values) {
          await pumpApp(
            tester,
            SizedBox(width: 320, child: StatusStepper(status: s)),
            brightness: brightness,
          );
          expect(find.text(s.label), findsOneWidget);
          expect(find.text('Step ${s.order + 1} of 7'), findsOneWidget);
        }
      });

      testWidgets('rework marker row appears only with hasRework', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const SizedBox(
            width: 320,
            child: StatusStepper(status: ComplaintStatus.inProgress),
          ),
          brightness: brightness,
        );
        expect(find.text('Rework'), findsNothing);
        await pumpApp(
          tester,
          const SizedBox(
            width: 320,
            child: StatusStepper(
              status: ComplaintStatus.inProgress,
              hasRework: true,
            ),
          ),
          brightness: brightness,
        );
        expect(find.text('Rework'), findsOneWidget);
        expect(find.byIcon(Icons.undo), findsOneWidget);
      });

      testWidgets('full stepper captions all seven statuses', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          const SizedBox(
            width: 640,
            child: StatusStepper(
              status: ComplaintStatus.assigned,
              variant: StatusStepperVariant.full,
            ),
          ),
          brightness: brightness,
          size: const Size(700, 400),
        );
        for (final ComplaintStatus s in ComplaintStatus.values) {
          expect(find.text(s.label), findsOneWidget);
        }
      });
    });

    group('MetricCard ($brightness)', () {
      testWidgets('default, attention, clickable, loading and error', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        int retries = 0;
        await pumpApp(
          tester,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              SizedBox(
                width: 220,
                child: MetricCard(
                  label: 'Total',
                  value: '128',
                  definition: 'All complaints',
                  onTap: () => taps++,
                ),
              ),
              const SizedBox(
                width: 220,
                child: MetricCard(
                  label: 'Critical / High',
                  value: '9',
                  attention: true,
                ),
              ),
              const SizedBox(
                width: 220,
                child: MetricCard(label: 'Loading', value: '', loading: true),
              ),
              SizedBox(
                width: 220,
                child: MetricCard(
                  label: 'Resolved',
                  value: '',
                  hasError: true,
                  onRetry: () => retries++,
                ),
              ),
            ],
          ),
          brightness: brightness,
        );
        expect(find.text('128'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
        expect(find.byType(Skeleton), findsOneWidget);
        expect(find.text('Could not load.'), findsOneWidget);
        await tester.tap(find.text('Total'));
        await tester.tap(find.text('Retry'));
        expect(taps, 1);
        expect(retries, 1);
      });

      testWidgets('bar rows fill by value using the matching set accent', (
        WidgetTester tester,
      ) async {
        await pumpApp(
          tester,
          Builder(
            builder: (BuildContext context) => SizedBox(
              width: 360,
              child: Column(
                children: <Widget>[
                  MetricBarRow.status(
                    context: context,
                    status: ComplaintStatus.inProgress,
                    value: 10,
                    maxValue: 40,
                  ),
                  MetricBarRow.priority(
                    context: context,
                    priority: Priority.high,
                    value: 5,
                    maxValue: 10,
                  ),
                  MetricBarRow.category(
                    context: context,
                    category: ProblemCategory.it,
                    value: 0,
                    maxValue: 0,
                  ),
                ],
              ),
            ),
          ),
          brightness: brightness,
        );
        expect(find.text('In Progress'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
        expect(find.text('10'), findsOneWidget);
        final List<FractionallySizedBox> fills = tester
            .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .toList();
        expect(
          fills.map((FractionallySizedBox f) => f.widthFactor).toList(),
          <double?>[0.25, 0.5, 0],
        );
        // The fill is painted at the full track height (not collapsed to 0).
        final Finder fillBoxes = find.descendant(
          of: find.byType(FractionallySizedBox).first,
          matching: find.byType(DecoratedBox),
        );
        expect(tester.getSize(fillBoxes.first).height, 12);
      });
    });
  }
}
