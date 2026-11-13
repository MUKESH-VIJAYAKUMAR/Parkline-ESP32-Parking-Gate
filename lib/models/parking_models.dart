enum ParkingDirection { entry, exit }

extension ParkingDirectionLabel on ParkingDirection {
  String get label => this == ParkingDirection.entry ? 'Entry' : 'Exit';
}

class ParkingUser {
  const ParkingUser({
    required this.id,
    required this.name,
    required this.vehiclePlate,
    required this.cardUid,
    required this.isInside,
    required this.registeredAt,
  });

  final String id;
  final String name;
  final String vehiclePlate;
  final String cardUid;
  final bool isInside;
  final DateTime registeredAt;
}

class AccessEvent {
  const AccessEvent({
    required this.id,
    required this.userName,
    required this.vehiclePlate,
    required this.cardUid,
    required this.direction,
    required this.cardTappedAt,
    required this.vehiclePassedAt,
    required this.allowed,
  });

  final String id;
  final String userName;
  final String vehiclePlate;
  final String cardUid;
  final ParkingDirection direction;
  final DateTime cardTappedAt;
  final DateTime vehiclePassedAt;
  final bool allowed;
}
