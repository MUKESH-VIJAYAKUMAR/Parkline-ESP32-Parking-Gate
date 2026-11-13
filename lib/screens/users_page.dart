import 'package:flutter/material.dart';

import '../models/parking_models.dart';
import '../widgets/dashboard_widgets.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.users});

  final List<ParkingUser> users;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = widget.users.where((user) {
      final query = _query.toLowerCase();
      return user.name.toLowerCase().contains(query) ||
          user.vehiclePlate.toLowerCase().contains(query) ||
          user.cardUid.toLowerCase().contains(query);
    }).toList();
    final width = MediaQuery.sizeOf(context).width;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        width < 640 ? 16 : 28,
        24,
        width < 640 ? 16 : 28,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'People and vehicles registered for parking access.',
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Search name, vehicle plate, or card UID',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StatusPill(
                label: '${filteredUsers.length} users',
                color: blueColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SurfacePanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 15),
                  child: SectionHeading(
                    title: 'Registered users',
                    subtitle: 'Each user is linked to one active vehicle and RFID card.',
                  ),
                ),
                const Divider(height: 1),
                if (filteredUsers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(36),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 34,
                          color: Color(0xFF9AA7B7),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No users found',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Try another search.',
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 720
                        ? Column(
                            children: filteredUsers
                                .map((user) => _MobileUserCard(user: user))
                                .toList(),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 45,
                              dataRowMinHeight: 64,
                              dataRowMaxHeight: 68,
                              horizontalMargin: 22,
                              columnSpacing: 34,
                              columns: const [
                                DataColumn(label: Text('PARKING USER')),
                                DataColumn(label: Text('VEHICLE PLATE')),
                                DataColumn(label: Text('RFID CARD UID')),
                                DataColumn(label: Text('PARKING STATUS')),
                                DataColumn(label: Text('REGISTERED')),
                              ],
                              rows: filteredUsers
                                  .map(
                                    (user) => DataRow(
                                      cells: [
                                        DataCell(_NameCell(user: user)),
                                        DataCell(
                                          Text(
                                            user.vehiclePlate,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            user.cardUid,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: mutedColor,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          StatusPill(
                                            label: user.isInside
                                                ? 'Inside'
                                                : 'Outside',
                                            color: user.isInside
                                                ? tealColor
                                                : mutedColor,
                                            icon: user.isInside
                                                ? Icons.local_parking_rounded
                                                : Icons.exit_to_app_rounded,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            relativeTime(user.registeredAt),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: mutedColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.user});
  final ParkingUser user;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PersonAvatar(name: user.name),
      const SizedBox(width: 11),
      Text(
        user.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _MobileUserCard extends StatelessWidget {
  const _MobileUserCard({required this.user});
  final ParkingUser user;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
    child: Column(
      children: [
        Row(
          children: [
            PersonAvatar(name: user.name, size: 38),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.vehiclePlate,
                    style: const TextStyle(fontSize: 11, color: mutedColor),
                  ),
                ],
              ),
            ),
            StatusPill(
              label: user.isInside ? 'Inside' : 'Outside',
              color: user.isInside ? tealColor : mutedColor,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.contactless_rounded, size: 15, color: mutedColor),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'RFID ${user.cardUid}',
                style: const TextStyle(fontSize: 11, color: mutedColor),
              ),
            ),
            Text(
              relativeTime(user.registeredAt),
              style: const TextStyle(fontSize: 11, color: mutedColor),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
      ],
    ),
  );
}
