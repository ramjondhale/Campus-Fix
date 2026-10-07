import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// A container with the demo reporter signed in.
Future<ProviderContainer> reporterContainer() async {
  final ProviderContainer container = testContainer();
  final SignInOutcome outcome = await container
      .read(sessionProvider.notifier)
      .signIn(
        demoAccount(UserRole.reporter).user.idNumber,
        demoAccount(UserRole.reporter).password,
      );
  expect(outcome, SignInOutcome.success);
  return container;
}

/// Waits for the first data value of an async provider that satisfies [test].
Future<T> settledWhere<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
  bool Function(T value) test,
) {
  final Completer<T> done = Completer<T>();
  final ProviderSubscription<AsyncValue<T>> sub = container
      .listen<AsyncValue<T>>(provider, (_, next) {
        if (next.hasValue && test(next.requireValue) && !done.isCompleted) {
          done.complete(next.requireValue);
        }
      }, fireImmediately: true);
  addTearDown(sub.close);
  return done.future.timeout(const Duration(seconds: 5));
}

/// Fills [container]'s draft with a valid report.
void fillDraft(
  ProviderContainer container, {
  ProblemCategory category = ProblemCategory.electrical,
}) {
  container.read(reportDraftProvider.notifier)
    ..setCategory(category)
    ..setBuilding('Academic Block A')
    ..setFloor('2')
    ..setRoom('Electronics Lab 204')
    ..addPhoto()
    ..setDescription('The ceiling light flickers and buzzes all day.');
}

