import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/visits_provider.dart';
import '../widgets/error_banner.dart';
import '../widgets/status_chip.dart';
import 'visit_detail_screen.dart';

/// Screen 3: Today's Visits (real-time list from Firestore).
class VisitsScreen extends StatelessWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final visits = context.watch<VisitsProvider>();
    final items = visits.active;

    Widget body;
    if (visits.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (visits.error != null) {
      body = Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(visits.error!));
    } else if (items.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No visits to do right now.\n\nFor testing, open Profile and tap "Load demo visits".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final v = items[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(child: Icon(Icons.home_outlined)),
              title: Text(v.clientAlias, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${v.clientAddress}\n${DateFormat('EEE d MMM, h:mm a').format(v.scheduledStart)}'),
              isThreeLine: true,
              trailing: StatusChip(v.status),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VisitDetailScreen(visitId: v.id),
              )),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Today's visits")),
      body: body,
    );
  }
}
