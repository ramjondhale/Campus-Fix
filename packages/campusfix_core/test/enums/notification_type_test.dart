import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

void main() {
  group('NotificationType', () {
    test('has the 5 spec values in order', () {
      expect(NotificationType.values.map((t) => t.name), [
        'submission',
        'assignment',
        'statusChange',
        'completion',
        'closure',
      ]);
    });

    test('every value has a non-empty, distinct label', () {
      final labels = NotificationType.values.map((t) => t.label).toList();
      expect(labels, everyElement(isNotEmpty));
      expect(labels.toSet(), hasLength(labels.length));
    });
  });
}
