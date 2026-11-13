import '../models/parking_models.dart';

class DemoData {
  static final DateTime _now = DateTime.now();

  static List<ParkingUser> users() => [
    ParkingUser(
      id: 'u-101',
      name: 'Aarav Nair',
      vehiclePlate: 'KA 03 MN 4481',
      cardUid: '7A 91 2C 4D',
      isInside: true,
      registeredAt: _now.subtract(const Duration(days: 41)),
    ),
    ParkingUser(
      id: 'u-102',
      name: 'Tanya Bose',
      vehiclePlate: 'KA 05 RP 2190',
      cardUid: '3C 17 8B 2F',
      isInside: false,
      registeredAt: _now.subtract(const Duration(days: 32)),
    ),
    ParkingUser(
      id: 'u-103',
      name: 'Rohan Das',
      vehiclePlate: 'KA 01 AB 6723',
      cardUid: 'E2 05 49 81',
      isInside: true,
      registeredAt: _now.subtract(const Duration(days: 25)),
    ),
    ParkingUser(
      id: 'u-104',
      name: 'Meera Menon',
      vehiclePlate: 'KA 04 VT 9035',
      cardUid: '6D 30 9A C2',
      isInside: true,
      registeredAt: _now.subtract(const Duration(days: 18)),
    ),
    ParkingUser(
      id: 'u-105',
      name: 'Dev Kapoor',
      vehiclePlate: 'KA 02 LC 5508',
      cardUid: 'B1 88 4E 73',
      isInside: false,
      registeredAt: _now.subtract(const Duration(days: 11)),
    ),
    ParkingUser(
      id: 'u-106',
      name: 'Isha Roy',
      vehiclePlate: 'KA 51 QX 1642',
      cardUid: '9F 24 6C D0',
      isInside: false,
      registeredAt: _now.subtract(const Duration(days: 3)),
    ),
  ];

  static List<AccessEvent> events() => [
    _event(
      'e-1',
      'Aarav Nair',
      'KA 03 MN 4481',
      '7A 91 2C 4D',
      ParkingDirection.entry,
      8,
    ),
    _event(
      'e-2',
      'Tanya Bose',
      'KA 05 RP 2190',
      '3C 17 8B 2F',
      ParkingDirection.exit,
      24,
    ),
    _event(
      'e-3',
      'Meera Menon',
      'KA 04 VT 9035',
      '6D 30 9A C2',
      ParkingDirection.entry,
      46,
    ),
    _event(
      'e-4',
      'Dev Kapoor',
      'KA 02 LC 5508',
      'B1 88 4E 73',
      ParkingDirection.exit,
      78,
    ),
    _event(
      'e-5',
      'Rohan Das',
      'KA 01 AB 6723',
      'E2 05 49 81',
      ParkingDirection.entry,
      112,
    ),
    _event(
      'e-6',
      'Isha Roy',
      'KA 51 QX 1642',
      '9F 24 6C D0',
      ParkingDirection.exit,
      159,
    ),
  ];

  static AccessEvent _event(
    String id,
    String name,
    String plate,
    String uid,
    ParkingDirection direction,
    int minutesAgo,
  ) {
    final tapped = _now.subtract(Duration(minutes: minutesAgo));
    return AccessEvent(
      id: id,
      userName: name,
      vehiclePlate: plate,
      cardUid: uid,
      direction: direction,
      cardTappedAt: tapped,
      vehiclePassedAt: tapped.add(const Duration(seconds: 4)),
      allowed: true,
    );
  }
}