void main() {
  group('report draft state', () {
    test('AC-16 defaults are moderate / individual / safety off', () {
      final ProviderContainer c = testContainer();
      final ReportDraft d = c.read(reportDraftProvider);
      expect(d.severity, Severity.moderate);
      expect(d.peopleAffected, PeopleAffected.individual);
      expect(d.safetyFlag, isFalse);
      expect(d.category, isNull);
      expect(d.hasInput, isFalse);
      expect(d.isComplete, isFalse);
    });

    test('AC-17 the safety category forces the flag on and locks it', () {
      final ProviderContainer c = testContainer();
      final ReportDraftNotifier n = c.read(reportDraftProvider.notifier)
        ..setCategory(ProblemCategory.safety);
      expect(c.read(reportDraftProvider).safetyFlag, isTrue);
      expect(c.read(reportDraftProvider).safetyLocked, isTrue);

      n.setSafetyFlag(false); // locked: ignored
      expect(c.read(reportDraftProvider).safetyFlag, isTrue);
    });

    test('AC-09 choosing safety then electrical clears the auto-set flag', () {
      final ProviderContainer c = testContainer();
      c.read(reportDraftProvider.notifier)
        ..setCategory(ProblemCategory.safety)
        ..setCategory(ProblemCategory.electrical);
      final ReportDraft d = c.read(reportDraftProvider);
      expect(d.safetyFlag, isFalse);
      expect(d.safetyLocked, isFalse);

      // A manual flag survives switching between non-safety categories.
      c.read(reportDraftProvider.notifier)
        ..setSafetyFlag(true)
        ..setCategory(ProblemCategory.plumbing);
      expect(c.read(reportDraftProvider).safetyFlag, isTrue);
    });

    test('AC-12/13/14 photos: 1 to 5, all before photos', () {
      final ProviderContainer c = testContainer();
      final ReportDraftNotifier n = c.read(reportDraftProvider.notifier);
      expect(c.read(reportDraftProvider).photosValid, isFalse);

      for (int i = 0; i < 5; i++) {
        expect(n.addPhoto(), isTrue);
      }
      expect(n.addPhoto(), isFalse, reason: 'the sixth photo is refused');
      final ReportDraft d = c.read(reportDraftProvider);
      expect(d.photos, hasLength(5));
      expect(d.photosValid, isTrue);
      expect(
        d.photos.every((a) => a.kind == AttachmentKind.beforePhoto),
        isTrue,
      );
      expect(d.photos.map((a) => a.id).toSet(), hasLength(5));

      n.removePhoto(d.photos.first.id);
      expect(c.read(reportDraftProvider).photos, hasLength(4));
    });

    test('captions are trimmed, capped at 80 and clearable', () {
      final ProviderContainer c = testContainer();
      final ReportDraftNotifier n = c.read(reportDraftProvider.notifier)
        ..addPhoto();
      final String id = c.read(reportDraftProvider).photos.single.id;

      n.setCaption(id, '  broken tap  ');
      expect(c.read(reportDraftProvider).photos.single.caption, 'broken tap');
      n.setCaption(id, 'x' * 200);
      expect(c.read(reportDraftProvider).photos.single.caption, hasLength(80));
      n.setCaption(id, '   ');
      expect(c.read(reportDraftProvider).photos.single.caption, isNull);
    });

    test('AC-15 the description needs 10 trimmed characters', () {
      final ProviderContainer c = testContainer();
      final ReportDraftNotifier n = c.read(reportDraftProvider.notifier);
      n.setDescription('too short   ');
      expect(c.read(reportDraftProvider).descriptionValid, isFalse);
      n.setDescription('  long enough text ');
      expect(c.read(reportDraftProvider).descriptionValid, isTrue);
      n.setDescription('x' * 1001);
      expect(c.read(reportDraftProvider).descriptionValid, isFalse);
    });

    test('AC-10 location needs building, floor and room; a building change '
        'clears floor and room', () {
      final ProviderContainer c = testContainer();
      final ReportDraftNotifier n = c.read(reportDraftProvider.notifier)
        ..setBuilding('Academic Block A');
      expect(c.read(reportDraftProvider).locationValid, isFalse);
      n
        ..setFloor('1')
        ..setRoom('   ');
      expect(c.read(reportDraftProvider).locationValid, isFalse);
      n.setRoom('Classroom 101');
      expect(c.read(reportDraftProvider).locationValid, isTrue);

      n.setBuilding('Central Library');
      final ReportDraft d = c.read(reportDraftProvider);
      expect(d.floor, isNull);
      expect(d.room, isEmpty);
      expect(d.locationValid, isFalse);
    });

    test('an unlisted building is typed and takes any floor', () {
      final ProviderContainer c = testContainer();
      final ReportDraftNotifier n = c.read(reportDraftProvider.notifier)
        ..selectOtherBuilding();
      expect(c.read(reportDraftProvider).otherBuilding, isTrue);
      expect(c.read(reportDraftProvider).trimmedBuilding, isEmpty);
      n
        ..setOtherBuildingName('Annex')
        ..setFloor('Terrace')
        ..setRoom('Water tank');
      expect(c.read(reportDraftProvider).locationValid, isTrue);
    });

    test('reset clears everything', () {
      final ProviderContainer c = testContainer();
      fillDraft(c);
      expect(c.read(reportDraftProvider).isComplete, isTrue);
      expect(c.read(reportDraftProvider).hasInput, isTrue);
      c.read(reportDraftProvider.notifier).reset();
      expect(c.read(reportDraftProvider).hasInput, isFalse);
    });
  });

  group('report submit controller', () {
    test('files one complaint for the signed-in reporter and clears the draft '
        '(AC-19, AC-21, AC-22)', () async {
      final ProviderContainer c = await reporterContainer();
      fillDraft(c);
      final SubmittedReport? report = await c
          .read(reportSubmitProvider.notifier)
          .submit();

      expect(report, isNotNull);
      expect(report!.complaintId, matches(RegExp(r'^CF-\d{4}-\d{5}$')));
      expect(
        report.priority,
        computePriority(
          const PriorityInputs(
            category: ProblemCategory.electrical,
            safetyFlag: false,
            severity: Severity.moderate,
            peopleAffected: PeopleAffected.individual,
          ),
        ),
      );
      expect(c.read(reportDraftProvider).hasInput, isFalse);
      expect(
        c.read(reportSubmitProvider).last?.complaintId,
        report.complaintId,
      );

      // The stored complaint is the reporter's own and shows up in My
      // Complaints (public view): reported, nobody assigned yet.
      final List<PublicComplaintView> mine = await settledWhere(
        c,
        myComplaintsProvider,
        (List<PublicComplaintView> l) =>
            l.any((v) => v.id == report.complaintId),
      );
      final PublicComplaintView filed = mine.firstWhere(
        (v) => v.id == report.complaintId,
      );
      expect(filed.status, ComplaintStatus.reported);
      expect(filed.assignedDepartment, isNull);
      expect(filed.timeline, hasLength(1));
      expect(filed.beforePhotos, hasLength(1));
      expect(filed.effectivePriority, report.priority);
      expect(filed.building, 'Academic Block A');
      expect(filed.room, 'Electronics Lab 204');
    });

    test('a second tap while in flight is ignored (AC-18)', () async {
      final ProviderContainer c = await reporterContainer();
      final int before =
          (await c.read(complaintRepositoryProvider).all()).length;
      fillDraft(c);
      final SubmitFutures f = SubmitFutures(c);
      await f.bothSettled;
      final int after =
          (await c.read(complaintRepositoryProvider).all()).length;
      expect(after - before, 1);
      expect(f.first, isNotNull);
      expect(f.second, isNull);
    });

    test('an incomplete draft is not submitted and is kept', () async {
      final ProviderContainer c = await reporterContainer();
      c.read(reportDraftProvider.notifier).setCategory(ProblemCategory.it);
      final SubmittedReport? report = await c
          .read(reportSubmitProvider.notifier)
          .submit();
      expect(report, isNull);
      expect(c.read(reportSubmitProvider).status, ReportSubmitStatus.failed);
      expect(c.read(reportDraftProvider).category, ProblemCategory.it);
    });

    test('only a signed-in reporter can submit', () async {
      final ProviderContainer c = testContainer(); // signed out
      fillDraft(c);
      expect(await c.read(reportSubmitProvider.notifier).submit(), isNull);
      expect(c.read(reportDraftProvider).isComplete, isTrue);
    });
  });
}

/// Two overlapping submits of the same draft.
class SubmitFutures {
  SubmitFutures(ProviderContainer c) {
    final ReportSubmitNotifier n = c.read(reportSubmitProvider.notifier);
    final Future<SubmittedReport?> a = n.submit();
    final Future<SubmittedReport?> b = n.submit();
    bothSettled =
        Future.wait<SubmittedReport?>(<Future<SubmittedReport?>>[a, b]).then((
          List<SubmittedReport?> r,
        ) {
          first = r[0];
          second = r[1];
        });
  }

  late final Future<void> bothSettled;
  SubmittedReport? first;
  SubmittedReport? second;
}
