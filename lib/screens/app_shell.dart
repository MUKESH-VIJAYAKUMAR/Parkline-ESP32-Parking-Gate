import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/parking_models.dart';
import '../widgets/add_user_dialog.dart';
import '../widgets/dashboard_widgets.dart';
import 'access_logs_page.dart';
import 'dashboard_page.dart';
import 'users_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<ParkingUser> _users = DemoData.users();
  final List<AccessEvent> _events = DemoData.events();
  int _selectedIndex = 0;

  static const _items = [
    _NavItem(label: 'Overview', icon: Icons.grid_view_rounded),
    _NavItem(label: 'Parking users', icon: Icons.people_alt_outlined),
    _NavItem(label: 'Access logs', icon: Icons.receipt_long_outlined),
  ];

  String get _pageTitle => _items[_selectedIndex].label;

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addUser() async {
    final user = await showDialog<ParkingUser>(
      context: context,
      builder: (context) => const AddUserDialog(),
    );
    if (user == null || !mounted) return;

    final normalizedUid = _normalizeUid(user.cardUid);
    final duplicate = _users.any(
      (existing) => _normalizeUid(existing.cardUid) == normalizedUid,
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That RFID card is already registered.')),
      );
      return;
    }

    setState(() => _users.insert(0, user));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.name} was added to the parking users.')),
    );
  }

  String _normalizeUid(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  Widget _page() {
    switch (_selectedIndex) {
      case 1:
        return UsersPage(users: _users);
      case 2:
        return AccessLogsPage(events: _events);
      default:
        return DashboardPage(
          users: _users,
          events: _events,
          onViewUsers: () => _selectPage(1),
          onViewEvents: () => _selectPage(2),
        );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 980;
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF5F7FB),
        drawer: compact
            ? Drawer(
                width: 278,
                child: _NavigationPanel(
                  selectedIndex: _selectedIndex,
                  onSelect: _selectPage,
                  items: _items,
                ),
              )
            : null,
        body: SafeArea(
          child: Row(
            children: [
              if (!compact)
                _NavigationPanel(
                  selectedIndex: _selectedIndex,
                  onSelect: _selectPage,
                  items: _items,
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      title: _pageTitle,
                      compact: compact,
                      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      onAddUser: _addUser,
                    ),
                    Expanded(child: _page()),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.selectedIndex,
    required this.onSelect,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) => Container(
    width: 246,
    color: const Color(0xFF101D30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 25, 18, 34),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: tealColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.local_parking_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'parkline',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'SMART PARKING',
                    style: TextStyle(
                      color: Color(0xFF9BA9BA),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 11),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              color: Color(0xFF7F8EA2),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          final selected = selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Material(
              color: selected ? const Color(0xFF1D3048) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelect(index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 19,
                        color: selected
                            ? const Color(0xFF63D8BB)
                            : const Color(0xFFA8B4C2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFFC0CAD6),
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF63D8BB),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF172940),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF263B54)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sensors_rounded,
                      size: 17,
                      color: Color(0xFF62D6B8),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Gate system',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    StatusPill(label: 'DEMO', color: Color(0xFF62D6B8)),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Entrance controller',
                  style: TextStyle(color: Color(0xFFAAB6C4), fontSize: 11),
                ),
                SizedBox(height: 4),
                Text(
                  'Device status is sample data',
                  style: TextStyle(color: Color(0xFF7F8EA2), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Row(
            children: [
              PersonAvatar(name: 'Parking Admin', size: 36),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parking Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Administrator',
                      style: TextStyle(color: Color(0xFF94A2B3), fontSize: 10),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz_rounded, color: Color(0xFF94A2B3)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.compact,
    required this.onMenu,
    required this.onAddUser,
  });

  final String title;
  final bool compact;
  final VoidCallback onMenu;
  final VoidCallback onAddUser;

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 28),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: borderColor)),
    ),
    child: Row(
      children: [
        if (compact) ...[
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded, color: inkColor),
          ),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: inkColor,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                Text(
                  formatLongDate(DateTime.now()),
                  style: const TextStyle(fontSize: 11, color: mutedColor),
                ),
              ],
            ],
          ),
        ),
        if (!compact) ...[
          const StatusPill(
            label: 'DEMO DATA',
            color: Color(0xFF55739A),
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(width: 18),
          const PersonAvatar(name: 'Parking Admin', size: 35),
          const SizedBox(width: 9),
          const Text(
            'Admin',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(width: 16),
        ],
        if (compact)
          IconButton.filled(
            onPressed: onAddUser,
            tooltip: 'Add parking user',
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
          )
        else
          FilledButton.icon(
            onPressed: onAddUser,
            style: FilledButton.styleFrom(
              backgroundColor: blueColor,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
            label: const Text(
              'Add user',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );
}
