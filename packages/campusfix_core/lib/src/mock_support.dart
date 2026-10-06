/// Internal helpers shared by the mock repositories. Not exported.
library;

import 'dart:async';

/// Simulates repository latency (screens-spec G-3). A zero [latency] still
/// yields to the event loop once, like any real async call.
Future<void> simulateLatency(Duration latency) => latency == Duration.zero
    ? Future<void>.value()
    : Future<void>.delayed(latency);

/// A stream that emits `snapshot()` as soon as it is listened to and again
/// after every event on [changes].
///
/// [changes] must be a **synchronous** broadcast stream fired right after each
/// mutation, so every emission reflects the state at that moment. Each call
/// returns an independent single-subscription stream.
Stream<T> snapshotStream<T>(Stream<void> changes, T Function() snapshot) {
  late final StreamController<T> controller;
  StreamSubscription<void>? subscription;
  controller = StreamController<T>(
    onListen: () {
      controller.add(snapshot());
      subscription = changes.listen((_) => controller.add(snapshot()));
    },
    onCancel: () async {
      await subscription?.cancel();
      subscription = null;
    },
  );
  return controller.stream;
}
