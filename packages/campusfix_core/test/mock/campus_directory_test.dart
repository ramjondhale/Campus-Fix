import 'package:campusfix_core/campusfix_core.dart';
import 'package:test/test.dart';

void main() {
  const dir = CampusDirectory.standard;
  final validFloor = RegExp(r'^(Basement|Ground|Terrace|[1-9]|10)$');

  group('CampusDirectory.standard', () {
    test('has a realistic set of buildings, floors and rooms', () {
      expect(dir.buildings.length, greaterThanOrEqualTo(8));
      for (final b in dir.buildings) {
        expect(b.floors, isNotEmpty, reason: b.name);
        for (final f in b.floors) {
          expect(f.rooms, isNotEmpty, reason: '${b.name} / ${f.name}');
        }
      }
    });

    test('names are non-blank and unique at every level', () {
      expect(dir.buildingNames.toSet(), hasLength(dir.buildings.length));
      for (final b in dir.buildings) {
        expect(b.name.trim(), isNotEmpty);
        final floors = [for (final f in b.floors) f.name];
        expect(floors.toSet(), hasLength(floors.length), reason: b.name);
        for (final f in b.floors) {
          expect(f.name.trim(), isNotEmpty);
          expect(f.rooms.toSet(), hasLength(f.rooms.length), reason: f.name);
          for (final r in f.rooms) {
            expect(r.trim(), isNotEmpty);
            // The report form caps the room / location at 60 characters.
            expect(r.length, lessThanOrEqualTo(60));
          }
        }
      }
    });

    test('floor labels are the picker values (screens-spec M-04)', () {
      for (final b in dir.buildings) {
        for (final f in b.floors) {
          expect(
            validFloor.hasMatch(f.name) || f.name == CampusDirectory.outdoor,
            isTrue,
            reason: '${b.name}: "${f.name}"',
          );
        }
      }
    });

    test('lookups', () {
      expect(dir.building('Central Library'), isNotNull);
      expect(dir.building('Nowhere'), isNull);
      expect(dir.floorsOf('Academic Block A'), containsAll(['Ground', '1']));
      expect(dir.floorsOf('Nowhere'), isEmpty);
      expect(dir.roomsOf('Academic Block A', '1'), contains('Classroom 101'));
      expect(dir.roomsOf('Academic Block A', '99'), isEmpty);
      expect(dir.roomsOf('Nowhere', '1'), isEmpty);
      expect(dir.building('Cafeteria')!.floor('Terrace'), isNotNull);
      expect(dir.building('Cafeteria')!.floor('Basement'), isNull);
    });

    test('contains checks building, floor and room together', () {
      expect(dir.contains('Academic Block A', '1', 'Classroom 101'), isTrue);
      expect(dir.contains('Academic Block A', '2', 'Classroom 101'), isFalse);
      expect(dir.contains('Academic Block B', '1', 'Classroom 101'), isFalse);
      expect(dir.contains('Nowhere', '1', 'Classroom 101'), isFalse);
    });

    test('value equality and hashCode', () {
      const a = CampusFloor('1', ['Room 1']);
      const b = CampusFloor('1', ['Room 1']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const CampusFloor('2', ['Room 1'])));
      expect(a, isNot(const CampusFloor('1', ['Room 2'])));
      const x = CampusBuilding('B', [a]);
      expect(x, const CampusBuilding('B', [b]));
      expect(x.hashCode, const CampusBuilding('B', [b]).hashCode);
      expect(x, isNot(const CampusBuilding('C', [a])));
      expect(const CampusDirectory([x]), const CampusDirectory([x]));
      expect(const CampusDirectory([x]), isNot(const CampusDirectory([])));
      expect(
        const CampusDirectory([x]).hashCode,
        const CampusDirectory([x]).hashCode,
      );
    });
  });
}
