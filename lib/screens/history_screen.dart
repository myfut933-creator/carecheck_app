import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/incident.dart';
import '../providers/auth_provider.dart';
import '../providers/visits_provider.dart';
import '../services/incident_service.dart';
import '../widgets/error_banner.dart';

/// Screen 6: History (completed visits and submitted incidents).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Visits'),
            Tab(icon: Icon(Icons.report_problem_outlined), text: 'Incidents'),
          ]),
        ),
        body: const TabBarView(children: [_VisitHistory(), _IncidentHistory()]),
      ),
    );
  }
}

class _VisitHistory extends StatelessWidget {
  const _VisitHistory();

  @override
  Widget build(BuildContext context) {
    final items = context.watch<VisitsProvider>().completed;
    if (items.isEmpty) {
      return const Center(child: Text('No completed visits yet.'));
    }
    final fmt = DateFormat('EEE d MMM, h:mm a');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = items[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(v.clientAlias),
            subtitle: Text(
                '${v.checkInAt != null ? fmt.format(v.checkInAt!) : fmt.format(v.scheduledStart)}'
                '${v.duration != null ? '  |  ${v.duration!.inMinutes} min' : ''}'
                '${v.lowAccuracy ? '\nLow GPS accuracy flagged' : ''}'),
            isThreeLine: v.lowAccuracy,
          ),
        );
      },
    );
  }
}

class _IncidentHistory extends StatelessWidget {
  const _IncidentHistory();

  Widget _buildIncidentImage(Incident inc) {
    if (inc.photoUrl == null) {
      return const Icon(Icons.report_problem_outlined, size: 32);
    }

    if (inc.photoUrl!.startsWith('data:')) {
      final marker = inc.photoUrl!.indexOf(',');
      if (marker != -1) {
        final bytes = base64Decode(inc.photoUrl!.substring(marker + 1));
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        inc.photoUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox.shrink();
    final fmt = DateFormat('d MMM, h:mm a');

    return StreamBuilder<List<Incident>>(
      stream: context.read<IncidentService>().watchIncidents(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child:
                ErrorBanner('Could not load incidents. Check your connection.'),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No incidents reported.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final inc = items[i];
            return Card(
              child: ListTile(
                leading: _buildIncidentImage(inc),
                title: Text('${inc.category}  (${inc.severity})'),
                subtitle: Text(
                  '${fmt.format(inc.createdAt)}${inc.clientAlias != null ? '  |  ${inc.clientAlias}' : ''}\n'
                  '${inc.description}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: inc.aiAssisted
                    ? const Tooltip(
                        message: 'AI-assisted wording',
                        child: Icon(Icons.auto_fix_high, size: 18))
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
