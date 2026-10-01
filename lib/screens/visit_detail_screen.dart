import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/visit.dart';
import '../providers/visits_provider.dart';
import '../services/visit_service.dart';
import '../utils/app_exception.dart';
import '../widgets/status_chip.dart';
import 'incident_screen.dart';

/// Screen 4: Visit Detail with GPS-gated check-in and check-out.
class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({super.key, required this.visitId});
  final String visitId;

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _distanceInfo;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshDistance(Visit v) async {
    final service = context.read<VisitService>();
    setState(() => _busy = true);
    try {
      final d = await service.distanceToClient(v);
      if (!mounted) return;
      final inRange = d <= VisitService.geofenceMetres;
      setState(() => _distanceInfo =
          'You are about ${d.round()} m from the client. ${inRange ? 'You can check in.' : 'Move closer to check in.'}');
    } on AppException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn(Visit v) async {
    final service = context.read<VisitService>();
    setState(() => _busy = true);
    try {
      final result = await service.checkIn(v);
      if (!mounted) return;
      _snack(result.synced
          ? 'Checked in (${result.distance.round()} m from client).'
          : 'Checked in. Saved on this device and will sync when you are online.');
      setState(() => _distanceInfo = null);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _distanceInfo = e.message);
        _snack(e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut(Visit v) async {
    final service = context.read<VisitService>();
    setState(() => _busy = true);
    try {
      final synced = await service.checkOut(v, _note.text);
      if (!mounted) return;
      _snack(synced
          ? 'Visit completed.'
          : 'Visit completed. Saved on this device and will sync when you are online.');
      Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<VisitsProvider>().byId(widget.visitId);
    if (v == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visit')),
        body: const Center(child: Text('This visit could not be found.')),
      );
    }
    final fmt = DateFormat('EEE d MMM, h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text(v.clientAlias)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(v.clientAlias, style: Theme.of(context).textTheme.titleLarge),
                      StatusChip(v.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _row(Icons.place_outlined, v.clientAddress),
                  _row(Icons.schedule, 'Scheduled: ${fmt.format(v.scheduledStart)}'),
                  if (v.checkInAt != null)
                    _row(Icons.login, 'Checked in: ${fmt.format(v.checkInAt!)}'),
                  if (v.distanceM != null)
                    _row(Icons.my_location,
                        'Verified ${v.distanceM!.round()} m from client (GPS accuracy ${v.accuracyM?.round() ?? '?'} m)'),
                  if (v.lowAccuracy)
                    _row(Icons.warning_amber, 'Low GPS accuracy: flagged for coordinator review'),
                  if (v.checkOutAt != null)
                    _row(Icons.logout, 'Checked out: ${fmt.format(v.checkOutAt!)}'),
                  if (v.duration != null)
                    _row(Icons.timer_outlined, 'Duration: ${v.duration!.inMinutes} min'),
                  if (v.note != null && v.note!.isNotEmpty)
                    _row(Icons.notes, 'Note: ${v.note}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_distanceInfo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_distanceInfo!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          if (v.status == VisitStatus.scheduled) ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => _checkIn(v),
              icon: _busy ? _spinner() : const Icon(Icons.location_on),
              label: const Text('Check in (GPS)'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _refreshDistance(v),
              child: const Text('Check my distance to the client'),
            ),
          ],
          if (v.status == VisitStatus.inProgress) ...[
            TextField(
              controller: _note,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Visit note (optional)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : () => _checkOut(v),
              icon: _busy ? _spinner() : const Icon(Icons.check_circle_outline),
              label: const Text('Check out'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => IncidentScreen(visit: v),
                    )),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Report an incident'),
          ),
        ],
      ),
    );
  }

  Widget _spinner() => const SizedBox(
      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
