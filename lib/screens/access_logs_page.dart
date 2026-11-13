import 'package:flutter/material.dart';

import '../models/parking_models.dart';
import '../widgets/dashboard_widgets.dart';

class AccessLogsPage extends StatefulWidget {
  const AccessLogsPage({super.key, required this.events});

  final List<AccessEvent> events;

  @override
  State<AccessLogsPage> createState() => _AccessLogsPageState();
}

class _AccessLogsPageState extends State<AccessLogsPage> {
  ParkingDirection? _filter;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.events
        .where((event) => _filter == null || event.direction == _filter)
        .toList();
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
            'Every card tap, access decision, and confirmed vehicle passage.',
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),
          const SizedBox(height: 19),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterChip(
                label: 'All activity',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              _FilterChip(
                label: 'Entries',
                selected: _filter == ParkingDirection.entry,
                onTap: () => setState(() => _filter = ParkingDirection.entry),
              ),
              _FilterChip(
                label: 'Exits',
                selected: _filter == ParkingDirection.exit,
                onTap: () => setState(() => _filter = ParkingDirection.exit),
              ),
              StatusPill(label: '${filtered.length} events', color: blueColor),
            ],
          ),
          const SizedBox(height: 16),
          AccessEventSection(events: filtered),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFEAF0FF) : Colors.white,
    borderRadius: BorderRadius.circular(100),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? const Color(0xFFC9D8FF) : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? blueColor : mutedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
