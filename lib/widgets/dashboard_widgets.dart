import 'package:flutter/material.dart';

import '../models/parking_models.dart';

const Color inkColor = Color(0xFF172334);
const Color mutedColor = Color(0xFF78869A);
const Color borderColor = Color(0xFFE8EDF3);
const Color blueColor = Color(0xFF3978F6);
const Color tealColor = Color(0xFF159D7A);

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor),
      boxShadow: const [
        BoxShadow(
          color: Color(0x070E2438),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: inkColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: mutedColor),
              ),
            ],
          ],
        ),
      ),
      ?action,
    ],
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    this.noteColor = mutedColor,
  });

  final String title;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final Color noteColor;

  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 27,
            height: 1,
            fontWeight: FontWeight.w700,
            color: inkColor,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          note,
          style: TextStyle(
            fontSize: 11,
            color: noteColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.size = 34});

  final String name;
  final double size;

  static const List<Color> _palette = [
    Color(0xFFEAF0FF),
    Color(0xFFE7F7F2),
    Color(0xFFFFF2E5),
    Color(0xFFF2ECFF),
    Color(0xFFFFEDEF),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty
        ? '?'
        : parts
              .take(2)
              .map((part) => part.isEmpty ? '' : part[0])
              .join()
              .toUpperCase();
    final index =
        name.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
        _palette.length;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _palette[index], shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * .31,
          fontWeight: FontWeight.w700,
          color: inkColor,
        ),
      ),
    );
  }
}

class DirectionBadge extends StatelessWidget {
  const DirectionBadge({super.key, required this.direction});

  final ParkingDirection direction;

  @override
  Widget build(BuildContext context) {
    final isEntry = direction == ParkingDirection.entry;
    final color = isEntry ? tealColor : blueColor;
    return StatusPill(
      label: direction.label,
      color: color,
      icon: isEntry ? Icons.south_west_rounded : Icons.north_east_rounded,
    );
  }
}

class GateStatusCard extends StatelessWidget {
  const GateStatusCard({
    super.key,
    required this.isOpen,
    required this.isOnline,
  });

  final bool isOpen;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final stateColor = isOpen ? const Color(0xFFD18A12) : tealColor;
    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Gate status',
            subtitle: 'Entrance lane · Device overview',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FC),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.door_sliding_rounded,
                    color: stateColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Main entrance',
                        style: TextStyle(
                          fontSize: 13,
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOpen ? 'Gate open' : 'Gate closed',
                        style: const TextStyle(
                          fontSize: 18,
                          color: inkColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(label: isOpen ? 'OPEN' : 'READY', color: stateColor),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DeviceLine(
            label: 'ESP32 controller',
            value: isOnline ? 'Online' : 'Offline',
            good: isOnline,
          ),
          const SizedBox(height: 11),
          const _DeviceLine(label: 'RFID reader', value: 'Ready', good: true),
          const SizedBox(height: 11),
          const _DeviceLine(
            label: 'Passage sensor',
            value: 'Clear',
            good: true,
          ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(Icons.sync_rounded, size: 15, color: mutedColor),
              const SizedBox(width: 7),
              Text(
                'Last update · ${formatTime(DateTime.now())}',
                style: const TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceLine extends StatelessWidget {
  const _DeviceLine({
    required this.label,
    required this.value,
    required this.good,
  });

  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? tealColor : const Color(0xFFC04C58);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: mutedColor),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class ActivityChart extends StatelessWidget {
  const ActivityChart({super.key});

  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Access activity',
          subtitle: 'Vehicle movement throughout today',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 186,
          width: double.infinity,
          child: CustomPaint(painter: _ActivityChartPainter()),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ChartLegend(color: blueColor, label: 'Entry'),
            SizedBox(width: 20),
            _ChartLegend(color: tealColor, label: 'Exit'),
          ],
        ),
      ],
    ),
  );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: mutedColor)),
    ],
  );
}

