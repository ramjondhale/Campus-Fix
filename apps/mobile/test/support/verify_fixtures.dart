import 'dart:async';

import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:campusfix_mobile/app.dart' show noAutoRetry;
import 'package:campusfix_mobile/providers/providers.dart';
import 'package:campusfix_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

export 'work_fixtures.dart'
    show FlakyWriteComplaintRepository, SlowWriteComplaintRepository;

/// Seed complaints of the verification flow. Unlike the maintenance queue, the
/// verifier's queue is not scoped to a department, so the stock seed already
/// gives the demo verifier (u-ver-01) four `resolved` complaints and no
/// re-purposing is needed.
///
/// The queue (most urgent first, then the longest waiting since resolved):
/// [criticalElectrical], then the two `high` ones, then [lowFurniture].
const String criticalElectrical = 'CF-2026-00016';
const String highIt = 'CF-2026-00012';
const String highPlumbing = 'CF-2026-00018';
const String lowFurniture = 'CF-2026-00015';

/// Every `resolved` complaint of the stock seed.
const List<String> resolvedIds = <String>[
  criticalElectrical,
  highIt,
  highPlumbing,
  lowFurniture,
];

/// Not awaiting verification: already `verified`, `closed`, `inProgress` (one
/// the maintenance worker started, one a verifier sent back) and `reported`.
const String verifiedJob = 'CF-2026-00007';
const String closedJob = 'CF-2026-00001';
const String inProgressJob = 'CF-2026-00020';
const String sentBackJob = 'CF-2026-00017';
const String reportedJob = 'CF-2026-00025';

/// The electrician who owns [criticalElectrical] (the demo maintenance login).
String get electricianId => demoAccount(UserRole.maintenance).user.id;

DateTime _resolvedAt(Complaint c) {
  for (final StatusEvent e in c.timeline.reversed) {
    if (e.status == ComplaintStatus.resolved) return e.at;
  }
  return c.updatedAt;
}

/// The IDs of the `resolved` complaints of [all] in queue order: most urgent
/// first, then the longest waiting since being resolved (screens-spec M-16).
List<String> queueOrder(Iterable<Complaint> all) {
  final List<Complaint> waiting =
      <Complaint>[
        for (final Complaint c in all)
          if (c.status == ComplaintStatus.resolved) c,
      ]..sort((Complaint a, Complaint b) {
        final int byWeight = b.effectivePriority.weight.compareTo(
          a.effectivePriority.weight,
        );
        return byWeight != 0
            ? byWeight
            : _resolvedAt(a).compareTo(_resolvedAt(b));
      });
  return <String>[for (final Complaint c in waiting) c.id];
}

/// A repository holding the stock seed.
MockComplaintRepository verifyRepository() =>
    MockComplaintRepository(initial: testSeed.complaints);

/// The seed with [lowFurniture]'s repair evidence stripped (no after-photo,
/// no resolution note): corrupt data a verifier can only send back.
List<Complaint> noEvidenceSeed() => <Complaint>[
  for (final Complaint c in testSeed.complaints)
    if (c.id == lowFurniture)
      c.copyWith(afterPhotos: const <Attachment>[], clearResolutionNote: true)
    else
      c,
];

// ---------------------------------------------------------------------------
// Widget-test helpers
// ---------------------------------------------------------------------------

/// The IDs of the complaint cards currently built, top to bottom.
List<String> shownIds(WidgetTester tester) => <String>[
  for (final ComplaintCard c in tester.widgetList<ComplaintCard>(
    find.byType(ComplaintCard),
  ))
    c.complaint.id,
];

Finder button(String label) => find.byWidgetPredicate(
  (Widget w) => w is AppButton && w.label == label,
  description: 'AppButton "$label"',
);

Finder dialogButton(String label) =>
    find.descendant(of: find.byType(AppDialog), matching: button(label));

bool isEnabled(WidgetTester tester, String label) =>
    tester.widget<AppButton>(button(label)).onPressed != null;

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(button(label));
  await tester.pumpAndSettle();
}

String pathOf(ProviderContainer container) =>
    container.read(appRouterProvider).state.uri.path;

/// The multiline note field of the verify detail.
Finder get noteField => find.descendant(
  of: find.byWidgetPredicate(
    (Widget w) => w is AppTextField && w.label == 'Note',
  ),
  matching: find.byType(TextField),
);

Future<void> typeNote(WidgetTester tester, String text) async {
  await tester.enterText(noteField, text);
  await tester.pump();
}

/// Boots the app as the demo verifier on [repository] (default: the stock
/// seed), on a tall view so whole lists are laid out.
Future<ProviderContainer> signedInAsVerifier(
  WidgetTester tester, {
  ComplaintRepository? repository,
}) async {
  final ProviderContainer container = await pumpCampusFix(
    tester,
    overrides: <Override>[
      complaintRepositoryProvider.overrideWithValue(
        repository ?? verifyRepository(),
      ),
    ],
  );
  await signInAs(tester, UserRole.verifier);
  useTallView(tester);
  return container;
}

/// Opens [location] as the signed-in verifier.
Future<ProviderContainer> openAt(
  WidgetTester tester,
  String location, {
  ComplaintRepository? repository,
}) async {
  final ProviderContainer container = await signedInAsVerifier(
    tester,
    repository: repository,
  );
  await openRoute(tester, container, location);
  return container;
}

Future<Complaint> stored(ProviderContainer container, String id) async =>
    (await container.read(complaintRepositoryProvider).byId(id))!;

/// A container wired like the app with [repository] as the complaint store,
/// the demo account of [role] signed in and the write controller kept alive
/// (it is auto-disposed, so something must listen).
Future<ProviderContainer> verifyContainer({
  ComplaintRepository? repository,
  UserRole role = UserRole.verifier,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      ...testOverrides(),
      complaintRepositoryProvider.overrideWithValue(
        repository ?? verifyRepository(),
      ),
    ],
    retry: noAutoRetry,
  );
  addTearDown(container.dispose);
  final MockAccount account = demoAccount(role);
  await container
      .read(sessionProvider.notifier)
      .signIn(account.user.idNumber, account.password);
  container.listen<VerifyActionState>(verifyActionProvider, (_, _) {});
  return container;
}

/// Waits for the first data value of an async provider.
Future<T> settled<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) {
  final Completer<T> done = Completer<T>();
  final ProviderSubscription<AsyncValue<T>> sub = container
      .listen<AsyncValue<T>>(provider, (_, next) {
        if (next.hasValue && !done.isCompleted) {
          done.complete(next.requireValue);
        }
      }, fireImmediately: true);
  addTearDown(sub.close);
  return done.future.timeout(const Duration(seconds: 5));
}
