import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

/// Waits for the first data value of an async provider (a provider nothing in
/// the widget tree listens to stays loading until something does).
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