class _ActivityChartPainter extends CustomPainter {
  static const _entry = <double>[
    16,
    22,
    19,
    31,
    36,
    32,
    48,
    55,
    50,
    70,
    66,
    82,
  ];
  static const _exit = <double>[9, 14, 18, 23, 27, 34, 40, 44, 50, 57, 63, 69];
  static const _labels = ['08', '10', '12', '14', '16', '18'];

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const top = 10.0;
    const right = 8.0;
    const bottom = 24.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFE9EEF4)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(fontSize: 10, color: mutedColor);

    for (var row = 0; row <= 3; row++) {
      final y = chart.top + chart.height * row / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = (100 - row * 30).toString();
      _drawText(canvas, value, Offset(0, y - 6), labelStyle);
    }

    for (var i = 0; i < _labels.length; i++) {
      final x = chart.left + chart.width * i / (_labels.length - 1);
      _drawText(
        canvas,
        _labels[i],
        Offset(x - 7, chart.bottom + 8),
        labelStyle,
      );
    }

    _drawSeries(canvas, chart, _entry, blueColor, fill: true);
    _drawSeries(canvas, chart, _exit, tealColor, fill: false);
  }

  void _drawSeries(
    Canvas canvas,
    Rect chart,
    List<double> values,
    Color color, {
    required bool fill,
  }) {
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * i / (values.length - 1);
      final y = chart.bottom - chart.height * values[i] / 100;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midpoint = (previous.dx + current.dx) / 2;
      path.cubicTo(
        midpoint,
        previous.dy,
        midpoint,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    if (fill) {
      final area = Path.from(path)
        ..lineTo(points.last.dx, chart.bottom)
        ..lineTo(points.first.dx, chart.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            colors: [color.withValues(alpha: .16), color.withValues(alpha: 0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(chart),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawText(Canvas canvas, String value, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ActivityChartPainter oldDelegate) => false;
}

class AccessEventSection extends StatelessWidget {
  const AccessEventSection({super.key, required this.events, this.onViewAll});

  final List<AccessEvent> events;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
          child: SectionHeading(
            title: 'Recent access',
            subtitle: 'Card taps and confirmed vehicle passages',
            action: onViewAll == null
                ? null
                : TextButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                    label: const Text('View all'),
                  ),
          ),
        ),
        const Divider(height: 1),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'No access activity yet.',
              style: TextStyle(color: mutedColor),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 650
                ? Column(
                    children: events
                        .map((event) => _MobileEventRow(event: event))
                        .toList(),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 42,
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 62,
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('PARKING USER')),
                        DataColumn(label: Text('RFID CARD')),
                        DataColumn(label: Text('DIRECTION')),
                        DataColumn(label: Text('CARD TAP')),
                        DataColumn(label: Text('VEHICLE PASSED')),
                        DataColumn(label: Text('RESULT')),
                      ],
                      rows: events
                          .map(
                            (event) => DataRow(
                              cells: [
                                DataCell(
                                  _UserCell(
                                    name: event.userName,
                                    detail: event.vehiclePlate,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    event.cardUid,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: mutedColor,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  DirectionBadge(direction: event.direction),
                                ),
                                DataCell(
                                  Text(
                                    formatTime(event.cardTappedAt),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    formatTime(event.vehiclePassedAt),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  StatusPill(
                                    label: event.allowed ? 'Allowed' : 'Denied',
                                    color: event.allowed
                                        ? tealColor
                                        : const Color(0xFFC04C58),
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
  );
}

class _MobileEventRow extends StatelessWidget {
  const _MobileEventRow({required this.event});
  final AccessEvent event;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _UserCell(
                name: event.userName,
                detail: event.vehiclePlate,
              ),
            ),
            DirectionBadge(direction: event.direction),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Text(
                'Card ${event.cardUid}',
                style: const TextStyle(fontSize: 11, color: mutedColor),
              ),
            ),
            Text(
              formatTime(event.cardTappedAt),
              style: const TextStyle(fontSize: 11, color: mutedColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Vehicle passed ${formatTime(event.vehiclePassedAt)}',
          style: const TextStyle(fontSize: 11, color: mutedColor),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
      ],
    ),
  );
}

class _UserCell extends StatelessWidget {
  const _UserCell({required this.name, required this.detail});
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PersonAvatar(name: name, size: 32),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              color: inkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(detail, style: const TextStyle(fontSize: 10, color: mutedColor)),
        ],
      ),
    ],
  );
}

String formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String formatLongDate(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[value.weekday - 1]}, ${value.day} ${months[value.month - 1]} ${value.year}';
}

String relativeTime(DateTime value) {
  final delta = DateTime.now().difference(value);
  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) return '${delta.inHours} hr ago';
  return '${delta.inDays} days ago';
}
