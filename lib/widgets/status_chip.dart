import 'package:flutter/material.dart';

import '../models/visit.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (status) {
      case VisitStatus.scheduled:
        label = 'Scheduled';
        color = Colors.blueGrey;
        break;
      case VisitStatus.inProgress:
        label = 'In progress';
        color = Colors.orange.shade800;
        break;
      case VisitStatus.completed:
        label = 'Completed';
        color = Colors.green.shade700;
        break;
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}
