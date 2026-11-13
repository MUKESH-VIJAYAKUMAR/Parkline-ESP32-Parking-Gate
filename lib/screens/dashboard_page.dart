import 'package:flutter/material.dart';

import '../models/parking_models.dart';
import '../widgets/dashboard_widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.users,
    required this.events,
    required this.onViewUsers,
    required this.onViewEvents,
  });

  final List<ParkingUser> users;
  final List<AccessEvent> events;
  final VoidCallback onViewUsers;
  final VoidCallback onViewEvents;

  @override
  Widget build(BuildContext context) {
    final inside = users.where((user) => user.isInside).length;
    final entryCount = events
        .where((event) => event.direction == ParkingDirection.entry)
        .length;
    final exitCount = events
        .where((event) => event.direction == ParkingDirection.exit)
        .length;
    final width = MediaQuery.sizeOf(context).width;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        width < 640 ? 16 : 28,
        22,
        width < 640 ? 16 : 28,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                color: Color(0xFFD18A12),
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Here’s your parking snapshot for today.',
                style: const TextStyle(fontSize: 13, color: mutedColor),
              ),
              const Spacer(),
              StatusPill(
                label: '${users.length} cards active',
                color: tealColor,
                icon: Icons.verified_user_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final gap = 14.0;
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Registered users',
                      value: users.length.toString(),
                      note: 'Active parking accounts',
                      icon: Icons.people_alt_outlined,
                      color: blueColor,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Vehicles inside',
                      value: inside.toString(),
                      note: 'Based on confirmed gate passages',
                      icon: Icons.local_parking_rounded,
                      color: tealColor,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Entries today',
                      value: entryCount.toString(),
                      note: 'Successful entry passages',
                      icon: Icons.south_west_rounded,
                      color: const Color(0xFF8259D8),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Exits today',
                      value: exitCount.toString(),
                      note: 'Successful exit passages',
                      icon: Icons.north_east_rounded,
                      color: const Color(0xFFE19042),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 920) {
                return const Column(
                  children: [
                    ActivityChart(),
                    SizedBox(height: 14),
                    GateStatusCard(isOpen: false, isOnline: true),
                  ],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: ActivityChart()),
                  SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: GateStatusCard(isOpen: false, isOnline: true),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          AccessEventSection(
            events: events.take(5).toList(),
            onViewAll: onViewEvents,
          ),
          const SizedBox(height: 18),
          _NewUsersPanel(users: users, onViewAll: onViewUsers),
        ],
      ),
    );
  }
}

class _NewUsersPanel extends StatelessWidget {
  const _NewUsersPanel({required this.users, required this.onViewAll});

  final List<ParkingUser> users;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final latest = [...users]
      ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: SectionHeading(
              title: 'Recently registered users',
              subtitle: 'New parking accounts and linked RFID cards',
              action: TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                label: const Text('Manage users'),
              ),
            ),
          ),
          const Divider(height: 1),
          if (latest.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No registered users yet.',
                style: TextStyle(color: mutedColor),
              ),
            )
          else
            ...latest
                .take(3)
                .map(
                  (user) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        PersonAvatar(name: user.name),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${user.vehiclePlate}  ·  Card ${user.cardUid}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          relativeTime(user.registeredAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
