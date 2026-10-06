import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// One floor of a [CampusBuilding] and the rooms / locations on it that the
/// report form suggests.
@immutable
class CampusFloor {
  const CampusFloor(this.name, this.rooms);

  /// Floor label as stored in `Complaint.floor`: `Basement`, `Ground`, `1`..
  /// `10`, `Terrace` or [CampusDirectory.outdoor].
  final String name;

  /// Rooms / locations on this floor, in display order. The report form lets
  /// the reporter type a different location (screens-spec M-04).
  final List<String> rooms;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusFloor &&
          other.name == name &&
          const ListEquality<String>().equals(other.rooms, rooms);

  @override
  int get hashCode =>
      Object.hash(name, const ListEquality<String>().hash(rooms));

  @override
  String toString() => 'CampusFloor($name, ${rooms.length} rooms)';
}

/// A building and its floors.
@immutable
class CampusBuilding {
  const CampusBuilding(this.name, this.floors);

  /// Building name as stored in `Complaint.building`.
  final String name;
  final List<CampusFloor> floors;

  /// The floor called [floorName], or `null`.
  CampusFloor? floor(String floorName) {
    for (final f in floors) {
      if (f.name == floorName) return f;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusBuilding &&
          other.name == name &&
          const ListEquality<CampusFloor>().equals(other.floors, floors);

  @override
  int get hashCode =>
      Object.hash(name, const ListEquality<CampusFloor>().hash(floors));

  @override
  String toString() => 'CampusBuilding($name, ${floors.length} floors)';
}

/// The campus buildings -> floors -> rooms the report form offers (R4,
/// screens-spec M-04 / SC-OI-3). Pure data; no I/O.
@immutable
class CampusDirectory {
  const CampusDirectory(this.buildings);

  /// Floor label for open-air locations (grounds, courts, car parks).
  static const String outdoor = 'Outdoor / N.A.';

  /// The prototype's campus.
  static const CampusDirectory standard = CampusDirectory(_standardBuildings);

  final List<CampusBuilding> buildings;

  /// Building names, in display order.
  List<String> get buildingNames => [for (final b in buildings) b.name];

  /// The building called [name], or `null`.
  CampusBuilding? building(String name) {
    for (final b in buildings) {
      if (b.name == name) return b;
    }
    return null;
  }

  /// Floor names of [buildingName]; empty when the building is unknown.
  List<String> floorsOf(String buildingName) => [
    for (final f in building(buildingName)?.floors ?? const <CampusFloor>[])
      f.name,
  ];

  /// Suggested rooms on [floorName] of [buildingName]; empty when either is
  /// unknown.
  List<String> roomsOf(String buildingName, String floorName) =>
      building(buildingName)?.floor(floorName)?.rooms ?? const <String>[];

  /// Whether [buildingName] / [floorName] / [room] is a listed location.
  bool contains(String buildingName, String floorName, String room) =>
      roomsOf(buildingName, floorName).contains(room);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusDirectory &&
          const ListEquality<CampusBuilding>().equals(
            other.buildings,
            buildings,
          );

  @override
  int get hashCode => const ListEquality<CampusBuilding>().hash(buildings);

  @override
  String toString() => 'CampusDirectory(${buildings.length} buildings)';
}

const List<CampusBuilding> _standardBuildings = [
  CampusBuilding('Academic Block A', [
    CampusFloor('Basement', ['Generator Room', 'Parking Bay']),
    CampusFloor('Ground', [
      'Main Lobby',
      'Seminar Hall 1',
      'Seminar Hall 2',
      'Staff Room',
      'Washroom (near stairs)',
      'Corridor',
    ]),
    CampusFloor('1', [
      'Classroom 101',
      'Classroom 102',
      'Classroom 103',
      'Classroom 104',
      'Department Office',
      'Washroom (near stairs)',
      'Corridor',
    ]),
    CampusFloor('2', [
      'Classroom 201',
      'Classroom 202',
      'Classroom 203',
      'Electronics Lab 204',
      'Washroom (near stairs)',
      'Corridor',
    ]),
    CampusFloor('3', [
      'Classroom 301',
      'Classroom 302',
      'Seminar Room 303',
      'Staircase',
      'Corridor',
    ]),
  ]),
  CampusBuilding('Academic Block B', [
    CampusFloor('Basement', ['Electrical Panel Room', 'Parking Bay']),
    CampusFloor('Ground', [
      'Lecture Theatre 1',
      'Lecture Theatre 2',
      'Washroom (near entrance)',
      'Corridor',
    ]),
    CampusFloor('1', [
      'Classroom B101',
      'Classroom B102',
      'Tutorial Room B103',
      'Washroom (near stairs)',
      'Corridor',
    ]),
    CampusFloor('2', [
      'Classroom B201',
      'Classroom B202',
      'Faculty Cabins',
      'Washroom (near stairs)',
      'Staircase',
    ]),
  ]),
  CampusBuilding('Science & Computer Block', [
    CampusFloor('Ground', [
      'Physics Lab',
      'Chemistry Lab',
      'Server Room',
      'Washroom (near lobby)',
    ]),
    CampusFloor('1', [
      'Computer Lab 1',
      'Computer Lab 2',
      'Project Lab',
      'Network Closet',
    ]),
    CampusFloor('2', ['Computer Lab 3', 'Research Lab', 'Seminar Room']),
  ]),
  CampusBuilding('Central Library', [
    CampusFloor('Ground', [
      'Reading Hall',
      'Circulation Desk',
      'Digital Library',
    ]),
    CampusFloor('1', [
      'Reference Section',
      'Study Cubicles',
      'Washroom (near stairs)',
    ]),
    CampusFloor('2', ['Archive Room', 'Group Study Room']),
  ]),
  CampusBuilding('Administrative Building', [
    CampusFloor('Ground', [
      'Reception',
      'Admissions Office',
      'Accounts Office',
      'Washroom (near lobby)',
    ]),
    CampusFloor('1', ['Conference Room', 'Exam Cell', 'Principal Office']),
  ]),
  CampusBuilding('Hostel Block A', [
    CampusFloor('Ground', ['Common Room', 'Mess Hall', 'Warden Office']),
    CampusFloor('1', ['Room 101', 'Room 105', 'Washroom Block', 'Corridor']),
    CampusFloor('2', ['Room 205', 'Washroom Block', 'Corridor']),
    CampusFloor('3', ['Room 310', 'Washroom Block', 'Corridor']),
  ]),
  CampusBuilding('Hostel Block B', [
    CampusFloor('Ground', ['Common Room', 'Mess Hall', 'Warden Office']),
    CampusFloor('1', ['Room 112', 'Washroom Block', 'Corridor']),
    CampusFloor('2', ['Room 214', 'Washroom Block', 'Corridor']),
  ]),
  CampusBuilding('Cafeteria', [
    CampusFloor('Ground', ['Dining Hall', 'Serving Counter', 'Wash Area']),
    CampusFloor('Terrace', ['Open Seating Area']),
  ]),
  CampusBuilding('Auditorium', [
    CampusFloor('Ground', ['Main Hall', 'Foyer', 'Green Room']),
    CampusFloor('1', ['Balcony', 'Control Room']),
  ]),
  CampusBuilding('Sports Complex', [
    CampusFloor('Ground', ['Indoor Court', 'Gym', 'Changing Room']),
    CampusFloor(CampusDirectory.outdoor, [
      'Basketball Court',
      'Cricket Ground',
      'Parking Area',
    ]),
  ]),
  CampusBuilding('Workshop Block', [
    CampusFloor('Ground', ['Mechanical Workshop', 'Welding Bay', 'Tool Store']),
    CampusFloor('1', ['CAD Lab']),
  ]),
  CampusBuilding('Campus Grounds', [
    CampusFloor(CampusDirectory.outdoor, [
      'Main Gate',
      'Garden Pathway',
      'Visitor Parking',
    ]),
  ]),
];
